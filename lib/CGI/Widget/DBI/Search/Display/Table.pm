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
    my $header_td_html = '';
    my %sortable_cols = %{ $self->{-sortable_columns} || {} };

    # build displayed column headers along with sort links and direction arrow
    foreach my $col (@{ $self->{'header_columns'} }) {
        my $align = $self->{-column_align}->{$col} ||
          ($self->{-numeric_columns}->{$col} || $self->{-currency_columns}->{$col} ? 'right' : undef);

        if ($self->{-unsortable_columns}->{$col} || (%sortable_cols && ! $sortable_cols{$col}) ) {
            $header_td_html .=
              $q->td({-class => $self->{s}->{-css_table_unsortable_header_class} || 'searchWidgetTableUnsortableHeader',
                      -bgcolor => $self->{s}->TABLE_HEADER_BGCOLOR(), -nowrap => 1,
                      ($align ? (-align => $align) : ())},
                     $self->{-display_columns}->{$col});
        } else {
            my $sortby = $self->{s}->{'sortby'} && $col eq $self->{s}->{'sortby'};
            $header_td_html .= $q->td
              ({-class => $self->{s}->{-css_table_header_class} || 'searchWidgetTableHeader',
                -bgcolor => $self->{s}->TABLE_HEADER_BGCOLOR(), -nowrap => 1,
                ($align ? (-align => $align) : ())},
               ($sortby ? "<B>" : "") .
                 $q->a({-href => $self->sortby_column_uri($col)},
                       $self->{-display_columns}->{$col}) . " " .
                         ($sortby
                          ? ($self->{s}->{'sort_reverse'}->{$col} ? '\\/' :'/\\')."</B>"
                          : ''));
        }
    }
    $self->{'header_html'} = $q->Tr({-class => $self->{s}->{-css_table_row_class} || 'searchWidgetTableRow'}, $header_td_html);
}

=item display_dataset()

Returns HTML rendering of current page in search results, along with navigation links.

=cut

sub display_dataset {
    my ($self) = @_;
    return (
        ($self->{-optional_header}||'') .
        $self->{s}->extra_vars_for_form() .
        $self->display_pager_links(1, 0) .
        $self->{q}->table({-class => $self->{s}->{-css_table_class} || 'searchWidgetTableTable', -width => '96%'},
                          $self->{'header_html'}, join('', @{ $self->{'dataset_rows_html'} })) .
        $self->display_pager_links(0, 1) .
        ($self->{-optional_footer}||'')
    );
}

=item display_row( $row )

Returns HTML rendering of given $row in dataset: '<tr> ... </tr>'.
Calls display_field($row, $header_col) for each header column.

=cut

sub display_row {
    my ($self, $row) = @_;
    # toggle color
    $self->{'_row_bgcolor'} = ($self->{'_row_bgcolor'}||'') eq $self->{s}->TABLE_BGCOLOR2()
      ? $self->{s}->TABLE_BGCOLOR1()
      : $self->{s}->TABLE_BGCOLOR2();

    return $self->{q}->Tr(
        {-class => $self->{s}->{-css_table_row_class} || 'searchWidgetTableRow',
         -style => 'background-color: '.$self->{'_row_bgcolor'}.';' },
        join '', map { $self->display_field($row, $_) } @{ $self->{'header_columns'} }
    );
}

=item display_field( $row, $col )

Returns HTML rendering of given $row / $col in dataset: '<td> ... </td>'.
Calls display_record($row, $col), inherited from L<CGI::Widget::DBI::Search::AbstractDisplay> for the cell contents.

=cut

sub display_field {
    my ($self, $row, $col) = @_;

    my $align = $self->{-column_align}->{$col} ||
      ($self->{-numeric_columns}->{$col} || $self->{-currency_columns}->{$col} ? 'right' : 'left');
    return $self->{q}->td(
        {-class => $self->{s}->{-css_table_cell_class} || 'searchWidgetTableCell', -align => $align},
        $self->display_record($row, $col)
    );
}


1;
__END__

=back

=head1 SEE ALSO

L<CGI::Widget::DBI::Search::AbstractDisplay>

=cut
