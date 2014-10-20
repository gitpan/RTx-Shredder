package RT::ScripAction;

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

# Scrips
	my $objs = RT::Scrips->new( $self->CurrentUser );
	$objs->Limit( FIELD => 'ScripAction', VALUE => $self->Id );
	$deps->_PushDependencies(
			BaseObj => $self,
			Flags => DEPENDS_ON,
			TargetObjs => $objs,
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

# TODO: Check here for exec module

	return $self->SUPER::__Relates( %args );
}

1;
