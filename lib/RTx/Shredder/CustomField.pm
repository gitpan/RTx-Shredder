package RT::CustomField;

use strict;
use RTx::Shredder::Constants;
use RTx::Shredder::Exceptions;
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
	my $list = [];

# Custom field values
	push( @$list, $self->Values );

# Ticket custom field values
	my $objs = RT::TicketCustomFieldValues->new( $self->CurrentUser );
	$objs->LimitToCustomField( $self->Id );
	push( @$list, $objs );

#TODO: Queues if we wish export tool

	$deps->_PushDependencies(
			BaseObj => $self,
			Flags => DEPENDS_ON,
			TargetObjs => $list,
			Shredder => $args{'Shredder'}
		);
	return $deps;
}


1;

