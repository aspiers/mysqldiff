package MySQL::Table;

use strict;

use Carp qw(:DEFAULT cluck);
use Class::MakeMethods::Template::Hash
  'new --and_then_init' => 'new',
  'scalar'              => 'name def source primary_key options',
  'array --get_set_ref' => 'lines',
  'hash'                => 'fields indices unique_index fulltext',
  ;

use MySQL::Utils qw(debug);

sub init {
  my $self = shift;
  debug(4, "      constructing new MySQL::Table\n");
  croak "MySQL::Table::new called without def params" unless $self->def;
  $self->parse;
}

sub parse {
  my $self = shift;

  (my $def = $self->def) =~ s/\n+/\n/;
  $self->def($def);
  $self->lines([ grep ! /^\s*$/, split /(?=^)/m, $def ]);
  my @lines = $self->lines;
  debug(5, "        parsing table def\n");

  my $name;
  if ($lines[0] =~ /^\s*create\s+table\s+(\S+)\s+\(\s*$/i) {
    $self->name($name = $1);
    debug(5, "        got table name `$name'\n");
    shift @lines;
  }
  else {
    croak "couldn't figure out table name";
  }

  while (@lines) {
    $_ = shift @lines;
    s/^\s*(.*?),?\s*$/$1/; # trim whitespace and trailing commas
    debug(7, "          line: [$_]\n");
    if (/^PRIMARY\s+KEY\s+(.+)$/) {
      my $primary = $1;
      croak "two primary keys in table `$name': `$primary', `",
            $self->primary_key, "'\n"
        if $self->primary_key;
      $self->primary_key($primary);
      debug(6, "          got primary key $primary\n");
      next;
    }

    if (/^(KEY|UNIQUE(?: KEY)?)\s+(\S+?)\s*\((.*)\)$/) {
      my ($type, $key, $val) = ($1, $2, $3);
      croak "index `$key' duplicated in table `$name'\n"
        if $self->indices($key);
      $self->indices_push($key, $val);
      my $unique = $type =~ /unique/i;
      $self->unique_index_push($key, $unique);
      debug(6, "          got ",
               $unique ? 'unique ' : '',
               "index key `$key': ($val)\n");
      next;
    }

    if (/^(FULLTEXT(?: KEY|INDEX)?)\s+(\S+?)\s*\((.*)\)$/) {
      my ($type, $key, $val) = ($1, $2, $3);
      croak "FULLTEXT index `$key' duplicated in table `$name'\n"
        if $self->fulltext($key);
      $self->fulltext_push($key, $val);
      debug(6, "          got FULLTEXT index `$key': ($val)\n");
      next;
    }

    if (/^\)\s*(.*?);$/) { # end of table definition
      my $options = $self->options($1);
      debug(6, "          got table options `$options'\n");
      last;
    }

    if (/^(\S+)\s*(.*)/) {
      my ($field, $def) = ($1, $2);
      croak "definition for field `$field' duplicated in table `$name'\n"
        if $self->fields($field);
      $self->fields_push($field, $def);
      debug(6, "          got field def `$field': $def\n");
      next;
    }

    croak "unparsable line in definition for table `$name':\n$_";
  }

  warn "table `$name' didn't have terminator\n"
    unless defined $self->options;

  @lines = grep ! m{^/\*!40000 ALTER TABLE \Q$name\E DISABLE KEYS \*/;},
                @lines;

  warn "table `$name' had trailing garbage:\n", join '', @lines
    if @lines;
}

1;
