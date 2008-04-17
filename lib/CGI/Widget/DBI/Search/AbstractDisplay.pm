package CGI::Widget::DBI::Search::AbstractDisplay;

use strict;

use base qw/ CGI::Widget::DBI::Search::Base /;

sub new {
    my ($this, $search) = @_;
    my $class = ref($this) || $this;
    my $self = bless {}, $class;
    $self->{s} = $search if $search;
    $self->{q} = $search->{q} if $search->{q};
    return $self;
}

=head1 NAME

CGI::Widget::DBI::Search::AbstractDisplay - Abstract Display class inherited by default display classes

=head1 SYNOPSIS

  package My::SearchWidget::DisplayClass;

  use base qw/ CGI::Widget::DBI::Search::AbstractDisplay /;

  # ... implement abstract methods

=head1 DESCRIPTION

This abstract class defines several methods useful to display classes, and is the base
class of all default display classes (shipped with this distribution).

=head1 ABSTRACT METHODS

=over 4

=item render_dataset()

=item display_dataset()

=back

=cut

sub render_dataset { die 'abstract'; }
sub display_dataset { die 'abstract'; }

=head1 METHODS

=over 4

=item display()

This is the top-level method called by L<CGI::Widget::DBI::Search>.  The default
implementation calls the _set_display_defaults() and render_dataset() methods,
then returns the result of the display_dataset() method.

If this method is overridden, it should return the rendering of the search
widget UI from data values stored in the search widget's 'results' object
variable (retrieved from the most recent call to its search() method).

=cut

sub display {
    my ($self) = @_;
    my $q = $self->{q};

    $self->_set_display_defaults();

    $self->render_dataset();

    return $self->display_dataset();
}

=item _set_display_defaults()

Sets object variables for displaying search results.  Called from display() method.

=cut

sub _set_display_defaults {
    my ($self) = @_;
    $self->{'action_uri'} = $self->{-action_uri} || $ENV{SCRIPT_NAME} || '';

    if (ref $self->{-href_extra_vars} eq "HASH") {
        $self->{'href_extra_vars'} = join('&', map {
            "$_=".(defined $self->{-href_extra_vars}->{$_}
                   ? $self->{-href_extra_vars}->{$_}
                   : $self->{q}->param($_));
        } keys %{$self->{-href_extra_vars}});
    } elsif ($self->{-href_extra_vars}) {
        $self->{'href_extra_vars'} = $self->{-href_extra_vars};
    }
    $self->{'href_extra_vars'} = '&'.$self->{'href_extra_vars'}
      if $self->{'href_extra_vars'} && $self->{'href_extra_vars'} !~ m/^&/;

    # read ordered list of table columns
    $self->{'sql_table_display_columns'} = ref $self->{s}->{-sql_retrieve_columns} eq "ARRAY"
      ? [ @{$self->{s}->{-sql_retrieve_columns}} ] : [ @{$self->{s}->{-sql_table_columns}} ];

    $self->_init_header_columns();
}

=item _init_header_columns()

Initializes list of columns to display in dataset, based on 'sql_table_display_columns'
object variable, and -pre_nondb_columns, -post_nondb_columns, and -display_columns
settings.

=cut

sub _init_header_columns {
    my ($self) = @_;
    $self->{'header_columns'} = [];
    my $init_display_columns = ! (ref $self->{-display_columns} eq "HASH");
    foreach my $sql_col (@{ $self->{-pre_nondb_columns} || [] },
                         @{ $self->{'sql_table_display_columns'} },
                         @{ $self->{-post_nondb_columns} || [] }) {
        my $col = $sql_col;
        $col =~ s/.*[. ](\w+)$/$1/;
        $self->{-display_columns}->{$col} = $col if $init_display_columns;
        push(@{ $self->{'header_columns'} }, $col) if $self->{-display_columns}->{$col};
    }
}

=item sortby_column_uri($column)

Returns URI for sorting the dataset by the given column.  If the dataset is currently
sorted by $column, then the URI returned will be for reversing the sort.

=cut

sub sortby_column_uri {
    my ($self, $column) = @_;
    my $sortby = $self->{s}->{'sortby'} && $column eq $self->{s}->{'sortby'};
    return $self->{s}->BASE_URI() . $self->{'action_uri'}
      . '?sortby=' . $column
      . ($sortby ? '&sort_reverse='.($self->{s}->{'sort_reverse'} ? '0':'1') : '')
      . ($self->{'href_extra_vars'} || '');
}

=item prev_page_uri()

Returns URI of location to previous page in search results.

=cut

sub prev_page_uri {
    my ($self) = @_;
    $self->{'prevlink'} ||= make_nav_uri($self, $self->{s}->{'page'} - 1);
    return $self->{'prevlink'};
}

=item next_page_uri()

Returns URI of location to next page in search results.

=cut

sub next_page_uri {
    my ($self) = @_;
    $self->{'nextlink'} ||= make_nav_uri($self, $self->{s}->{'page'} + 1);
    return $self->{'nextlink'};
}

=item first_page_uri()

Returns URI of location to first page in search results.

=cut

sub first_page_uri {
    my ($self) = @_;
    $self->{'firstlink'} ||= make_nav_uri($self, 0);
    return $self->{'firstlink'};
}

=item last_page_uri()

Returns URI of location to last page in search results.

=cut

sub last_page_uri {
    my ($self) = @_;
    $self->{'lastlink'} ||= make_nav_uri($self, $self->{s}->{'lastpage'});
    return $self->{'lastlink'};
}

=item make_nav_uri( $page_no )

Generates and returns a URI for a given page number in the search result set.
Pages start at 0, with each page containing at most -max_results_per_page.

=cut

sub make_nav_uri {
    my ($self, $page_no) = @_;
    my $link = $self->{s}->BASE_URI().$self->{'action_uri'}.'?search_startat='.$page_no;
    if ($self->{s}->{-no_persistent_object} && $self->{s}->{'sortby'}) {
        $link .= '&sortby=' . ($self->{s}->{'sortby'}||'')
          . '&sort_reverse=' . ($self->{s}->{'sort_reverse'}||'');
    }
    $link .= $self->{'href_extra_vars'} || '';
    return $link;
}

=item display_record($row, $column)

Returns HTML rendering of a single record in the dataset, for column name $column.
The $row parameter is the entire row hash for the row being displayed.

=cut

sub display_record {
    my ($self, $row, $column) = @_;
    return (ref $self->{-columndata_closures}->{$column} eq "CODE"
            ? $self->{-columndata_closures}->{$column}->($self, $row)
	    : $self->{-currency_columns}->{$column}
	    ? sprintf('$%.2f', $row->{$column})
	    : $row->{$column} || '');
}

=item display_page_range_links()

Returns a chunk of HTML which shows links to the surrounding pages in the search set.
The number of pages shown is determined by the -page_range_nav_limit setting.

=cut

sub display_page_range_links {
    my ($self, $startat) = @_;
    my $q = $self->{q};
    my @page_range;
    my ($pre, $post) = ('', '');
    if ($startat <= $self->{-page_range_nav_limit}
          && $startat + $self->{-page_range_nav_limit} >= $self->{s}->{'lastpage'}) {
        @page_range = 0 .. $self->{s}->{'lastpage'};
    } elsif ($startat <= $self->{-page_range_nav_limit}) {
        @page_range = 0 .. ($startat + $self->{-page_range_nav_limit});
        $post = ' ...';
    } elsif ($startat + $self->{-page_range_nav_limit} >= $self->{s}->{'lastpage'}) {
        @page_range = ($startat - $self->{-page_range_nav_limit}) .. $self->{s}->{'lastpage'};
        $pre = '... ';
    } else {
        @page_range = ($startat - $self->{-page_range_nav_limit}) .. ($startat + $self->{-page_range_nav_limit});
        $pre = '... ';
        $post = ' ...';
    }
    return $pre.join(' ', map {
        $startat == $_ ? $q->b($_) : $q->a({-href => make_nav_uri($self, $_)}, $_)
    } @page_range).$post;
}


1;
