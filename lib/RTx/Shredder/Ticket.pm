use RT::Ticket ();
package RT::Ticket;

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RTx::Shredder::Constants;
use RTx::Shredder::Exceptions;
use RTx::Shredder::Dependencies;

sub __DependsOn
{
	my $self = shift;
	my %args = (
			Shredder => undef,
			Dependencies => undef,
			@_,
		   );
	my $deps = $args{'Dependencies'};
	my $list = [];

# Tickets which were merged in
	my $objs = RT::Tickets->new( $self->CurrentUser );
	$objs->{'allow_deleted_search'} = 1;
	$objs->Limit( FIELD => 'EffectiveId', VALUE => $self->Id );
	$objs->Limit( FIELD => 'id', OPERATOR => '!=', VALUE => $self->Id );
	push( @$list, $objs );

# Ticket role groups( Owner, Requestors, Cc, AdminCc )
	$objs = RT::Groups->new( $self->CurrentUser );
	$objs->Limit( FIELD => 'Domain', VALUE => 'RT::Ticket-Role' );
	$objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
	push( @$list, $objs );

# Links
# Native API calls that select using Ticket's URI
	push( @$list, $self->_Links( 'Base' ) );
	push( @$list, $self->_Links( 'Target' ) );

# Indirect lowlevel clean up via Local* fields
	$objs = RT::Links->new( $self->CurrentUser );
	$objs->Limit( FIELD => 'LocalBase', VALUE => $self->Id );
	push( @$list, $objs );
	$objs = RT::Links->new( $self->CurrentUser );
	$objs->Limit( FIELD => 'LocalTarget', VALUE => $self->Id );
	push( @$list, $objs );

#TODO: Users, Queues if we wish export tool
	$deps->_PushDependencies(
			BaseObj => $self,
			Flags => DEPENDS_ON,
			TargetObjs => $list,
			Shredder => $args{'Shredder'}
		);

	return $self->SUPER::__DependsOn( %args );
}

sub __Relates
{
	my $self = shift;
	my %args = (
			Shredder => undef,
			Dependencies => undef,
			@_,
		   );
	my $deps = $args{'Dependencies'};
	my $list = [];

# Queue
	my $obj = $self->QueueObj;
	if( $obj && defined $obj->id ) {
		push( @$list, $obj );
	} else {
		my $rec = $args{'Shredder'}->GetRecord( Object => $self );
		$self = $rec->{'Object'};
		$rec->{'State'} |= INVALID;
		$rec->{'Description'} = "Have no related Queue #". $self->Queue ." object";
	}

	$deps->_PushDependencies(
			BaseObj => $self,
			Flags => RELATES,
			TargetObjs => $list,
			Shredder => $args{'Shredder'}
		);
	return $self->SUPER::__Relates( %args );
}

1;
