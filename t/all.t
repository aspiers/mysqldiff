#!/usr/bin/perl -w

use strict;

use Test::More;
use MySQL::Diff;
use MySQL::Diff::Database;

my $TEST_USER = 'test';
my @VALID_ENGINES = qw(MyISAM InnoDB);
my $VALID_ENGINES = join '|', @VALID_ENGINES;

my %tables = (
  foo1 => '
CREATE TABLE foo (
  id INT(11) NOT NULL auto_increment,
  foreign_id INT(11) NOT NULL, 
  PRIMARY KEY (id)
) DEFAULT CHARACTER SET utf8;
',

  foo2 => '
# here be a comment

CREATE TABLE foo (
  id INT(11) NOT NULL auto_increment,
  foreign_id INT(11) NOT NULL, # another random comment
  field BLOB,
  PRIMARY KEY (id)
) DEFAULT CHARACTER SET utf8;
',

  foo3 => '
CREATE TABLE foo (
  id INT(11) NOT NULL auto_increment,
  foreign_id INT(11) NOT NULL, 
  field TINYBLOB,
  PRIMARY KEY (id)
) DEFAULT CHARACTER SET utf8;
',

  foo4 => '
CREATE TABLE foo (
  id INT(11) NOT NULL auto_increment,
  foreign_id INT(11) NOT NULL, 
  field TINYBLOB,
  PRIMARY KEY (id, foreign_id)
) DEFAULT CHARACTER SET utf8;
',

  bar1 => '
CREATE TABLE bar (
  id     INT AUTO_INCREMENT NOT NULL PRIMARY KEY, 
  ctime  DATETIME,
  utime  DATETIME,
  name   CHAR(16), 
  age    INT
) DEFAULT CHARACTER SET utf8;
',

  bar2 => '
CREATE TABLE bar (
  id     INT AUTO_INCREMENT NOT NULL PRIMARY KEY, 
  ctime  DATETIME,
  utime  DATETIME,   # FOO!
  name   CHAR(16), 
  age    INT,
  UNIQUE (name, age)
) DEFAULT CHARACTER SET utf8;
',

  bar3 => '
CREATE TABLE bar (
  id     INT AUTO_INCREMENT NOT NULL PRIMARY KEY, 
  ctime  DATETIME,
  utime  DATETIME,
  name   CHAR(16), 
  age    INT,
  UNIQUE (id, name, age)
) DEFAULT CHARACTER SET utf8;
',

  baz1 => '
CREATE TABLE baz (
  firstname CHAR(16),
  surname   CHAR(16)
) DEFAULT CHARACTER SET utf8;
',

  baz2 => '
CREATE TABLE baz (
  firstname CHAR(16),
  surname   CHAR(16),
  UNIQUE (firstname, surname)
) DEFAULT CHARACTER SET utf8;
',

  baz3 => '
CREATE TABLE baz (
  firstname CHAR(16),
  surname   CHAR(16),
  KEY (firstname, surname)
) DEFAULT CHARACTER SET utf8;
',

  qux1 => '
CREATE TABLE qux (
  age INT
) DEFAULT CHARACTER SET utf8;
',

  qux2 => '
CREATE TABLE qux (
  id  INT NOT NULL AUTO_INCREMENT,
  age INT,
  PRIMARY KEY (id)
) DEFAULT CHARACTER SET utf8;
',

  qux3 => '
CREATE TABLE qux (
  id  INT NOT NULL AUTO_INCREMENT,
  age INT,
  UNIQUE KEY (id)
) DEFAULT CHARACTER SET utf8;
',

);

my %tests = (
  'add column' =>
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
  
  'drop column' =>
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

  'change column' =>
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

  'no-old-defs' =>
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

  'add table' =>
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
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

',
  ],

  'drop table' =>
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

  'only-both' =>
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

  'keep-old-tables' =>
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

  'keep-old-columns' =>
  [
    { 'keep-old-columns' => 1 },
    $tables{foo2} . $tables{bar1}, $tables{foo1},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
## Options: keep-old-columns
##
## --- file: tmp.db1
## +++ file: tmp.db2

DROP TABLE bar;

',
  ],

  'table-re' =>
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

  'single-transaction' =>
  [
    { 'single-transaction' => 'ba' },
    $tables{foo1} . $tables{bar1} . $tables{baz1},
    $tables{foo2} . $tables{bar2} . $tables{baz2},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
## Options: single-transaction=ba
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE bar ADD UNIQUE name (name,age);
ALTER TABLE baz ADD UNIQUE firstname (firstname,surname);
ALTER TABLE foo ADD COLUMN field blob;
',
  ],

  'drop primary key with auto weirdness' =>
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
      
  'drop additional primary key' =>
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

  'unique changes' =>
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
      
  'drop index' =>
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
      
  'alter indices' =>
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

  'alter indices 2' =>
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

  'add unique index' =>
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

  'drop unique index' =>
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

  'alter unique index' =>
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

  'alter unique index 2' =>
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

  'add auto increment primary key' =>
  [
    {},
    $tables{qux1},
    $tables{qux2},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE qux ADD COLUMN id int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY;
',
  ],

  'add auto increment unique key' =>
  [
    {},
    $tables{qux1},
    $tables{qux3},
    '## mysqldiff <VERSION>
##
## Run on <DATE>
##
## --- file: tmp.db1
## +++ file: tmp.db2

ALTER TABLE qux ADD COLUMN id int(11) NOT NULL AUTO_INCREMENT UNIQUE KEY;
',
  ],
);

my $BAIL = check_setup();
plan skip_all => $BAIL  if($BAIL);

my $total = scalar(keys %tests) * 5;
plan tests => $total;

use Data::Dumper;

my @tests = (keys %tests); #keys %tests

{
    my %debug = ( debug_file => 'debug.log', debug => 9 );
    unlink $debug{debug_file};

    for my $test (@tests) {
      note( "Testing $test\n" );

      my ($opts, $db1_defs, $db2_defs, $expected) = @{$tests{$test}};

      note("test=".Dumper($tests{$test}));

      my $diff = MySQL::Diff->new(%$opts, %debug);
      isa_ok($diff,'MySQL::Diff');

      my $db1 = get_db($db1_defs, 1, $opts->{'table-re'}, $opts->{'single_transaction'});
      my $db2 = get_db($db2_defs, 2, $opts->{'table-re'}, $opts->{'single_transaction'});

      my $d1 = $diff->register_db($db1, 1);
      my $d2 = $diff->register_db($db2, 2);
      note("d1=" . Dumper($d1));
      note("d2=" . Dumper($d2));

      isa_ok($d1, 'MySQL::Diff::Database');
      isa_ok($d2, 'MySQL::Diff::Database');

      my $diffs = $diff->diff();
      $diffs =~ s/^## mysqldiff [\d.]+/## mysqldiff <VERSION>/m;
      $diffs =~ s/^## Run on .*/## Run on <DATE>/m;
      $diffs =~ s{/\*!40\d{3} .*? \*/;\n*}{}m;
      $diffs =~ s/ *$//gm;
      for ($diffs, $expected) {
        s/ default\b/ DEFAULT/gi;
        s/PRIMARY KEY +\(/PRIMARY KEY (/g;
        s/auto_increment/AUTO_INCREMENT/gi;
      }

      my $engine = 'InnoDB';
      my $ENGINE_RE = qr/ENGINE=($VALID_ENGINES)/;
      if ($diffs =~ $ENGINE_RE) {
        $engine = $1;
        $expected =~ s/$ENGINE_RE/ENGINE=$engine/g;
      }

      note("diffs = "    . Dumper($diffs));
      note("expected = " . Dumper($expected));

      is_deeply($diffs, $expected, ".. expected differences for $test");

      # Now test that $diffs correctly patches $db1_defs to $db2_defs.
      my $patched = get_db($db1_defs . "\n" . $diffs, 1, $opts->{'table-re'}, $opts->{'single-transaction'});
      $diff->register_db($patched, 1);
      is_deeply($diff->diff(), '', ".. patched differences for $test");
    }
}


sub get_db {
    my ($defs, $num, $table_re, $single_transaction) = @_;

    note("defs=$defs");

    my $file = "tmp.db$num";
    open(TMP, ">$file") or die "open: $!";
    print TMP $defs;
    close(TMP);
    my $db = MySQL::Diff::Database->new(file => $file, auth => { user => $TEST_USER }, 'table-re' => $table_re, 'single-transaction' => $single_transaction);
    unlink $file;
    return $db;
}

sub check_setup {
    my $failure_string = "Cannot proceed with tests without ";
    _output_matches("mysql --help", qr/--password/) or
        return $failure_string . 'a MySQL client';
    _output_matches("mysqldump --help", qr/--password/) or
        return $failure_string . 'mysqldump';
    _output_matches("echo status | mysql -u $TEST_USER 2>&1", qr/Connection id:/) or
        return $failure_string . 'a valid connection';
    return '';
}

sub _output_matches {
    my ($cmd, $re) = @_;
    my ($exit, $out) = _run($cmd);

    my $issue;
    if (defined $exit) {
        if ($exit == 0) {
            $issue = "Output from '$cmd' didn't match /$re/:\n$out" if $out !~ $re;
        }
        else {
            $issue = "'$cmd' exited with status code $exit";
        }
    }
    else {
        $issue = "Failed to execute '$cmd'";
    }

    if ($issue) {
        warn $issue, "\n";
        return 0;
    }
    return 1;
}

sub _run {
    my ($cmd) = @_;
    unless (open(CMD, "$cmd|")) {
        return (undef, "Failed to execute '$cmd': $!\n");
    }
    my $out = join '', <CMD>;
    close(CMD);
    return ($?, $out);
}
