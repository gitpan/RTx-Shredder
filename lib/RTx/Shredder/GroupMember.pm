package RT::GroupMember;

use strict;
use RTx::Shredder::Constants;
use RTx::Shredder::Exceptions;
use RTx::Shredder::Dependencies;


sub Dependencies
{
	my $self = shift;
	my %args = (
			Shredder => undef,
			Flags => DEPENDS_ON,
			@_,
		   );

	unless( $self->id ) {
		RTx::Shredder::Exception->throw('Object is not loaded');
	}

	my $deps = RTx::Shredder::Dependencies->new();

# No dependencies that should be deleted with record

#TODO: If we plan write export tool we also should fetch parent groups
# now we only wipeout things.

	return $deps;
}

1;
