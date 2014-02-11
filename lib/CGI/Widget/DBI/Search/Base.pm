package CGI::Widget::DBI::Search::Base;

use strict;

use Encode qw/decode/;
use Encode::Detect;
use Scalar::Util qw/blessed/;
use URI::Escape;

# --------------------- USER CUSTOMIZABLE VARIABLES ------------------------

use constant DEBUG => 0;

# --------------------- END USER CUSTOMIZABLE VARIABLES --------------------

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = ref($_[0]) =~ m/^CGI::Widget::DBI::/ && scalar(@_) == 1
      ? bless { %{ $_[0] } }, $class
      : bless { @_ }, $class;
    $self->initialize if $self->can('initialize');
    return $self;
}

sub caller_function {
    my ($self, $stacklvl) = @_;
    my ($func) = ( (caller($stacklvl || 1))[3] =~ m/::([^:]+)\z/ );
    return $func || '';
}

sub log_error {
    my ($self, $msg) = @_;
    my $method = $self->caller_function(2) || $self->caller_function(3); # check one level higher in case called from eval
    my $logmsg = (ref($self)||$self).'->'.$method.': '.$msg;
    if (blessed($self->{r}) && $self->{r}->can('log_error')) {
	$self->{r}->log_error($logmsg);
    } elsif (ref $self->{parent} and ref $self->{parent}->{r} eq 'Apache') {
	$self->{parent}->{r}->log_error($logmsg);
    } else {
	print STDERR '['.localtime().'] [error] [client '.$ENV{REMOTE_ADDR}.'] (STDERR) '.$logmsg."\n";
    }
}

sub warn {
    my ($self, $msg) = @_;
    return unless $self->{_DEBUG} || DEBUG;
    my $method = $self->caller_function(2) || $self->caller_function(3);
    my $logmsg = (ref($self)||$self).'->'.$method.': '.$msg;
    if (blessed($self->{r}) && $self->{r}->can('warn')) {
	$self->{r}->warn($logmsg);
    } elsif (ref $self->{parent} and ref $self->{parent}->{r} eq 'Apache') {
	$self->{parent}->{r}->warn($logmsg);
    } else {
	print STDERR '['.localtime().'] [warn] [client '.$ENV{REMOTE_ADDR}.'] (STDERR) '.$logmsg."\n";
    }
}

sub extra_vars_for_uri {
    my ($self, $exclude_param_list) = @_;
    return '' unless ref $self->{-href_extra_vars} eq 'HASH';
    my %exclude = map {$_=>1} @{$exclude_param_list||[]};
    return join('&', map {
        $exclude{$_} ? ()
          : uri_escape($_).'='.uri_escape_utf8(defined $self->{-href_extra_vars}->{$_}
                                                 ? $self->{-href_extra_vars}->{$_}
                                                 : $self->{q}->param($_) // '');
    } keys %{$self->{-href_extra_vars}});
}

sub extra_vars_for_form {
    my ($self) = @_;
    return '' unless ref $self->{-form_extra_vars} eq 'HASH';
    return join('', map { $self->{q}->hidden($_) } sort keys %{$self->{-form_extra_vars}});
}

sub decode_utf8 {
    my ($self, $input) = @_;
    my $output = eval { decode('Detect', $input); };
    if ($@) {
        return $input if $@ =~ m/^Unknown encoding:/;
        die $@;
    }
    return $output;
}


1;
__END__

=head1 AUTHOR

Adi Fairbank <adi@adiraj.org>

=cut
