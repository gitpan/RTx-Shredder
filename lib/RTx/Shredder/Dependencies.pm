package RTx::Shredder::Dependencies;

use strict;
use RTx::Shredder::Exceptions;
use RTx::Shredder::Constants;
use RTx::Shredder::Dependency;
use RT::Record;

sub new
{
	my $proto = shift;
	my $self = bless( {}, ref $proto || $proto );
	$self->{'list'} = [];
	return $self;
}

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

sub DESTROY
{
	print ref($_[0]) ." gotcha\n";
}
1;
