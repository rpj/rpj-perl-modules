package RPJ::MCServer::Players;

use RPJ::MCServer::Defaults;
use RPJ::MCServer::Outputer;
use RPJ::Debug qw(pdebug ddump);
use RPJ::Util;
use parent 'RPJ::MCServer::Outputer';
use strict;
use warnings;
use Exporter qw(import);
use Time::Local;
use JSON;
use DBI;

our @EXPORT = qw();

my $IP_RX = qr/\[\/[\d\.]+\:\d+\]/;
my $UNAME_RX = qr/\<?([_0-9\w].*?)\>?/;
my $DATE_RX = qr/(\d{4}\-\d{2}\-\d{2})\s+(\d{2}:\d{2}:\d{2})/;
my $USER_INFO_RX = qr/\[INFO\]\s+$UNAME_RX/;
my $LOGIN_RX = qr/$USER_INFO_RX\s+$IP_RX\s+logged\s+in/;
my $LOGOUT_RX = qr/$USER_INFO_RX\s+lost\s+connection:\s+disconnect\.(.*)/;
my $CHAT_RX = qr/$USER_INFO_RX\s+(.*)/;

my $DCONN_LINE_RX = qr/$DATE_RX\s+\[INFO\]\s+Disconnecting\s+$UNAME_RX\s+($IP_RX)\:\s+(.*)/;
my $LOGIN_LINE_RX = qr/$DATE_RX\s+$LOGIN_RX/;
my $LOGOUT_LINE_RX = qr/$DATE_RX\s+$LOGOUT_RX/;
my $CHAT_LINE_RX = qr/$DATE_RX\s+$CHAT_RX/;

sub _f_convertTimestampToSeconds($$) {
	my $date = shift;
	my $time = shift;
	
	my ($y, $m, $d) = split(/\-/, $date);
	my ($h, $min, $sec) = split(/:/, $time);
	$m -= 1;

	return timelocal($sec, $min, $h, $d, $m, $y);
}

sub _checkAndSetLeaderboard {
	my $self = shift;
	my $uh = shift;
	my $key = shift;
	my $un = shift;

	push (@{$self->{m}->{ahash}->{'lists'}->{$key}}, { 'value' => $uh->{$key}, 'user' => $un });

	my $chkval = $self->{m}->{ahash}->{'leaderboard'}->{$key}->{'value'};
	
	if (defined($uh->{$key}) && (!defined($chkval) || (defined($chkval) && $uh->{$key} > $chkval))) {
		$self->{m}->{ahash}->{'leaderboard'}->{$key} = { 'value' => $uh->{$key}, 'user' => $un };
	}
}

sub _sortLeadLists() {
	my $self = shift;
	
	# first pass: sort lists
	foreach my $lKey (keys %{$self->{m}->{ahash}->{'lists'}})
	{
		# sorts descending so that the largest val (the leader) is at index 0
		my @newarr = sort { $b->{'value'} <=> $a->{'value'} } @{$self->{m}->{ahash}->{'lists'}->{$lKey}};
		$self->{m}->{ahash}->{'lists'}->{$lKey} = \@newarr;
	}

	# second pass: determine player ranks
	foreach my $lKey (keys %{$self->{m}->{ahash}->{'lists'}})
	{
		my $h = $self->{m}->{ahash}->{'lists'}->{$lKey};
	
		for (my $i = 0; $i < scalar(@{$h}); $i++)
		{
			my $un = $h->[$i]->{'user'};
			$self->{m}->{ahash}->{'ranks'}->{$lKey}->{$un} = $i + 1;
			$self->{m}->{uhash}->{$un}->{'ranks'}->{$lKey} = $i + 1;
		}
	}
}

sub _parsePlayerStats
{
	my $self = shift;
	
	open (LF, "$self->{m}->{LOG_FILE}") or die "Failed to open $self->{m}->{LOG_FILE}: $!\n\n";

	my $lc = 1;
	foreach my $line (<LF>) {
		if ($line =~ $LOGIN_LINE_RX) {
			my $user = $self->getUser($3);

			$user->{loginCount}++;
			$user->{'lastLogin'} = _f_convertTimestampToSeconds($1, $2); 
			$self->{m}->{ahash}->{loginCount}++;
		}

		if ($line =~ $LOGOUT_LINE_RX) {
			my $username = $3;
			my $user = $self->{m}->{uhash}->{$username};
			my $llTime = undef;

			if (defined($user) && ($llTime = $user->{'lastLogin'}) > 0) {
				my $loTime = _f_convertTimestampToSeconds($1, $2);
				my $dur = $loTime - $llTime;
				$user->{'accumLoggedIn'} += $dur;
				$user->{'lastSeen'} = { 'time' => $user->{'lastLogin'}, 'duration' => $dur };
				$user->{'lastLogin'} = -1;
				$user->{'disconnects'}->{'proper'}->{$4}++;

				$user->{'longestSession'} = $dur, if (!defined($user->{'longestSession'}) || $dur > $user->{'longestSession'});

				$self->{m}->{ahash}->{'disconnects'}->{'proper'}++;
				push(@{$self->{m}->{thash}->{loginDurations}}, $dur);
			}
			else {
				print STDERR "Mismatch for user $3 at logout time '$1 $2':\n\t[$self->{m}->{LOG_FILE}:$lc] $line\n";
			}
		}

		if ($line =~ $CHAT_LINE_RX) {
			my $uh = $self->{m}->{uhash}->{$3};
			$uh->{'chatLineCount'}++;
			$self->{m}->{ahash}->{'chatLineCount'}++;
		}

		if ($line =~ $DCONN_LINE_RX) {
			my $uh = $self->getUser($3);
			push (@{$uh->{'disconnects'}->{'forced'}}, { 'date' => $1, 'time' => $2 });
			$self->{m}->{ahash}->{'disconnects'}->{'forced'}++;
		}

		++$lc;
	}
	
	$self->{m}->{ahash}->{loginDurations}->{mean} = mean($self->{m}->{thash}->{loginDurations});
	$self->{m}->{ahash}->{loginDurations}->{stdDev} = sampleStdDev($self->{m}->{thash}->{loginDurations});

	# second pass
	foreach my $un (sort(keys(%{$self->{m}->{uhash}}))) {
		my $uh = $self->{m}->{uhash}->{$un};

		if (defined($uh->{loginCount}) && $uh->{loginCount} > 0)
		{
			$uh->{'avgLoggedInTime'} = $uh->{'accumLoggedIn'} / $uh->{loginCount};
			$self->{m}->{ahash}->{'accumLoggedIn'} += $uh->{'accumLoggedIn'};
			$self->{m}->{ahash}->{'activeUserCount'}++;

			$self->_checkAndSetLeaderboard($uh, 'longestSession', $un);
			$self->_checkAndSetLeaderboard($uh, 'avgLoggedInTime', $un);
			$self->_checkAndSetLeaderboard($uh, 'accumLoggedIn', $un);
			$self->_checkAndSetLeaderboard($uh, 'loginCount', $un);
			$self->_checkAndSetLeaderboard($uh, 'chatLineCount', $un);
		}
	}

	# third pass
	$self->_sortLeadLists();

	# parse stats.db
	if (-e $self->{m}->{STATS_DB_FILE})
	{
		my $dbh = DBI->connect("dbi:SQLite:dbname=$self->{m}->{STATS_DB_FILE}", "", "");
		# TODO ..
	}
}

sub _init
{
	my $self = shift;

	if (defined($self->{oconfig}) && defined($self->{oconfig}->{ConfigHashRef}))
	{
		$self->{config} = $self->{oconfig}->{ConfigHashRef};
		$self->{m}->{LOG_FILE} = "$self->{config}->{ServerRoot}/$self->{config}->{ServerLogRelPath}";
		$self->{m}->{STATS_DB_FILE} = "$self->{config}->{ServerRoot}/$self->{config}->{StatsDBRelPath}";
		$self->{m}->{uhash} = {};
		$self->{m}->{ahash} = {};
	}
	else
	{
		$self = undef;
	}
	
	return $self;
}

sub getUser {
	my $self = shift;
	my $user = shift;
	$self->{m}->{uhash}->{$user} = {}, unless(defined($self->{m}->{uhash}->{$user}));
	return $self->{m}->{uhash}->{$user};
}

sub getInfo
{
	my $self = shift;
	my %args = @_;
	
	$self->_parsePlayerStats();
	
	my $stats = { aggregate => $self->{m}->{ahash}, perUser => $self->{m}->{uhash} };
	
	$args{type} = $self->{config}->{OutputType}, if (defined($self->{config}->{OutputType}) && !defined($args{type}));
	
	if (defined($args{type}) && $args{type} eq $DEFS->{TypeNames}->{ASCII})
	{
		$stats = "Total logins:\t$self->{m}->{ahash}->{loginCount}\n";
		$stats .= "Total playtime:\t" . sprintf("%0.1f", $self->{m}->{ahash}->{'accumLoggedIn'} / 60.0) . " minutes\n";
		$stats .= "-------------------+-------------------+------------------------+------------------------\n";
		$stats .= "     Username      |   # of logins     |  Total playtime (mins) |  Playtime/login (mins)\n";
		$stats .= "-------------------+-------------------+------------------------+------------------------\n";

		foreach my $un (sort(keys(%{$self->{m}->{uhash}}))) {
			my $uh = $self->{m}->{uhash}->{$un};
			
			$stats .= sprintf("%17s%s | %11s (#%02d) | %16s (#%02d) | %16s (#%02d)\n", $un, 
				($uh->{'lastLogin'} == -1 ? ' ' : "*"),
				$uh->{'loginCount'}, $self->{m}->{ahash}->{'ranks'}->{'loginCount'}->{$un},
				sprintf("%0.2f", ($uh->{'accumLoggedIn'} / 60.0)), $self->{m}->{ahash}->{'ranks'}->{'accumLoggedIn'}->{$un},
				sprintf("%0.2f", ($uh->{'avgLoggedInTime'} / 60.0)),
				$self->{m}->{ahash}->{'ranks'}->{'avgLoggedInTime'}->{$un}), 
					if (defined($uh->{'loginCount'}));
		}

		$stats .= "-------------------+-------------------+------------------------+------------------------\n";
	}
	
	return ((!defined($args{type}) || $args{refOK}) ? $stats : $self->SUPER::genOutput(type => $args{type}, data => $stats));
}

sub new
{
	my $class = shift;
	my %conf = @_;
	my $self = {};

	bless($self, $class);
	$self->{oconfig} = { %conf };

	return $self->_init();
}

1;
