use lib qw(.);
use inc::Module::Install;

$ENV{'WITH_SUBDIRS'} = 'sbin,lib';
RTx			('Shredder');
author			('Ruslan U. Zakirov <cubic@wildgate.miee.ru>');
license			('perl');

build_requires		('Test::More');
requires		('Getopt::Long');
requires		('Getopt::Simple');
requires		('Exception::Class');

my ($lp) = $INC{'RT.pm'} =~ /^(.*)[\\\/]/;
my $lib_path = join( ' ', "$RT::LocalPath/lib", $lp );
print `./configure --with-rt-lib='$lib_path'`;

skip( qr/\.in$/ );

&WriteAll;
