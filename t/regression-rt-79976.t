#!/usr/bin/perl -w
use strict;

use Test::More tests => 4;

# checks for regression to https://rt.cpan.org/Public/Bug/Display.html?id=79976

use_ok('MySQL::Diff::Database');
can_ok 'MySQL::Diff::Database', 'auth_args';

my $out = `mysqldump test`;
SKIP: {
  skip q{`mysqldump test` failed.}, 2 if $? != 0;
  my $db = new_ok 'MySQL::Diff::Database' => [ db => 'test' ];
  can_ok $db, 'auth_args';
}

__END__
