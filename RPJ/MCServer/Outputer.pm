package RPJ::MCServer::Outputer;

use strict;
use warnings;
use Exporter qw(import);
use RPJ::MCServer::Defaults;
use RPJ::Debug qw(pdebug);

our @EXPORT = ();
our @EXPORT_OK = ();

sub genOutput
{
	my $self = shift;
	my %args = @_;
	my $outstr = undef;
	my $type = $args{type};
	my $types = $DEFS->{TypeNames};
	
	$type = $self->{oconfig}->{OutputType}, if (!defined($type) && defined($self->{oconfig}->{OutputType}));
	
	if ($type eq $types->{ASCII})
	{
		$outstr = $args{data};
	}
	else
	{
		my ($reqmod, $func);
		
		if ($type eq $types->{JSON})
		{
			$reqmod = "JSON";
			$func = "JSON::encode_json";
		}
		elsif ($type eq $types->{DataDumper})
		{
			$reqmod = "Data::Dumper";
			$func = "Data::Dumper::Dumper";
		}
		
		if (defined($reqmod) && defined($func))
		{
			eval "require $reqmod; \$outstr = $func(\$args{data});";
			die "Failed to generate $reqmod output: $@\n\n", if ($@);
		}
		else
		{
			die "Unknown output type in genOutput: $args{type}\n\n";
		}
	}
	
	return $outstr;
}

sub new
{
	my $class = shift;
	my %conf = @_;
	my $self = {};

	bless($self, $class);
	$self->{oconfig} = { %conf };

	return $self;
}

1;