package CGI::Widget::DBI::Search;

require 5.004;
use strict;

# COPYRIGHT
#
# Copyright (c) 2004 - Adi Fairbank
#
# This software, the CGI::Widget::DBI::Search Perl module,
# is copyright Adi Fairbank
#
# LICENSE
#
# Perl Artistic License / GPL - see below, pod

use base qw(CGI::Widget::DBI::Search::Base);
use vars qw($VERSION);
$CGI::Widget::DBI::Search::VERSION = "0.10";

use DBI;

# --------------------- USER CUSTOMIZABLE VARIABLES ------------------------

# default values - these can be overridden by method parameters
use constant MAX_PER_PAGE => 20;

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
   -action_uri => 1, -display_table_padding => 1, -display_columns => 1,
   -numeric_columns => 1, -currency_columns => 1, -unsortable_columns => 1,
   -optional_header => 1, -optional_footer => 1, -href_extra_vars => 1,
   -where_clause => 1, -bind_params => 1, -opt_precols_sql => 1,
   -max_results_per_page => 1, -show_total_numresults => 1,
   -no_persistent_object => 1,
   # vars not beginning with '-' are instance vars, set by methods in class
   results => 1, numresults  => 1, page        => 1,
   sortby  => 1, page_sortby => 1, reversesort => 1
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

  use CGI::Widget::DBI::Search;

  $ws = CGI::Widget::DBI::Search->new(q => $self->{q}, -dbh => $self->{dbh});

  # the following shows a configuration for a car parts database search
  $ws->{-sql_table} = 'Cars2Diagram AS c, Diagram AS d, Parts AS p, DiagramScheme AS s';
  $ws->{-where_clause} = 'WHERE c.CarCode=? AND c.DiagramCode=d.DiagramCode AND d.Category=? AND d.DiagramCode=s.DiagramCode AND s.PartCode=p.PartCode';
  $ws->{-bind_params} = [$carcode, $category];
  $ws->{-sql_retrieve_columns} =
    [qw(p.PartCode p.PartName p.Description p.UnitPrice p.CoreCharge),
     '(p.UnitPrice + p.CoreCharge) AS TotalCharge'];
  $ws->{-display_columns} =
    { PartCode => "Code ", PartName => "Name", Description => "Description",
      UnitPrice => "Price", CoreCharge => "Core Charge", TotalCharge => "Total Charge",
    };

  $ws->{-numeric_columns} = { PartCode => 1 };
  $ws->{-currency_columns} = { UnitPrice => 1, CoreCharge => 1 };
  #$ws->{-display_table_padding} = 4;
  $ws->{-no_persistent_object} = 1;
  $ws->{-show_total_numresults} = 1;

  # execute database search
  $ws->search();

  # output search results to browser
  print $q->header;
  print $q->start_html;
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

=item Database retrieval options

  -sql_table            => Database table(s) to query,
  -sql_table_columns    => [ARRAY] List of all columns in sql_table,
  -sql_retrieve_columns => [ARRAY] List of columns for retrieval,
  -opt_precols_sql      => Optional SQL code to insert between 'SELECT' and
                           columns to retrieve (-sql_retrieve_columns).
                           This is commonly something like 'DISTINCT',
  -where_clause         => Literal SQL WHERE clause to use in SELECT state-
                           ment sent to database (may contain placeholders),
  -bind_params          => [ARRAY] If -where_clause used placeholders ("?"),
                           this must be the ordered values to use for them,
  -fetchrow_closure     => (CODE) A code ref to execute upon retrieving a
                           single row of data from database.  First arg to
                           closure will be calling object; subsequent args
                           will be the values of the retrieved row of data.
                           The closure's return value will be push()d onto the
                           object's results array, which is unique to a search,


=item Search result display options

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
      -{pre,post}_nondb_columns columns, you should define a
      -columndata_closure for each column you list)

  -optional_header        => Optional HTML header to display just above search
                             result display table,
  -optional_footer        => Optional HTML footer to display just below search
                             result display table,
  -href_extra_vars        => Literal string to append to column sorting and
                             navigation links in search result display table,
  -action_uri             => HTTP URI of script this is running under
                             (default: SCRIPT_NAME environment variable),
  -max_results_per_page   => Maximum number of database records to display on a
                             single page of search result display table,
  -show_total_numresults  => Show total number of records found by most recent
                             search, with First/Last page navigation links,
  -columndata_closure     => {HASH} of (CODE): Reference to a hash containing a
                             code reference for each column which should be
                             passed through before displaying in result table,

=item Universal options

  -no_persistent_object   => Inform object that we are not running under a
                             persistent object framework (eg. Apache::Session):
                             disable all features which enhance performance
                             under a persistence framework, and enable features
                             necessary for smooth operation without persistence,

=back

=head1 METHODS

=over 4

=item search([ $where_clause, $bind_params, $clobber ])

 input:  SQL WHERE clause and, optionally, arrayref of bind parameters
         (assuming you used placeholders in your WHERE clause)
 output: in self->{'results'}, a reference to a hash containing matched
         items

=cut

sub search {
    my ($self, $where_clause, $bind_params, $clobber) = @_;
    my $q = $self->{q};

    $self->{-dbi_connect_dsn} = DBI_CONNECT_DSN()
      unless $self->{-dbi_connect_dsn};
    # default to mysql dsn if no other was specified
    $self->{-dbi_connect_dsn} = 'DBI:mysql:database='.$self->{-sql_database}.
      ';host='.$self->{-dbi_host} unless $self->{-dbi_connect_dsn};
    $self->{-dbi_user} = DBI_USER() unless $self->{-dbi_user};
    $self->{-dbi_pass} = DBI_PASS() unless $self->{-dbi_pass};

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
    $self->{'page'} = 0 unless defined $self->{'page'};
    $self->{'page'} = $q->param('search_startat')
      if defined $q->param('search_startat');

    # return cached results if page has not changed
    if ($self->{'page'} == $old_page and ref $self->{'results'} eq "ARRAY") {
	$self->warn("search", "no page change, using cached results");
	return $self;
    }

    # read sortby column from cgi
    $self->{'sortby'} = $q->param('sortby') if $q->param('sortby');

    $self->{-where_clause} = $where_clause if $where_clause;
    $self->{-bind_params} = $bind_params if ref $bind_params eq "ARRAY";
    $self->{-max_results_per_page} = MAX_PER_PAGE
      unless $self->{-max_results_per_page};
    $self->{-limit_clause} =
      ('LIMIT '.($self->{-max_results_per_page}*$self->{'page'}).','.
       $self->{-max_results_per_page});
    $self->{-orderby_clause} = 'ORDER BY '.$self->{'sortby'}
      if $self->{'sortby'};

    eval {
	my $dbh = ref $self->{-dbh} eq "DBI::db" ? $self->{-dbh}
	  : DBI->connect($self->{-dbi_connect_dsn}, $self->{-dbi_user},
			 $self->{-dbi_pass}, {'RaiseError' => 1});
	my $sql = ("SELECT ".$self->{-opt_precols_sql}." ".
		   join(',', @{$self->{-sql_retrieve_columns}}).
		   " FROM ".$self->{-sql_table}." ".$self->{-where_clause}." ".
		   $self->{-orderby_clause}." ".$self->{-limit_clause});
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
	   : sub {
	       shift;
	       return { map { my $c = $self->{-sql_retrieve_columns}->[$_];
			      $c =~ s/.*[. ](\w+)$/$1/;
			      $c => $_[$_]; } 0..$#_ };
	   });
	while ($sth->fetchrow_arrayref) {
	    push(@{$self->{'results'}}, $closure->($self, @row_data));
	}

	$sth->finish;

	# read total number of results in search set
	if ($self->{-show_total_numresults}) {
	    $sth = $dbh->prepare_cached
	      ("SELECT COUNT(*) FROM ".$self->{-sql_table}." ".$self->{-where_clause});
	    $sth->execute(@{$self->{-bind_params}});
	    my $ary_ref = $sth->fetchrow_arrayref;
	    $self->{'numresults'} = $ary_ref->[0];
	    $sth->finish;
	}

	$dbh->disconnect unless ref $self->{-dbh} eq "DBI::db";
    };
    if ($@) {
	$self->log_error("search", $@);
	return undef;
    }

    #$self->pagesort_results($self->{'page_sortby'}) if $self->{'page_sortby'};
    return $self;
}


=item pagesort_results($col, $reverse)

 input:  column to sort by, $col
         boolean flag $reverse
 output: none; but self->{'results'} will be reordered
 desc:   sorts a single page of results.  this method is not currently used.

=cut

sub pagesort_results {
    my ($self, $col, $reverse) = @_;

    # handle sorting by arbitrary data column
    if ($self->{'page_sortby'} and $reverse) {
	# toggle reverse flag if they clicked the current sort column
	$self->{'reversesort'}->{$self->{'page_sortby'}} =
	  $self->{'reversesort'}->{$self->{'page_sortby'}} ? 0 : 1;
	@{$self->{'results'}} = reverse @{$self->{'results'}};
    } else {
	# set new page_sortby column, and sort results array
	$self->{'page_sortby'} = $col;
	@{$self->{'results'}} = sort {
	    ($self->{-numeric_columns}->{$self->{'page_sortby'}} ||
	     $self->{-currency_columns}->{$self->{'page_sortby'}}
	     ? $a->{$self->{'page_sortby'}} <=> $b->{$self->{'page_sortby'}}
	     : uc($a->{$self->{'page_sortby'}}) cmp uc($b->{$self->{'page_sortby'}}))
	} @{$self->{'results'}};
	@{$self->{'results'}} = reverse @{$self->{'results'}}
	  if $self->{'reversesort'}->{$self->{'page_sortby'}};
    }
}


=item display_results([ $disp_cols ])

 input:  a hashref $disp_cols, which contains colname => label pairs to
         display in an HTML table.  the set of keys in the hash must be a
         subset of $self->{-sql_table_columns}
 output: an HTML table displaying data values that were retrieved from the
         most recent call to search() - and hence stored in 'results'

=cut

sub display_results {
    my ($self, $disp_cols) = @_;
    my $q = $self->{q};

    unless (ref $self->{'results'} eq "ARRAY" and
	    (ref $self->{-sql_table_columns} eq "ARRAY" or
	     ref $self->{-sql_retrieve_columns} eq "ARRAY")) {
	$self->log_error("display_results", "instance variables '-sql_table_columns' or '-sql_retrieve_columns', and data resultset 'results' (ARRAYs) are required");
	return undef;
    }

    my $action_uri = $self->{-action_uri}
      ? $self->{-action_uri} : $ENV{SCRIPT_NAME};

    # read ordered list of table columns
    my @sql_table_columns = ref $self->{-sql_retrieve_columns} eq "ARRAY"
      ? @{$self->{-sql_retrieve_columns}} : @{$self->{-sql_table_columns}};
    my @pre_nondb_columns = ref $self->{-pre_nondb_columns} eq "ARRAY"
      ? @{$self->{-pre_nondb_columns}} : ();
    my @post_nondb_columns = ref $self->{-post_nondb_columns} eq "ARRAY"
      ? @{$self->{-post_nondb_columns}} : ();

    $self->{-display_columns} = $disp_cols if ref $disp_cols eq "HASH";
    $self->{-display_columns} =
      { map {my $c=$_; $c =~ s/.*[. ](\w+)$/$1/; $c=>$c} @sql_table_columns }
	unless ref $self->{-display_columns} eq "HASH";

    $self->{-unsortable_columns} = {}
      unless ref $self->{-unsortable_columns} eq "HASH";

#    if ($q->param('page_sortby') and
#	!$self->{-unsortable_columns}->{$q->param('page_sortby')}) {
#	$self->pagesort_results($q->param('page_sortby'),
#			    $self->{'page_sortby'} eq $q->param('page_sortby'));
#    }

    # build displayed column headers along with sort links and direction arrow
    my (@cols, $header_labels, @rows);
    foreach my $col (@pre_nondb_columns, @sql_table_columns, @post_nondb_columns) {
	# remove any "tbl." if SQL stmt uses tbl aliases
	$col =~ s/.*[. ](\w+)$/$1/;
	if ($self->{-display_columns}->{$col}) {
	    push(@cols, $col);
	    if ($self->{-unsortable_columns}->{$col}) {
		$header_labels .=
		  $q->td({-bgcolor => TABLE_HEADER_BGCOLOR(),
			  ($self->{-currency_columns}->{$col}
			   ? (-align=>'right') : ()), -nowrap},
			 $self->{-display_columns}->{$col});
	    } else {
		# if no page_sortby column was set, use first sortable one
		#$self->pagesort_results($col) unless $self->{'page_sortby'};
		$header_labels .= $q->td
		  ({-bgcolor => TABLE_HEADER_BGCOLOR(),
		    ($self->{-currency_columns}->{$col}
		     ? (-align=>'right') : ()), -nowrap},
		   ($col eq $self->{'sortby'} ? "<B>" : "") .
		   $q->a({-href => BASE_URI().$action_uri.'?sortby='.$col.
			  $self->{-href_extra_vars}},
			 $self->{-display_columns}->{$col}) . " " .
		   ($col eq $self->{'sortby'}
		    ? ($self->{'reversesort'}->{$col} ? '\\/' :'/\\')."</B>"
		    : ''));
	    }
	}
    }

    # iterate over most recently returned 'results', which should be a
    # (possibly blessed) hashref
    my $color;
    foreach my $item (@{$self->{'results'}}) {
	# toggle color
	$color = ($color eq TABLE_BGCOLOR2()
		  ? TABLE_BGCOLOR1()
		  : TABLE_BGCOLOR2());

	# build a table row
	push(@rows, join '', map {
	    (ref $self->{-columndata_closures}->{$_} eq "CODE"
	     ? $self->{-columndata_closures}->{$_}->($self, $item, $color)
	     : $self->{-currency_columns}->{$_}
	     ? $q->td({-bgcolor => $color, -align => 'right'},
		      sprintf('$%.2f', $item->{$_}))
	     : $q->td({-bgcolor => $color}, $item->{$_}))
	} @cols );
    }

    my $firstlink = my $lastlink;
    my $prevlink = my $nextlink = BASE_URI().$action_uri.'?search_startat=';
    if ($self->{-show_total_numresults}) {
	$firstlink = $lastlink = $prevlink;
	$firstlink .= '0';
	$lastlink .= int(($self->{'numresults'}-1) /
			 $self->{-max_results_per_page});
    }
    $prevlink .= $self->{'page'} - 1;
    $nextlink .= $self->{'page'} + 1;
    if ($self->{-no_persistent_object} and $self->{'sortby'}) {
	$prevlink .= '&sortby='.$self->{'sortby'};
	$nextlink .= '&sortby='.$self->{'sortby'};
	$firstlink .= '&sortby='.$self->{'sortby'} if $firstlink;
	$lastlink .= '&sortby='.$self->{'sortby'} if $lastlink;
    }
    if ($self->{-href_extra_vars}) {
	$prevlink .= $self->{-href_extra_vars};
	$nextlink .= $self->{-href_extra_vars};
	$firstlink .= $self->{-href_extra_vars} if $firstlink;
	$lastlink .= $self->{-href_extra_vars} if $lastlink;
    }

    return
      ($self->{-optional_header} .
       $self->display_pager_links
       ($self->{'page'}, $#{$self->{'results'}}+1,
	$self->{-max_results_per_page}, $self->{'numresults'},
	$prevlink, $nextlink, $firstlink, $lastlink, 1) .
       $q->table
       ({-cellpadding => $self->{-display_table_padding}
	 ? $self->{-display_table_padding} : '2', -width => '96%'}, $q->Tr
	([ $header_labels, @rows ])) .
       $self->display_pager_links
       ($self->{'page'}, $#{$self->{'results'}}+1,
	$self->{-max_results_per_page}, $self->{'numresults'},
	$prevlink, $nextlink, $firstlink, $lastlink) .
       $self->{-optional_footer}
      );
}


=item display_pager_links($startat, $pagetotal, $maxpagesize, $searchtotal,
			  $prevlink, $nextlink, $firstlink, $lastlink, $showtotal)

 input:  $startat	page of results on which to start
         $pagetotal	number of items on *this* page
         $maxpagesize	size of page: maximum number of items to show per page
         $searchtotal	total number of items returned by search
         $prevlink	HTML href link to previous page of results
         $nextlink	HTML href link to next page of results
         $firstlink	HTML href link to first page of results
         $lastlink	HTML href link to last page of results
         $showtotal	boolean to toggle whether to show total number
			of results along with range on current page
 output: an HTML table containing navigation links for first, previous, next,
         and last pages of result set

=back

=cut

sub display_pager_links {
    my ($self, $startat, $pagetotal, $maxpagesize, $searchtotal,
	$prevlink, $nextlink, $firstlink, $lastlink, $showtotal) = @_;
    my $q = $self->{q};

    return
      ($q->table
       ({-width => '96%'},
	$q->Tr($q->td({-align => 'left', -width => $showtotal ? '30%' : '50%'},
		      $q->font({-size => '-1'},
			       ($startat > 0
				? $q->b(($firstlink
					 ? $q->a({-href =>$firstlink},"|&lt;First").'&nbsp;&nbsp;&nbsp;'
					 : '').
					$q->a({-href =>$prevlink},"&lt;Previous"))
				: "|At first page"))) .
	       ($showtotal
		? $q->td({-width => '40%'}, "<B>$pagetotal</B> result".
			 ($pagetotal == 1 ? '':'s')." displayed:".
			 ($searchtotal ? ' <B>'.($startat*$maxpagesize + 1).' - '.($startat*$maxpagesize + $pagetotal).'</B> of <B>'.$searchtotal.'</B>' : ''))
		: '') .
	       $q->td({-align => 'right',-width => $showtotal ? '30%' : '50%'},
		      $q->font({-size => '-1'},
			       (defined $searchtotal && defined $maxpagesize &&
				#$pagetotal >= $maxpagesize
				$startat != int(($searchtotal-1)/$maxpagesize)
				? $q->b($q->a({-href =>$nextlink},"Next&gt;").
					($lastlink
					 ? '&nbsp;&nbsp;&nbsp;'.$q->a({-href =>$lastlink},"Last&gt;|")
					 : ''))
				: "At last page|"))))
       ));
}


1;
__END__

=head1 AUTHOR

Adi Fairbank <adi@adiraj.org>

=head1 COPYRIGHT

Copyright (c) 2004 - Adi Fairbank

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

April 01, 2004

=cut
