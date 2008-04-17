package CGI::Widget::DBI::Search::Display::Grid;

use strict;

use base qw/ CGI::Widget::DBI::Search::AbstractDisplay /;

=head1 NAME

CGI::Widget::DBI::Search::Display::Grid - Grid display class for Search widget

=head1 SYNOPSIS

  This class is not intended to be used directly

=head1 DESCRIPTION

This class displays search results retrieved in the search widget in a grid format
with each row in the dataset inhabiting its own cell.  The dataset can be sorted
via a drop-down menu at the upper-right of the grid, and paging links appear at the
lower right.

=head1 METHODS

=over 4

=item render_dataset()

Builds an HTML table in grid layout for current page in the dataset.

Builds data in object variables:

  dataset_cells_html

=cut

sub render_dataset {
    my ($self) = @_;
    my $q = $self->{q};
    $self->{'dataset_cells_html'} = [];

    # iterate over most recently returned 'results', which should be a
    # (possibly blessed) hashref
    foreach my $row (@{$self->{s}->{'results'}}) {
	# build a cell in the grid
	push(@{ $self->{'dataset_cells_html'} }, $self->display_cell($row));
    }
}

=item display_cell( $row )

Returns an HTML table cell rendering for row $row in the dataset.  Called by
render_dataset() for each row in the current page of search results.

=cut

sub display_cell {
    my ($self, $row) = @_;
    my $q = $self->{q};

    return $q->td(
        join '', map {
            $q->p( $self->display_record($row, $_) )
        } @{ $self->{'header_columns'} }
    );
}

=item display_dataset()

Returns HTML rendering of current page in search results, along with navigation links.

=cut

sub display_dataset {
    my ($self) = @_;
    my $q = $self->{q};

    my @grid_rows;
    foreach my $i (0 .. $#{ $self->{'dataset_cells_html'} }) {
        if ($i % $self->{-grid_columns} == 0) {
            push(@grid_rows, $self->{'dataset_cells_html'}->[$i]);
        } else {
            $grid_rows[-1] .= $self->{'dataset_cells_html'}->[$i];
        }
    }
    return (
        ($self->{-optional_header}||'') .
        $q->table({-cellpadding => $self->{-display_table_padding} || 2, -width => '96%'},
                  $q->Tr([ @grid_rows ])) .
#        $self->display_pager_links() .
        ($self->{-optional_footer}||'')
    );
}

=item _set_display_defaults()

Sets grid-layout specific default settings in addition to settings in
AbstractDisplay.

=cut

sub _set_display_defaults {
    my ($self) = @_;
    $self->SUPER::_set_display_defaults();
    $self->{-grid_columns} ||= 4;
}


1;
