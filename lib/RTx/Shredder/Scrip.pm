package RT::Scrip;

use strict;
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

# No dependencies that should be deleted with record
# Scrip actions and conditions should be exported in feature with it.

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
	if( defined $obj->id ) {
		push( @$list, $obj );
	} else {
		my $rec = $args{'Shredder'}->GetRecord( Object => $self );
		$self = $rec->{'Object'};
		$rec->{'State'} |= INVALID;
		$rec->{'Description'} = "Have no related Queue #". $self->id ." object";
	}

# Condition
	$obj = $self->ConditionObj;
	if( defined $obj->id ) {
		push( @$list, $obj );
	} else {
		my $rec = $args{'Shredder'}->GetRecord( Object => $self );
		$self = $rec->{'Object'};
		$rec->{'State'} |= INVALID;
		$rec->{'Description'} = "Have no related ScripCondition #". $self->id ." object";
	}
# Action
	$obj = $self->ActionObj;
	if( defined $obj->id ) {
		push( @$list, $obj );
	} else {
		my $rec = $args{'Shredder'}->GetRecord( Object => $self );
		$self = $rec->{'Object'};
		$rec->{'State'} |= INVALID;
		$rec->{'Description'} = "Have no related ScripAction #". $self->id ." object";
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
