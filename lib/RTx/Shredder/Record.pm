package RT::Record;

use strict;
use RTx::Shredder::Constants;

=head2 _AsString

Returns string in format ClassName-ObjectId.

=cut

sub _AsString
{
	my $self = shift;

	my $res = ref($self) ."-". $self->id;

	return $res;
}

=head2 Dependencies

=cut

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
	if( $args{'Flags'} & DEPENDS_ON ) {
		$self->__DependsOn( %args, Dependencies => $deps );
	}
	if( $args{'Flags'} & RELATES ) {
		$self->__Relates( %args, Dependencies => $deps );
	}
	return $deps;
}

sub __DependsOn
{
	return;
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

	if( $self->_Accessible( 'Creator', 'read' ) ) {
		my $obj = RT::Principal->new( $self->CurrentUser );
		$obj->Load( $self->Creator );

		if( $obj && defined $obj->id ) {
			push( @$list, $obj );
		} else {
			my $rec = $args{'Shredder'}->GetRecord( Object => $self );
			$self = $rec->{'Object'};
			$rec->{'State'} |= INVALID;
			push @{ $rec->{'Description'} },
				"Have no related User(Creator) #". $self->Creator ." object";
		}
	}

	if( $self->_Accessible( 'LastUpdatedBy', 'read' ) ) {
		my $obj = RT::Principal->new( $self->CurrentUser );
		$obj->Load( $self->LastUpdatedBy );

		if( $obj && defined $obj->id ) {
			push( @$list, $obj );
		} else {
			my $rec = $args{'Shredder'}->GetRecord( Object => $self );
			$self = $rec->{'Object'};
			$rec->{'State'} |= INVALID;
			push @{ $rec->{'Description'} },
				"Have no related User(LastUpdatedBy) #". $self->LastUpdatedBy ." object";
		}
	}

	$deps->_PushDependencies(
			BaseObj => $self,
			Flags => RELATES,
			TargetObjs => $list,
			Shredder => $args{'Shredder'}
		);

	# cause of this $self->SUPER::__Relates should be called last
	# in overridden subs
	my $rec = $args{'Shredder'}->GetRecord( Object => $self );
	$rec->{'State'} |= VALID unless( $rec->{'State'} & INVALID );

	return;
}

=head2 Wipeout

Really delete record from database.
Returns nothing.
Arguments
	Shredder: RTx::Shredder object, is used for object cache. If
	skipped creates new as temporary storage.

=cut

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

sub ValidateRelations
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
	return if( $rec->{'State'} & VALID );
	$self = $rec->{'Object'};

	$self->_ValidateRelations( %args, Flags => RELATES );
	$rec->{'State'} |= VALID unless( $rec->{'State'} & INVALID );

	return;
}

sub _ValidateRelations
{
	my $self = shift;
	my %args = ( @_ );

	my $deps = $self->Dependencies( %args );

	$deps->ValidateRelations( %args );

	return;
}

1;
