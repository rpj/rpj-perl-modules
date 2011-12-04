package RPJ::MCServer::Config;

use strict;
use warnings;
use Exporter qw(import);
use RPJ::Config;
use parent qw(RPJ::Config);
use RPJ::MCServer::Defaults;

sub _init
{
	my $self = (shift)->SUPER::_init();

	my $tarrref = [];

	foreach my $ckey (keys(%{$DEFS->{ConfigKeys}})) { push(@$tarrref, $ckey); }
	$self->SUPER::setReqdKeys($tarrref);

	return $self;
}

1;
