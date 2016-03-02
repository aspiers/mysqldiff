#!/usr/bin/perl -w
use strict;

use Test::More tests => 4;

# checks for regression to https://rt.cpan.org/Public/Bug/Display.html?id=77002 

BEGIN {
    use_ok('MySQL::Diff::Table');
}

my $table_def = <<END;
CREATE TABLE table_1 (
  id INT(11) NOT NULL auto_increment,
  foreign_id INT(11) NOT NULL, # another random comment
  field BLOB,
  PRIMARY KEY (id)
);
END

my $table = new_ok 'MySQL::Diff::Table' => [ def => $table_def ];

ok $table->{name} eq 'table_1', 'ensuring table name parsed properly';

my $duplicate_field_table_def = <<END;
CREATE TABLE table_1 (
  id INT(11) NOT NULL auto_increment,
  id INT(11) NOT NULL auto_increment,
  foreign_id INT(11) NOT NULL, # another random comment
  field BLOB,
  PRIMARY KEY (id)
);
END

# construct directly, outside new_ok
eval {
    my $table2 = MySQL::Diff::Table->new( def => $duplicate_field_table_def );
};
my $expected = qq{definition for field 'id' duplicated in table 'table_1'};
my @g        = split /\n/, $@;
my $got      = $g[0];

ok $got eq $expected,
  'ensuring table name returned in duplicate field name error';

__END__
