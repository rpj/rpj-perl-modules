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

	$self->{ReqdKeysArrRef} = [ "$RPJ::Config::REQD_WILDCARD > 0" ];
	my $tarrref = [];

	push(@$tarrref, $ckey), foreach my $ckey (keys(@{$DEFS->{ConfigKeys}}));
	$self->SUPER::setReqdKeys($tarrref);

	return $self;
}

sub new 
{
	my $cls = shift;
	my %conf = @_;
	my $self = {};

	bless ($self, $cls);
	$self->{oconfig} = (defined($conf{ConfigHashRef}) ? $conf{ConfigHashRef} : { %conf });

	return $self->_init();
}

1;
