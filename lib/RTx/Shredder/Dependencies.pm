package RTx::Shredder::Dependencies;

use strict;
use RTx::Shredder::Exceptions;
use RTx::Shredder::Constants;
use RTx::Shredder::Dependency;
use RT::Record;



=head1 METHODS

=head2 new

Creates new empty collection of dependecies.

=cut

sub new
{
	my $proto = shift;
	my $self = bless( {}, ref $proto || $proto );
	$self->{'list'} = [];
	return $self;
}

=head2 _PushDependencies

Put in objects into collection.
Takes
BaseObj - any supported object of RT::Record subclass;
Flags - flags that describe relationship between target and base objects;
TargetObjs - any of RT::SearchBuilder or RT::Record subclassed objects
or array ref on list of this objects;
Shredder - RTx::Shredder object.

SeeAlso: _PushDependecy, RTx::Shredder::Dependency

=cut

sub _PushDependencies
{
	my $self = shift;
	my %args = (
			BaseObj => undef,
			TargetObjs => undef,
			Shredder => undef,
			@_
		   );
	my ($targets) = delete $args{'TargetObjs'};
	if( UNIVERSAL::isa( $targets, 'RT::SearchBuilder' ) ) {
		while( my $tmp = $targets->Next ) {
			$self->_PushDependency( %args, TargetObj => $tmp );
		}
	} elsif ( UNIVERSAL::isa( $targets, 'RT::Record' ) ) {
		$self->_PushDependency( %args, TargetObj => $targets );
	} elsif ( ref $targets eq 'ARRAY' ) {
		foreach my $tmp( @$targets ) {
			$self->_PushDependencies( %args, TargetObjs => $tmp );
		}
	} else {
		RTx::Shredder::Exception->throw( "Unsupported type ". ref $targets );
	}

	return;
}

sub _PushDependency
{
	my $self = shift;
	my %args = (
			BaseObj => undef,
			Flags => undef,
			TargetObj => undef,
			Shredder => undef,
			@_
		   );
	my $shredder = $args{'Shredder'};
	my $rec = $shredder->PutObject( Object => $args{'TargetObj'} );
	return if( $rec->{'State'} );
	push( @{ $self->{'list'} }, RTx::Shredder::Dependency->new(
			BaseObj => $args{'BaseObj'},
			Flags => $args{'Flags'},
			TargetObj => $rec->{'Object'} )
	    );

	if( scalar @{ $self->{'list'} } > ( $RT::DependenciesLimit || 1000 ) ) {
		RTx::Shredder::Exception->throw( "Dependencies list overflow" );
	}
	return;
}

=head2 Wipeout

Goes thourgh collection of RTx::Shredder::Dependency objects and wipeout target object
if it depends on base.
Takes two optional arguments WithFlags and WithoutFlags and checks Dependency flags if
arhuments are defined.

=cut

# TODO: Callback sub that check Flags instead of arguments.
sub Wipeout
{
	my $self = shift;
	my %args = (
		WithFlags => undef,
		WithoutFlags => undef,
		@_
	);

	my $wflags = delete $args{'WithFlags'};
	my $woflags = delete $args{'WithoutFlags'};
	my $deps = $self->{'list'};

	foreach my $d ( @{ $deps } ) {
		next unless( $d->Flags & DEPENDS_ON );
		next if( defined( $wflags ) && !$d->Flags & $wflags );
		next if( defined( $woflags ) && $d->Flags & $woflags );
		my $o = $d->TargetObj;
		$o->Wipeout( %args );
	}

	return;
}

sub ValidateRelations
{
	my $self = shift;
	my %args = (
		WithFlags => undef,
		WithoutFlags => undef,
		@_
	);

	my $wflags = delete $args{'WithFlags'};
	my $woflags = delete $args{'WithoutFlags'};
	my $deps = $self->{'list'};

	foreach my $d ( @{ $deps } ) {
		next unless( $d->Flags & RELATES );
		next if( defined( $wflags ) && !$d->Flags & $wflags );
		next if( defined( $woflags ) && $d->Flags & $woflags );
		my $o = $d->TargetObj;
		$o->ValidateRelations( %args );
	}

	return;
}

sub DESTROY
{
#	print ref($_[0]) ." gotcha\n";
}
1;
