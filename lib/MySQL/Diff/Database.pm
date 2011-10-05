package MySQL::Diff::Database;

=head1 NAME

MySQL::Diff::Database - Database Definition Class

=head1 SYNOPSIS

  use MySQL::Diff::Database;

  my $db = MySQL::Diff::Database->new(%options);
  my $source    = $db->source_type();
  my $summary   = $db->summary();
  my $name      = $db->name();
  my @tables    = $db->tables();
  my $table_def = $db->table_by_name($table);

  my @dbs = MySQL::Diff::Database::available_dbs();

=head1 DESCRIPTION

Parses a database definition into component parts.

=cut

use warnings;
use strict;
use vars qw($VERSION);

$VERSION = '0.40';

# ------------------------------------------------------------------------------
# Libraries

use Carp qw(:DEFAULT);
use File::Slurp;
use IO::File;

use MySQL::Diff::Utils qw(debug);
use MySQL::Diff::Table;

# ------------------------------------------------------------------------------
# Public Methods

sub new {
    my $class = shift;
    my %p = @_;
    my $self = {};
    bless $self, ref $class || $class;

    debug(3,"\nconstructing new MySQL::Diff::Database");

    my $string = _auth_args_string(%{$p{auth}});
    debug(3,"auth args: $string");
    $self->{_source}{auth} = $string;
    $self->{_source}{dbh} = $p{dbh} if($p{dbh});

    if ($p{file}) {
        $self->_canonicalise_file($p{file});
    } elsif ($p{db}) {
        $self->_read_db($p{db});
    } else {
        confess "MySQL::Diff::Database::new called without db or file params";
    }

    $self->_parse_defs();
    return $self;
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
    } elsif ($self->{_source}{db}) {
        my $args = $self->{_source}{auth};
        $args =~ tr/-//d;
        $args =~ s/\bpassword=\S+//;
        $args =~ s/^\s*(.*?)\s*$/$1/;
        my $summary = "  db: " . $self->{_source}{db};
        $summary .= " ($args)" if $args;
        return $summary;
    } else {
        return 'unknown';
    }
}

sub name {
    my $self = shift;
    return $self->{_source}{file} || $self->{_source}{db};
}

sub tables {
    my $self = shift;
    return @{$self->{_tables}};
}

sub table_by_name {
    my ($self,$name) = @_;
    return $self->{_by_name}{$name};
}

sub available_dbs {
    my %auth = @_;
    my $args = _auth_args_string(%auth);
  
    # evil but we don't use DBI because I don't want to implement -p properly
    # not that this works with -p anyway ...
    my $fh = IO::File->new("mysqlshow$args |") or die "Couldn't execute 'mysqlshow$args': $!\n";
    my @dbs;
    while (<$fh>) {
        next unless /^\| ([\w-]+)/;
        push @dbs, $1;
    }
    $fh->close() or die "mysqlshow$args failed: $!";

    return map { $_ => 1 } @dbs;
}


# ------------------------------------------------------------------------------
# Private Methods

sub _canonicalise_file {
    my ($self, $file) = @_;

    $self->{_source}{file} = $file;
    debug(2,"fetching table defs from file $file");

    # FIXME: option to avoid create-and-dump bit
    # create a temporary database using defs from file ...
    # hopefully the temp db is unique!
    my $temp_db = sprintf "test_mysqldiff-temp-%d_%d_%d", time(), $$, rand();
    debug(3,"creating temporary database $temp_db");
  
    my $defs = read_file($file);
    die "$file contains dangerous command '$1'; aborting.\n"
        if $defs =~ /;\s*(use|((drop|create)\s+database))\b/i;
  
    my $args = $self->{_source}{auth};
    my $fh = IO::File->new("| mysql $args") or die "Couldn't execute 'mysql$args': $!\n";
    print $fh "\nCREATE DATABASE \`$temp_db\`;\nUSE \`$temp_db\`;\n";
    print $fh $defs;
    $fh->close;

    # ... and then retrieve defs from mysqldump.  Hence we've used
    # MySQL to massage the defs file into canonical form.
    $self->_get_defs($temp_db);

    debug(3,"dropping temporary database $temp_db");
    $fh = IO::File->new("| mysql $args") or die "Couldn't execute 'mysql$args': $!\n";
    print $fh "DROP DATABASE \`$temp_db\`;\n";
    $fh->close;
}

sub _read_db {
    my ($self, $db) = @_;
    $self->{_source}{db} = $db;
    debug(3, "fetching table defs from db $db");
    $self->_get_defs($db);
}

sub _get_defs {
    my ($self, $db) = @_;

    my $args = $self->{_source}{auth};
    my $fh = IO::File->new("mysqldump -d $args $db 2>&1 |")
        or die "Couldn't read ${db}'s table defs via mysqldump: $!\n";
    debug(3, "running mysqldump -d $args $db");
    my $defs = $self->{_defs} = [ <$fh> ];
    $fh->close;

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

    debug(2, "parsing table defs");
    my $defs = join '', grep ! /^\s*(\#|--|SET|\/\*)/, @{$self->{_defs}};
    $defs =~ s/`//sg;
    my @tables = split /(?=^\s*(?:create|alter|drop)\s+table\s+)/im, $defs;
    $self->{_tables} = [];
    for my $table (@tables) {
        debug(4, "  table def [$table]");
        if($table =~ /create\s+table/i) {
            my $obj = MySQL::Diff::Table->new(source => $self->{_source}, def => $table);
            push @{$self->{_tables}}, $obj;
            $self->{_by_name}{$obj->name()} = $obj;
        }
    }
}

sub _auth_args_string {
    my %auth = @_;
    my $args = '';
    for my $arg (qw/host port user password socket/) {
        $args .= " --$arg=$auth{$arg}" if $auth{$arg};
    }
    return $args;
}

1;

__END__

=head1 METHODS

=head2 Constructor

=over 4

=item new( %options )

Instantiate the objects, providing the command line options for database
access and process requirements.

=back

=head2 Public Methods

=over 4

=item * source_type()

Returns 'file' if the data source is a text file, and 'db' if connected 
directly to a database.

=item * summary()

Provides a summary of the database.

=item * name()

Returns the name of the database;

=item * tables()

Returns a list of tables for the current database.

=item * table_by_name( $name )

Returns the table definition (see L<MySQL::Diff::Table>) for the given table.

=back

=head1 FUNCTIONS

=head2 Public Functions

=over 4

=item * available_dbs()

Returns a list of the available databases.

Note that is used as a function call, not a method call.

=back

=head1 AUTHOR

Adam Spiers <mysqldiff@adamspiers.org>

=head1 COPYRIGHT AND LICENSE

  Copyright (c) 2000-2011 Adam Spiers

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut
