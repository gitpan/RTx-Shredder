package RTx::Shredder;
use strict;

=head1 NAME

RTx::Shredder - Cleanup RT database

=head1 SYNOPSIS

  rtx-shredder --force --sqldump unshred.sql 2005-01-01

  use RTx::Shredder;
  RTx::Shredder::Init( force => 1 );
  my $deleted = RT::Tickets->new( $RT::SystemUser );
  $deleted->{'allow_deleted_search'} = 1;
  $deleted->LimitStatus( VALUE => 'deleted' );
  while( my $t = $deleted->Next ) {
      $t->Wipeout;
  }

=head1 DESCRIPTION

RTx::Shredder is extention to RT API which allow to delete data from database.

=head1 USAGE

RTx::Shredder is extension to RT API which add(push) methods into base RT
classes. If you are looking for end-user command line tool then see also
C<rtx-shredder> script that is shipped with the distribution.

=head1 CONFIGURATION

=head2 $RT::DependenciesLimit

Shredder stops with error if object has more then C<$RT::DependenciesLimit>
dependencies. By default this value is 1000. For example: ticket has 1000
transactions or transaction has 1000 attachments. This is protection
from bugs in shredder code, but sometimes when you for example when you
have big mail loops you may hit it. You can chage default value, in
C<RT_SiteConfig.pm> add Set( $DependenciesLimit, new_limit );

=head1 METHODS

=head2 Dependencies

Dependencies method implementend in each RT class which Shredder can delete.
Now Shredder support wipe out of Ticket, Transaction, Attachment,
TicketCustomFieldValue, Principal, ACE, Group, GroupMember,
CachedGroupMember.

=head1 NOTES

=head2 You should patch RT

RTx-Shredder distribution contains patch that should be applied to RT.
Please read README file to learn more about this patch.

=head2 Transactions support

Transactions unsupported yet, so it's only save when all other
interactions with RT DB are stopped. For example if you are going to
wipe ticket that was deleted an year ago then it's probably ok to run
shredder on it, but if you're going to delete some actively used object
then it's better to stop http server.

=head2 Foreign keys

This two keys don't allow delete Tickets because of bug in MySQL
	ALTER TABLE Tickets ADD FOREIGN KEY (EffectiveId) REFERENCES Tickets(id);
	ALTER TABLE CachedGroupMembers ADD FOREIGN KEY (Via) REFERENCES CachedGroupMembers(id);

	http://bugs.mysql.com/bug.php?id=4042

=head1 BUGS

=head2 *.in files

When you install this distribution also useless *.in file are installed,
this shouldn't happen in future. I didn't find good solution yet.

=head2 Documentation

Many bugs in small docs: insanity, spelling, gramar and so on.
Patches are wellcome.

=head1 AUTHOR

	Ruslan U. Zakirov <cubic@wildgate.miee.ru>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
Perl distribution.

=head1 SEE ALSO

perl(1), C<rtx-shredder>

=cut

our $VERSION = '0.01_01';


BEGIN {
# I can't use 'use lib' here since it breakes tests
# cause test suite uses old RTx::Shredder setup from
# RT lib path
	push @INC, qw(/opt/rt3/local/lib /opt/rt3/lib);
	use RTx::Shredder::Constants;

	require RT;

	require RT::Record;
	require RTx::Shredder::Record;

	require RT::Ticket;
	require RT::Group;
	require RT::GroupMember;
	require RT::CachedGroupMember;
	require RT::Transaction;
	require RT::Attachment;
	require RT::Principal;
	require RT::Link;
	require RT::TicketCustomFieldValue;
	require RT::CustomField;
	require RT::CustomFieldValue;
	require RT::Scrip;
	require RT::Queue;
	require RT::ScripCondition;
	require RT::ScripAction;
	require RT::Template;
	require RT::User;

	require RTx::Shredder::Attachment;
	require RTx::Shredder::CachedGroupMember;
	require RTx::Shredder::CustomField;
	require RTx::Shredder::CustomFieldValue;
	require RTx::Shredder::GroupMember;
	require RTx::Shredder::Group;
	require RTx::Shredder::Link;
	require RTx::Shredder::Principal;
	require RTx::Shredder::Queue;
	require RTx::Shredder::Scrip;
	require RTx::Shredder::ScripAction;
	require RTx::Shredder::ScripCondition;
	require RTx::Shredder::Template;
	require RTx::Shredder::TicketCustomFieldValue;
	require RTx::Shredder::Ticket;
	require RTx::Shredder::Transaction;
	require RTx::Shredder::User;
}

our %opt = ();

sub Init
{
	%opt = @_;
	RT::LoadConfig();
	RT::Init();
}

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
	my %args = (
			%opt,
			@_
		   );
	$self->{'opt'} = \%args;
	$self->{'Cache'} = {};
};

sub PutObjects
{
	my $self = shift;
	my %args = (
			Objects => undef,
			@_
		   );

	my $targets = $args{'Objects'};
	if( UNIVERSAL::isa( $targets, 'RT::SearchBuilder' ) ) {
		while( my $tmp = $targets->Next ) {
			$self->PutObject( Object => $tmp, Flags => $args{'Flags'} );
		}
	} elsif ( UNIVERSAL::isa( $targets, 'RT::Record' ) ) {
		$self->PutObject( Object => $targets, Flags => $args{'Flags'} );
	} else {
		RTx::Shredder::Exception->throw( "Unsupported type ". ref $targets );
	}

	return;
}

sub PutObject
{
	my $self = shift;
	my %args = (
			Object => undef,
			@_
		   );

	my $obj = $args{'Object'};
	unless( UNIVERSAL::isa( $obj, 'RT::Record' ) ) {
		RTx::Shredder::Exception->throw( "Unsupported type ". (ref $obj || $obj) );
	}

	my $str = $obj->_AsString;

	return $self->{'Cache'}->{ $str } if( $self->{'Cache'}->{ $str } );

	my $rec = {
                State => ON_STACK,
                Object => $obj,
        };
	$self->{'Cache'}->{ $str } = $rec;
	return $rec;
}

sub _ParseRefStrArgs
{
	my $self = shift;
	my %args = (
		String => '',
		Object => undef,
		@_
	);
	my $str = $args{'String'};
	unless( $str ) {
		$str = $args{'Object'}->_AsString;
	}

	return $str;
}

sub GetRecord
{
	my $self = shift;
	my $str = $self->_ParseRefStrArgs( @_ );
	return $self->{'Cache'}->{ $str };
}

sub GetObject
{
	my $self = shift;
	return $self->GetRecord( @_ )->{'Object'};
}

sub GetState
{
	my $self = shift;
	return $self->GetRecord( @_ )->{'State'};
}

sub DumpSQL
{
	my $self = shift;
	my %args = (
		Query => undef,
		@_
	);
	return unless exists $self->{opt}->{sqldump};
	my $fh = $self->{opt}->{sqldump};
	print $fh $args{'Query'};
	print $fh "\n" unless $args{'Query'} =~ /\n$/;
	return;
}

sub Wipeout
{
	my $self = shift;
	my %args = (
			@_
		   );

	foreach my $record( values %{ $self->{'Cache'} } ) {
		next if( $record->{'State'} & WIPED );
		$record->{'Object'}->Wipeout( Shredder => $self );
	}
}

sub ValidateRelations
{
	my $self = shift;
	my %args = (
			@_
		   );

	foreach my $record( values %{ $self->{'Cache'} } ) {
		next if( $record->{'State'} & VALID );
		$record->{'Object'}->ValidateRelations( Shredder => $self );
	}
}

1;
__END__
