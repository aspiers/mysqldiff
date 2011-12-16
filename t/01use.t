#!/usr/bin/perl -w
use strict;

use Test::More tests => 4;

BEGIN {
	use_ok( 'MySQL::Diff' );
	use_ok( 'MySQL::Diff::Database' );
	use_ok( 'MySQL::Diff::Table' );
	use_ok( 'MySQL::Diff::Utils' );
}

