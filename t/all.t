#!/usr/bin/perl -w

use strict;

use Test;
use MySQL::Database;
use MySQL::Diff qw(diff_dbs);

my %tables = (
  foo1 => '
CREATE TABLE foo (
  id INT(11) NOT NULL auto_increment,
  foreign_id INT(11) NOT NULL, 
  PRIMARY KEY (id)
);
',

  foo2 => '
# here be a comment

CREATE TABLE foo (
  id INT(11) NOT NULL auto_increment,
  foreign_id INT(11) NOT NULL, # another random comment
  field BLOB,
  PRIMARY KEY (id)
);
',

  foo3 => '
CREATE TABLE foo (
  id INT(11) NOT NULL auto_increment,
  foreign_id INT(11) NOT NULL, 
  field TINYBLOB,
  PRIMARY KEY (id)
);
',

  foo4 => '
CREATE TABLE foo (
  id INT(11) NOT NULL auto_increment,
  foreign_id INT(11) NOT NULL, 
  field TINYBLOB,
  PRIMARY KEY (id, foreign_id)
);
',

  bar1 => '
CREATE TABLE bar (
  id     INT AUTO_INCREMENT NOT NULL PRIMARY KEY, 
  ctime  DATETIME,
  utime  DATETIME,
  name   CHAR(16), 
  age    INT
);
',

  bar2 => '
CREATE TABLE bar (
  id     INT AUTO_INCREMENT NOT NULL PRIMARY KEY, 
  ctime  DATETIME,
  utime  DATETIME,   # FOO!
  name   CHAR(16), 
  age    INT,
  UNIQUE (name, age)
);
',

  bar3 => '
CREATE TABLE bar (
  id     INT AUTO_INCREMENT NOT NULL PRIMARY KEY, 
  ctime  DATETIME,
  utime  DATETIME,
  name   CHAR(16), 
  age    INT,
  UNIQUE (id, name, age)
);
',

  baz1 => '
CREATE TABLE baz (
  firstname CHAR(16),
  surname   CHAR(16)
);
',

  baz2 => '
CREATE TABLE baz (
  firstname CHAR(16),
  surname   CHAR(16),
  UNIQUE (firstname, surname)
);
',

  baz3 => '
CREATE TABLE baz (
  firstname CHAR(16),
  surname   CHAR(16),
  KEY (firstname, surname)
);
',
);

my @tests = (
  'add column',
  [
    {},
    @tables{qw/foo1 foo2/},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE foo ADD COLUMN field blob;
',
  ],
  
  'drop column',
  [
    {},
    @tables{qw/foo2 foo1/},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE foo DROP COLUMN field; # was blob
',
  ],

  'change column',
  [
    {},
    @tables{qw/foo2 foo3/},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE foo CHANGE COLUMN field field tinyblob; # was blob
'
  ],

  'no-old-defs',
  [
    { 'no-old-defs' => 1 },
    @tables{qw/foo2 foo1/},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
## Options: no-old-defs
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE foo DROP COLUMN field;
',
  ],

  'add table',
  [
    { },
    $tables{foo1}, $tables{foo2} . $tables{bar1},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE foo ADD COLUMN field blob;
CREATE TABLE bar (
  id int(11) NOT NULL auto_increment,
  ctime datetime default NULL,
  utime datetime default NULL,
  name char(16) default NULL,
  age int(11) default NULL,
  PRIMARY KEY  (id)
) TYPE=MyISAM;

',
  ],

  'drop table',
  [
    { },
    $tables{foo1} . $tables{bar1}, $tables{foo2},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

DROP TABLE bar;

ALTER TABLE foo ADD COLUMN field blob;
',
  ],

  'only-both',
  [
    { 'only-both' => 1 },
    $tables{foo1} . $tables{bar1}, $tables{foo2},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
## Options: only-both
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE foo ADD COLUMN field blob;
',
  ],

  'keep-old-tables',
  [
    { 'keep-old-tables' => 1 },
    $tables{foo1} . $tables{bar1}, $tables{foo2},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
## Options: keep-old-tables
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE foo ADD COLUMN field blob;
',
  ],

  'table-re',
  [
    { 'table-re' => 'ba' },
    $tables{foo1} . $tables{bar1} . $tables{baz1},
    $tables{foo2} . $tables{bar2} . $tables{baz2},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
## Options: table-re=ba
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE bar ADD UNIQUE name (name,age);
ALTER TABLE baz ADD UNIQUE firstname (firstname,surname);
',
  ],

  'drop primary key with auto weirdness',
  [
    {},
    $tables{foo3},
    $tables{foo4},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE foo ADD INDEX (id); # auto columns must always be indexed
ALTER TABLE foo DROP PRIMARY KEY; # was (id)
ALTER TABLE foo ADD PRIMARY KEY (id,foreign_id);
ALTER TABLE foo DROP INDEX id;
',
  ],
      
  [
    {},
    $tables{foo4},
    $tables{foo3},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE foo ADD INDEX (id); # auto columns must always be indexed
ALTER TABLE foo DROP PRIMARY KEY; # was (id,foreign_id)
ALTER TABLE foo ADD PRIMARY KEY (id);
ALTER TABLE foo DROP INDEX id;
',
  ],

  'unique changes',
  [
    {},
    $tables{bar1},
    $tables{bar2},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE bar ADD UNIQUE name (name,age);
',
  ],
      
  [
    {},
    $tables{bar2},
    $tables{bar1},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE bar DROP INDEX name; # was UNIQUE (name,age)
',
  ],
      
  [
    {},
    $tables{bar2},
    $tables{bar3},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE bar DROP INDEX name; # was UNIQUE (name,age)
ALTER TABLE bar ADD UNIQUE id (id,name,age);
',
  ],

  [
    {},
    $tables{bar3},
    $tables{bar2},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE bar DROP INDEX id; # was UNIQUE (id,name,age)
ALTER TABLE bar ADD UNIQUE name (name,age);
',
  ],

  [
    {},
    $tables{bar1},
    $tables{bar3},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE bar ADD UNIQUE id (id,name,age);
',
  ],

  [
    {},
    $tables{bar3},
    $tables{bar1},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE bar DROP INDEX id; # was UNIQUE (id,name,age)
',
  ],

  [
    {},
    $tables{baz2},
    $tables{baz3},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE baz DROP INDEX firstname; # was UNIQUE (firstname,surname)
ALTER TABLE baz ADD INDEX firstname (firstname,surname);
',
  ],

  [
    {},
    $tables{baz3},
    $tables{baz2},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE baz DROP INDEX firstname; # was INDEX (firstname,surname)
ALTER TABLE baz ADD UNIQUE firstname (firstname,surname);
',
  ],
);

my $run = 0;
my $total = scalar(grep ref, @tests) * 2 + 4;
plan tests => $total;

print "# Test loading MySQL::Diff\n";
my_ok(1);

print "# Test can run mysql client\n";
my $client_ok = (open(MYSQL, "mysql --help|") &&
                   join('', <MYSQL>) =~ /net_buffer_length/);
bail("Cannot proceed with tests without a mysql client")
  unless $client_ok;
my_ok($client_ok);

print "# Test can run mysqldump utility\n";
my $mysqldump_ok = (open(MYSQLDUMP, "mysqldump --help|") &&
                      join('', <MYSQLDUMP>) =~ /net_buffer_length/);
bail("Cannot proceed with tests without mysqldump")
  unless $mysqldump_ok;
my_ok($mysqldump_ok);

print "# Test can connect to mysql db\n";
my $connection_ok = (open(MYSQL, "echo status | mysql 2>&1 |") &&
                       join('', <MYSQL>) =~ /Connection id:/i);
bail("Cannot proceed with tests without a valid connection")
  unless $connection_ok;
my_ok($connection_ok);

foreach my $test (@tests) {
  if (! ref $test) {
    print "# Testing $test\n";
    next;
  }

  my ($opts, $db1_defs, $db2_defs, $expected) = @$test;

  my $db1 = get_db($db1_defs, 1);
  my $db2 = get_db($db2_defs, 2);

  my $diffs = diff_dbs($opts, $db1, $db2);
  $diffs =~ s/^## mysqldiff [\d.]+/## mysqldiff <VERSION>/m;
  $diffs =~ s/^## Run on .*/## Run on <DATE>/m;
  $diffs =~ s{/\*!40000 ALTER TABLE .* DISABLE KEYS \*/;\n*}{}m;
  $diffs =~ s/ *$//gm;

  my_ok($diffs, $expected);

  # Now test that $diffs correctly patches $db1_defs to $db2_defs.
  my $patched = get_db($db1_defs . "\n" . $diffs, 1);
  my_ok(diff_dbs($opts, $patched, $db2), '');
}

sub get_db {
  my ($defs, $num) = @_;

  my $file = "tmp.db$num";
  open(TMP, ">$file") or die "open: $!";
  print TMP $defs;
  close(TMP);
  my $db = MySQL::Database->new(file => $file);
  unlink $file;
  return $db;
}

sub my_ok { # do we really need this?
  $run++;
  &ok;
}

sub bail { # because Test::More::BAIL_OUT is still unimplemented ...
  my ($reason) = @_;
  ok(0);
  print "$reason.\n";
  if ($ENV{FAKE_SUCCESS}) {
    print "FAKE_SUCCESS was set; assuming OK and faking success for rest of tests ...\n";
    ok(1) for 1 .. ($total - $run);
  }
  else {
    print "Aborting rest of tests.\n";
  }
  exit 0;
}
