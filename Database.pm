package MySQL::Database;

use strict;

use Carp qw(:DEFAULT cluck);

use MySQL::Utils qw(debug auth_args_string read_file);
use MySQL::Table;

sub new {
  my $class = shift;
  my %p = @_;
  my $self = {};
  bless $self, ref $class || $class;

  debug(2, "  constructing new MySQL::Database\n");

  $self->parse_auth_args($p{auth});

  if ($p{file}) {
    $self->canonicalise_file($p{file});
  }
  elsif ($p{db}) {
    $self->read_db($p{db});
  }
  else {
    confess "MySQL::Database::new called without db or file params";
  }

  $self->_parse_defs();

  return $self;
}

sub parse_auth_args {
  my $self = shift;
  my ($args) = @_;
  my $string = auth_args_string(%$args);
  debug(3, "    auth args: $string\n");
  $self->{_source}{auth} = $string;
}

sub canonicalise_file {
  my $self = shift;
  my ($file) = @_;

  $self->{_source}{file} = $file;
  debug(3, "    fetching table defs from file $file\n");

# FIXME: option to avoid create-and-dump bit
  # create a temporary database using defs from file ...
  # hopefully the temp db is unique!
  my $temp_db = sprintf "test_mysqldiff_temp_%d_%d", time(), $$;
  debug(3, "    creating temporary database $temp_db\n");
  
  my $defs = join '', read_file($file);
  die "$file contains dangerous command '$1'; aborting.\n"
    if $defs =~ /;\s*(use|((drop|create)\s+database))\s/i;
  
  my $args = $self->auth_args;
  open(MYSQL, "| mysql $args")
    or die "Couldn't execute `mysql$args': $!\n";
  print MYSQL <<EOF;
CREATE DATABASE $temp_db;
USE $temp_db;
EOF
  print MYSQL $defs;
  close(MYSQL);

  # ... and then retrieve defs from mysqldump.  Hence we've used
  # MySQL to massage the defs file into canonical form.
  $self->_get_defs($temp_db);

  debug(3, "    dropping temporary database $temp_db\n");
  open(MYSQL, "| mysql $args")
    or die "Couldn't execute `mysql$args': $!\n";
  print MYSQL "DROP DATABASE $temp_db;\n";
  close(MYSQL);
}

sub read_db {
  my $self = shift;
  my ($db) = @_;
  $self->{_source}{db} = $db;
  debug(3, "    fetching table defs from db $db\n");
  $self->_get_defs($db);
}

sub auth_args {
  my $self = shift;
  return $self->{_source}{auth};
}

sub _get_defs {
  my $self = shift;
  my ($db) = @_;

  my $args = $self->auth_args;
  open(MYSQLDUMP, "mysqldump -d $args $db 2>&1 |")
      or die "Couldn't read ${db}'s table defs via mysqldump: $!\n";
  debug(3, "    running mysqldump -d $args $db\n");
  my $defs = $self->{_defs} = [ <MYSQLDUMP> ];
  close(MYSQLDUMP);

  if (grep /mysqldump: Got error: .*: Unknown database/, @$defs) {
    die <<EOF;
Failed to create temporary database $db
during canonicalization.  Make sure that your mysql.db table has a row
authorizing full access to all databases matching 'test\\_%', and that
the database doesn't already exist.
EOF
  }
}

sub _parse_defs {
  my $self = shift;

  return if $self->{_tables};

  debug(3, "    parsing table defs\n");
  my $defs = join '', grep ! /^\s*(\#|--)/, @{$self->{_defs}};
  my @tables = split /(?=^\s*create\s+table\s+)/im, $defs;
  $self->{_tables} = [];
  foreach my $table (@tables) {
    next unless $table =~ /create\s+table/i;
    my $obj = MySQL::Table->new(source => $self->{_source},
                                def => $table);
    push @{$self->{_tables}}, $obj;
    $self->{_by_name}{$obj->name()} = $obj;
  }
}

sub name {
  my $self = shift;
  return $self->{_source}{file} || $self->{_source}{db};
}

sub tables {
  return @{$_[0]->{_tables}};
}

sub table_by_name {
  my $self = shift;
  my ($name) = @_;
  return $self->{_by_name}{$name};
}

sub source_type {
  my $self = shift;
  return 'file' if $self->{_source}{file};
  return 'db'   if $self->{_source}{db};
}

sub summary {
  my $self = shift;
  
  if ($self->{_source}{file}) {
    return "file: " . $self->{_source}{file};
  }
  elsif ($self->{_source}{db}) {
    my $args = $self->{_source}{auth};
    $args =~ tr/-//d;
    $args =~ s/\bpassword=\S+//;
    $args =~ s/^\s*(.*?)\s*$/$1/;
    my $summary = "  db: " . $self->{_source}{db};
    $summary .= " ($args)" if $args;
    return $summary;
  }
  else {
    return 'unknown';
  }
}

1;
