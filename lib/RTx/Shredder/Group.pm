package RT::Group;

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

	if( $self->Domain eq 'SystemInternal' ) {
		RTx::Shredder::Exception->throw('Couldn\'t delete system group');
	}

	my $deps = RTx::Shredder::Dependencies->new();
	my $list = [];

# User is inconsistent without own Equivalence group
	if( $self->Domain eq 'ACLEquivalence' ) {
		my $objs = RT::User->new($self->CurrentUser);
		$objs->Load( $self->Instance );
		push( @$list, $objs );
	}

# Principal
	$deps->_PushDependency(
			BaseObj => $self,
			Flags => DEPENDS_ON | WIPE_AFTER,
			TargetObj => $self->PrincipalObj,
			Shredder => $args{'Shredder'}
		);

# Group members records
	my $objs = RT::GroupMembers->new( $self->CurrentUser );
	$objs->LimitToMembersOfGroup( $self->PrincipalId );
	push( @$list, $objs );

# Group member records group belongs to
	$objs = RT::GroupMembers->new( $self->CurrentUser );
	$objs->Limit(
			VALUE => $self->PrincipalId,
			FIELD => 'MemberId',
			ENTRYAGGREGATOR => 'OR',
			QUOTEVALUE => 0
		    );
	push( @$list, $objs );

# Cached group members records
	push( @$list, $self->DeepMembersObj );

# Cached group member records group belongs to
	$objs = RT::GroupMembers->new( $self->CurrentUser );
	$objs->Limit(
			VALUE => $self->PrincipalId,
			FIELD => 'MemberId',
			ENTRYAGGREGATOR => 'OR',
			QUOTEVALUE => 0
		    );
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
