package RTx::Shredder::Dependencies;

use strict;
use RTx::Shredder::Exceptions;
use RTx::Shredder::Dependency;
use RT::Record;

sub new
{
	my $proto = shift;
	my $self = bless( {}, ref $proto || $proto );
	$self->{'list'} = [];
	return $self;
}

sub Lookup
{
	my $self = shift;
	my %args = (
			Object => undef,
			Strength => 'DependOn',
			@_
		   );
	my $list = $self->{'list'} || [];
	my $o = $args{'Object'};
	foreach my $d( @{ $list } ) {
		next unless( $d->TargetClass eq ref $o );
		next unless( $d->TargetObj->id eq $o->id );
		next if( $d->StrengthAsString ne $args{'Strength'} );

		return $d;
	}
	return undef;
}

sub Expand
{
	my $self = shift;
	my %args = (
			Strength => 'DependsOn',
			@_,
		   );

	my $deps = $self->{'list'};
	foreach my $d( @{ $deps } ) {
		next unless( $d->Strength > $args{'Strength'} );
		$d->TargetObj->Dependencies( Cached => $self, Strength => $args{'Strength'} );
	}
	$self->{'expanded'} = 1;
	return;
}

sub _PushDependencies
{
	my $self = shift;
	my $base = shift;
	my $strength = shift;
	my ($targets) = @_;
	if( scalar @_ > 1 ) {
		$targets = [ @_ ];
	}
	unless( ref $targets ) {
		RTx::Shredder::Exception->throw( 'Not references' );
	}

	if( ref( $targets ) =~ /^RT::.*/ && $targets->isa('RT::SearchBuilder') ) {
		while( my $tmp = $targets->Next ) {
			$self->_PushDependency( $base, $strength, $tmp);
		}
	} elsif ( ref( $targets ) =~ /^RT::.*/ && $targets->isa('RT::Record') ) {
		$self->_PushDependency( $base, $strength, $targets);
	} elsif ( ref $targets eq 'ARRAY' ) {
		foreach my $tmp( @$targets ) {
			$self->_PushDependency( $base, $strength, $tmp);
		}
	} else {
		RTx::Shredder::Exception->throw( "Unsupported type ". ref $targets );
	}

	return;
}

sub _PushDependency
{
	my $self = shift;
	my ($base, $strength, $target) = @_;
	return if( $self->Lookup(
				Object => $target,
				Strength => 'DependsOn'
				) );
	push( @{ $self->{'list'} }, RTx::Shredder::Dependency->new(
			BaseObj => $base,
			Strength => $strength,
			TargetObj => $target )
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
			@_,
		   );

	unless( $self->{'expanded'} ) {
		RTx::Shredder::Exception->throw( 'Cant wipeout not expanded dependencies' );
	};

	$self->_Wipeout( %args );

	return;
}

sub _Wipeout
{
	my $self = shift;

	my $deps = $self->{'list'};

	while( my $d = pop @{ $deps } ) {
		my $o = $d->TargetObj;
		my $msg = $d->TargetClass ." #". $o->id ."deleted\n";
		print $msg;
		print join(", ", eval "@".$d->TargetClass."::ISA") ."\n";
		$o->__Wipeout();
	}

	return;
}

1;
