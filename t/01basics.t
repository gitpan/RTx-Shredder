#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Deep;
BEGIN { require "t/utils.pl"; }
init_db();

plan tests => 3;

create_savepoint();

use RT::Tickets;
my $ticket = RT::Ticket->new( $RT::SystemUser );
my ($id) = $ticket->Create( Subject => 'test', Queue => 1 );
ok( $id, "created new ticket" );

$ticket = RT::Ticket->new( $RT::SystemUser );
my ($status, $msg) = $ticket->Load( $id );
ok( $id, "load ticket" ) or diag( "error: $msg" );

my $shredder = RTx::Shredder->new();
$shredder->PutObject( Object => $ticket );
$shredder->Wipeout();

cmp_deeply( dump_current_and_savepoint(), "current DB equal to savepoint");

if( is_all_successful() ) {
	cleanup_tmp();
} else {
	diag( note_on_fail() );
}
