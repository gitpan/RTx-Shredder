package RT::Transaction;

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

# Attachments
	$deps->_PushDependencies( $self, 'DependsOn', $self->Attachments );

	return $deps;
}


sub Wipeout
{
	my $self = shift;
	my %args = (
			@_,
		   );





	return;
}

sub _Wipeout
{
	my $self = shift;
	my %args = (
			@_,
		   );




	return;
}

1;

