package RTx::Shredder::Plugin::Objects;

use strict;
use warnings FATAL => 'all';
use base qw(RTx::Shredder::Plugin::Base);

use RTx::Shredder;

=head1 NAME

RTx::Shredder::Plugin::Objects - search plugin for wiping any selected object.

=cut

sub Type { return 'search' }

=head1 ARGUMENTS

This plugin searches and RT object you want, so you can use
the object name as argument and id as value, for example if
you want select ticket #123 then from CLI you write next
command:

  rtx-shredder --plugin 'Objects=Ticket,123'

=cut

sub SupportArgs
{
	return $_[0]->SUPER::SupportArgs, @RTx::Shredder::SUPPORTED_OBJECTS;
}

sub TestArgs
{
	my $self = shift;
	my %args = @_;

	my @strings;
	foreach my $name( @RTx::Shredder::SUPPORTED_OBJECTS ) {
		next unless $args{$name};

		my $list = $args{$name};
		$list = [$list] unless UNIVERSAL::isa( $list, 'ARRAY' );
		push @strings, map "RT::$name\-$_", @$list;
	}

	my @objs = RTx::Shredder->CastObjectsToRecords( Objects => \@strings );

	my @res = $self->SUPER::TestArgs( %args );

	$self->{'opt'}->{'objects'} = \@objs;

	return (@res);
}

sub Run
{
	my $self = shift;
	my %args = ( Shredder => undef, @_ );
	return (1, @{$self->{'opt'}->{'objects'}});
}

1;

