package RTx::Shredder;
use strict;

=head1 NAME

RTx::Shredder - Cleanup RT database

=head1 SYNOPSIS

  use RTx::Shredder;
  RTx::Shredder::Init();
  my $deleted = RT::Tickets->new( $RT::SystemUser );
  $deleted->{'allow_deleted_search'} = 1;
  $deleted->Limit( VALUE => 'deleted' );
  while( my $t = $deleted->Next ) {
      $t->Wipeout;
  }

=head1 DESCRIPTION

RTx::Shredder is extention to RT API which allow to delete data from database.

=head1 USAGE

RTx::Shredder is extension to RT API which add(push) methods into base RT
classes.

=head2 Dependencies

Dependencies method implementend in each RT class which Shredder can delete.
Now Shredder support wipe out of Ticket, Transaction, Attachment,
TicketCustomFieldValue, Principal, ACE, Group, GroupMember,
CachedGroupMember.

=head1 NOTES

=head2 Transactions support

Transactions unsupported yet, so it's only save when all other
interactions with RT DB are stopped.

=head2 Foreign keys

This two keys don't allow delete Tickets because of bug in MySQL
	ALTER TABLE Tickets ADD FOREIGN KEY (EffectiveId) REFERENCES Tickets(id);
	ALTER TABLE CachedGroupMembers ADD FOREIGN KEY (Via) REFERENCES CachedGroupMembers(id);

	http://bugs.mysql.com/bug.php?id=4042

=head1 BUGS

=head2 rtx-shredder.in

Module also install crappy rtx-shredder.in file, this shouldn't happen
in future.

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

perl(1), rtx-shredder

=cut

our $VERSION = '0.00_03';


BEGIN {
	use lib qw(/opt/rt3/local/lib /opt/rt3/lib);
	use RTx::Shredder::Constants;

	use RT;
	use RT::Record;
	require RTx::Shredder::Record;
	use RT::Ticket;
	use RT::Group;
	use RT::GroupMember;
	use RT::CachedGroupMember;
	use RT::Transaction;
	use RT::Attachment;
	use RT::Principal;
	use RT::Link;
	use RT::TicketCustomFieldValue;
	use RT::CustomField;
	use RT::CustomFieldValue;
	use RT::Scrip;
	use RT::Queue;
	use RT::ScripCondition;
	use RT::ScripAction;
	use RT::Template;

	require RTx::Shredder::Ticket;
	require RTx::Shredder::Group;
	require RTx::Shredder::GroupMember;
	require RTx::Shredder::CachedGroupMember;
	require RTx::Shredder::Transaction;
	require RTx::Shredder::Attachment;
	require RTx::Shredder::Principal;
	require RTx::Shredder::Link;
	require RTx::Shredder::TicketCustomFieldValue;
	require RTx::Shredder::CustomField;
	require RTx::Shredder::CustomFieldValue;
	require RTx::Shredder::Scrip;
	require RTx::Shredder::Queue;
	require RTx::Shredder::ScripCondition;
	require RTx::Shredder::ScripAction;
	require RTx::Shredder::Template;
}

sub Init
{
	RT::LoadConfig;
	RT::Init;
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
			@_
		   );
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
		RTx::Shredder::Exception->throw( "Unsupported type ". ref $obj );
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

sub Wipeout
{
	my $self = shift;
	my %args = (
			@_
		   );

	foreach my $record( keys %{ $self->{'Cache'} } ) {
		next if( $record->{'State'} & WIPED );
		$record->Wipeout( Shredder => $self );
	}
}

1;
__END__
