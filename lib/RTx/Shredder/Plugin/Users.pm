package RTx::Shredder::Plugin::Users;

use strict;
use warnings FATAL => 'all';
use base qw(RTx::Shredder::Plugin::Base);

=head1 NAME

RTx::Shredder::Plugin::Users - search plugin for wiping users.

=cut

sub Type { return 'search' }

=head1 ARGUMENTS

=head2 status - string

=head2 name_mask - name address mask

=head2 email_mask - email address mask

=head2 replace_relations - user identifier

When you delete user there is could be minor links to him in RT DB.
This option allow you to replace this links with link to other user.
This links are Creator and LastUpdatedBy, but NOT any watcher roles,
this mean that if user is watcher(Requestor, Owner,
Cc or AdminCc) of the ticket or queue then link would be deleted.

This argument could be user id or name.

=cut

sub SupportArgs
{
	return $_[0]->SUPER::SupportArgs,
	       qw(status name_mask email_mask replace_relations);
}

sub TestArgs
{
	my $self = shift;
	my %args = @_;
	if( $args{'status'} ) {
		unless( $args{'status'} =~ /^(disabled|enabled|any)$/i ) {
			return (0, "Status '$args{'status'}' is unsupported.");
		}
	}
	if( $args{'email_mask'} ) {
		unless( $args{'email_mask'} =~ /^[\w\.@?*]+$/ ) {
			return (0, "Invalid characters in email_mask '$args{'email_mask'}'");
		}
	}
	if( $args{'name_mask'} ) {
		unless( $args{'name_mask'} =~ /^[\w?*]+$/ ) {
			return (0, "Invalid characters in name_mask '$args{'name_mask'}'");
		}
	}
	if( $args{'replace_relations'} ) {
		my $uid = $args{'replace_relations'};
		my $user = RT::User->new( $RT::SytemUser );
		$user->Load( $uid );
		unless( $user->id ) {
			return (0, "Couldn't load user '$uid'" );
		}
		$args{'replace_relations'} = $user->id;
	}
	return $self->SUPER::TestArgs( %args );
}

sub Run
{
	my $self = shift;
	my %args = ( Shredder => undef, @_ );
	my $objs = RT::Users->new( $RT::SystemUser );
	if( $self->{'opt'}{'status'} ) {
		my $s = $self->{'opt'}{'status'};
		if( $s eq 'any' ) {
			$objs->{'find_disabled_rows'} = 1;
		} elsif( $s eq 'disabled' ) {
			$objs->{'find_disabled_rows'} = 1;
			$objs->Limit( ALIAS => $objs->PrincipalsAlias,
				      FIELD    => 'Disabled',
				      OPERATOR => '!=',
				      VALUE    => '0',
				    );
		} else {
			$objs->LimitToEnabled;
		}
	}
	if( $self->{'opt'}{'email_mask'} ) {
		my $mask = $self->{'opt'}{'email_mask'};
		$mask =~ s/[^\w\.@?*]//g;
		$mask =~ s/\*/%/g;
		$mask =~ s/\?/_/g;
		$objs->Limit( FIELD => 'EmailAddress',
			      OPERATOR => 'MATCHES',
			      VALUE => $mask,
			    );
	}
	if( $self->{'opt'}{'name_mask'} ) {
		my $mask = $self->{'opt'}{'email_mask'};
		$mask =~ s/[^\w?*]//g;
		$mask =~ s/\*/%/g;
		$mask =~ s/\?/_/g;
		$objs->Limit( FIELD => 'Name',
			      OPERATOR => 'MATCHES',
			      VALUE => $mask,
			    );
	}
	if( $self->{'opt'}{'limit'} ) {
		$objs->RowsPerPage( $self->{'opt'}{'limit'} );
	}
	return (1, $objs);
}

sub SetResolvers
{
	my $self = shift;
	my %args = ( Shredder => undef, @_ );
	
	if( $self->{'opt'}{'replace_relations'} ) {
		my $uid = $self->{'opt'}{'replace_relations'};
		my $resolver = sub {
			my %args = (@_);
			my $t =	$args{'TargetObj'};
			foreach my $method ( qw(Creator LastUpdatedBy) ) {
				next unless $t->_Accessible( $method => 'read' );
				$t->__Set( Field => $method, Value => $uid );
			}
		};
		$args{'Shredder'}->PutResolver( BaseClass => 'RT::User', Code => $resolver );
	}
	return (1);
}

1;
