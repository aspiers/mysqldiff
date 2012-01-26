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

our $VERSION = '0.45';

# ------------------------------------------------------------------------------
# Libraries

use Carp qw(:DEFAULT);
use File::Slurp;
use IO::File;

use MySQL::Diff::Utils qw(debug get_save_quotes);
use MySQL::Diff::Table;
use MySQL::Diff::View;

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

    debug(1,"\nconstructing new MySQL::Diff::Database");

    my $string = _auth_args_string(%{$p{auth}});
    debug(1,"auth args: $string");
    $self->{_source}{auth} = $string;
    $self->{_source}{dbh} = $p{dbh} if($p{dbh});

	my $tl = $p{table_list} // "";
    if ($p{file}) {
        debug(1, "Started to canonicalise file ".$p{file});
        $self->_canonicalise_file($p{file},$tl);
    } elsif ($p{db}) {
        debug(1, "Started to read db ".$p{db});
        $self->_read_db($p{db},$tl);
    } else {
        confess "MySQL::Diff::Database::new called without db or file params";
    }

    debug(1, "Started to parse defs");
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

=item * views()

Returns a list of views for the current database

=cut
sub views {
    my $self = shift;
    return @{$self->{_views}};
}

=item * table_by_name( $name )

Returns the table definition (see L<MySQL::Diff::Table>) for the given table.

=cut

sub table_by_name {
    my ($self,$name) = @_;
    return $self->{_by_name}{$name};
}

=item * view_by_name( $name )

Returns the view definitions (see L<MySQL::Diff:View>) for the given view

=cut

sub view_by_name {
    my ($self,$name) = @_;
    return $self->{v_by_name}{$name};
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
    debug(1, "Started to get available databases list");
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

=back

=cut

# ------------------------------------------------------------------------------
# Private Methods

sub _canonicalise_file {
    my ($self, $file, $table_list) = @_;

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
    my $sql = "\nCREATE DATABASE \`$temp_db\`;\nUSE \`$temp_db\`;\nSET foreign_key_checks = 0;\n$defs";
    print $fh $sql;
    my $result = $fh->close;

    # ... and then retrieve defs from mysqldump.  Hence we've used
    # MySQL to massage the defs file into canonical form.
    $self->_get_defs($temp_db, $table_list);

    debug(3,"dropping temporary database $temp_db");
    $fh = IO::File->new("| mysql $args") or die "Couldn't execute 'mysql$args': $!\n";
    print $fh "DROP DATABASE \`$temp_db\`;\n";
    $fh->close;

	die "Couldn't execute mysql command:[$args] '$sql'\n" unless ($result);
}

sub _read_db {
    my ($self, $db, $table_list) = @_;
    $self->{_source}{db} = $db;
    debug(1, "fetching ". (($table_list) ? $table_list : "all") . " table defs from db $db");
    $self->_get_defs($db, $table_list);
}

sub _get_defs {
    my ($self, $db, $table_list) = @_;

	$table_list =~ s/,/ /g;

    my $args = $self->{_source}{auth};
    my $start_time = time();
    my $fh = IO::File->new("mysqldump -d -q --single-transaction $args $db $table_list 2>&1 |")
        or die "Couldn't read ${db}'s table defs via mysqldump: $!\n";
    debug(2, "running mysqldump -d $args $db");
    my $defs = $self->{_defs} = [ <$fh> ];
    $fh->close;
    debug(1, "dump time: ".(time() - $start_time));
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
    my $defs = join '', @{$self->{_defs}};
    my $c = get_save_quotes();
    if (!$c) {
        $defs =~ s/`//sg;
    }
    #warn "DEF1:\n", $defs;
    $defs =~ s/(\#|--).*?\n//g; # delete singleline comments
    $defs =~ s/.*?SET\s+.*?;\s*//ig; #delete SETs
    $defs =~ s/\/\*[^\/\*]*?\!\d+\s+([^\/\*]*?)\*\/\s*/\n$1/gs; # get content from executable comments
    $defs =~ s/\/\*[^\/\*]*?\*\/\s*//gs; #delete all multiline comments
    $defs =~ s/DELIMITER\s+.*?\s//ig;
    #warn "DEF2:\n", $defs;
    my @tables = split /(?=^\s*(?:create|alter|drop)\s+(?:table|.*?view)\s+)/ims, $defs;
    $self->{_tables} = [];
    $self->{_views} = [];
    for my $table (@tables) {
        debug(1, "  table def [$table]");
		next unless $table;
        if($table =~ /create\s+table/i) {
            my $obj = MySQL::Diff::Table->new(source => $self->{_source}, def => $table);
            $self->{_by_name}{$obj->name()} = $obj;
        } 
        elsif ($table =~ /create\s+.*?\s+view/is) {
            my $obj = MySQL::Diff::View->new(source => $self->{_source}, def => $table);
            $self->{v_by_name}{$obj->name()} = $obj;
            if ($self->{_by_name}{$obj->name()}) {
                delete($self->{_by_name}{$obj->name()});
            }
        } 
    }
    for my $t (keys %{$self->{_by_name}}) {
        push @{$self->{_tables}}, $self->{_by_name}{$t};
    }
    for my $v (keys %{$self->{v_by_name}}) {
        push @{$self->{_views}}, $self->{v_by_name}{$v};
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

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2000-2011 Adam Spiers. All rights reserved. This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<mysqldiff>, L<MySQL::Diff>, L<MySQL::Diff::Table>, L<MySQL::Diff::Utils>

=head1 AUTHOR

Adam Spiers <mysqldiff@adamspiers.org>

=cut
