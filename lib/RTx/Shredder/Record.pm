package RT::Record;

use strict;
use RTx::Shredder::Constants;

sub _AsString
{
	my $self = shift;

	my $res = ref($self) ."-". $self->id;

	return $res;
}

sub Wipeout
{
	my $self = shift;
	my %args = (
			Shredder => undef,
			@_
		   );
	unless( $args{'Shredder'} ) {
		$args{'Shredder'} = new RTx::Shredder();
	}

	my $rec = $args{'Shredder'}->PutObject( Object => $self );
	return if( $rec->{'State'} & WIPED );
	$self = $rec->{'Object'};

	$self->_Wipeout( %args );

	return;
}

sub _Wipeout
{
	my $self = shift;
	my %args = ( @_ );

	my $deps = $self->Dependencies( %args );

	$deps->Wipeout( WithoutFlags => WIPE_AFTER, %args );
	$self->__Wipeout( %args );
	$deps->Wipeout( WithFlags => WIPE_AFTER, %args );

	return;
}

# implement proxy method because some RT classes
# override Delete method
sub __Wipeout
{
	my $self = shift;
	my %args = ( @_ );
	my $msg = $self->_AsString ." deleted";

	$self->SUPER::Delete();

	my $rec = $args{'Shredder'}->GetRecord( Object => $self );
	$rec->{'State'} |= WIPED;
	delete $rec->{'Object'};

	$RT::Logger->warning( $msg );

	return;
}

1;
