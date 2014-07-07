# -*- perl -*-
use strict;
use warnings;

use Test::More;
use Config;

plan skip_all => 'This test is only run for the module author'
    unless -d '.git' || $ENV{AUTOMATED_TESTING};
plan skip_all => 'Test::Kwalitee fails with clang -faddress-sanitizer'
    if $Config{ccflags} =~ /(-fsanitize=address|-faddress-sanitizer)/;

use File::Copy 'cp';
cp('MYMETA.yml','META.yml') if -e 'MYMETA.yml' and !-e 'META.yml';

eval {
  require Test::Kwalitee; Test::Kwalitee->import;
};
plan skip_all => "Test::Kwalitee needed for testing kwalitee"
    if $@;
