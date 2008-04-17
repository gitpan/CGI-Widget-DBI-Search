package CGI::Widget::DBI::Search::Display::TEST::TestCase;

use strict;
use base qw/ CGI::Widget::DBI::TEST::Search /;


sub test_display_results {}

sub assert_display_contains {
    my ($self, @rows) = @_;
    my $ws = $self->{ws};
    local $Error::Depth = 1;
    my $regex = join('.*', map {defined $_ && $_ ne '' ? '\b'.$_.'\b' : ()} map {@$_} @rows);
    $self->assert_matches(
        qr/$regex/s,
        $ws->display_results,
    );
}

sub assert_display_does_not_contain {
    my ($self, @rows) = @_;
    my $ws = $self->{ws};
    local $Error::Depth = 1;
    my $regex = join('.*', map {defined $_ && $_ ne '' ? '\b'.$_.'\b' : ()} map {@$_} @rows);
    $self->assert_does_not_match(
        qr/$regex/s,
        $ws->display_results,
    );
}


1;
