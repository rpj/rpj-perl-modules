package RPJ::MCServer::Defaults;

use strict;
use warnings;
use Exporter qw(import);

our @EXPORT = qw($DEFS);

our $DEFS =
{
	TypeNames 		=>
	{
		JSON 				=> 'json',
		ASCII 				=> 'ascii',
		DataDumper 			=> 'dump',
	},
	ConfigFilePath 	=> "./mc-server-info.conf",
	ConfigKeys 		=>
	{
		ServerRoot			=> '/minecraft',
		ServerLogRelPath	=> 'server.log',
		StatsDBRelPath		=> 'plugins/Stats/stats.db',
		ServerInfoOutput	=> '/tmp/mc-server-info.output',
		ServerOutputOwner	=> 'ec2-user',
		ServerOutputMode	=> '0600',
		ServerCmdRelPath	=> 'rtoolkit.sh',
		ToolkitPort			=> '20099',
		ToolkitUser			=> 'user',
		ToolkitPass			=> 'pass',
		ManagerRunPath		=> '/root',
	},
};

1;