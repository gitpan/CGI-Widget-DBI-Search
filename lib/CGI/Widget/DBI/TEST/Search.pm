package CGI::Widget::DBI::TEST::Search;

use strict;
use base qw/ CGI::Widget::DBI::TEST::TestCase /;

use DBI;
use CGI;
use CGI::Widget::DBI::Search;

sub set_up
{
    my $self = shift;
    #create test database schema and insert data ...
    $self->{-dbh} = DBI->connect('DBI:mysql:database=test;host=localhost', 'test', undef);
    map { $self->{-dbh}->do($_); } _db_schemas();

    $self->_insert_test_data($self->{-dbh});

    my $q = CGI->new;
    $self->{ws} = CGI::Widget::DBI::Search->new(q => $q, -dbh => $self->{-dbh});
}

sub tear_down
{
    my $self = shift;
#    map { $self->{ws}->{-dbh}->do("drop table $_"); } qw/widgets tools widget_tools/;
    $self->{ws}->{-dbh}->disconnect();
}

sub _db_schemas {
    my @schemas = (<<'DDL1');
create temporary table widgets (
  widget_no   integer     not null primary key auto_increment,
  name        varchar(32),
  description text,
  size        varchar(16)
)
DDL1
    push(@schemas, <<'DDL2');
create temporary table tools (
  tool_no     integer     not null primary key auto_increment,
  name        varchar(32),
  type        varchar(16)
)
DDL2
    push(@schemas, <<'DDL3');
create temporary table widget_tools (
  widget_no   integer not null,
  tool_no     integer not null
)
DDL3
    return @schemas;
}

sub _insert_test_data {
    my ($self) = @_;
    my $sth1 = $self->{-dbh}->prepare_cached('insert into widgets (widget_no, name, description, size) values (?, ?, ?, ?)');
    my $sth2 = $self->{-dbh}->prepare_cached('insert into tools (tool_no, name, type) values (?, ?, ?)');
    my $sth3 = $self->{-dbh}->prepare_cached('insert into widget_tools (widget_no, tool_no) values (?, ?)');
    $sth1->execute(1, 'clock_widget', "A time keeper widget", 'small');
    $sth1->execute(2, 'calendar_widget', "A date tracker widget", 'medium');
    $sth1->execute(3, 'silly_widget', "A goofball widget", 'unknown');
    $sth2->execute(1, 'hammer', 'hand');
    $sth2->execute(2, 'wrench', 'hand');
    $sth2->execute(3, 'ls', 'unix');
    $sth2->execute(4, 'rm', 'unix');
    $sth2->execute(5, 'emacs', 'software');
    $sth2->execute(6, 'apache', 'software');
    $sth3->execute(1, 2);
    $sth3->execute(1, 1);
    $sth3->execute(2, 5);
    $sth3->execute(2, 6);
    $sth3->execute(3, 4);

    $self->assert_table_contents_equal(
        'widgets', [qw/widget_no name description size/],
        [
            [ 1, 'clock_widget', "A time keeper widget", 'small', ],
            [ 2, 'calendar_widget', "A date tracker widget", 'medium', ],
            [ 3, 'silly_widget', "A goofball widget", 'unknown', ],
        ],
    );
    $self->assert_table_contents_equal(
        'tools', [qw/tool_no name type/],
        [
            [ 1, 'hammer', 'hand', ],
            [ 2, 'wrench', 'hand', ],
            [ 3, 'ls', 'unix', ],
            [ 4, 'rm', 'unix', ],
            [ 5, 'emacs', 'software', ],
            [ 6, 'apache', 'software', ],
        ],
    );
    $self->assert_table_contents_equal(
        'widget_tools', [qw/widget_no tool_no/],
        [
            [  1, 2, ],
            [  1, 1, ],
            [  2, 5, ],
            [  2, 6, ],
            [  3, 4, ],
        ],
    );
}

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
      [qw/w.widget_no w.name w.description w.size t.tool_no t.name t.type/];

    $ws->search();

    $self->assert_deep_equals(
        [
            { widget_no => 1, name => 'clock_widget', description => "A time keeper widget", size => 'small',
              tool_no => 2, name => 'wrench', type => 'hand', },
            { widget_no => 1, name => 'clock_widget', description => "A time keeper widget", size => 'small',
              tool_no => 1, name => 'hammer', type => 'hand', },
            { widget_no => 2, name => 'calendar_widget', description => "A date tracker widget", size => 'medium',
              tool_no => 5, name => 'emacs', type => 'software', },
            { widget_no => 2, name => 'calendar_widget', description => "A date tracker widget", size => 'medium',
              tool_no => 6, name => 'apache', type => 'software', },
            { widget_no => 3, name => 'silly_widget', description => "A goofball widget", size => 'unknown',
              tool_no => 4, name => 'rm', type => 'unix', },
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
      [qw/w.widget_no w.name w.description w.size t.tool_no t.name t.type/];
    $ws->{-max_results_per_page} = 2;

    $ws->search();

    $self->assert_deep_equals(
        [
            { widget_no => 1, name => 'clock_widget', description => "A time keeper widget", size => 'small',
              tool_no => 2, name => 'wrench', type => 'hand', },
            { widget_no => 1, name => 'clock_widget', description => "A time keeper widget", size => 'small',
              tool_no => 1, name => 'hammer', type => 'hand', },
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
              tool_no => 5, name => 'emacs', type => 'software', },
            { widget_no => 2, name => 'calendar_widget', description => "A date tracker widget", size => 'medium',
              tool_no => 6, name => 'apache', type => 'software', },
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
              tool_no => 4, name => 'rm', type => 'unix', },
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

# sub test_search__with_restricted_column_display
# {
#     my $self = shift;
#     my $ws = $self->{ws};
# }


1;
