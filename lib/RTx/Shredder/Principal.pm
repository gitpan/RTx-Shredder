package RT::Principal;

use strict;
use RTx::Shredder::Exceptions;
use RTx::Shredder::Constants;
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

# Group or User
# Could be wiped allready
	my $obj = $self->Object;
	if( defined $obj->id ) {
		push( @$list, $obj );
	}

# Access Control List
	my $objs = RT::ACL->new( $self->CurrentUser );
	$objs->Limit(
			FIELD => 'PrincipalId',
			OPERATOR        => '=',
			VALUE           => $self->Id
		   );
	push( @$list, $objs );

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

	my $obj = $self->Object;
	if( defined $obj->id ) {
		push( @$list, $obj );
	} else {
		my $rec = $args{'Shredder'}->GetRecord( Object => $self );
		$self = $rec->{'Object'};
		$rec->{'State'} |= INVALID;
		$rec->{'Description'} = "Have no related ". $self->Type ." #". $self->id ." object";
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
