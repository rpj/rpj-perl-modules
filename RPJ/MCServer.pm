package RPJ::MCServer;

use strict;
use warnings;
use Exporter qw(import);
use RPJ::MCServer::Defaults;
use RPJ::Debug;

our @EXPORT = qw();

sub _init
{
	my $self = shift;

	if (defined($self->{'config'}))
	{
		$self->_completeConfigFromDefaults();
		RPJ::Debug::ddump($self->{'config'}, "$self\->new()");
	}
	else
	{
		$self = undef;
	}
	
	return $self;
}

sub _completeConfigFromDefaults($$)
{
	my $self = shift;
	my $config = $self->{'config'};
	
	foreach my $dkey (keys(%{$DEFS->{ConfigKeys}}))
	{
		$config->{$dkey} = $DEFS->{ConfigKeys}->{$dkey}, unless(defined($config->{$dkey}));
	}
}

sub getPlayers
{
	my $self = shift;
	
	if (!defined($self->{'players'}))
	{
		$self->{'players'} = RPJ::MCServer::Players->new(ConfigHashRef => $self->{'config'}, ParentServerObj => $self);
	}
	
	return $self->{'players'};
}

sub new
{
	my $class = shift;
	my %conf = @_;
	my $self = {};

	bless($self, $class);
	$self->{'config'} = (defined($conf{ConfigHashRef}) ? $conf{ConfigHashRef} : { %conf });

	return $self->_init();
}

1;