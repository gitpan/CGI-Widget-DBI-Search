package CGI::Widget::DBI::Search;

use strict;

use base qw/ CGI::Widget::DBI::Search::Base /;
use vars qw/ $VERSION /;
$CGI::Widget::DBI::Search::VERSION = '0.21';

use DBI;

# --------------------- USER CUSTOMIZABLE VARIABLES ------------------------

# default values - these can be overridden by method parameters
use constant MAX_PER_PAGE => 20;
use constant PAGE_RANGE_NAV_LIMIT => 10;

use constant SQL_DATABASE       => "";

use constant DBI_CONNECT_HOST   => "localhost";
#use constant DBI_CONNECT_DSN    => 'DBI:mysql:database='.SQL_DATABASE().';host='.DBI_CONNECT_HOST();
use constant DBI_CONNECT_DSN    => "";
use constant DBI_USER           => "";
use constant DBI_PASS           => "";

use constant BASE_URI             => '';
use constant TABLE_HEADER_BGCOLOR => '#cccccc';
use constant TABLE_BGCOLOR1       => '#eeeeee';
use constant TABLE_BGCOLOR2       => '#ffffff';

# --------------------- END USER CUSTOMIZABLE VARIABLES --------------------


# instance variables to keep across http requests
#  NOTE: closure variables should NOT be kept! Storable cannot handle CODE refs
use constant VARS_TO_KEEP =>
  {# vars beginning with '-' are object config vars, set by programmer
   -sql_table => 1, -sql_table_columns => 1, -sql_retrieve_columns => 1,
   -pre_nondb_columns => 1, -post_nondb_columns => 1,
   -action_uri => 1, -display_table_padding => 1,
   -display_columns => 1, -unsortable_columns => 1,
   -numeric_columns => 1, -currency_columns => 1, -default_orderby_columns => 1,
   -optional_header => 1, -optional_footer => 1, -href_extra_vars => 1,
   -where_clause => 1, -bind_params => 1, -opt_precols_sql => 1,
   -max_results_per_page => 1, -page_range_nav_limit => 1, -show_total_numresults => 1,
   -no_persistent_object => 1,
   # vars not beginning with '-' are instance vars, set by methods in class
   results => 1, numresults => 1, page => 1, lastpage => 1, sortby  => 1,
   page_sortby => 1, reverse_pagesort => 1,
  };

sub cleanup {
    my ($self) = @_;
    # delete instance variables not set to keep across http requests
    while (my ($k, $v) = each %$self) {
	delete $self->{$k} unless VARS_TO_KEEP->{$k};
    }
}

=head1 NAME

CGI::Widget::DBI::Search - Database search widget

=head1 SYNOPSIS

  use CGI;
  use CGI::Widget::DBI::Search;

  my $q = CGI->new;
  my $ws = CGI::Widget::DBI::Search->new(q => $q);

  # database connection info
  $ws->{-dbi_connect_dsn} = 'DBI:Pg:dbname=my_pg_database;host=localhost';
  $ws->{-dbi_user} = 'pguser';
  $ws->{-dbi_pass} = 'pgpass';

  # what table to use in the SQL query FROM clause
  $ws->{-sql_table} = 'table1 t1 inner join table2 t2 using (key_col)';

  # optional WHERE clause
  $ws->{-where_clause} = 'WHERE t1.filter = ? OR t2.filter != ?';
  # bind params needed for WHERE clause
  $ws->{-bind_params} = [ $filter, $inverse_filter ];

  # what columns to retrieve from query
  $ws->{-sql_retrieve_columns} =
    [ qw/t1.id t1.name t2.long_description/, '(t1.price + t2.price) AS total_price'];
  # what columns to display in search results (with header name)
  $ws->{-display_columns} =
    { id => "ID", name => "Name", long_description => "Description", total_price => "Price" };

  $ws->{-numeric_columns} = { id => 1 };
  $ws->{-currency_columns} = { total_price => 1 };

  $ws->{-show_total_numresults} = 1;

  # execute database search
  $ws->search();

  # output search results to browser
  print $q->header;
  print $q->start_html;

  # show search results as HTML
  print $ws->display_results();

  print $q->end_html;

=head1 DESCRIPTION

Encapsulates a DBI search in a Perl class, including all SQL statements
required for performing the search, query results, HTML display methods,
and multi-column, sortable result set displayed page-by-page
(using HTML navigation links).

=head1 CONSTRUCTOR

=item new(@config_options)

Creates and initializes a new CGI::Widget::DBI::Search object.
Possible configuration options:

=over 4

=item Database connection options

  -dbi_connect_dsn      => DBI data source name (full connection string)
  -dbi_user             => database username
  -dbi_pass             => database password
  -dbi_host             => host to connect to database (overridden by -dbi_connect_dsn)
  -sql_database         => database to connect to (overridden by -dbi_connect_dsn)

=item Database retrieval options

  -sql_table            => Database table(s) to query,
  -sql_table_columns    => [ARRAY] List of all columns in sql_table,
  -sql_retrieve_columns => [ARRAY] List of columns for retrieval,
  -opt_precols_sql      => Optional SQL code to insert between 'SELECT' and
                           columns to retrieve (-sql_retrieve_columns).
                           This is commonly something like 'DISTINCT',
  -where_clause         => Literal SQL WHERE clause to use in SELECT state-
                           ment sent to database (may contain placeholders),
  -default_orderby_columns => [ARRAY] Default list of columns to use in ORDER BY
                           clause.  If 'sortby' cgi param is passed (e.g. from
                           user clicking a column sort link), it will always be
                           the first column in the ORDER BY clause, with these
                           coming after it.
  -bind_params          => [ARRAY] If -where_clause used placeholders ("?"),
                           this must be the ordered values to use for them,
  -fetchrow_closure     => (CODE) A code ref to execute upon retrieving a
                           single row of data from database.  First arg to
                           closure will be calling object; subsequent args
                           will be the values of the retrieved row of data.
                           The closure's return value will be push()d onto the
                           object's results array, which is unique to a search.
                           It should be a hash reference with a key for each
                           column returned in the search, and values with the
                           search field values.


=item Search result display options

The following settings affect display of search results, but also affect
the search logic (SQL query executed).

  -max_results_per_page   => Maximum number of database records to display on a
                             single page of search result display table
                             (default: 20)
  -show_total_numresults  => Show total number of records found by most recent
                             search, with First/Last page navigation links
                             (default: true)

The following settings only affect display of search results, not the
search logic.

  -display_table_padding  => Size of HTML display table cellpadding attribute,
  -display_columns        => {HASH} Associative array holding column names as
                             keys, and labels for display table as values,
  -numeric_columns        => {HASH} Columns of numeric type should have a
                             true value in this hash,
  -currency_columns       => {HASH} Columns of monetary value should have a
                             true value in this hash,
  -unsortable_columns     => {HASH} Columns which the user should not be able
                             to sort should have a true value in this hash,
  -pre_nondb_columns      => [ARRAY] Columns to show left of database columns
                             in display table,
  -post_nondb_columns     => [ARRAY] Columns to show right of database columns
                             in display table,
     (Note: Since no data from the database will be present for
      -{pre,post}_nondb_columns columns, you should define
      -columndata_closures for each column you list)

  -optional_header        => Optional HTML header to display just above search
                             result display table,
  -optional_footer        => Optional HTML footer to display just below search
                             result display table,
  -href_extra_vars        => Extra CGI params to append to column sorting and
                             navigation links in search result display table.
                             May be either a HASHREF or a literal string
                             containing key/values to append.  If a key in the
                             HASHREF has an undef value, will take the value
                             from an existing CGI param on request named the
                             same as key.
  -action_uri             => HTTP URI of script this is running under
                             (default: SCRIPT_NAME environment variable),
  -page_range_nav_limit   => Maximum number of pages to allow user to navigate to
                             before and after the current page in the result set
                             (default: 10)
  -columndata_closures    => {HASH} of (CODE): Reference to a hash containing a
                             code reference for each column which should be
                             passed through before displaying in result table.
                             Each closure will be passed 3 arguments:
                              $searchobj (this CGI::Widget::DBI::Search object),
                              $row (the current row from the result set)
                              $color (the current background color of this row)
                             and is (currently) expected to return an HTML table
                             cell (e.g. "<td>blah</td>")

=item Universal options

  -no_persistent_object   => Inform object that we are not running under a
                             persistent object framework (eg. Apache::Session):
                             disable all features which enhance performance
                             under a persistence framework, and enable features
                             necessary for smooth operation without persistence
                             (default: true)

=back

=head1 PRIVATE METHODS

=over 4

=item _set_defaults()

Sets necessary object variables from defaults in package constants, if not already set.
Called from search() method.

=cut

sub _set_defaults {
    my ($self) = @_;

    $self->{-dbi_connect_dsn} ||= DBI_CONNECT_DSN();
    # default to mysql dsn if no other was specified
    $self->{-dbi_connect_dsn} ||=
      'DBI:mysql:database='.($self->{-sql_database}||'').';host='.($self->{-dbi_host}||'');
    $self->{-dbi_user} ||= DBI_USER();
    $self->{-dbi_pass} ||= DBI_PASS();

    $self->{-show_total_numresults} = 1
      unless defined $self->{-show_total_numresults};
    $self->{-no_persistent_object} = 1
      unless defined $self->{-no_persistent_object};
}


=head1 METHODS

=over 4

=item default_fetchrow_closure()

This is the default -fetchrow_closure that will be called for each row returned
by a search.  It can be called by an overridden -fetchrow_closure to selectively
modify desired fields.

=cut

sub default_fetchrow_closure {
    my $self = shift;
    return { map {
        my $col = $self->{-sql_retrieve_columns}->[$_];
        $col =~ s/.*[. ](\w+)$/$1/; # strip off table name or pre-alias column name
        $col => $_[$_];
    } 0 .. $#_ };
};


=item search([ $where_clause, $bind_params, $clobber ])

Perform the search: runs the database query, and stores the matched results in an
object variable: 'results'.

Optional parameters $where_clause and $bind_params will override object
variables -where_clause and -bind_params.  If $clobber is true, search results
from a previous execution will be deleted before running new search.

=cut

sub search {
    my ($self, $where_clause, $bind_params, $clobber) = @_;
    my $q = $self->{q};

    $self->_set_defaults;

    # method call syntax checks
    unless ($self->{-sql_table} and
	    ref $self->{-sql_retrieve_columns} eq "ARRAY" and
	    (ref $self->{-dbh} eq "DBI::db" or $self->{-dbi_connect_dsn} and
	     defined $self->{-dbi_user} and defined $self->{-dbi_pass})) {
	$self->log_error("search", "instance variables '-sql_table' (SCALAR), '-sql_retrieve_columns' (ARRAY); '-dbh' or '-dbi_connect_dsn' and '-dbi_user' and '-dbi_pass' (SCALARs) are required");
	return undef;
    }

    # clobber old search results if desired
    if ($clobber) {
	delete $self->{-where_clause};
	delete $self->{-bind_params};
	delete $self->{'results'};
    }

    # handle paging logic
    my $old_page = $self->{'page'};
    $self->{'page'} ||= 0;
    $self->{'page'} = $q->param('search_startat')
      if defined $q->param('search_startat');

    # return cached results if page has not changed
    if (defined $old_page && $self->{'page'} == $old_page && ref $self->{'results'} eq "ARRAY") {
	$self->warn("search", "no page change, using cached results");
	return $self;
    }

    # read sortby column from cgi
    $self->{'sortby'} = $q->param('sortby') if $q->param('sortby');
    $self->{'sort_reverse'} = $q->param('sort_reverse') if $q->param('sort_reverse');

    $self->{-where_clause} = $where_clause if $where_clause;
    $self->{-bind_params} = $bind_params if ref $bind_params eq "ARRAY";
    $self->{-max_results_per_page} ||= MAX_PER_PAGE;
    $self->{-page_range_nav_limit} ||= PAGE_RANGE_NAV_LIMIT;
    $self->{-limit_clause} =
      ('LIMIT '.($self->{-max_results_per_page}*$self->{'page'}).','.
       $self->{-max_results_per_page});

    my @orderby;
    if (ref $self->{-default_orderby_columns} eq 'ARRAY') {
        @orderby = @{ $self->{-default_orderby_columns} };
    }
    if ($self->{'sortby'}) {
        @orderby = ($self->{'sortby'}, grep($_ ne $self->{'sortby'}, @orderby));
    }
    $self->{-orderby_clause} =
      'ORDER BY '.join(',', map {$_.($self->{'sort_reverse'} ? ' DESC' : '')} @orderby)
        if @orderby;

    eval {
	my $should_disconnect = !(ref $self->{-dbh} eq "DBI::db");
	my $dbh = $self->{-dbh} = ref $self->{-dbh} eq "DBI::db"
	  ? $self->{-dbh}
	  : DBI->connect($self->{-dbi_connect_dsn}, $self->{-dbi_user},
			 $self->{-dbi_pass}, {'RaiseError' => 1});

	my $sql = ("SELECT ".($self->{-opt_precols_sql}||'')." ".
		   join(',', @{$self->{-sql_retrieve_columns}}).
		   " FROM ".$self->{-sql_table}." ".($self->{-where_clause}||'')." ".
		   ($self->{-orderby_clause}||'')." ".($self->{-limit_clause}||''));
	my $sth = $dbh->prepare_cached($sql);

	$sth->execute(@{$self->{-bind_params}});
	$self->warn("search", "SQL statement executed: $sql; bind params: ".join(', ', @{$self->{-bind_params}}));

	my @row_data;
	$sth->bind_columns
	  (map { \$row_data[$_] } 0..$#{$self->{-sql_retrieve_columns}});

	$self->{'results'} = [];
	my $closure =
	  (ref $self->{-fetchrow_closure} eq "CODE"
	   ? $self->{-fetchrow_closure}
	   : \&default_fetchrow_closure);
	while ($sth->fetchrow_arrayref) {
	    push(@{$self->{'results'}}, $closure->($self, @row_data));
	}

	$sth->finish;

	$self->get_num_results;

	$dbh->disconnect if $should_disconnect;
    };
    if ($@) {
	$self->log_error("search", $@);
	return undef;
    }

    #$self->pagesort_results($self->{'page_sortby'}) if $self->{'page_sortby'};
    return $self;
}

=item get_num_results()

Executes a SELECT COUNT() query with the current search parameters and stores result
in object variable: 'numresults'.  Has no effect unless -show_total_numresults object
variable is true.  As a side-effect, this method also sets the 'lastpage' object
variable which, no surprise, is the page number denoting the last page in the search
result set.

This is used for displaying total number of results found, and is
necessary to provide a last-page link to skip to the end of the search results.

=cut

sub get_num_results {
    my ($self) = @_;
    return unless $self->{-show_total_numresults};

    # read total number of results in search set
    my $sth = $self->{-dbh}->prepare_cached
      ("SELECT COUNT(1) FROM ".$self->{-sql_table}." ".($self->{-where_clause}||''));
    $sth->execute(@{$self->{-bind_params}});
    my $ary_ref = $sth->fetchrow_arrayref;
    $sth->finish;
    $self->{'numresults'} = $ary_ref->[0];
    $self->{'lastpage'} = int(($self->{'numresults'} - 1) / $self->{-max_results_per_page});
    return $self->{'numresults'};
}

=item pagesort_results($col, $reverse)

Sorts a single page of results by column $col.  Reorders object variable 'results'
based on sort column $col and boolean $reverse parameters.

(note: method currently unused)

=cut

# sub pagesort_results {
#     my ($self, $col, $reverse) = @_;

#     # handle sorting by arbitrary data column
#     if ($self->{'page_sortby'} and $reverse) {
# 	# toggle reverse flag if they clicked the current sort column
# 	$self->{'reverse_pagesort'}->{$self->{'page_sortby'}} =
# 	  $self->{'reverse_pagesort'}->{$self->{'page_sortby'}} ? 0 : 1;
# 	@{$self->{'results'}} = reverse @{$self->{'results'}};
#     } else {
# 	# set new page_sortby column, and sort results array
# 	$self->{'page_sortby'} = $col;
# 	@{$self->{'results'}} = sort {
# 	    ($self->{-numeric_columns}->{$self->{'page_sortby'}} ||
# 	     $self->{-currency_columns}->{$self->{'page_sortby'}}
# 	     ? $a->{$self->{'page_sortby'}} <=> $b->{$self->{'page_sortby'}}
# 	     : uc($a->{$self->{'page_sortby'}}) cmp uc($b->{$self->{'page_sortby'}}))
# 	} @{$self->{'results'}};
# 	@{$self->{'results'}} = reverse @{$self->{'results'}}
# 	  if $self->{'reverse_pagesort'}->{$self->{'page_sortby'}};
#     }
# }

=item display_results([ $disp_cols ])

Displays an HTML table of data values stored in object variable 'results' (retrieved
from the most recent call to search() method).  Optional variable $disp_cols overrides
object variable -display_columns.

=cut

sub display_results {
    my ($self, $disp_cols) = @_;
    unless (ref $self->{'results'} eq "ARRAY" &&
	    (ref $self->{-sql_table_columns} eq "ARRAY" ||
	     ref $self->{-sql_retrieve_columns} eq "ARRAY")) {
	$self->log_error("display_results", "instance variables '-sql_table_columns' or '-sql_retrieve_columns', and data resultset 'results' (ARRAYs) are required");
	return undef;
    }

    $self->{-display_columns} = $disp_cols if ref $disp_cols eq "HASH";

    use CGI::Widget::DBI::Search::Display::Table;
    $self->{display} = CGI::Widget::DBI::Search::Display::Table->new($self);
    $self->_transfer_display_settings();
    return $self->{display}->display();
}

=item _transfer_display_settings()

Transfers all display-specific settings from search widget object to the
search display widget object.

=cut

sub _transfer_display_settings {
    my ($self) = @_;
    foreach my $var (
        qw/-action_uri
           -columndata_closures
           -currency_columns
           -display_columns
           -display_table_padding
           -href_extra_vars
           -numeric_columns
           -optional_header
           -optional_footer
           -page_range_nav_limit
           -post_nondb_columns
           -pre_nondb_columns
           -unsortable_columns
          /) {
        if (defined $self->{$var}) {
            $self->{display}->{$var} = $self->{$var};
            delete $self->{$var};
        }
    }
}


1;
__END__

=head1 AUTHOR

Adi Fairbank <adi@adiraj.org>

=head1 COPYRIGHT

Copyright (c) 2004-2008 - Adi Fairbank

This software, the CGI::Widget::DBI::Search Perl module,
is copyright Adi Fairbank.

=head1 COPYLEFT (LICENSE)

This module is free software; you can redistribute it and/or modify it
under the terms of either:

  a) the GNU General Public License as published by the Free Software
     Foundation; either version 1, or (at your option) any later version,

  or

  b) the "Artistic License" which comes with this module.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See either the GNU General Public
License or the Artistic License for more details.

You should have received a copy of the Artistic License with this module,
in the file ARTISTIC; if not, the following URL references a copy of it
(as of June 8, 2003):

  http://www.perl.com/language/misc/Artistic.html

You should have received a copy of the GNU General Public License along
with this program, in the file GPL; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA;
or try the following URL which references a copy of it (as of June 8, 2003):

  http://www.fsf.org/licenses/gpl.html

=head1 LAST MODIFIED

Apr 9, 2008

=cut
