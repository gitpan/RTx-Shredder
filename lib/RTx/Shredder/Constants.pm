package RTx::Shredder::Constants;

require Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter);

=head1 NAME

RTx::Shredder::Constants -  RTx::Shredder constants that is used to mark state of RT objects.

=head1 DESCRIPTION

This module exports two group of bit constants.
First group is group of flags which are used to dependecies between objects, and
second group is states of RT objects in Shredder cache.

=head1 FLAGS

=head2 DEPENDS_ON

Targets that has such dependency flag set should be wiped out with base object.

=head2 WIPE_AFTER

If dependency has such flag then target object should be wiped only
after base object. Group and Principal have such relation ship.

=head2 RELATES

This flag is used to validate relationships integrity. Base object
is valid only when all target objects which are marked with this flags
exist.

=cut

use constant {
	DEPENDS_ON	=> 0x000001,
	WIPE_AFTER	=> 0x000010,
	RELATES		=> 0x000100,
};

=head1 STATES

=head2 ON_STACK

Default state of object in Shredder cache that means that object is
loaded and placed into cache.

=head2 WIPED

Objects with this state are not exist any more in DB, but perl
object is still in memory. This state is used to be shure that
delete query is called once.

=head2 VALID

Object is marked with this state only when its relationships
are valid.

=head2 INVALID

=cut

use constant {
	ON_STACK	=> 0x00000,
	WIPED		=> 0x00001,
	VALID		=> 0x00010,
	INVALID		=> 0x00100,
};

our @EXPORT = qw(
		DEPENDS_ON
		WIPE_AFTER
		RELATES
		ON_STACK
		WIPED
		VALID
		INVALID
		);

1;
