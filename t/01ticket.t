#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Deep;

plan tests => 4;

BEGIN { require "t/utils.pl"; }
init_db();
create_savepoint('clean');

use RT::Ticket;
use RT::Tickets;

my $ticket = RT::Ticket->new( $RT::SystemUser );
my ($id) = $ticket->Create( Subject => 'test', Queue => 1 );
ok( $id, "created new ticket" );
$ticket->Delete;
is( $ticket->Status, 'deleted', "successfuly changed status" );

my $tickets = RT::Tickets->new( $RT::SystemUser );
$tickets->{'allow_deleted_search'} = 1;
$tickets->LimitStatus( VALUE => 'deleted' );
is( $tickets->Count, 1, "found one deleted ticket" ) or diag( note_not_patched );

my $shredder = RTx::Shredder->new();
$shredder->PutObjects( Objects => $tickets );
$shredder->Wipeout();

cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");

if( is_all_successful() ) {
	cleanup_tmp();
} else {
	diag( note_on_fail() );
}

