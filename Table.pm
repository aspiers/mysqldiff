package MySQL::Table;

use Carp qw(:DEFAULT cluck);

use MySQL::Utils qw(debug);

sub new {
  my $class = shift;
  my %p = @_;
  my $self = {};
  bless $self, ref $class || $class;

  debug(4, "      constructing new MySQL::Table\n");

  if (! $p{def}) {
    croak "MySQL::Table::new called without def params";
  }

  $self->parse($p{def});

  $self->{_source} = $p{source};

  return $self;
}

sub parse {
  my $self = shift;
  my ($def) = @_;

  $def =~ s/\n+/\n/;
  $self->{_def} = $def;
  $self->{_lines} = [ grep ! /^\s*$/, split /(?=^)/m, $def ];
  my @lines = @{$self->{_lines}};

  debug(5, "        parsing table def\n");

  my $name;
  if ($lines[0] =~ /^\s*create\s+table\s+(\S+)\s+\(\s*$/i) {
    $name = $self->{_name} = $1;
    debug(5, "        got table name `$name'\n");
    shift @lines;
  }
  else {
    croak "couldn't figure out table name";
  }

  while (@lines) {
    $_ = shift @lines;
    s/^\s*(.*?),?\s*$/$1/; # trim whitespace and trailing commas
    if (/^\);$/) {
      last;
    }

    if (/^PRIMARY\s+KEY\s+(.+)$/) {
      my $primary = $1;
      croak "two primary keys in table `$name': `$primary', `",
            $self->{_primary_key}, "'\n"
        if $self->{_primary_key};
      $self->{_primary_key} = $primary;
      debug(6, "          got primary key `$primary'\n");
      next;
    }

    if (/^(KEY|UNIQUE)\s+(\S+?)\s+\((.*)\)$/) {
      my ($type, $key, $val) = ($1, $2, $3);
      croak "index `$key' duplicated in table `$name'\n"
        if $self->{_indices}{$key};
      $self->{_indices}{$key} = $val;
      $self->{_unique_index}{$key} = ($type =~ /unique/i) ? 1 : 0;
      debug(6, "          got ",
               ($type =~ /unique/i) ? 'unique ' : '',
               "index key `$key': ($val)\n");
      next;
    }

    if (/^(\S+)\s*(.*)/) {
      my ($field, $def) = ($1, $2);
      croak "definition for field `$field' duplicated in table `$name'\n"
        if $self->{_fields}{$field};
      $self->{_fields}{$field} = $def;
      debug(6, "          got field def `$field': $def\n");
      next;
    }

    croak "unparsable line in definition for table `$name':\n$_";
  }

  if (@lines) {
    my $name = $self->name();
    warn "table `$name' had trailing garbage:\n", join '', @lines;
  }
}

sub def             { $_[0]->{_def}                 }
sub name            { $_[0]->{_name}                }
sub source          { $_[0]->{_source}              }
sub fields          { $_[0]->{_fields}  || {}       }
sub indices         { $_[0]->{_indices} || {}       }
sub primary_key     { $_[0]->{_primary_key}         }
sub is_unique_index { $_[0]->{_unique_index}{$_[1]} }


1;
