package RT::TicketCustomFieldValue;

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

#TODO: We should export Custom Field if want export tool.

	return $deps;
}

1;

