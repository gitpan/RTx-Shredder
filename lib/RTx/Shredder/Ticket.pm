package RT::Ticket;

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

# Ticket role groups( Owner, Requestors, Cc, AdminCc )
	my $objs = RT::Groups->new( $self->CurrentUser );
	$objs->Limit( FIELD => 'Domain', VALUE => 'RT::Ticket-Role' );
	$objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
	$deps->_PushDependencies( $self, 'DependsOn', $objs );

# Transactions
	$objs = $self->Transactions;
	$deps->_PushDependencies( $self, 'DependsOn', $objs );
# Links
	$objs = $self->_Links( 'Base' );
	$deps->_PushDependencies( $self, 'DependsOn', $objs );

	$objs = $self->_Links( 'Target' );
	$deps->_PushDependencies( $self, 'DependsOn', $objs );
# Ticket custom field values
	$objs = RT::TicketCustomFieldValues->new( $self->CurrentUser );
	$objs->LimitToTicket( $self->Id() );

#TODO: Users, Queues if we wish export tool

	return $deps;
}


1;
