package RPJ::MCServer::Manager;

use strict;
use warnings;
use Exporter qw(import);
use Net::Telnet ();
use RPJ::MCServers;
use RPJ::MCServer;
use RPJ::MCServer::Players;
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

sub __checkMgrRunPath
{
	my $self = shift;
	`mkdir -p $self->{config}->{ManagerRunPath}`, unless (-d $self->{config}->{ManagerRunPath});
}

sub __loggedInTelnetObj
{
	my $self = shift;
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
	}
	else { $t = undef; }

	return $t;
}

sub __loggedInCount
{
	my $self = shift;
	my $t = $self->__loggedInTelnetObj();
	my $numusers = -1;

	if ($t)
	{
		$t->print("list");
		print "Sent 'list' to $t, now waiting...\n";
		my ($pre, $match) = $t->waitfor('/.*\[INFO\].*?There\s+are.*?(\d+).*?out\s+of\s+a\s+maximum.*?(\d+).*?/');
		$pre =~ tr/\000-\037/ /c;
		$match =~ tr/\000-\037/ /c;
		print "PRE: [$pre]\tMATCH: [$match]\n";
	}

	return $numusers;
}

sub _action_canshutdown
{
	my $self = shift;
	my $output = "";
	
	if ($self->{parent})
	{
		my $pinfo = $self->{parent}->getPlayers()->getInfo(forceRef => 1);
		my $ainfo = $pinfo->{aggregate};
		my $uinfo = $pinfo->{perUser};
		
		if ($pinfo)
		{
			$self->__checkMgrRunPath();

			my $rfp = "$self->{config}->{ManagerRunPath}/.$self->{config}->{ServerName}.cs";
			my $meanmin = $ainfo->{loginDurations}->{mean} / 60;
			my $sigmamin = $ainfo->{loginDurations}->{stdDev} / 60;
			my $sigcoeff = 0.1;
			my $csigmin = $sigmamin * $sigcoeff;

			$output = "Mean:\t$meanmin\nCSig:\t$csigmin\n";

			my $csinfo = { IdleTime => 0, LastLogin => 0 };
=cut
			if (-e $rfp)
			{
				open (R, "$rfp") or return "$rfp: $!\n\n";
				{ local $/ = undef; $csinfo = <R>; close(R); }
				
				eval { $csinfo = decode_json($csinfo); };
				return "decode_json for $rfp failed: $@\n\n", if ($@);
			}
=cut			
			my $now = time();
			my $canshutdown = 1;
			
			foreach my $uname (keys %$uinfo)
			{
				next, unless (defined($uinfo->{$uname}->{lastSeen}));

				my $durLast = $uinfo->{$uname}->{lastSeen}->{duration};
				my $seenLast = ($now - ($uinfo->{$uname}->{lastSeen}->{time} + $durLast)) / 60;
				$durLast /= 60;

				if ($seenLast <= $meanmin)
				{
					$output .= "$uname seen $seenLast minutes ago...\n";

					if ($durLast > $csigmin) {
						$output .= "$uname saved the server by playing for $durLast minutes!\n";
					}
					else {
						$output .= "$uname doomed the server by only playing $durLast minutes...\n";
					}
				}

				if ($uinfo->{$uname}->{lastLogin} > 0) {
					$output .= "$uname is logged in now!\n";
					$canshutdown = 0;
				}
				else {
					# because of the way $seenLast is calculated, the second condition here
					# is redundant, I believe. but since I haven't proven that, I'm leaving it here
					$canshutdown = ($seenLast <= $meanmin && $durLast > $csigmin) ? 0 : 1;
				}

				last, if (!$canshutdown);
			}

			# don't fuck with this output line!
			$output .= "[Can Shutdown: $canshutdown]\n\n";
		}
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

	$self->__checkMgrRunPath();

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
