package RT::CustomFieldValue;

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
# I should decide is TicketCustomFieldValue depends by this or not.
# Today I think no. What would be tomorrow I don't know.

	return $deps;
}

1;

