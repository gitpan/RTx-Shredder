package RT::Record;

use strict;

sub Wipeout
{
	my $self = shift;

	my $deps = $self->Dependencies;

	$deps->Wipeout();
	$self->__Wipeout();

	return;
}

# implement proxy method because some RT classes
# override Delete method
sub __Wipeout
{
	my $self = shift;

	$self->SUPER::Delete();

	return;
}


1;

