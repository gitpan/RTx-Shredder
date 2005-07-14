#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Deep;
BEGIN { require "t/utils.pl"; }
init_db();

plan tests => 1;

create_savepoint();
cmp_deeply( dump_current_and_savepoint(), "current DB equal to savepoint");

if( is_all_successful() ) {
	cleanup_tmp();
} else {
	diag( note_on_fail() );
}

