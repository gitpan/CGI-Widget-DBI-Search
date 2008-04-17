package CGI::Widget::DBI::TEST::Search;

use strict;
use base qw/ CGI::Widget::DBI::TEST::TestCase /;

sub test_search__basic
{
    my $self = shift;
    my $ws = $self->{ws};

    $ws->{-sql_table} = 'widgets';
    $ws->{-sql_retrieve_columns} = [qw/widget_no name description size/];

    $ws->search();

    $self->assert_deep_equals(
        [
            { widget_no => 1, name => 'clock_widget', description => "A time keeper widget", size => 'small', },
            { widget_no => 2, name => 'calendar_widget', description => "A date tracker widget", size => 'medium', },
            { widget_no => 3, name => 'silly_widget', description => "A goofball widget", size => 'unknown', },
        ],
        $ws->{'results'},
    );
}

sub test_search__with_a_join
{
    my $self = shift;
    my $ws = $self->{ws};

    $ws->{-sql_table} =
      'widgets w inner join widget_tools wt using (widget_no) inner join tools t using (tool_no)';
    $ws->{-sql_retrieve_columns} =
      [qw/w.widget_no w.name w.description w.size t.tool_no/, 't.name as tool_name', 't.type'];

    $ws->search();

    $self->assert_deep_equals(
        [
            { widget_no => 1, name => 'clock_widget', description => "A time keeper widget", size => 'small',
              tool_no => 2, tool_name => 'wrench', type => 'hand', },
            { widget_no => 1, name => 'clock_widget', description => "A time keeper widget", size => 'small',
              tool_no => 1, tool_name => 'hammer', type => 'hand', },
            { widget_no => 2, name => 'calendar_widget', description => "A date tracker widget", size => 'medium',
              tool_no => 5, tool_name => 'emacs', type => 'software', },
            { widget_no => 2, name => 'calendar_widget', description => "A date tracker widget", size => 'medium',
              tool_no => 6, tool_name => 'apache', type => 'software', },
            { widget_no => 3, name => 'silly_widget', description => "A goofball widget", size => 'unknown',
              tool_no => 4, tool_name => 'rm', type => 'unix', },
        ],
        $ws->{'results'},
    );
}

sub test_search__with_a_filter
{
    my $self = shift;
    my $ws = $self->{ws};

    $ws->{-sql_table} = 'widgets';
    $ws->{-sql_retrieve_columns} = [qw/widget_no name description size/];

    $ws->{-where_clause} = 'WHERE name LIKE ?';
    $ws->{-bind_params} = ['c%']; # name begins with 'c'

    $ws->search();

    $self->assert_deep_equals(
        [
            { widget_no => 1, name => 'clock_widget', description => "A time keeper widget", size => 'small', },
            { widget_no => 2, name => 'calendar_widget', description => "A date tracker widget", size => 'medium', },
        ],
        $ws->{'results'},
    );

    # try a different filter
    delete $ws->{'results'}; # need to clear old results or it will just return cached copy
    $ws->{-where_clause} = 'WHERE name LIKE ? AND size = ?';
    $ws->{-bind_params} = ['c%', 'medium']; # name begins with 'c' and size is medium

    $ws->search();

    $self->assert_deep_equals(
        [
            { widget_no => 2, name => 'calendar_widget', description => "A date tracker widget", size => 'medium', },
        ],
        $ws->{'results'},
    );
}

sub test_search__paging
{
    my $self = shift;
    my $ws = $self->{ws};
    my $q = $ws->{q};

    $ws->{-sql_table} =
      'widgets w inner join widget_tools wt using (widget_no) inner join tools t using (tool_no)';
    $ws->{-sql_retrieve_columns} =
      [qw/w.widget_no w.name w.description w.size t.tool_no/, 't.name as tool_name', 't.type'];
    $ws->{-max_results_per_page} = 2;

    $ws->search();

    $self->assert_deep_equals(
        [
            { widget_no => 1, name => 'clock_widget', description => "A time keeper widget", size => 'small',
              tool_no => 2, tool_name => 'wrench', type => 'hand', },
            { widget_no => 1, name => 'clock_widget', description => "A time keeper widget", size => 'small',
              tool_no => 1, tool_name => 'hammer', type => 'hand', },
        ],
        $ws->{'results'},
    );

    # reset search
    delete $ws->{'results'};

    $q->param('search_startat', 1);
    $ws->search();

    $self->assert_deep_equals(
        [
            { widget_no => 2, name => 'calendar_widget', description => "A date tracker widget", size => 'medium',
              tool_no => 5, tool_name => 'emacs', type => 'software', },
            { widget_no => 2, name => 'calendar_widget', description => "A date tracker widget", size => 'medium',
              tool_no => 6, tool_name => 'apache', type => 'software', },
        ],
        $ws->{'results'},
    );

    # reset search
    delete $ws->{'results'};

    $q->param('search_startat', 2);
    $ws->search();

    $self->assert_deep_equals(
        [
            { widget_no => 3, name => 'silly_widget', description => "A goofball widget", size => 'unknown',
              tool_no => 4, tool_name => 'rm', type => 'unix', },
        ],
        $ws->{'results'},
    );
}

sub test_search__sorting
{
    my $self = shift;
    my $ws = $self->{ws};
    my $q = $ws->{q};

    $ws->{-sql_table} = 'widgets';
    $ws->{-sql_retrieve_columns} = [qw/widget_no name description size/];
    $q->param('sortby', 'description');
    $ws->search();

    $self->assert_deep_equals(
        [
            { widget_no => 2, name => 'calendar_widget', description => "A date tracker widget", size => 'medium', },
            { widget_no => 3, name => 'silly_widget', description => "A goofball widget", size => 'unknown', },
            { widget_no => 1, name => 'clock_widget', description => "A time keeper widget", size => 'small', },
        ],
        $ws->{'results'},
    );

    # reset search
    delete $ws->{'results'};

    $q->param('sortby', 'widget_no');
    $q->param('sort_reverse', 1);
    $ws->search();

    $self->assert_deep_equals(
        [
            { widget_no => 3, name => 'silly_widget', description => "A goofball widget", size => 'unknown', },
            { widget_no => 2, name => 'calendar_widget', description => "A date tracker widget", size => 'medium', },
            { widget_no => 1, name => 'clock_widget', description => "A time keeper widget", size => 'small', },
        ],
        $ws->{'results'},
    );
}

sub test_search__default_orderby_and_sorting
{
    my $self = shift;
    my $ws = $self->{ws};
    my $q = $ws->{q};

    $ws->{-sql_table} = 'widgets';
    $ws->{-sql_retrieve_columns} = [qw/widget_no name description size/];
    $ws->{-default_orderby_columns} = [qw/name widget_no/];

    $ws->search();

    $self->assert_deep_equals(
        [
            { widget_no => 2, name => 'calendar_widget', description => "A date tracker widget", size => 'medium', },
            { widget_no => 1, name => 'clock_widget', description => "A time keeper widget", size => 'small', },
            { widget_no => 3, name => 'silly_widget', description => "A goofball widget", size => 'unknown', },
        ],
        $ws->{'results'},
    );

    # reset search
    delete $ws->{'results'};

    $q->param('sortby', 'widget_no');
    $ws->search();

    $self->assert_deep_equals(
        [
            { widget_no => 1, name => 'clock_widget', description => "A time keeper widget", size => 'small', },
            { widget_no => 2, name => 'calendar_widget', description => "A date tracker widget", size => 'medium', },
            { widget_no => 3, name => 'silly_widget', description => "A goofball widget", size => 'unknown', },
        ],
        $ws->{'results'},
    );

    # reset search
    delete $ws->{'results'};

    $q->param('sortby', 'size');
    $q->param('sort_reverse', 1);
    $ws->search();

    $self->assert_deep_equals(
        [
            { widget_no => 3, name => 'silly_widget', description => "A goofball widget", size => 'unknown', },
            { widget_no => 1, name => 'clock_widget', description => "A time keeper widget", size => 'small', },
            { widget_no => 2, name => 'calendar_widget', description => "A date tracker widget", size => 'medium', },
        ],
        $ws->{'results'},
    );
}

sub test_display_results
{
    my $self = shift;
    my $ws = $self->{ws};
    $self->test_search__basic();

    $self->assert_matches(
        qr/\b1\b.*\bclock_widget\b.*\bA\ time\ keeper\ widget\b.*\bsmall\b.*
           \b2\b.*\bcalendar_widget\b.*\bA\ date\ tracker\ widget\b.*\bmedium\b.*
           \b3\b.*\bsilly_widget\b.*\bA\ goofball\ widget\b.*\bunknown\b
          /sx,
        $ws->display_results,
    );

    # reset search and set default ordering
    delete $ws->{'results'};
    $ws->{-default_orderby_columns} = [qw/name widget_no/];

    $ws->search();

    $self->assert_matches(
        qr/\b2\b.*\bcalendar_widget\b.*\bA\ date\ tracker\ widget\b.*\bmedium\b.*
           \b1\b.*\bclock_widget\b.*\bA\ time\ keeper\ widget\b.*\bsmall\b.*
           \b3\b.*\bsilly_widget\b.*\bA\ goofball\ widget\b.*\bunknown\b
          /sx,
        $ws->display_results,
    );
}


1;
