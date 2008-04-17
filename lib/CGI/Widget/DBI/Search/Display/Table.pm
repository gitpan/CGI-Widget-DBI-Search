package CGI::Widget::DBI::Search::Display::Table;

use strict;

use base qw/ CGI::Widget::DBI::Search::AbstractDisplay /;

=head1 NAME

CGI::Widget::DBI::Search::Display::Table - HTML table display class for Search widget

=head1 SYNOPSIS

  This class is not intended to be used directly

=head1 DESCRIPTION

This class displays search results retrieved in the search widget in table format,
much like the output from a typical relational database client.  The dataset can be
sorted via column header anchor tags, and paging links appear on all corners of
the table display, as well as a list of navigable page ranges at bottom center.

=head1 METHODS

=over 4

=cut

=item render_dataset()

Builds HTML table rows for current page in the dataset, including a header row
with the visible columns with sortable columns as clickable anchor tags.

Builds data in object variables:

  dataset_rows_html
  header_columns
  header_html

=cut

sub render_dataset {
    my ($self) = @_;
    my $q = $self->{q};
    $self->{'dataset_rows_html'} = [];

    $self->render_column_headers();

    # iterate over most recently returned 'results', which should be a
    # (possibly blessed) hashref
    my $bgcolor;
    foreach my $row (@{$self->{s}->{'results'}}) {
	# toggle color
	$bgcolor = (($bgcolor||'') eq $self->{s}->TABLE_BGCOLOR2()
		  ? $self->{s}->TABLE_BGCOLOR1()
		  : $self->{s}->TABLE_BGCOLOR2());

	# build a table row
	push(@{ $self->{'dataset_rows_html'} }, join '', map {
            my $align = $self->{-numeric_columns}->{$_}
              || $self->{-currency_columns}->{$_} ? 'right' : 'left';
            $q->td({-bgcolor => $bgcolor, -align => $align},
                   $self->display_record($row, $_));
	} @{ $self->{'header_columns'} } );
    }
}

=item render_column_headers()

Called by render_dataset() to render just the column headers (along with sort
links) for the most recent search.

=cut

sub render_column_headers {
    my ($self) = @_;
    my $q = $self->{q};
    $self->{'header_html'} = '';

    # build displayed column headers along with sort links and direction arrow
    foreach my $col (@{ $self->{'header_columns'} }) {
        if ($self->{-unsortable_columns}->{$col}) {
            $self->{'header_html'} .=
              $q->td({-bgcolor => $self->{s}->TABLE_HEADER_BGCOLOR(), -nowrap => 1,
                      ($self->{-currency_columns}->{$col} || $self->{-numeric_columns}->{$col}
                       ? (-align=>'right') : ())},
                     $self->{-display_columns}->{$col});
        } else {
            my $sortby = $self->{s}->{'sortby'} && $col eq $self->{s}->{'sortby'};
            $self->{'header_html'} .= $q->td
              ({-bgcolor => $self->{s}->TABLE_HEADER_BGCOLOR(), -nowrap => 1,
                ($self->{-currency_columns}->{$col} || $self->{-numeric_columns}->{$col}
                 ? (-align=>'right') : ())},
               ($sortby ? "<B>" : "") .
                 $q->a({-href => $self->sortby_column_uri($col)},
                       $self->{-display_columns}->{$col}) . " " .
                         ($sortby
                          ? ($self->{s}->{'sort_reverse'} ? '\\/' :'/\\')."</B>"
                          : ''));
        }
    }
}

=item display_dataset()

Returns HTML rendering of current page in search results, along with navigation links.

=cut

sub display_dataset {
    my ($self) = @_;
    my $q = $self->{q};
    return (
        ($self->{-optional_header}||'') .
        $self->display_pager_links(1, 0) .
        $q->table({-cellpadding => $self->{-display_table_padding} || 2, -width => '96%'},
                  $q->Tr([ $self->{'header_html'}, @{ $self->{'dataset_rows_html'} } ])) .
        $self->display_pager_links(0, 1) .
        ($self->{-optional_footer}||'')
    );
}

=item display_pager_links($showtotal, $showpages)

Returns an HTML table containing navigation links for first, previous, next,
and last pages of result set, and optionally, number and range of results being
displayed, and/or navigable list of pages in the dataset.

This method is called from display() and should be treated as a protected method.

parameters:
  $showtotal	boolean to toggle whether to show total number
                of results along with range on current page
  $showpages    boolean to toggle whether to show page range links
                for easier navigation in large datasets
                (has no effect unless -show_total_numresults setting is set)

=cut

sub display_pager_links {
    my ($self, $showtotal, $showpages) = @_;
    my $q = $self->{q};
    my $startat = $self->{s}->{'page'};
    my $pagetotal = scalar( @{$self->{s}->{'results'}} );
    my $maxpagesize = $self->{s}->{-max_results_per_page};
    my $searchtotal = $self->{s}->{'numresults'};
    my $middle_column = $showtotal || $showpages && $searchtotal;

    return
      ($q->table
       ({-width => '96%'}, $q->Tr
	($q->td({-align => 'left',
		 -width => $middle_column ? '30%' : '50%'},
		$q->font({-size => '-1'},
			 ($startat > 0
			  ? $q->b(($self->first_page_uri()
				   ? $q->a({-href => $self->first_page_uri()},
					   "|&lt;First").'&nbsp;&nbsp;&nbsp;'
				   : '').
				  $q->a({-href => $self->prev_page_uri()}, "&lt;Previous"))
			  : "|At first page"))) .
	 ($middle_column
	  ? $q->td({-align => 'center', -width => '40%', -nowrap => 1},
                   ($showtotal
                    ? "<B>$pagetotal</B> result".
                      ($pagetotal == 1 ? '' : 's')." displayed".
                      ($searchtotal
                       ? (': <B>'.($startat*$maxpagesize + 1).' - '.
                          ($startat*$maxpagesize + $pagetotal).'</B> of <B>'.
                          $searchtotal.'</B>')
                       : '').$q->br
                    : '') .
                    ($showpages && $searchtotal
                     ? $q->font({-size => '-1'},
                                "Skip to page: ".$self->display_page_range_links($startat))
                     : '')
                  )
	  : '') .
	 $q->td({-align => 'right', -width => $middle_column ? '30%' : '50%'},
		$q->font({-size => '-1'},
			 (defined $maxpagesize &&
			  ((defined $searchtotal
			    && $startat != int(($searchtotal-1)/$maxpagesize))
			   || (!$searchtotal && $pagetotal >= $maxpagesize))
			  ? $q->b($q->a({-href => $self->next_page_uri()}, "Next&gt;").
				  ($self->last_page_uri()
				   ? '&nbsp;&nbsp;&nbsp;'.$q->a({-href => $self->last_page_uri()},"Last&gt;|")
				   : ''))
			  : "At last page|"))))
       ));
}


1;
