package RT::TicketCustomFieldValue;

use strict;
use RTx::Shredder::Exceptions;
use RTx::Shredder::Dependencies;


sub Dependencies
{
	my $self = shift;
	my %args = (
			Cached => undef,
			Strength => 'DependsOn',
			@_,
		   );

	unless( $self->id ) {
		RTx::Shredder::Exception->throw('Object is not loaded');
	}

	my $deps = $args{'Cached'} || RTx::Shredder::Dependencies->new();

# No dependencies that should be deleted with record

#TODO: We should export Custom Field if want export tool.

	return $deps;
}

1;

