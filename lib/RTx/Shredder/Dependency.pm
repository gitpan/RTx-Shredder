package RTx::Shredder::Dependency;

use strict;
use RTx::Shredder::Constants;
use RTx::Shredder::Exceptions;

our %FlagDescs = (
	1	=> 'depends on',
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
	my %args = (
			BaseObj => undef,
			Flags => DEPENDS_ON,
			TargetObj => undef,
			@_
		);

	unless( $args{'BaseObj'} && ref $args{'BaseObj'} &&
			$args{'TargetObj'} && ref $args{'TargetObj'}
	      ) {
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
	my $res = $self->BaseClass;
	$res .= " #". $self->BaseObj->id;
	$res .= " ". $self->FlagsAsString;
	$res .= " ". $self->TargetClass;
	$res .= " #". $self->TargetObj->id;
	return $res;
}

sub Flags
{
	my $self = shift;
	return $self->{'_Flags'};
}

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


sub BaseObj
{
	my $self = shift;
	return $self->Object( Type => 'Base' );
}

sub TargetObj
{
	my $self = shift;
	return $self->Object( Type => 'Target' );
}

sub Object
{
	my $self = shift;
	my %args = (
			Type => 'Target',
			@_
		);
	
	return $self->{"_". $args{'Type'} . "Obj"};
}

sub TargetClass
{
	return $_[0]->Class( Type => 'Target' );
}

sub BaseClass
{
	return $_[0]->Class( Type => 'Base' );
}

sub Class
{
	my $self = shift;
	my %args = (
			Type => 'Target',
			@_
		);
	
	return ref $self->{"_". $args{'Type'} . "Obj"};
}

sub DESTROY
{
	print ref($_[0]) ." gotcha\n";
}

1;
