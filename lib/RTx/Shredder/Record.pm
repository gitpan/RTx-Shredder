package RT::Record;

use strict;

sub Wipeout
{
	my $self = shift;

	my $deps = $self->Dependencies;
	$deps->Expand();

	$deps->Wipeout();
	$self->__Wipeout();

	return;
}

# implement proxy method because some RT classes
# override Delete method
sub __Wipeout
{
	my $self = shift;
	my $msg = ref($self) ." #". $self->id ." deleted\n";

	$self->SUPER::Delete();
	warn $msg;

	return;
}


1;

