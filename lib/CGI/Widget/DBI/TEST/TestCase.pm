package CGI::Widget::DBI::TEST::TestCase;

use strict;
use base qw/ Test::Unit::TestCase /;

use Data::Dumper;

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
