package RT::Queue;

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

	unless( defined $self->id ) {
		RTx::Shredder::Exception->throw('Object is not loaded');
	}

	unless( $self->id ) {
		RTx::Shredder::Exception->throw('Global queue could not be deleted');
	}

	my $deps = RTx::Shredder::Dependencies->new();
	my $list = [];

# Tickets
	my $objs = RT::Tickets->new( $self->CurrentUser );
	$objs->{'allow_deleted_search'} = 1;
	$objs->Limit( FIELD => 'Queue', VALUE => $self->Id );
	push( @$list, $objs );

# Queue role groups( Cc, AdminCc )
	$objs = RT::Groups->new( $self->CurrentUser );
	$objs->Limit( FIELD => 'Domain', VALUE => 'RT::Queue-Role' );
	$objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
	push( @$list, $objs );

# Templates
	$objs = $self->Templates;
	push( @$list, $objs );

# Custom Fields
	$objs = RT::CustomFields->new( $self->CurrentUser );
	$objs->Limit( FIELD => 'Queue', VALUE => $self->id );
	push( @$list, $objs );

	$deps->_PushDependencies(
			BaseObj => $self,
			Flags => DEPENDS_ON,
			TargetObjs => $list,
			Shredder => $args{'Shredder'}
		);
	return $deps;
}


1;
