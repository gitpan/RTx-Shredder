package RT::Principal;

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

# Group or User
	$deps->_PushDependencies( $self, 'DependsOn', $self->Object );

# Access Control List
	my $acl = RT::ACL->new( $self->CurrentUser );
	$acl->Limit(
			FIELD => 'PrincipalId',
			OPERATOR        => '=',
			VALUE           => $self->Id
		   );
	$deps->_PushDependencies( $self, 'DependsOn', $acl );

	return $deps;
}

1;
