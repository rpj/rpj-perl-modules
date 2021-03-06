package RPJ::Config;

use strict;
use warnings;
use Exporter qw(import);
use Scalar::Util qw(reftype);
use JSON;
use Data::Dumper;
use RPJ::Debug qw(pdebug ddump pdebugl);

our $REQD_WILDCARD = '_WC_';
our @EXPORT = qw($REQD_WILDCARD);

# TODO: differentiate between hash and arrays in the wildcard spec, because w/o
# type checking, an otherwise invalid config can appear valid via this class
=cut
[
	'max-queue-size', 'max-num-blocks', 'max-running-procs', 'mc-land-gen-path',
	'mc-land-gen-jar-name', 'map-render-output-path', 'min-side-size', 
	[ 'minecraft-versions', "$REQD_WILDCARD > 0" ], 
	[ 'map-renderers', "$REQD_WILDCARD > 0", [ 'path', 'exec-name', 'cmd-line' ] ]	
];
=cut

sub _setErrorString
{
	my $self = shift;
	my $string = shift;
	$self->{'error-string'} = $string;
}

sub _isConfigValid
{
	my $self = shift;
	my $ch = shift;
	my $reqdarr = shift;
	my $lastkey = shift;
	my $chrt = reftype($ch);

	pdebug "$self\::_isConfigValid() starting...\n";
	
	return 1, if ($self->{'config-is-valid'});
	return 0, unless (reftype($reqdarr) eq 'ARRAY');
	
	if (!defined($self->{ReqdConfKeys}))
	{
		$self->_setErrorString("$self\->{ReqdConfKeys} is not set. Cannot validate.");
		return 0;
	}

	my $reqdarrlen = scalar(@$reqdarr);
	pdebugl(2, "_isConfigValid(" . Dumper($ch) . ", " . Dumper($reqdarr) . " ($reqdarrlen))\n");

	my $traverseDownNextIter = 0;

	foreach my $vspec (@{$reqdarr})
	{
		my $vsrt = reftype($vspec);
		pdebugl(2, "LOOP TOP: '$vspec' (" . (defined($vsrt) ? $vsrt : "SCALAR") . ")\n");

		if (!defined($vsrt) || $vsrt eq 'SCALAR')
		{
			if ($vspec =~ /^$REQD_WILDCARD\s+(.*)/)
			{
				pdebug "Got wildcard spec: $1\n";

				my $wcspec = $1;
				
				if (!defined($chrt) || $chrt eq 'SCALAR')
				{
					$self->_setErrorString("Value type for key '$lastkey' is scalar: must be an array or hash.");
					return 0;
				}
				
				my $len = scalar(($chrt eq 'HASH' ? keys(%$ch) : @$ch));
				my $cond = "die, unless ($len $wcspec);";
				
				pdebugl(2, "Condition: $cond\n");
				eval "$cond";
		
				if ($@)
				{
					$self->_setErrorString("Length of value collection ($len) for key '$lastkey' " .
						"doesn't match required length ($wcspec).");
					return 0;
				}

				# $@ is null, hence the condition was satisfied.
				# however, if the reqdarr is larger than 1, there is another level
				# that is a child of this one that we must validate.
				$traverseDownNextIter = 1, if ($reqdarrlen > 1);
			}
			else
			{
				unless (defined($ch->{$vspec}))
				{
					$self->_setErrorString("Required configuration key '$vspec' (scalar) was not found.");
					return 0;
				}
			}
		}
		elsif ($vsrt eq 'ARRAY')
		{
			if ($traverseDownNextIter)
			{
				foreach my $cKey (keys(%$ch))
				{
					return 0, if (!$self->_isConfigValid($ch->{$cKey}, $vspec));
				}

				$traverseDownNextIter = 0;
			}
			else
			{
				my $vkey = shift(@$vspec);
				pdebugl(2, "". Dumper($vspec) ." is an array for key '$vkey'\n");

				unless ($ch->{$vkey})
				{
					$self->_setErrorString("Required configuration key '$vkey' (collection) was not found.");
					return 0;
				}
				
				return 0, if (!$self->_isConfigValid($ch->{$vkey}, $vspec, $vkey));
			}
		}
	}

	pdebug "RPJ::Config::_isConfigValid($ch) ending successfully.\n";
	return 1;
}

sub _completeConfigFromDefaults
{
	my $self = shift;
	my $config = $self->{config};
	my $defs = $self->{Defaults};

	if (defined($defs))
	{
		foreach my $dkey (keys(%{$defs}))
		{
			$config->{$dkey} = $defs->{$dkey}, unless(defined($config->{$dkey}));
		}
	}
}

sub _runValidation
{
	my $self = shift;
	$self->_completeConfigFromDefaults();
	$self->{'config-is-valid'} = $self->_isConfigValid($self->{'config'}, $self->{ReqdConfKeys});
}

sub _init 
{
	my $self = shift;
	my $configFile = $self->{'config-file-path'} = $self->{oconfig}->{ConfigFilePath};
	
	$self->{'config-is-valid'} = 0;
	$self->{'error-string'} = "No error";
	
	$self->{ReqdConfKeys} = $self->{oconfig}->{ReqdConfKeys};

	if ($self->{'config-file-path'})
	{
		die "Cannot find config file at '$configFile': $!\n\n", unless (-e $configFile);

		my $confSlurp = undef;
		open (CFS, "$configFile") or die "open('$configFile') failed: $!\n\n";
		{ local $/ = undef; $confSlurp = <CFS>; }
		close (CFS);

		$self->{'config'} = undef;
		eval { $self->{'config'} = decode_json($confSlurp); };
	}
	elsif ($self->{oconfig})
	{
		$self->{config} = $self->{oconfig};
	}
	else
	{
		$@ = "Unable to find a validate config to validate.";
	}

	if (!$@)
	{
		# if everything was successful to this point, determine if the configuration is valid as spec'ed
		$self->_runValidation(), if (defined($self->{ReqdConfKeys}));
	}
	else
	{
		$self->{'error-string'} = "Malformed JSON: $@";
	}

	return $self;
}

sub configRef
{
	return (shift)->{config};
}

sub valueForKey
{
	return (shift)->{'config'}->{(shift)};
}

sub isValid
{
	return (shift)->{'config-is-valid'};
}

sub errorString
{
	return (shift)->{'error-string'};
}

sub setReqdKeys
{
	my $self = shift;
	my $reqd_keys = shift;
	
	$self->{ReqdConfKeys} = $reqd_keys;
	$self->_runValidation();
}

sub new 
{
	my $cls = shift;
	my %conf = @_;
	my $self = {};

	bless ($self, $cls);
	$self->{oconfig} = (defined($conf{ConfigHashRef}) ? $conf{ConfigHashRef} : { %conf });
	$self->{Defaults} = $conf{Defaults}, if (defined($conf{Defaults}));

	return $self->_init();
}

1;
