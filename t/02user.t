#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Deep;
BEGIN { require "t/utils.pl"; }
init_db();

plan tests => 6;

create_savepoint('clean');

my $queue = RT::Queue->new( $RT::SystemUser );
my ($qid) = $queue->Load( 'General' );
ok( $qid, "loaded queue" );

my $everyone_group = RT::Group->new( $RT::SystemUser );
$everyone_group->LoadSystemInternalGroup( 'Everyone' );
$everyone_group->PrincipalObj->GrantRight( Right => 'CreateTicket', Object => $queue );

my $ticket = RT::Ticket->new( $RT::SystemUser );
my ($tid) = $ticket->Create( Queue => $qid, Subject => 'test' );
ok( $tid, "ticket created" );

create_savepoint('bucreate'); # berfore user create
my $user = RT::User->new( $RT::SystemUser );
my ($uid, $msg) = $user->Create( Name => 'new user', Privileged => 1, Disabled => 0 );
ok( $uid, "created new user" ) or diag "error: $msg";
is( $user->id, $uid, "id is correct" );

# hack to init VARIABLE dependencies
$ticket->__Set( Field => 'Creator', Value => $uid );
$ticket->__Set( Field => 'LastUpdatedBy', Value => $uid );

ok( $queue->HasRight( Right => 'CreateTicket', Principal => $user ), "has right" );

my $shredder = RTx::Shredder->new();
$shredder->PutObjects( Objects => $user );

my $resolver = sub {
	my %args = (@_);
	my $t =	$args{'TargetObj'};
	my $resolver_uid = $RT::SystemUser->id;
	foreach my $method ( qw(Creator LastUpdatedBy) ) {
		next unless $t->_Accessible( $method => 'read' );
		$t->__Set( Field => $method, Value => $resolver_uid );
	}
};
$shredder->PutResolver( BaseClass => 'RT::User', Code => $resolver );

$shredder->Wipeout();
cmp_deeply( dump_current_and_savepoint('bucreate'), "current DB equal to savepoint");

if( is_all_successful() ) {
	cleanup_tmp();
} else {
	diag( note_on_fail() );
}

