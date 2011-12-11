package RPJ::MCServer::Manager;

use strict;
use warnings;
use Exporter qw(import);
use Net::Telnet ();
use RPJ::MCServer::Defaults;
use RPJ::MCServer::Players;
use RPJ::Debug qw(pdebug ddump);

our @EXPORT = ();
our @EXPORT_OK = ();

my $RTSTOPCMD = '.stopwrapper';
my $SCREEN = `which screen` || '/usr/bin/screen';
chomp($SCREEN);
my $SCREENRCTEMPLATE = <<__SRCDOC__;
screen -t server-console bash
shell -bash
chdir <GAMEDIR>
exec <GAMEDIR>/<GAMESCRIPT>
__SRCDOC__

sub _action_canshutdown
{
	my $self = shift;
	my $output = "";
	
	if ($self->{parent})
	{
		my $pinfo = $self->{parent}->getPlayers()->getInfo();
	}

	return $output;
}

sub _action_start
{
	my $self = shift;
	my $output = "";
	my $screenrctemplate = $SCREENRCTEMPLATE;
	my $screenrc = $screenrctemplate;

	my $dir = $self->{config}->{ServerRoot};
	my $cmd = $self->{config}->{ServerCmdRelPath};
	my $name = $self->{config}->{ServerName};

	$screenrc =~ s/\<GAMEDIR\>/$dir/g;
	$screenrc =~ s/\<GAMESCRIPT\>/$cmd/g;

	`mkdir -p $self->{config}->{ManagerRunPath}`, unless (-d $self->{config}->{ManagerRunPath});

	my $rcname = "$self->{config}->{ManagerRunPath}/.${name}.screenrc";
	print "Creating $rcname...\n";
	open (RC, "+>$rcname") or die "open(+>$rcname): $!\n\n";
	print RC $screenrc;
	close (RC);

	my $cmdstr = "$SCREEN -S $name -c $rcname -d -m";
	print "Launching '$cmdstr'\n";
	`$cmdstr`;

	return $output;
}

sub _action_stop
{
	my $self = shift;
	my $output = "";
	
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
		$output = "Stoped server '$self->{config}->{ServerName}' at toolkit " .
			"port $self->{config}->{ToolkitPort} successfully.\n";
		
		# kill off the screen session, assuming no other windows had been added
		`$SCREEN -D '$self->{config}->{ServerName}'`;
	}
	else
	{
		$output = "Cannot connect to $self->{config}->{ServerName} remote toolkit ".
				"on port $self->{config}->{ToolkitPort}\n\n";
	}
	
	return $output;
}

sub _action__default
{
	my $self = shift;
	my $rv = "Running screens ($SCREEN):\n\n";
	$rv .= `$SCREEN -ls`;
	return $rv;
}

sub runAction
{
	my $self = shift;
	my $action = shift || "";
	ddump($self, "$self -> runAction");
	my $output = "RPJ::MCServer::Manager(name='$self->{config}->{ServerName}') running action ".
		"'$action' at " . scalar(localtime()) . "\n";
	pdebug($output);
	
	$action = "_default", unless ($action && length($action));

	my $evalstr = "\$output .= \$self->_action_${action}()";
	pdebug("evalstr -> $evalstr\n");
	eval "$evalstr";
	print "ERROR running action '$action': $@", if ($@);
	
	return $output;
}

sub _init { return (shift); }

sub new
{
	my $class = shift;
	my %conf = @_;
	my $self = {};

	bless($self, $class);
	$self->{config} = (defined($conf{ConfigHashRef}) ? $conf{ConfigHashRef} : { %conf });
	$self->{parent} = $conf{ParentObj};

	return $self->_init();
}

1;
