package RT::Link;

use strict;
use RTx::Shredder::Exceptions;
use RTx::Shredder::Dependencies;
use RTx::Shredder::Constants;


sub Dependencies
{
	my $self = shift;
	my %args = (
			Cached => undef,
			Flags => DEPENDS_ON,
			@_,
		   );

	unless( $self->id ) {
		RTx::Shredder::Exception->throw('Object is not loaded');
	}

	my $deps = $args{'Cached'} || RTx::Shredder::Dependencies->new();

# No dependencies that should be deleted with record

#TODO: Link record has small strength, but should be encountered
# if we plan write export tool.

	return $deps;
}

1;
