package CGI::Widget::DBI::Search::Display::TEST::Table;

use strict;
use base qw/ CGI::Widget::DBI::Search::Display::TEST::TestCase /;


sub test_search__basic
{
    my $self = shift;
    $self->SUPER::test_search__basic;

    $self->assert_display_contains(
        [ 'At first page', 'At last page' ],
        [ map {("sortby=$_", $_)} qw/widget_no name description size/ ],
        [ 1, 'clock_widget', 'A time keeper widget', 'small' ],
        [ 2, 'calendar_widget', 'A date tracker widget', 'medium' ],
        [ 3, 'silly_widget', 'A goofball widget', 'unknown' ],
    );
}

sub test_search__display_only_subset_of_columns
{
    my $self = shift;
    $self->{ws}->{-display_columns} = { map {$_ => $_} qw/widget_no name size/ };
    $self->SUPER::test_search__basic;

    $self->assert_display_contains(
        [ 'At first page', 'At last page' ],
        [ map {("sortby=$_", $_)} qw/widget_no name size/ ],
        [ 1, 'clock_widget', 'small' ],
        [ 2, 'calendar_widget', 'medium' ],
        [ 3, 'silly_widget', 'unknown' ],
    );
    $self->assert_display_does_not_contain( [ 'description' ] );
    $self->assert_display_does_not_contain( [ 'A time keeper widget', ] );
    $self->assert_display_does_not_contain( [ 'A date tracker widget', ] );
    $self->assert_display_does_not_contain( [ 'A goofball widget', ] );
}

sub test_search__display_nondb_columns_and_columndata_closures
{
    my $self = shift;
    $self->{ws}->{-pre_nondb_columns} = [qw/my_header1/];
    $self->{ws}->{-post_nondb_columns} = [qw/my_header2 my_header3/];
    $self->{ws}->{-columndata_closures} = {
        my_header1 => sub { my ($self, $row) = @_; return "Widget #".$row->{widget_no}; },
        my_header2 => sub { my ($self, $row) = @_; return "Widget Size: ".$row->{size}; },
        my_header3 => sub { return "***"; },
    };
    $self->SUPER::test_search__basic;

    $self->assert_display_contains(
        [ 'At first page', 'At last page' ],
        [ 'my_header1', (map {("sortby=$_", $_)} qw/widget_no name description size/), qw/my_header2 my_header3/ ],
        [ 'Widget #1', 1, 'clock_widget', 'A time keeper widget', 'small', 'Widget Size: small', '">\*\*\*</', ],
        [ 'Widget #2', 2, 'calendar_widget', 'A date tracker widget', 'medium', 'Widget Size: medium', '">\*\*\*</', ],
        [ 'Widget #3', 3, 'silly_widget', 'A goofball widget', 'unknown', 'Widget Size: unknown', '">\*\*\*</', ],
    );
}

sub test_search__with_a_join
{
    my $self = shift;
    $self->SUPER::test_search__with_a_join;

    $self->assert_display_contains(
        [ 'At first page', 'At last page' ],
        [ map {("sortby=$_", $_)} qw/widget_no name description size tool_no tool_name type/ ],
        [ 1, 'clock_widget', 'A time keeper widget', 'small', 2, 'wrench', 'hand' ],
        [ 1, 'clock_widget', 'A time keeper widget', 'small', 1, 'hammer', 'hand' ],
        [ 2, 'calendar_widget', 'A date tracker widget', 'medium', 5, 'emacs', 'software' ],
        [ 2, 'calendar_widget', 'A date tracker widget', 'medium', 6, 'apache', 'software' ],
        [ 3, 'silly_widget', 'A goofball widget', 'unknown', 4, 'rm', 'unix' ],
    );
}

sub test_search__with_a_filter
{
    my $self = shift;
    $self->SUPER::test_search__with_a_filter;

    # only displays most recent filter
    $self->assert_display_contains(
        [ 'At first page', 'At last page' ],
        [ map {("sortby=$_", $_)} qw/widget_no name description size/ ],
        [ 2, 'calendar_widget', 'A date tracker widget', 'medium' ],
    );
}

sub test_search__paging
{
    my $self = shift;
    $self->SUPER::test_search__paging;

    # only displays most recent page of search
    $self->assert_display_contains(
        [ 'search_startat=0', 'First', 'search_startat=1', 'Previous', 'At last page' ],
        [ map {("sortby=$_", $_)} qw/widget_no name description size tool_no tool_name type/ ],
        [ 3, 'silly_widget', 'A goofball widget', 'unknown', 4, 'rm', 'unix' ],
    );
}

sub test_search__sorting
{
    my $self = shift;
    $self->SUPER::test_search__sorting;

    # only displays most recent sorting
    $self->assert_display_contains(
        [ 'At first page', 'At last page' ],
        [ "sortby=widget_no&amp;sort_reverse=0", "widget_no", (map {("sortby=$_", $_)} qw/name description size/) ],
        [ 3, 'silly_widget', 'A goofball widget', 'unknown' ],
        [ 2, 'calendar_widget', 'A date tracker widget', 'medium' ],
        [ 1, 'clock_widget', 'A time keeper widget', 'small' ],
    );
}

sub test_search__default_orderby_and_sorting
{
    my $self = shift;
    $self->SUPER::test_search__default_orderby_and_sorting;

    # only displays most recent sorting
    $self->assert_display_contains(
        [ 'At first page', 'At last page' ],
        [ (map {("sortby=$_", $_)} qw/widget_no name description/), "sortby=size&amp;sort_reverse=0", "size" ],
        [ 3, 'silly_widget', 'A goofball widget', 'unknown' ],
        [ 1, 'clock_widget', 'A time keeper widget', 'small' ],
        [ 2, 'calendar_widget', 'A date tracker widget', 'medium' ],
    );
}


1;
