package RPJ::Debug;

use threads;
use POSIX qw(strftime);
use Exporter qw(import);

@EXPORT = qw(pdebug pdebugl qprint debugLevel);

our $__DEBUG = 2;

sub __prependString {
    my $pch = shift || "-";
    return "[$0 <$$> - " . (strftime("%a %b %e %H:%M:%S %Y", localtime)) . " - DL ${pch} - Thread " . threads->tid() . " ] ";
}

sub qprint($) {
    { my $ofh = select STDOUT; $| = 1; select $ofh; }
    print __prependString() . (shift) . "";
}
sub pdebug($) {
    { my $ofh = select STDERR; $| = 1; select $ofh; }
    print STDERR __prependString($__DEBUG) . (shift) . "", if ($__DEBUG);
}

sub pdebugl($$) {
    my ($level, $str) = @_;
    pdebug($str), if ($level <= $__DEBUG);
}

sub setDebugLevel {
    $__DEBUG = shift;
}

sub debugLevel {
	return $__DEBUG;
}

1;
