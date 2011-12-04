package RPJ::MCServer::Players;

use strict;
use warnings;
use Exporter qw(import);

our @EXPORT = qw();

sub _init
{
	my $self = shift;

	if (defined($self->{'config'}))
	{
	}
	else
	{
		$self = undef;
	}
	
	return $self;
}

sub new
{
	my $class = shift;
	my %conf = @_;
	my $self = {};

	bless($self, $class);
	$self->{'config'} = { %conf };

	return $self->_init();
}

1;