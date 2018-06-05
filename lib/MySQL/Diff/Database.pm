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
use String::ShellQuote qw(shell_quote);

our $VERSION = '0.60';

# ------------------------------------------------------------------------------
# Libraries

use Carp qw(:DEFAULT);
use File::Slurp;
use IO::File;

use MySQL::Diff::Utils qw(debug);
use MySQL::Diff::Table;

# ------------------------------------------------------------------------------

=head1 METHODS

=head2 Constructor

=over 4

=item new( %options )

Instantiate the objects, providing the command line options for database
access and process requirements.

=back

=cut

sub new {
    my $class = shift;
    my %p = @_;
    my $self = {};
    bless $self, ref $class || $class;

    debug(3,"\nconstructing new MySQL::Diff::Database");

    my $auth_ref = _auth_args_string(%{$p{auth}});
    my $string = shell_quote @$auth_ref;
    debug(3,"auth args: $string");
    $self->{_source}{auth} = $string;
    $self->{_source}{dbh} = $p{dbh} if $p{dbh};
    $self->{'single-transaction'} = $p{'single-transaction'};
    $self->{'table-re'} = $p{'table-re'};

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

=head2 Public Methods

=over 4

=item * source_type()

Returns 'file' if the data source is a text file, and 'db' if connected
directly to a database.

=cut

sub source_type {
    my $self = shift;
    return 'file' if $self->{_source}{file};
    return 'db'   if $self->{_source}{db};
}

=item * summary()

Provides a summary of the database.

=cut

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

=item * name()

Returns the name of the database.

=cut

sub name {
    my $self = shift;
    return $self->{_source}{file} || $self->{_source}{db};
}

=item * tables()

Returns a list of tables for the current database.

=cut

sub tables {
    my $self = shift;
    return @{$self->{_tables}};
}

=item * table_by_name( $name )

Returns the table definition (see L<MySQL::Diff::Table>) for the given table.

=cut

sub table_by_name {
    my ($self,$name) = @_;
    return $self->{_by_name}{$name};
}

=back

=head1 FUNCTIONS

=head2 Public Functions

=over 4

=item * available_dbs()

Returns a list of the available databases.

Note that is used as a function call, not a method call.

=cut

sub available_dbs {
    my %auth = @_;
    my $args_ref = _auth_args_string(%auth);
    unshift @$args_ref, q{mysqlshow}; 
  
    # evil but we don't use DBI because I don't want to implement -p properly
    # not that this works with -p anyway ...
    my $command = shell_quote @$args_ref;
    my $fh = IO::File->new("$command |") or die "Couldn't execute '$command': $!\n";
    my $dbs_ref = _parse_mysqlshow_from_fh_into_arrayref($fh);
    $fh->close() or die "$command failed: $!";

    return map { $_ => 1 } @{$dbs_ref};
}

=back

=cut

# ------------------------------------------------------------------------------
# Private Methods

sub auth_args {
  return _auth_args_string();
}

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

sub _get_tables_to_dump {
    my ( $self, $db ) = @_;

    my $tables_ref = $self->_get_tables_in_db($db);

    my $compiled_table_re = qr/$self->{'table-re'}/;

    my @matching_tables = grep { $_ =~ $compiled_table_re } @{$tables_ref};

    return join( ' ', @matching_tables );
}

sub _get_tables_in_db {
    my ( $self, $db ) = @_;

    my $args = $self->{_source}{auth};

    # evil but we don't use DBI because I don't want to implement -p properly
    # not that this works with -p anyway ...
    my $fh = IO::File->new("mysqlshow $args $db|")
      or die "Couldn't execute 'mysqlshow $args $db': $!\n";
    my $tables_ref = _parse_mysqlshow_from_fh_into_arrayref($fh);
    $fh->close() or die "mysqlshow $args $db failed: $!";

    return $tables_ref;
}

# Note that is used as a function call, not a method call.
sub _parse_mysqlshow_from_fh_into_arrayref {
    my ($fh) = @_;

    my @items;
    while (<$fh>) {
        next unless /^\| ([\w-]+)/;
        push @items, $1;
    }

    return \@items;
}

sub _get_defs {
    my ( $self, $db ) = @_;

    my $args   = $self->{_source}{auth};
    my $single_transaction = $self->{'single-transaction'} ? "--single-transaction" : "";
    my $tables = '';                       #dump all tables by default
    if ( my $table_re = $self->{'table-re'} ) {
        $tables = $self->_get_tables_to_dump($db);
        if ( !length $tables ) {           # No tables to dump
            $self->{_defs} = [];
            return;
        }
    }

    my $fh = IO::File->new("mysqldump -d $single_transaction $args $db $tables 2>&1 |")
      or die "Couldn't read ${db}'s table defs via mysqldump: $!\n";

    debug( 3, "running mysqldump -d $single_transaction $args $db $tables" );
    my $defs = $self->{_defs} = [<$fh>];
    $fh->close;
    my $exit_status = $? >> 8;

    if ( grep /mysqldump: Got error: .*: Unknown database/, @$defs ) {
        die <<EOF;
Failed to create temporary database $db
during canonicalization.  Make sure that your mysql.db table has a row
authorizing full access to all databases matching 'test\\_%', and that
the database doesn't already exist.
EOF
    } elsif ($exit_status) {
        # If mysqldump exited with a non-zero status, then
        # we can not reliably make a diff, so better to die and bubble that error up.
        die "mysqldump failed. Exit status: $exit_status:\n" . join( "\n", @{$defs} );
    }
    return;
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
    my $args = [];
    for my $arg (qw/host port user password socket/) {
        push @$args, qq/--$arg=$auth{$arg}/ if $auth{$arg};
    }
    return $args;
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2000-2016 Adam Spiers. All rights reserved. This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<mysqldiff>, L<MySQL::Diff>, L<MySQL::Diff::Table>, L<MySQL::Diff::Utils>

=head1 AUTHOR

Adam Spiers <mysqldiff@adamspiers.org>

=cut
