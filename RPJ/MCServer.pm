package RPJ::MCServer;

use RPJ::MCServer::Defaults;
use RPJ::MCServer::Outputer;
use parent 'RPJ::MCServer::Outputer';
use RPJ::MCServer::Config;
use RPJ::Debug qw(pdebug ddump);
use strict;
use warnings;
use Exporter qw(import);

our @EXPORT = qw();

my $cmds = {
	'uptime' => {
		'command' => '/usr/bin/uptime',
		'regex' => qr/up\s+(.*?),\s+\d+\s+user.*?load\s+average:\s+(\d+\.\d+),\s+(\d+\.\d+),\s+(\d+\.\d+)/,
		'regexValues' => [ 'Uptime', 'LoadAvg1Min', 'LoadAvg5Min', 'LoadAvg15Min' ]
	},
	'CPUAndMem' => {
		'command' => '/bin/ps aux | /bin/grep -e "java.*nogui"',
		'regex' => qr/root\s+\d+\s+(\d+\.\d+)\s+(\d+\.\d+).*?(\d+\:\d+)\s+java.*?/,
		'regexValues' => ['CPU', 'Memory']
	}
};

sub _init
{
	my $self = shift;

	if (defined($self->{config}))
	{
		$self->{ConfigObj} = RPJ::MCServer::Config->new(
			ConfigHashRef => $self->{config},
			Defaults => $RPJ::MCServer::Defaults::DEFS->{ConfigKeys}
		);
		
		if ($self->{ConfigObj}->_isConfigValid())
		{
			$self->{config} = $self->{ConfigObj}->configRef();
		}
	}
	else
	{
		$self = undef;
	}
	
	return $self;
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

sub getInfo
{
	my $self = shift;
	my %args = @_;
	my $stats = {};
	
	$args{type} = $self->{config}->{OutputType}, if (defined($self->{config}->{OutputType}) && !defined($args{type}));

	foreach my $cmdName (keys(%{$cmds})) {
		my $cmd = $cmds->{$cmdName}->{'command'};
		pdebug "$self\->getInfo: \$cmd = $cmd\n";

		if (defined($cmd) && length($cmd)) {
			my $output = qx/$cmd/;
			pdebug "output:\n$output\n";
			my $regex = $cmds->{$cmdName}->{'regex'};
			my $rxVals = $cmds->{$cmdName}->{'regexValues'};
			pdebug "regex: $regex\trxVals: $rxVals\n";

			if ($output =~ /$regex/ig) {
				$stats->{$cmdName} = {};

				for (my $i = 0; $i < scalar(@{$rxVals}); $i++) {
					my $rxVal;
					my $rxInd = $i + 1;
					eval "\$rxVal = \$$rxInd";
					pdebug "post-eval for $rxInd: $rxVal\n";
					$stats->{$cmdName}->{$rxVals->[$i]} = $rxVal;
				}
			}
			else { print STDERR "Output for '$cmd' doesn't match '$regex':\n\t<<<<<\n$output\n\t>>>>>\n"; }
		}
		else { print STDERR "No command defined for '$cmdName'!\n"; }
	}

	ddump($stats, "$self\->getInfo()");
	
	if (defined($args{type}) && $args{type} eq $DEFS->{TypeNames}->{ASCII})
	{
		$stats = "No ASCII output type defined for $self.\n\n";
	}
	
	return ((!defined($args{type}) || $args{refOK}) ? $stats : $self->SUPER::genOutput(type => $args{type}, data => $stats));
}

sub getManager
{
	my $self = shift;

	if (!defined($self->{ManagerObj}))
	{
		$self->{ManagerObj} = RPJ::MCServer::Manager->new(
			ConfigHashRef => $self->{config}, 
			ParentObj => $self);
	}

	return $self->{ManagerObj};
}

sub new
{
	my $class = shift;
	my %conf = @_;
	my $self = {};

	bless($self, $class);
	$self->{config} = (defined($conf{ConfigHashRef}) ? $conf{ConfigHashRef} : { %conf });

	return $self->_init();
}

1;
