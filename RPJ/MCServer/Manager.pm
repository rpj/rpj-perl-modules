package RPJ::MCServer::Manager;

use strict;
use warnings;
use Exporter qw(import);
use Net::Telnet ();
use RPJ::MCServer::Defaults;

our @EXPORT = ();
our @EXPORT_OK = ();

my $RTSTOPCMD = '.stopwrapper';
my $SCREEN = `which screen` || '/usr/bin/screen';
my $SCREENRCTEMPLATE = <<__SRCDOC__;
screen -t server-console bash
shell -bash
chdir <GAMEDIR>
exec <GAMEDIR>/<GAMESCRIPT>
__SRCDOC__

sub _action_start
{
	my $self = shift;
	my $output = "";
	my $screenrctemplate = $SCREENRCTEMPLATE;
	my $screenrc = $screenrctemplate;

	my $dir = $self->{config}->{ServerRoot};
	my $cmd = "$self->{config}->{ServerRoot}/$self->{config}->{ServerCmdRelPath}";
	my $name = $self->{config}->{ServerName};

	$screenrc =~ s/\<GAMEDIR\>/$dir/g;
	$screenrc =~ s/\<GAMESCRIPT\>/$cmd/g;

	my $rcname = "$self->{config}->{ManagerRunPath}/.${name}.screenrc";
	print "Creating $rcname...\n";
	open (RC, "+>$rcname") or die "open(+>$rcname): $!\n\n";
	print RC $screenrc;
	close (RC);

	my $cmdstr = "$SCREEN -S '$name -c $rcname -d -m";
	print "Launching '$cmdstr'\n";
	`$cmdstr`;

	return $output;
}

sub _action_stop
{
	my $self = shift;
	my $output = "";
	
	my $tk = $server->{'toolkit'};

	if (defined($tk))
	{
		my $t = Net::Telnet->new(Timeout => 120);
		$t->telnetmode(0);

		if (($t->open(Host => 'localhost', Port => int($self->{config}->{ToolkitPort})) == 1))
		{
			$t->waitfor('/Minecraft\s+RemoteShell.*$/');
			$t->waitfor('/Enter\s+username:\s+/');
			$t->print("$self->{config}->{ToolkitUser}");

			$t->waitfor('/Enter\s+password:\s+/');
			$t->print("$self->{config}->{ToolkitPass}");

			$t->waitfor('/Connected to console!/');
			$t->print("$RTSTOPCMD");

			$t->waitfor('/.*\[INFO\]\s+Stopping\s+server/');
			$output = "Stoped server $self->{config}->{ServerName} at " .
				"rt-port $self->{config}->{ToolkitPort} successfully.\n";
		}
		else
		{
			$output = "Cannot connect to remote toolkit for $self->{config}->{ServerName}\n\n";
		}
	}
	
	return $output;
}

sub _action__default
{
	my $self = shift;
	return "Running screens:\n\n" . `$SCREEN -ls`;
}

sub runAction
{
	my $self = shift;
	my $action = shift;
	my $output = "$0::$self running '$action' action at " . scalar(localtime()) . "\n";
	
	eval "\$output .= &\$self->$action()";
	$output .= $self->_action__default(), if ($@);
	
	return $output;
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