package RT::Group;

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

# Principal
	$deps->_PushDependencies( $self, 'DependsOn', $self->PrincipalObj );

# Group members records
	my $objs = RT::GroupMembers->new( $self->CurrentUser );
	$objs->LimitToMembersOfGroup( $self->PrincipalId );
	$deps->_PushDependencies( $self, 'DependsOn', $objs );

# Group member records group belongs to
	$objs->UnLimit();
	$objs->Limit(
			VALUE => $self->PrincipalId,
			FIELD => 'MemberId',
			ENTRYAGGREGATOR => 'OR',
			QUOTEVALUE => 0
		    );
	$deps->_PushDependencies( $self, 'DependsOn', $objs );

# Cached group members records
	$deps->_PushDependencies( $self, 'DependsOn', $self->DeepMembersObj );
# Cached group member records group belongs to
	$objs = RT::GroupMembers->new( $self->CurrentUser );
	$objs->Limit(
			VALUE => $self->PrincipalId,
			FIELD => 'MemberId',
			ENTRYAGGREGATOR => 'OR',
			QUOTEVALUE => 0
		    );
	$deps->_PushDependencies( $self, 'DependsOn', $objs );

	return $deps;
}

1;
