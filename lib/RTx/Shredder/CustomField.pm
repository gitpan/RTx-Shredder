package RT::CustomField;

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

# Custom field values
	my $objs = $self->Values;
	$deps->_PushDependencies( $self, 'DependsOn', $objs );

# Ticket custom field values
	$objs = RT::TicketCustomFieldValues->new( $self->CurrentUser );
	$objs->LimitToCustomField( $self->Id );
	$deps->_PushDependencies( $self, 'DependsOn', $objs );

#TODO: Queues if we wish export tool

	return $deps;
}


1;

