use RT::Link ();
package RT::Link;

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RTx::Shredder::Exceptions;
use RTx::Shredder::Dependencies;
use RTx::Shredder::Constants;

# No dependencies that should be deleted with record

#TODO: Link record has small strength, but should be encountered
# if we plan write export tool.


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
# FIXME: if link is local then object should exist

	return $self->SUPER::__Relates( %args );
}

1;
