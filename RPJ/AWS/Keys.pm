package RPJ::AWS::Keys;

use strict;
use warnings;

use Exporter qw(import);

my $KEY_FILE_PATH = '/home/sulciphur/AWS';
my $PUB_KEY_FILE = 'public.key';
my $SEC_KEY_FILE = 'secret.key';

my $PUB_KEY = undef;

our @EXPORT = qw(public_key secret_key);

sub _read_from_file($)
{
    my $file = shift;
    my $rv = undef;

    open (PK, "$file") or die "open($file): $!\n\n";
    $rv = <PK>;
    chomp($rv);
    close(PK);
    
    return $rv;
}

sub public_key 
{
    $PUB_KEY = _read_from_file("$KEY_FILE_PATH/$PUB_KEY_FILE"), if (!defined($PUB_KEY));
    return $PUB_KEY;
}

sub secret_key
{
    return _read_from_file("$KEY_FILE_PATH/$SEC_KEY_FILE");
}

1;
