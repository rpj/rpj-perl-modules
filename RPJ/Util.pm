package RPJ::Util;

use strict;
use warnings;
use Exporter qw(import);
use Scalar::Util qw(reftype);

our @EXPORT = qw(sampleStdDev movingMean mean);

sub movingMean
{
	my $idx = shift;
	my $newval = shift;
	my $lastvalref = shift;
	
	return ($$lastvalref = ($newval + ($idx * $$lastvalref)) / ($idx + 1));
}

sub mean
{
	my $arr = shift;
	my $mean = 0;
	my $i = 0;
	
	if ($arr && reftype($arr) eq 'ARRAY')
	{
		for ($i = 0; $i < scalar(@$arr); $i++) { movingMean($i, $arr->[$i], \$mean); }
	}
	
	return $mean;
}

sub sampleStdDev
{
	my $arr = shift;
	my $sum = undef;
	
	if ($arr && reftype($arr) eq 'ARRAY')
	{
		my $tarr = [];
		my $mean = mean($arr);
		my $val;
		
		foreach $val (@$arr) { push(@$tarr, ($val - $mean) ** 2); }
		foreach $val (@$tarr) { $sum += $val; }
		$sum /= scalar(@$arr) - 1;
		$sum = sqrt($sum);
	}
	
	return $sum;
}

1;