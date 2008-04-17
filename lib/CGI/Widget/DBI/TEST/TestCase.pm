package CGI::Widget::DBI::TEST::TestCase;

use strict;
use base qw/ Test::Unit::TestCase /;

use DBI;
use CGI;
use CGI::Widget::DBI::Search;
use Data::Dumper;

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

# TODO: release as separate open source module, e.g. Test::Unit::MoreAsserts
sub assert_table_contents_equal {
    my ($self, $table, $columns, $row_contents, $verbose) = @_;
    die "no DBI handle set: set -dbh variable in your test object"
      unless ref $self->{-dbh} eq 'DBI::db';
    my $sth = $self->{-dbh}->prepare_cached("SELECT ".join(',', @$columns)." FROM $table");
    $sth->execute();
    my $table_contents = $sth->fetchall_arrayref();

    if ($verbose) {
        print "==== contents of table in database ====\n" . (Dumper [$table_contents])
          . "====\n";;
    }

    local $Error::Depth = 1;
    $self->assert_deep_equals(
        $row_contents,
        $table_contents,
    );
}


1;
