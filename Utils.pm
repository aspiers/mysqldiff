package MySQL::Utils;

use strict;

use base qw(Exporter);
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(available_dbs auth_args parse_arg debug_level debug);

sub available_dbs {
  my %auth = @_;
  my $args = auth_args(%auth);
  
  # evil but we don't use DBI because I don't want to implement -p properly
  # not that this works with -p anyway ...
  open(MYSQLSHOW, "mysqlshow$args |")
    or die "Couldn't execute `mysqlshow$args': $!\n";
  my @dbs = ();
  while (<MYSQLSHOW>) {
    next unless /^\| (\w+)/;
    push @dbs, $1;
  }
  close(MYSQLSHOW) or die "mysqlshow$args failed: $!";

  return map { $_ => 1 } @dbs;
}

sub parse_arg {
  my ($opts, $arg, $num) = @_;

  my %opts = %$opts;

  debug(1, "parsing arg $num: `$arg'\n");

  my $authnum = $num + 1;
  
  my %auth = ();
  for my $auth (qw/host user password/) {
    $auth{$auth} = $opts{"$auth$authnum"} || $opts{$auth};
    delete $auth{$auth} unless $auth{$auth};
  }

  if ($arg =~ /^db:(.*)/) {
    return new MySQL::Database(db => $1, %auth);
  }

  if ($opts{"host$authnum"}     ||
      $opts{"user$authnum"}     ||
      $opts{"password$authnum"} ||
      $opts{"socket$authnum"})
  {
    return new MySQL::Database(db => $arg, %auth);
  }

  if (-e $arg) {
    return new MySQL::Database(file => $arg, %auth);
  }

  my %dbs = available_dbs(%auth);
  debug(2, "  available databases: ", (join ', ', keys %dbs), "\n");

  if ($dbs{$arg}) {
    return new MySQL::Database(db => $arg, %auth);
  }

  return "`$arg' is not a valid file or database.\n";
}

sub auth_args {
  my %auth = @_;
  my $args = '';
  for my $arg (qw/host user password socket/) {
    $args .= " --$arg=$auth{$arg}" if $auth{$arg};
  }
  return $args;
}

{
  my $debug_level = 0;

  sub debug_level {
    my ($new_debug_level) = @_;
    $debug_level = $new_debug_level if defined $new_debug_level;
    return $debug_level;
  }

  sub debug {
    my $level = shift;
    print STDERR @_ if ($debug_level >= $level) && @_;
  }
}


1;
