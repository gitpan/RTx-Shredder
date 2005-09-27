use lib qw(.);
use inc::Module::Install;

$ENV{'WITH_SUBDIRS'} = 'sbin,lib,html';
RTx			('Shredder');
author			('Ruslan U. Zakirov <Ruslan.Zakirov@gmail.com>');
license			('perl');

requires		('Getopt::Long');
requires		('Exception::Class');
requires		('RT', 3.4);
requires		('IO::String');
requires		('Pod::Parser');

build_requires		('DBD::SQLite');
build_requires		('Test::More');
build_requires		('Test::Deep');
build_requires		('File::Spec');
build_requires		('File::Path');
build_requires		('File::Copy');
build_requires		('Cwd');

my ($lp) = $INC{'RT.pm'} =~ /^(.*)[\\\/]/;
my $lib_path = join( ' ', "$RT::LocalPath/lib", $lp );
my $sbin_path = $RT::SbinPath || "$RT::BasePath/sbin" || "/opt/rt3/sbin";

substitute( { RT_LIB_PATH => $lib_path,
	      RT_SBIN_PATH => $sbin_path,
	    },
	    qw(sbin/rtx-shredder
	       sbin/rtx-validator
	       lib/RTx/Shredder.pm
	       t/utils.pl)
	  );

&WriteAll;
