package RTx::Shredder::Plugin;

use strict;
use warnings FATAL => 'all';
use File::Spec ();

sub new
{
	my $proto = shift;
	my $self = bless( {}, ref $proto || $proto );
	$self->_Init( @_ );
	return $self;
}

sub _Init
{
	my $self = shift;
	my %args = ( @_ );
	$self->{'opt'} = \%args;
}

sub List
{
	my $self = shift;
	my @files;
	foreach my $root( @INC ) {
		my $mask = File::Spec->catdir( $root, qw(RTx Shredder Plugin *.pm) );
		push @files, glob $mask;
	}

	my %res = map { $_ =~ m/([^\\\/]+)\.pm$/; $1 => $_ } reverse @files;

	return %res;
}

sub LoadByName
{
	my $self = shift;
	my $plugin = "RTx::Shredder::Plugin::". ( shift || '' );

	local $@;
	eval "require $plugin";
	return( 0, $@ ) if $@;

	my $obj = eval { $plugin->new };
	return( 0, $@ ) if $@;
	return( 0, 'constructor returned empty object' ) unless $obj;

	$self->Rebless( $obj );
	return( 1, "successfuly load plugin" );
}

sub LoadByString
{
	my $self = shift;
	my ($plugin, $args) = split /=/, $_[0];
	my %args = map { my( $k,$v ) = split /\s*,\s*/, $_; $k => $v; }
		       split /\s*;\s*/, ( $args || '' );

	my ($status, $msg) = $self->LoadByName( $plugin );
	return( $status, $msg ) unless $status;

	($status, $msg) = $self->HasSupportForArgs( keys %args );
	return( $status, $msg ) unless $status;

	($status, $msg) = $self->TestArgs( %args );
	return( $status, $msg ) unless $status;

	return( 1, "successfuly load plugin" );
}

sub Rebless
{
	my( $self, $obj ) = @_;
	bless( $self, ref $obj );
	%{$self} = %{$obj};
	return;
}

1;
