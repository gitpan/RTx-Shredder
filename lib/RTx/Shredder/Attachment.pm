package RT::Attachment;

use strict;
use RTx::Shredder::Exceptions;
use RTx::Shredder::Constants;
use RTx::Shredder::Dependencies;


sub Dependencies
{
	my $self = shift;
	my %args = (
			Flags => DEPENDS_ON,
			@_,
		   );

	unless( $self->id ) {
		RTx::Shredder::Exception->throw('Object is not loaded');
	}

	my $deps = RTx::Shredder::Dependencies->new();

# No dependencies that should be deleted with record

	return $deps;
}

1;
