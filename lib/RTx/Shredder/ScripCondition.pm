package RT::ScripCondition;

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

	my $deps = RTx::Shredder::Dependencies->new();

# Scrips
	my $objs = RT::Scrips->new( $self->CurrentUser );
	$objs->Limit( FIELD => 'ScripCondition', VALUE => $self->Id );
	$deps->_PushDependencies(
			BaseObj => $self,
			Flags => DEPENDS_ON,
			TargetObjs => $objs,
			Shredder => $args{'Shredder'}
		);

	return $deps;
}


1;
