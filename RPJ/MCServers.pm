package RPJ::MCServers;

use RPJ::Config;
use RPJ::Debug qw(pdebug ddump);
use RPJ::MCServer;
use RPJ::MCServer::Defaults;
use parent qw(RPJ::Config);
use strict;
use warnings;
use Exporter qw(import);

sub _init
{
	my $self = (shift)->SUPER::_init();
	
	$self->setReqdKeys([ "$RPJ::Config::REQD_WILDCARD > 0" ]);

	if ($self->_isConfigValid())
	{
		$self->{ServerObjs} = {};

		foreach my $server (keys(%{$self->configRef()}))
		{
			$self->configRef()->{$server}->{ServerName} = $server;
			$self->{ServerObjs}->{$server} = 
				RPJ::MCServer->new(ConfigHashRef => $self->configRef()->{$server});
		}
	}

	return $self;
}

sub getServers
{
	my @vals = values(%{(shift)->{ServerObjs}});
	return \@vals;
}

sub getServerByName
{
	my $self = shift;
	my $name = shift;

	return $self->{ServerObjs}->{$name};
}

1;
