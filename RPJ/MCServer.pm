package RPJ::MCServer;

use strict;
use warnings;
use Exporter qw(import);

use Data::Dumper;

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
	
	print "$self CONFIG " . Dumper($self->{'config'}) . "\n";

	return $self->_init();
}

1;