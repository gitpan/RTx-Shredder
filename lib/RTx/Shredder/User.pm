package RT::User;

use strict;
use RTx::Shredder::Constants;
use RTx::Shredder::Exceptions;
use RTx::Shredder::Dependencies;

my $OBJECTS = qw(
	Attachments
	CachedGroupMembers
	CustomFields
	CustomFieldValues
	GroupMembers
	Groups
	Links
	Principals
	Queues
	ScripActions
	ScripConditions
	Scrips
	Templates
	TicketCustomFieldValues
	Tickets
	Transactions
	Users
);

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

# Principal
	push( @$list, $self->PrincipalObj );

# ACL equivalence group
# don't use LoadACLEquivalenceGroup cause it may not exists any more
	my $objs = RT::Groups->new( $self->CurrentUser );
	$objs->Limit( FIELD => 'Domain', VALUE => 'ACLEquivalence' );
	$objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
	push( @$list, $objs );

# Cleanup user's membership
	$objs = RT::GroupMembers->new( $self->CurrentUser );
	$objs->Limit( FIELD => 'MemberId', VALUE => $self->Id );
	push( @$list, $objs );
# deep memebership
	$objs = RT::CachedGroupMembers->new( $self->CurrentUser );
	$objs->Limit( FIELD => 'MemberId', VALUE => $self->Id );
	push( @$list, $objs );
	

# TODO: Almost all objects has Creator, LastUpdatedBy and etc. fields
# which are references on users(Principal actualy)

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

# Principal
	my $obj = $self->PrincipalObj;
	if( $obj && defined $obj->id ) {
		push( @$list, $obj );
	} else {
		my $rec = $args{'Shredder'}->GetRecord( Object => $self );
		$self = $rec->{'Object'};
		$rec->{'State'} |= INVALID;
		$rec->{'Description'} = "Have no related ACL equivalence Group object";
	}

	$obj = RT::Group->new( $RT::SystemUser );
	$obj->LoadACLEquivalenceGroup( $self->PrincipalObj );
	if( $obj && defined $obj->id ) {
		push( @$list, $obj );
	} else {
		my $rec = $args{'Shredder'}->GetRecord( Object => $self );
		$self = $rec->{'Object'};
		$rec->{'State'} |= INVALID;
		$rec->{'Description'} = "Have no related Principal #". $self->id ." object";
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
