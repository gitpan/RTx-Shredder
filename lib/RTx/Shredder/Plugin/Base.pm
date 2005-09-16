package RTx::Shredder::Plugin::Base;

use strict;
use warnings FATAL => 'all';

=head1 NAME

RTx::Shredder::Plugin::Base - base class for Shredder plugins.

=cut

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
	$self->{'opt'} = { @_ };
}

=head1 ARGUMENTS

Arguments which all plugins support.

=head2 limit - unsigned integer

Allow you to limit search results.

=cut

sub SupportArgs { return qw(limit) }

sub HasSupportForArgs
{
	my $self = shift;
	my @args = @_;
	my @unsupported = ();
	foreach my $a( @args ) {
		push @unsupported, $a unless grep $_ eq $a, $self->SupportArgs;
	}
	return( 1 ) unless @unsupported;
	return( 0, "Plugin doesn't support argument(s): @unsupported" ) if @unsupported;
}

sub TestArgs
{
	my $self = shift;
	my %args = @_;
	if( defined $args{'limit'} && $args{'limit'} ne '' ) {
		my $limit = $args{'limit'};
		$limit =~ s/[^0-9]//g;
		unless( $args{'limit'} eq $limit ) {
			return( 0, "Argmument limit should be an unsigned integer");
		}
		$args{'limit'} = $limit;
	} else {
		$args{'limit'} = 10;
	}
	$self->{'opt'} = \%args;
	return 1;
}


sub Type { return '' }

sub Run { return (0, "This is abstract plugin, you couldn't use it directly") }

sub SetResolvers { return (1) }

1;
