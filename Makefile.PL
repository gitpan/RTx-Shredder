use lib qw(.);
use inc::Module::Install;

$ENV{'WITH_SUBDIRS'} = 'sbin,lib';
RTx			('Shredder');
author			('Ruslan U. Zakirov <cubic@wildgate.miee.ru>');
license			('perl');

my ($lp) = $INC{'RT.pm'} =~ /^(.*)[\\\/]/;
my $lib_path = join( ' ', "$RT::LocalPath/lib", $lp );
print `./configure --with-rt-lib='$lib_path'`;

build_requires		('Test::More');
requires		('Getopt::Simple');

skip( qr/\.in$/ );

&WriteAll;
