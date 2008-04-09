package CGI::Widget::DBI::Search::Base;

require 5.004;
use strict;

# --------------------- USER CUSTOMIZABLE VARIABLES ------------------------

use constant DEBUG => 0;

# --------------------- END USER CUSTOMIZABLE VARIABLES --------------------

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = bless { @_ }, $class;
    $self->initialize if $self->can('initialize');
    return $self;
}

###############################################################################
# Apache logging methods
###############################################################################

sub log_error {
    my ($self, $method, $msg) = @_;
    my $logmsg = (ref($self)||$self)."->".$method.": ".$msg;
    if (ref $self->{r} eq "Apache") {
	$self->{r}->log_error($logmsg);
    } elsif (ref $self->{parent} and ref $self->{parent}->{r} eq "Apache") {
	$self->{parent}->{r}->log_error($logmsg);
    } else {
	print STDERR "[".localtime()."] [error] [client $ENV{REMOTE_ADDR}] ".
	  $logmsg."\n";
    }
}

sub warn {
    my ($self, $method, $msg) = @_;
    return unless $self->{_DEBUG} || DEBUG;
    my $logmsg = (ref($self)||$self)."->".$method.": ".$msg;
    if (ref $self->{r} eq "Apache") {
	$self->{r}->warn($logmsg);
    } elsif (ref $self->{parent} and ref $self->{parent}->{r} eq "Apache") {
	$self->{parent}->{r}->warn($logmsg);
    } else {
	print STDERR "[".localtime()."] [warn] [client $ENV{REMOTE_ADDR}] ".
	  $logmsg."\n";
    }
}


1;
__END__

=head1 AUTHOR

Adi Fairbank <adi@adiraj.org>

=head1 COPYRIGHT

Copyright (c) 2004-2008 - Adi Fairbank

This software, the CGI::Widget::DBI::Search::Base Perl module,
is copyright Adi Fairbank.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the terms of either:

  a) the GNU General Public License as published by the Free Software
     Foundation; either version 1, or (at your option) any later version,

  or

  b) the "Artistic License" which comes with this module.

=head1 LAST MODIFIED

April 9, 2008

=cut
