package MySQL::Database;

use Carp qw(:DEFAULT cluck);

use MySQL::Utils qw(auth_args debug);
use MySQL::Table;

sub new {
  my $class = shift;
  my %p = @_;
  my $self = {};
  bless $self, ref $class || $class;

  debug(2, "  constructing new MySQL::Database\n");

  my $args = auth_args(%p);
  debug(3, "    auth args: $args\n");

  if ($p{file}) {
    $self->{_source} = { file => $p{file} };
    debug(3, "    fetching table defs from file $p{file}\n");

# FIXME: option to avoid create-and-dump bit
    # create a temporary database using defs from file ...
    # hopefully the temp db is unique!
    my $temp_db = sprintf "test_mysqldiff_temp_%d_%d", time(), $$;
    debug(3, "    creating temporary database $temp_db\n");

    open(DEFS, $p{file})
      or die "Couldn't open `$p{file}': $!\n";
    open(MYSQL, "| mysql $args")
      or die "Couldn't execute `mysql$args': $!\n";
    print MYSQL <<EOF;
CREATE DATABASE $temp_db;
USE $temp_db;
EOF
    print MYSQL <DEFS>;
    close(DEFS);
    close(MYSQL);

    # ... and then retrieve defs from mysqldump.  Hence we've used
    # MySQL to massage the defs file into canonical form.
    $self->_get_defs($temp_db, $args);

    debug(3, "    dropping temporary database $temp_db\n");
    open(MYSQL, "| mysql $args")
      or die "Couldn't execute `mysql$args': $!\n";
    print MYSQL "DROP DATABASE $temp_db;\n";
    close(MYSQL);
  }
  elsif ($p{db}) {
    $self->{_source} = { db => $p{db}, auth => $args };
    debug(3, "    fetching table defs from db $p{db}\n");
    $self->_get_defs($p{db}, $args);
  }
  else {
    confess "MySQL::Database::new called without db or file params";
  }

  $self->_parse_defs();

  return $self;
}

sub _get_defs {
  my $self = shift;
  my ($db, $args) = @_;

  open(MYSQLDUMP, "mysqldump -d $args $db |")
      or die "Couldn't read ${db}'s table defs via mysqldump: $!\n";
  debug(3, "    running mysqldump -d $args $db\n");
  $self->{_defs} = [ <MYSQLDUMP> ];
  close(MYSQLDUMP);
}

sub _parse_defs {
  my $self = shift;

  return if $self->{_tables};

  debug(3, "    parsing table defs\n");
  my $defs = join '', grep ! /^\s*\#/, @{$self->{_defs}};
  my @tables = split /(?=^\s*create\s+table\s+)/im, $defs;
  foreach my $table (@tables) {
    next unless $table =~ /create\s+table/i;
    my $obj = MySQL::Table->new(source => $self->{_source},
                                def => $table);
    push @{$self->{_tables}}, $obj;
    $self->{_by_name}{$obj->name()} = $obj;
  }
}

sub tables {
  return @{$_[0]->{_tables}};
}

sub table_by_name {
  my $self = shift;
  my ($name) = @_;
  return $self->{_by_name}{$name};
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
