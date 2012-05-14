package MySQL::Diff;

=head1 NAME

MySQL::Diff - Generates a database upgrade instruction set

=head1 SYNOPSIS

  use MySQL::Diff;

  my $md = MySQL::Diff->new( %options );
  my $db1 = $md->register_db($ARGV[0], 1);
  my $db2 = $md->register_db($ARGV[1], 2);
  my $diffs = $md->diff();

=head1 DESCRIPTION

Generates the SQL instructions required to upgrade the first database to match
the second.

=cut

use warnings;
use strict;

our $VERSION = '0.45';

# ------------------------------------------------------------------------------
# Libraries

use MySQL::Diff::Database;
use MySQL::Diff::Utils qw(debug debug_level debug_file set_save_quotes);

use Data::Dumper;

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
    my %hash  = @_;
    my $self = {};
    bless $self, ref $class || $class;

    $self->{opts} = \%hash;
    
    if($hash{debug})        { debug_level($hash{debug})     ; delete $hash{debug};      }
    if($hash{debug_file})   { debug_file($hash{debug_file}) ; delete $hash{debug_file}; }
    
    if ($hash{'save-quotes'}) {
        set_save_quotes($hash{'save-quotes'});
    }

    debug(1,"\nconstructing new MySQL::Diff");

    return $self;
}

=head2 Public Methods

Fuller documentation will appear here in time :)

=over 4

=item * register_db($name,$inx)

Reference the database, and setup a connection. The name can be an already
existing 'MySQL::Diff::Database' database object. The index can be '1' or '2',
and refers both to the order of the diff, and to the host, port, username and
password arguments that have been supplied.

=cut

sub register_db {
    my ($self, $name, $inx) = @_;
    debug(1, "Register database $name as # $inx");
    return unless $inx == 1 || $inx == 2;

    my $db = ref $name eq 'MySQL::Diff::Database' ? $name : $self->_load_database($name,$inx);
    $self->{databases}[$inx-1] = $db;
    return $db;
}

=item * db1()

=item * db2()

Return the first and second databases registered via C<register_db()>.

=cut

sub db1 { shift->{databases}->[0] }
sub db2 { shift->{databases}->[1] }

=item * diff()

Performs the diff, returning a string containing the commands needed to change
the schema of the first database into that of the second.

=back

=cut

sub diff {
    my $self = shift;
    my $table_re = $self->{opts}{'table-re'};
    my @changes;

    debug(1, "\ncomparing databases");

    for my $table1 ($self->db1->tables()) {
        my $name = $table1->name();
        debug(1, "looking at table '$name' in first database");
        debug(6, "table 1 $name = ".Dumper($table1));
        if ($table_re && $name !~ $table_re) {
            debug(2,"table '$name' didn't match /$table_re/; ignoring");
            next;
        }
        if (!$self->{opts}{'refs'}) {
            $self->{'used_tables'}{$name} = 1;       
            if (my $table2 = $self->db2->table_by_name($name)) {
                debug(1,"comparing tables called '$name'");
                push @changes, $self->_diff_tables($table1, $table2);
            } else {
                debug(1,"table '$name' dropped");
                my $change = '';
                $change = "-- $name\n" unless !$self->{opts}{'list-tables'};
                $change .= "DROP TABLE $name;\n\n";
                push @changes, [$change, {'k' => 5}]                 
                    unless $self->{opts}{'only-both'} || $self->{opts}{'keep-old-tables'}; # drop table after all
            }
        } else {
                if (!$self->{'used_tables'}{$name}) {
                    $self->{'used_tables'}{$name} = 1;
                    my $additional_tables = '';
                    my $additional_fk_tables = $table1->fk_tables();
                    if ($additional_fk_tables) {
                        $additional_tables = "|" . join "|", keys %$additional_fk_tables;
                        push @changes, $self->_add_ref_tables($additional_fk_tables);
                    }
                    my $change = '';
                    $change = "$name$additional_tables\n";
                    push @changes, [$change, {'k' => 1}];
                }
        }
    }

    for my $view1 ($self->db1->views()) {
        my $name = $view1->name();
        $self->{'used_tables'}{$name} = 1;
        debug(1, "looking at view '$name' in first database");
        if (my $view2 = $self->db2->view_by_name($name)) {
            debug(1, "Comparing views called '$name'");
            my $f1 = $view1->fields();
            my $f2 = $view2->fields();
            my $sel1 = $view1->select();
            my $sel2 = $view2->select();
            my $opts1 = $view1->options();
            my $opts2 = $view2->options();
            if ( ($f1 ne $f2) || 
                 ($sel1 ne $sel2) || 
                 ($opts1->{'security'} ne $opts2->{'security'}) || 
                 ($opts1->{'trail'} ne $opts2->{'trail'}) || 
                 ($opts1->{'algorithm'} ne $opts2->{'algorithm'})
               ) {
                my $change = '';
                $change = "-- $name\n" unless !$self->{opts}{'list-tables'};
                $change .= "ALTER ALGORITHM=$opts2->{'algorithm'} DEFINER=CURRENT_USER SQL SECURITY $opts2->{'security'} VIEW $name $f2 AS ($sel2) $opts2->{'trail'}";
                push @changes, [$change, {'k' => 5}]                 
                    unless $self->{opts}{'only-both'} || $self->{opts}{'keep-old-tables'}; 
            }
        } else {
            debug(1, "view '$name' dropped");
            my $change = '';
            $change = "-- $name\n" unless !$self->{opts}{'list-tables'};
            $change .= "DROP VIEW $name;\n\n";
            push @changes, [$change, {'k' => 5}]                 
                 unless $self->{opts}{'only-both'} || $self->{opts}{'keep-old-tables'}; 
        }
    }

    if (!$self->{opts}{'refs'}) {
        for my $table2 ($self->db2->tables()) {
            my $name = $table2->name();
            debug(1, "looking at table '$name' in second database");
            debug(6, "table 2 $name = ".Dumper($table2));
            if ($table_re && $name !~ $table_re) {
                debug(2,"table '$name' matched $self->{opts}{'table-re'}; ignoring");
                next;
            }
            if (! $self->db1->table_by_name($name) && ! $self->{'used_tables'}{$name}) {
                $self->{'used_tables'}{$name} = 1;
                debug(1, "table '$name' added to diff");
                debug(2, "definition of '$name': ".$table2->def());
                my $additional_tables = '';
                my $additional_fk_tables = $table2->fk_tables();
                if ($additional_fk_tables) {
                    $additional_tables = "|" . join "|", keys %$additional_fk_tables;
                    push @changes, $self->_add_ref_tables($additional_fk_tables);
                }
                my $change = '';
                $change = "-- $name$additional_tables\n" unless !$self->{opts}{'list-tables'};
                $change .= $table2->def() . "\n";
                push @changes, [$change, {'k' => 5}]
                    unless $self->{opts}{'only-both'};
            }
        }
        for my $view2 ($self->db2->views()) {
            my $name = $view2->name();
            debug(1, "looking at view '$name' in second database");
            if (!$self->db1->view_by_name($name) && ! $self->{'used_tables'}{$name}) {
                $self->{'used_tables'}{$name} = 1;
                my $change = '';
                $change = "-- $name\n" unless !$self->{opts}{'list-tables'};
                $change .= $view2->def() . "\n";
                push @changes, [$change, {'k' => 5}]
                    unless $self->{opts}{'only-both'};
            }
        }
    }

    debug(4, Dumper(@changes));

    my $out = '';
    if (@changes) {
        if (!$self->{opts}{'list-tables'} && !$self->{opts}{'refs'} && !$self->{opts}{'quiet'}) {
            $out .= $self->_diff_banner();
        }
        my @sorted = sort { return $b->[1]->{'k'} cmp $a->[1]->{'k'} } @changes;
        my $column_index = 0;
        my $line = join '', map $_->[$column_index], @sorted;
        $out .= $line;
    }
    return $out;
}

# ------------------------------------------------------------------------------
# Private Methods

sub _add_ref_tables {
    my ($self, $tables) = @_;
    my @changes = ();
    for my $name (keys %$tables) {
        if (!$self->{'used_tables'}{$name}) {
            $self->{'used_tables'}{$name} = 1;
            my $table;
            if (!$self->{opts}{'refs'}) {
                $table = $self->db2->table_by_name($name);
            } else {
                $table = $self->db1->table_by_name($name);
            }
            debug(2, "Related table: '$name'");
            if ($table) {
                my $additional_tables = '';
                my $additional_fk_tables = $table->fk_tables();
                if ($additional_fk_tables) {
                        $additional_tables = "|" . join "|", keys %$additional_fk_tables;
                        push @changes, $self->_add_ref_tables($additional_fk_tables);
                }
                my $change = '';
                if (!$self->{opts}{'refs'}) {
                    $change = "-- $name$additional_tables\n" unless !$self->{opts}{'list-tables'};
                    $change .= $table->def()."\n";
                } else {
                    $change = "$name$additional_tables\n";
                }
                push @changes, [$change, {'k' => 2}];
            }
        }
    }
    return @changes;
}


sub _diff_banner {
    my ($self) = @_;

    my $summary1 = $self->db1->summary();
    my $summary2 = $self->db2->summary();

    my $opt_text =
        join ', ',
            map { $self->{opts}{$_} eq '1' ? $_ : "$_=$self->{opts}{$_}" }
                keys %{$self->{opts}};
    $opt_text = "## Options: $opt_text\n" if $opt_text;

    my $now = scalar localtime();
    return <<EOF;
## mysqldiff $VERSION
## 
## Run on $now
$opt_text##
## --- $summary1
## +++ $summary2

EOF
}

sub _diff_tables {
    my $self = shift;
    my @changes = $self->_diff_fields(@_);
    push @changes, $self->_diff_indices(@_);
    push @changes, $self->_diff_primary_key(@_);
    push @changes, $self->_diff_foreign_key(@_);
    push @changes, $self->_diff_options(@_);    

    $changes[-1][0] =~ s/\n*$/\n/  if (@changes);
    return @changes;
}

sub _diff_fields {
    my ($self, $table1, $table2) = @_;

    my $name1 = $table1->name();

    my $fields1 = $table1->fields;
    my $fields2 = $table2->fields;

    return () unless $fields1 || $fields2;

    my @changes;
  
    if($fields1) {
        for my $field (keys %$fields1) {
            debug(3,"table1 had field '$field'");
            my $f1 = $fields1->{$field};
            my $f2 = $fields2->{$field};
            if ($fields2 && $f2) {
                if ($self->{opts}{tolerant}) {
                    for ($f1, $f2) {
                        s/ COLLATE [\w_]+//gi;
                    }
                }
                if ($f1 ne $f2) {
                    if (not $self->{opts}{tolerant} or 
                        (($f1 !~ m/$f2\(\d+,\d+\)/) and
                         ($f1 ne "$f2 DEFAULT '' NOT NULL") and
                         ($f1 ne "$f2 NOT NULL") ))
                    {
                        debug(3,"field '$field' changed");
                        my $change = '';
                        $change =  "-- $name1\n" unless !$self->{opts}{'list-tables'};
                        $change .= "ALTER TABLE $name1 CHANGE COLUMN $field $field $f2;";
                        $change .= " # was $f1" unless $self->{opts}{'no-old-defs'};
                        $change .= "\n";
                        my $weight = 5;
                        if ($f2 =~ /(CURRENT_TIMESTAMP(?:\(\))?|NOW\(\)|LOCALTIME(?:\(\))?|LOCALTIMESTAMP(?:\(\))?)/) {
                                $weight = 1;
                        }
                        push @changes, [$change, {'k' => $weight}]; # column must be changed/added first
                    }
                }
            } else {
                debug(3,"field '$field' removed");
                my $change = '';
                $change = "-- $name1\n" unless !$self->{opts}{'list-tables'};
                $change .= "ALTER TABLE $name1 DROP COLUMN $field;";
                $change .= " # was $fields1->{$field}" unless $self->{opts}{'no-old-defs'};
                $change .= "\n";
                push @changes, [$change, {'k' => 1}]; # column must be dropped last
            }
        }
    }

    if($fields2) {
        for my $field (keys %$fields2) {
            unless($fields1 && $fields1->{$field}) {
                debug(3,"field '$field' added");
                my $change = '';
                $change = "-- $name1\n" unless !$self->{opts}{'list-tables'};
                $change .= "ALTER TABLE $name1 ADD COLUMN $field $fields2->{$field};\n";
                my $weight = 5;
                if ($fields2->{$field} =~ /(CURRENT_TIMESTAMP(?:\(\))?|NOW\(\)|LOCALTIME(?:\(\))?|LOCALTIMESTAMP(?:\(\))?)/) {
                        $weight = 1;
                }
                push @changes, [$change, {'k' => $weight}];
            }
        }
    }

    return @changes;
}

sub _diff_indices {
    my ($self, $table1, $table2) = @_;
    my $name1 = $table1->name();

    my $indices1 = $table1->indices();
    my $opts1 = $table1->indices_opts();
    my $indices2 = $table2->indices();
    my $opts2 = $table2->indices_opts();

    return () unless $indices1 || $indices2;

    my @changes;

    if($indices1) {
        for my $index (keys %$indices1) {
            my $ind1_opts = '';
            my $ind2_opts = '';
            if ($opts1 && $opts1->{$index}) {
                $ind1_opts = $opts1->{$index};
            }
            if ($opts2 && $opts2->{$index}) {
                $ind2_opts = $opts2->{$index};
            }
            debug(1,"$name1 had index '$index' with opts: $ind1_opts");
            my $old_type = $table1->is_unique($index) ? 'UNIQUE' : 
                           $table1->is_fulltext($index) ? 'FULLTEXT INDEX' : 'INDEX';

            if ($indices2 && $indices2->{$index}) {
                if( ($indices1->{$index} ne $indices2->{$index}) or
                    ($table1->is_unique($index) xor $table2->is_unique($index)) or
                    ($table1->is_fulltext($index) xor $table2->is_fulltext($index))  or
                    ($ind1_opts ne $ind2_opts)
                  )
                {
                    debug(1,"index '$index' changed");
                    my $new_type = $table2->is_unique($index) ? 'UNIQUE' : 
                                   $table2->is_fulltext($index) ? 'FULLTEXT INDEX' : 'INDEX';
                    my $changes = '';
                    $changes = "-- $name1\n" unless !$self->{opts}{'list-tables'};
                    $changes .= "ALTER TABLE $name1 DROP INDEX $index;";
                    $changes .= " # was $old_type ($indices1->{$index})$ind1_opts"
                        unless $self->{opts}{'no-old-defs'};
                    $changes .= "\nALTER TABLE $name1 ADD $new_type $index ($indices2->{$index})$ind2_opts;\n";
                    push @changes, [$changes, {'k' => 3}]; # index must be added/changed after column add/change
                }
            } else {
                my $auto = _check_for_auto_col($table2, $indices1->{$index}, 1) || '';
                my $changes = '';
                $changes = "-- $name1\n" unless !$self->{opts}{'list-tables'};
                $changes .= $auto ? _index_auto_col($table1, $indices1->{$index}, $self->{opts}{'no-old-defs'}) : '';
                $changes .= "ALTER TABLE $name1 DROP INDEX $index;";
                $changes .= " # was $old_type ($indices1->{$index})$ind1_opts" 
                    unless $self->{opts}{'no-old-defs'};
                $changes .= "\n";
                push @changes, [$changes, {'k' => 3}]; # index must be dropped before column drop
            }
        }
    }

    if($indices2) {
        for my $index (keys %$indices2) {
            next    if($indices1 && $indices1->{$index});
            debug(1,"index '$index' added");
            my $new_type = $table2->is_unique($index) ? 'UNIQUE' : 'INDEX';
            my $opts = '';
            if ($opts2->{$index}) {
                $opts = $opts2->{$index};
            }
            my $changes = '';
            $changes = "-- $name1\n" unless !$self->{opts}{'list-tables'};
            $changes .= "ALTER TABLE $name1 ADD $new_type $index ($indices2->{$index})$opts;\n";
            push @changes, [$changes, {'k' => 3}];
        }
    }

    return @changes;
}

sub _diff_primary_key {
    my ($self, $table1, $table2) = @_;

    my $name1 = $table1->name();

    my $primary1 = $table1->primary_key();
    my $primary2 = $table2->primary_key();

    return () unless $primary1 || $primary2;

    my @changes;
  
    if ($primary1 && ! $primary2) {
        debug(3,"primary key '$primary1' dropped");
        my $changes = '';
        $changes .= "-- $name1\n" unless !$self->{opts}{'list-tables'};
        $changes = _index_auto_col($table2, $primary1, $self->{opts}{'no-old-defs'});
        $changes .= "ALTER TABLE $name1 DROP PRIMARY KEY;";
        $changes .= " # was $primary1" unless $self->{opts}{'no-old-defs'};
        return ["$changes\n", {'k' => 4}]; # DROP PK FIRST
    }

    if (! $primary1 && $primary2) {
        debug(3,"primary key '$primary2' added");
        my $changes = '';
        $changes .= "-- $name1\n" unless !$self->{opts}{'list-tables'};
        $changes .= "ALTER TABLE $name1 ADD PRIMARY KEY $primary2;\n";
        return ["$changes\n", {'k' => 3}]; # ADD/CHANGE PK AFTER COLUMN ADD
    }

    if ($primary1 ne $primary2) {
        debug(3,"primary key changed");
        my $auto = _check_for_auto_col($table2, $primary1) || '';
        my $changes = '';
        $changes = "-- $name1\n" unless !$self->{opts}{'list-tables'};
        $changes .= $auto ? _index_auto_col($table2, $auto, $self->{opts}{'no-old-defs'}) : '';
        $changes .= "ALTER TABLE $name1 DROP PRIMARY KEY;";
        $changes .= " # was $primary1" unless $self->{opts}{'no-old-defs'};
        $changes .= "\nALTER TABLE $name1 ADD PRIMARY KEY $primary2;\n";
        $changes .= "ALTER TABLE $name1 DROP INDEX $auto;\n"    if($auto);
        push @changes, [$changes, {'k' => 3}];
    }

    return @changes;
}

sub _diff_foreign_key {
    my ($self, $table1, $table2) = @_;

    my $name1 = $table1->name();

    my $fks1 = $table1->foreign_key();
    my $fks2 = $table2->foreign_key();

    return () unless $fks1 || $fks2;

    my @changes;
  
    if($fks1) {
        for my $fk (keys %$fks1) {
            debug(1,"$name1 has fk '$fk'");

            if ($fks2 && $fks2->{$fk}) {
                if($fks1->{$fk} ne $fks2->{$fk})  
                {
                    debug(1,"foreign key '$fk' changed");
                    my $additional_tables = '';
                    my $additional_fk_tables = $table2->fk_tables();
                    if ($additional_fk_tables) {
                        $additional_tables = "|" . join "|", keys %$additional_fk_tables;
                    }   
                    my $changes = '';
                    $changes = "-- $name1$additional_tables\n" unless !$self->{opts}{'list-tables'};
                    $changes .= "ALTER TABLE $name1 DROP FOREIGN KEY $fk;";
                    $changes .= " # was CONSTRAINT $fk $fks1->{$fk}"
                        unless $self->{opts}{'no-old-defs'};
                    $changes .= "\n";
                    push @changes, [$changes, {'k' => 5}]; # DROP FK FIRST
                    $changes = "ALTER TABLE $name1 ADD CONSTRAINT $fk FOREIGN KEY $fks2->{$fk};\n";
                    push @changes, [$changes, {'k' => 1}]; # ADD FK LAST
                }
            } else {
                debug(1,"foreign key '$fk' removed");
                my $changes = '';
                $changes = "-- $name1\n" unless !$self->{opts}{'list-tables'};
                $changes .= "ALTER TABLE $name1 DROP FOREIGN KEY $fk;";
                $changes .= " # was CONSTRAINT $fk $fks1->{$fk}"
                        unless $self->{opts}{'no-old-defs'};
                $changes .= "\n";
                push @changes, [$changes, {'k' => 5}]; # DROP FK FIRST
            }
        }
    }

    if($fks2) {
        for my $fk (keys %$fks2) {
            next    if($fks1 && $fks1->{$fk});
            debug(1, "foreign key '$fk' added");
            my $additional_tables = '';
            my $additional_fk_tables = $table2->fk_tables();
            if ($additional_fk_tables) {
                $additional_tables = "|" . join "|", keys %$additional_fk_tables;
            }
            my $change = '';
            $change = "-- $name1$additional_tables\n" unless !$self->{opts}{'list-tables'};
            $change .= "ALTER TABLE $name1 ADD CONSTRAINT $fk FOREIGN KEY $fks2->{$fk};\n";
            push @changes, [$change, {'k' => 1}];
        }
    }

    return @changes;
}

# If we're about to drop a composite (multi-column) index, we need to
# check whether any of the columns in the composite index are
# auto_increment; if so, we have to add an index for that
# auto_increment column *before* dropping the composite index, since
# auto_increment columns must always be indexed.
sub _check_for_auto_col {       
    my ($table, $fields, $primary) = @_;

    $fields =~ s/^\s*\((.*)\)\s*$/$1/g; # strip brackets if any
    my @fields = split /\s*,\s*/, $fields;
    
    for my $field (@fields) {
        next if (!$table->field($field));
        next if($table->field($field) !~ /auto_increment/i);
        next if($table->isa_index($field));
        next if($primary && $table->isa_primary($field));

        return $field;
    }

    return;
}

sub _index_auto_col {
    my ($table, $field, $comment) = @_;
    if (!($field =~ /\(.*?\)/)) {
        $field = '(' . $field . ')';
    }
    my $name = $table->name;
    my $changes = "ALTER TABLE $name ADD INDEX $field;";
    $changes .= " # auto columns must always be indexed"
                        unless $comment;
    return $changes. "\n";
}

sub _diff_options {
    my ($self, $table1, $table2) = @_;

    my $name     = $table1->name();
    my $options1 = $table1->options();
    my $options2 = $table2->options();

    return () unless $options1 || $options2;

    my @changes;

    if ($self->{opts}{tolerant}) {
      for ($options1, $options2) {
        s/ AUTO_INCREMENT=\d+//gi;
        s/ COLLATE=[\w_]+//gi;
      }
    }

    if ($options1 ne $options2) {
        my $change = '';
        $change = "-- $name\n" unless !$self->{opts}{'list-tables'};
        $change .= "ALTER TABLE $name $options2;";
        $change .= " # was " . ($options1 || 'blank') unless $self->{opts}{'no-old-defs'};
        $change .= "\n";
        push @changes, [$change, {'k' => 0}]; # the lastest
    }

    return @changes;
}

sub _load_database {
    my ($self, $arg, $authnum) = @_;

    debug(1, "Load database: parsing arg $authnum: '$arg'\n");

    my $table_list = $self->{opts}{'tables'} || "";
    my %auth;
    for my $auth (qw/dbh host port user password socket/) {
        $auth{$auth} = $self->{opts}{"$auth$authnum"} || $self->{opts}{$auth};
        delete $auth{$auth} unless $auth{$auth};
    }

    if ($arg =~ /^db:(.*)/) {
        return MySQL::Diff::Database->new(db => $1, table_list => $table_list, auth => \%auth);
    }

    if ($self->{opts}{"dbh"}              ||
        $self->{opts}{"host$authnum"}     ||
        $self->{opts}{"port$authnum"}     ||
        $self->{opts}{"user$authnum"}     ||
        $self->{opts}{"password$authnum"} ||
        $self->{opts}{"socket$authnum"}) {
        return MySQL::Diff::Database->new(db => $arg, table_list => $table_list, auth => \%auth);
    }

    if (-f $arg) {
        return MySQL::Diff::Database->new(file => $arg, table_list => $table_list, auth => \%auth);
    }

    my %dbs = MySQL::Diff::Database::available_dbs(%auth);
    debug(1, "  available databases: ", (join ', ', keys %dbs), "\n");

    if ($dbs{$arg}) {
        return MySQL::Diff::Database->new(db => $arg, table_list => $table_list, auth => \%auth);
    }

    warn "'$arg' is not a valid file or database.\n";
    return;
}

sub _debug_level {
    my ($self,$level) = @_;
    debug_level($level);
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2000-2011 Adam Spiers. All rights reserved. This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<mysqldiff>, L<MySQL::Diff::Database>, L<MySQL::Diff::Table>, L<MySQL::Diff::Utils>

=head1 AUTHOR

Adam Spiers <mysqldiff@adamspiers.org>

=cut
