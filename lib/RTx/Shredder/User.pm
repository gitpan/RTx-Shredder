package RT::User;

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

	my $deps = $args{'Cached'} || RTx::Shredder::Dependencies->new();
	my $list = [];

# Principal
	push( @$list, $self->PrincipalObj );

# ACL equivalence group
	my $objs = RT::Groups->new( $self->CurrentUser );
	$objs->Limit( FIELD => 'Domain', VALUE => 'ACLEquivalence' );
	$objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
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
