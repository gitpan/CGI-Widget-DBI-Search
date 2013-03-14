package CGI::Widget::DBI::Search::Display::Table;

use strict;

use base qw/ CGI::Widget::DBI::Search::AbstractDisplay /;

=head1 NAME

CGI::Widget::DBI::Search::Display::Table - HTML table display class for Search widget

=head1 SYNOPSIS

  my $ws = CGI::Widget::DBI::Search->new(q => CGI->new);
  ...
  $ws->{-display_class} = 'CGI::Widget::DBI::Search::Display::Table';

  # or instead, simply:
  $ws->{-display_mode} = 'table';

  # note: this is default behavior for the search widget, so this is all just for
  # informational purposes, e.g. to write your own display class

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
    $self->{'dataset_rows_html'} = [];

    $self->render_column_headers();

    # iterate over most recently returned 'results', which should be a (possibly blessed) hashref
    foreach my $row (@{$self->{s}->{'results'}}) {
        # build a table row
        push(@{ $self->{'dataset_rows_html'} }, $self->display_row($row));
    }
}

=item render_column_headers()

Called by render_dataset() to render just the column headers (along with sort
links) for the most recent search.

=cut

sub render_column_headers {
    my ($self) = @_;
    my $q = $self->{q};
    my $header_th_html = '';
    my $header_bgcolor = $self->{s}->TABLE_HEADER_BGCOLOR();
    my %sortable_cols = %{ $self->{-sortable_columns} || {} };

    # build displayed column headers along with sort links and direction arrow
    foreach my $col (@{ $self->{'header_columns'} }) {
        my $align = $self->{-column_align}->{$col} ||
          ($self->{-numeric_columns}->{$col} || $self->{-currency_columns}->{$col} ? 'right' : undef);

        if ($self->{-unsortable_columns}->{$col} || (%sortable_cols && ! $sortable_cols{$col}) ) {
            $header_th_html .=
              $q->th({-class => $self->{s}->{-css_table_unsortable_header_cell_class} || 'searchWidgetTableUnsortableHeaderCell',
                      ($header_bgcolor ? (-bgcolor => $header_bgcolor) : ()), -nowrap => 1,
                      ($align ? (-align => $align) : ())},
                     $self->{-display_columns}->{$col});
        } else {
            my $sortby = $self->{s}->{'sortby'} && $col eq $self->{s}->{'sortby'};
            my %extra_attributes = %{ $self->get_option_value('-extra_table_header_cell_attributes', [$col]) || {} };
            $header_th_html .= $q->th
              ({-class => $self->{s}->{-css_table_header_cell_class} || 'searchWidgetTableHeaderCell',
                ($header_bgcolor ? (-bgcolor => $header_bgcolor) : ()), -nowrap => 1,
                ($align ? (-align => $align) : ()), %extra_attributes},
               ($sortby ? '<b>' : '')
               .'<a href="'.$self->sortby_column_uri($col).'" title="'.($self->{-column_titles}->{$col} || 'Sort by: '.$self->{-display_columns}->{$col}).'">'
               .'<span>'.$self->{-display_columns}->{$col}.'</span></a>'
               .' '.($sortby ? ($self->{s}->{'sort_reverse'}->{$col} ? '\\/' :'/\\').'</b>' : '')
              );
        }
    }
    $self->{'header_html'} = '<tr class="'.($self->{s}->{-css_table_header_row_class} || 'searchWidgetTableHeaderRow').'">'.$header_th_html.'</tr>';
}

=item display_dataset()

Returns HTML rendering of current page in search results, along with navigation links.

=cut

sub display_dataset {
    my ($self) = @_;
    return ($self->{-optional_header}||'')
      . $self->{s}->extra_vars_for_form()
      . $self->display_pager_links(1, 0)
      . '<table class="'.($self->{s}->{-css_table_class} || 'searchWidgetTableTable').'" width="96%">'
        . '<thead>'.$self->{'header_html'}.'</thead>'
        . '<tbody>'.join('', @{ $self->{'dataset_rows_html'} }).'</tbody>'
      . '</table>'
      . $self->display_pager_links(0, 1)
      . ($self->{-optional_footer}||'');
}

=item display_row( $row )

Returns HTML rendering of given $row in dataset: '<tr> ... </tr>'.
Calls display_field($row, $header_col) for each header column.

=cut

sub display_row {
    my ($self, $row) = @_;
    $self->{'_row_index'}++;
    if ($self->{s}->TABLE_BGCOLOR1 && $self->{s}->TABLE_BGCOLOR2) { # toggle color
        $self->{'_row_bgcolor'} = ($self->{'_row_bgcolor'}||'') eq $self->{s}->TABLE_BGCOLOR2
          ? $self->{s}->TABLE_BGCOLOR1
          : $self->{s}->TABLE_BGCOLOR2;
    }

    return '<tr class="'.($self->{s}->{-css_table_row_class} || 'searchWidgetTableRow').' '
      .($self->{'_row_index'} % 2 == 0 ? 'evenRow' : 'oddRow').'"'
      .($self->{'_row_bgcolor'} ? ' style="background-color: '.$self->{'_row_bgcolor'}.';"' : '').'>'
        .join('', map { $self->display_field($row, $_) } @{ $self->{'header_columns'} })
      .'</tr>';
}

=item display_field( $row, $col )

Returns HTML rendering of given $row / $col in dataset: '<td> ... </td>'.
Calls display_record($row, $col), inherited from L<CGI::Widget::DBI::Search::AbstractDisplay> for the cell contents.

=cut

sub display_field {
    my ($self, $row, $col) = @_;
    my %extra_attributes = %{ $self->get_option_value('-extra_table_cell_attributes', [$row, $col]) || {} };

    my $align = $self->{-column_align}->{$col} ||
      ($self->{-numeric_columns}->{$col} || $self->{-currency_columns}->{$col} ? 'right' : 'left');
    return $self->{q}->td(
        {-class => $self->{s}->{-css_table_cell_class} || 'searchWidgetTableCell', -align => $align, %extra_attributes},
        $self->display_record($row, $col)
    );
}


1;
__END__

=back

=head1 SEE ALSO

L<CGI::Widget::DBI::Search::AbstractDisplay>

=cut
