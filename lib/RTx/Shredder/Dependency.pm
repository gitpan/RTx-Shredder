package RTx::Shredder::Dependency;

use strict;
use RTx::Shredder::Constants;
use RTx::Shredder::Exceptions;

our %FlagDescs = (
	DEPENDS_ON, 'depends on',
	WIPE_AFTER, 'delete after',
	RELATES, 'relates with',
	VARIABLE, 'resolvable dependency',
);


sub new
{
	my $proto = shift;
	my $self = bless( {}, ref $proto || $proto );
	$self->Set( @_ );
	return $self;
}

sub Set
{
	my $self = shift;
	my %args = ( BaseObj => undef,
		     Flags => DEPENDS_ON,
		     TargetObj => undef,
		     @_,
		   );

	unless( $args{'BaseObj'} && ref $args{'BaseObj'} &&
		$args{'TargetObj'} && ref $args{'TargetObj'} ) {
			RTx::Shredder::Exception->throw("Wrong args");
	}

	$self->{'_Flags'} = $args{'Flags'};
	$self->{'_BaseObj'} = $args{'BaseObj'};
	$self->{'_TargetObj'} = $args{'TargetObj'};

	return;
}

sub AsString
{
	my $self = shift;
	my $res = $self->BaseObj->_AsString;
	$res .= " ". $self->FlagsAsString;
	$res .= " ". $self->TargetObj->_AsString;
	return $res;
}

sub Flags { return $_[0]->{'_Flags'} }
sub FlagsAsString
{
	my $self = shift;
	my @res = ();
	foreach ( keys %FlagDescs ) {
		if( $self->{'_Flags'} & $_ ) {
			push( @res, $FlagDescs{ $_ } );
		}
	}
	push( @res, 'no flags' ) unless( @res );
	return "(" . join( ',', @res ) . ")";
}


sub BaseObj { return $_[0]->Object( Type => 'Base' ) }
sub TargetObj {	return $_[0]->Object( Type => 'Target' ) }
sub Object { return (shift)->{"_". ({@_}->{'Type'} || 'Target') . "Obj"} }

sub TargetClass { return $_[0]->Class( Type => 'Target' ) }
sub BaseClass {	return $_[0]->Class( Type => 'Base' ) }
sub Class { return ref( (shift)->Object( @_ ) ) }

sub ResolveVariable
{
	my $self = shift;
	my %args = ( Shredder => undef, @_ );

	my $shredder = $args{'Shredder'};
	my $resolver = $shredder->GetResolver( BaseClass => $self->BaseClass,
				TargetClass => $self->TargetClass,
			      );

	unless( $resolver ) {
		die "couldn't find resolver for dependency '". $self->AsString ."'";
	}
	unless( UNIVERSAL::isa( $resolver => 'CODE' ) ) {
		die "resolver is not code reference: '$resolver'";
	}
	eval {
		$resolver->( Shredder => $shredder,
			     BaseObj => $self->BaseObj,
			     TargetObj => $self->TargetObj,
			   );
	};
	die "couldn't run resolver: $@" if $@;

	return;
}

1;
