package RTx::Shredder::Dependency;

use strict;
use RTx::Shredder::Exceptions;

# now it's not used at all and also would be changed
# to bit flags constants
our %StrengthLevels = (
		DependBy => 0,
		ExportWith => 1,
		DependsOn => 2,
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
			Strength => 'DependsOn',
			TargetObj => undef,
			@_
		);

	unless( $args{'BaseObj'} && ref $args{'BaseObj'} &&
			$args{'TargetObj'} && ref $args{'TargetObj'} &&
			$args{'Strength'} && $StrengthLevels{ $args{'Strength'} }
	      ) {
		RTx::Shredder::Exception->throw("Wrong args");
	}

	$self->{'_Strength'} = $args{'Strength'};
	$self->{'_BaseObj'} = $args{'BaseObj'};
	$self->{'_TargetObj'} = $args{'TargetObj'};

	return;
}

sub AsString
{
	my $self = shift;
	my $res = $self->BaseClass;
	$res .= " #". $self->BaseObj->id;
	$res .= " ". $self->StrengthAsString;
	$res .= " ". $self->TargetClass;
	$res .= " #". $self->TargetObj->id;
	return $res;
}

sub Strength
{
	my $self = shift;
	return $StrengthLevels{ $self->{'_Strength'} };
}

sub StrengthAsString
{
	my $self = shift;
	return $self->{'_Strength'};
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

1;
