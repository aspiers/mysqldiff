#!/usr/bin/perl -w
#
# mysqldiff
#
# Utility to compare table definitions in two MySQL databases,
# and output a patch in the format of ALTER TABLE statements
# which converts the first database structure into in the second.
#
# Developed as part of the http://www.guideguide.com/ project.
# If you like hacking Perl in a cool environment, come and work for us!
#
# See http://adamspiers.org/computing/mysqldiff/ for the
# latest version.
#
# Copyright (c) 2000 Adam Spiers <adam@spiers.net>. All rights
# reserved. This program is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#

use strict;

require 5.004;

use Carp qw(:DEFAULT cluck);
use FindBin qw($RealBin $Script);
use lib $RealBin;
use Getopt::Long;

use MySQL::Diff qw(parse_arg diff_dbs);
use MySQL::Utils qw(debug_level);

my %opts = ();
GetOptions(\%opts, "help|?", "debug|d:i", "apply|A", "batch-apply|B",
           "keep-old-tables|k", "no-old-defs|n", "only-both|o", "table-re|t=s",
           "host|h=s",   "port|P=s", "user|u=s",   "password|p:s",
           "host1|h1=s", "port1|P1=s", "user1|u1=s", "password1|p1:s",
           "host2|h2=s", "port2|P2=s", "user2|u2=s", "password2|p2:s",
           "socket|s=s", "socket1|s1=s", "socket2|s2=s",
           "tolerant|i"
          );

if (@ARGV != 2 or $opts{help}) {
  usage();
  exit 1;
}

$opts{debug}++ if exists $opts{debug} && $opts{debug} == 0;
debug_level($opts{debug} || 0);

my $table_re;
$table_re = qr/$opts{'table-re'}/ if $opts{'table-re'};

my @db = ();
for my $num (0, 1) {
  my $new_db = parse_arg(\%opts, $ARGV[$num], $num);
  usage($new_db) unless ref $new_db;
  $db[$num] = $new_db;
}

$| = 1;
my $diffs = diff_dbs(\%opts, @db);
print $diffs;
apply($diffs) if $opts{apply} || $opts{'batch-apply'};

exit 0;

##############################################################################

sub usage {
  print STDERR @_, "\n" if @_;
  die <<EOF;
Usage: $Script [ options ] <database1> <database2>

Options:
  -?,  --help             show this help
  -A,  --apply            interactively patch database1 to match database2
  -B,  --batch-apply      non-interactively patch database1 to match database2
  -d,  --debug[=N]        enable debugging [level N, default 1]
  -o,  --only-both        only output changes for tables in both databases
  -k,  --keep-old-tables  don't output DROP TABLE commands
  -n,  --no-old-defs      suppress comments describing old definitions
  -t,  --table-re=REGEXP  restrict comparisons to tables matching REGEXP
  -i,  --tolerant         ignore DEFAULT and formatting changes

  -h,  --host=...         connect to host
  -P,  --port=...         use this port for connection
  -u,  --user=...         user for login if not current user
  -p,  --password[=...]   password to use when connecting to server
  -s,  --socket=...       socket to use when connecting to server

for <databaseN> only, where N == 1 or 2,
  -hN, --hostN=...        connect to host
  -PN, --portN=...        use this port for connection
  -uN, --userN=...        user for login if not current user
  -pN, --passwordN[=...]  password to use when connecting to server
  -sN, --socketN=...      socket to use when connecting to server

Databases can be either files or database names.
If there is an ambiguity, the file will be preferred;
to prevent this prefix the database argument with `db:'.
EOF
}

sub apply {
  my ($diffs) = @_;

  if (! $diffs) {
    print "No differences to apply.\n";
    exit 0;
  }

  my $db0  = $db[0]->name;
  if ($db[0]->source_type ne 'db') {
    die "$db0 is not a database; cannot apply changes.\n";
  }

  unless ($opts{'batch-apply'}) {
    print "\nApply above changes to $db0 [y/N] ? ";
    print "\n(CAUTION! Changes contain DROP TABLE commands.) "
      if $diffs =~ /\bDROP TABLE\b/i;
    my $reply = <STDIN>;
    return unless $reply =~ /^y(es)?$/i;
  }

  print "Applying changes ... ";
  my $args = $db[0]->auth_args;
  my $pipe = "mysql$args $db0";
  open(PATCH, "|$pipe")
    or die "Couldn't open pipe to '$pipe': $!\n";
  print PATCH $diffs;
  close(PATCH) or die "Couldn't close pipe: $!\n";
  print "done.\n";
}

