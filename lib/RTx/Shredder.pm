package RTx::Shredder;
use strict;

=head1 NAME

RTx::Shredder - Cleanup RT database

=head1 SYNOPSIS

  use RTx::Shredder;
  my $deleted = RT::Tickets->new( $RT::SystemUser );
  $deleted->Limit( VALUE => 'deleted' );
  while( my $t = $deleted->Next ) {
      $t->Wipeout;
  }

=head1 DESCRIPTION

RTx::Shredder is extention to RT API which allow to delete data from database.

=head1 USAGE

RT::Shredder is extension to RT API which add(push) methods into base RT
classes.

=head2 Dependencies

Dependencies method implementend in each RT class which Shredder can delete.
Now Shredder support wipe out of Ticket, Transaction, Attachment,
TicketCustomFieldValue, Principal, ACE, Group, GroupMember,
CachedGroupMember.

=head1 BUGS

=head2 Transactions support

Transactions unsupported yet, so you it's only save when all other
interactions with RT DB are stopped.

=head2 rtx-shredder.in

Modlue also install crappy rtx-shredder.in file, this shouldn't happen
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

perl(1), rtx-shredder.

=cut

our $VERSION = '0.00_02';


BEGIN {
	use RT;
	RT::LoadConfig;
	RT::Init;
	use RT::Record;
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

	require RTx::Shredder::Record;
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
}


1;
__END__

