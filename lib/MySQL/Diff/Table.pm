package MySQL::Diff::Table;

=head1 NAME

MySQL::Diff::Table - Table Definition Class

=head1 SYNOPSIS

  use MySQL::Diff::Table

  my $db = MySQL::Diff::Database->new(%options);
  my $def           = $db->def();
  my $name          = $db->name();
  my $field         = $db->field();
  my $fields        = $db->fields();                # %$fields
  my $primary_key   = $db->primary_key();
  my $indices       = $db->indices();               # %$indices
  my $options       = $db->options();

  my $isfield       = $db->isa_field($field);
  my $isprimary     = $db->isa_primary($field);
  my $isindex       = $db->isa_index($field);
  my $isunique      = $db->is_unique($field);
  my $isfulltext    = $db->is_fulltext($field);

=head1 DESCRIPTION

Parses a table definition into component parts.

=cut

use warnings;
use strict;

our $VERSION = '0.46';

# ------------------------------------------------------------------------------
# Libraries

use Carp qw(:DEFAULT);
use Data::Dumper;
use MySQL::Diff::Utils qw(debug get_save_quotes write_log);

# ------------------------------------------------------------------------------

=head1 METHODS

=head2 Constructor

=over 4

=item new( %options )

Instantiate the objects, providing the command line options for database
access and process requirements.

=cut

sub new {
    my $class = shift;
    my %hash  = @_;
    my $self = {};
    bless $self, ref $class || $class;

    $self->{$_} = $hash{$_} for(keys %hash);

    debug(6,"\nconstructing new MySQL::Diff::Table");
    croak "MySQL::Diff::Table::new called without def params" unless $self->{def};
    $self->_parse;
    return $self;
}

=back

=head2 Public Methods

Fuller documentation will appear here in time :)

=over 4

=item * def

Returns the table definition as a string.

=item * name

Returns the name of the current table.

=item * field

Returns the current field definition of the given field.

=item * fields

Returns an array reference to a list of fields.

=item * primary_key

Returns a hash reference to fields used as primary key fields.

=item * primary_parts

Returns a hash reference to parts of composite primary key

=item * indices

Returns a hash reference to fields used as index fields.

=item * indices_opts

Returns a hash reference to options of index fields

=item * indices_parts

Returns a hash reference to parts of composite index fields

=item * options

Returns the additional options added to the table definition.

=item * isa_field

Returns 1 if given field is used in the current table definition, otherwise 
returns 0.

=item * isa_primary

Returns 1 if given field is defined as a primary key, otherwise returns 0.

=item * isa_index

Returns 1 if given field is used as an index field, otherwise returns 0.

=item * is_unique

Returns 1 if given field is used as unique index field, otherwise returns 0.

=item * is_fulltext

Returns 1 if given field is used as fulltext index field, otherwise returns 0.

=back

=cut

sub def             { my $self = shift; return $self->{def};            }
sub name            { my $self = shift; return $self->{name};           }
sub field           { my $self = shift; return $self->{fields}{$_[0]};  }
sub fields          { my $self = shift; return $self->{fields};         }
sub fields_links    { my $self = shift; return $self->{fields_links}{$_[0]}; }
sub fields_order    { my $self = shift; return $self->{fields_order};   }
sub primary_key     { my $self = shift; return $self->{primary_key};    }
sub primary_parts   { my $self = shift; return $self->{primary};        }
sub indices         { my $self = shift; return $self->{indices};        }
sub indices_opts    { my $self = shift; return $self->{indices_opts};   }
sub indices_parts   { my $self = shift; return $self->{indices_parts}{$_[0]};  }
sub options         { my $self = shift; return $self->{options};        }
sub foreign_key     { my $self = shift; return $self->{foreign_key};    }
sub fk_tables       { my $self = shift; return $self->{fk_tables};      }
sub get_fk_by_col   { my $self = shift; return $self->{fk_by_column}{$_[0]}; }

sub isa_field       { my $self = shift; return $_[0] && $self->{fields}{$_[0]}   ? 1 : 0;       }
sub isa_primary     { my $self = shift; return $_[0] && $self->{primary}{$_[0]}  ? 1 : 0;       }
sub isa_fk          { my $self = shift; return $_[0] && $self->{foreign_key}{$_[0]}  ? 1 : 0;   }
sub isa_index       { my $self = shift; return $_[0] && $self->{indices}{$_[0]}  ? 1 : 0;       }
sub is_unique       { my $self = shift; return $_[0] && $self->{unique}{$_[0]}   ? 1 : 0;       }
sub is_fulltext     { my $self = shift; return $_[0] && $self->{fulltext}{$_[0]} ? 1 : 0;       }

# ------------------------------------------------------------------------------
# Private Methods

sub _parse {
    my $self = shift;
    debug(5,"parsing table def '$self->{def}'");
    my $c = get_save_quotes();
    if (!$c) {
        $self->{def} =~ s/`([^`]+)`/$1/gs; # later versions quote names
    }
    $self->{def} =~ s/\n+/\n/;
    $self->{lines} = [ grep ! /^\s*$/, split /(?=^)/m, $self->{def} ];
    my @lines = @{$self->{lines}};
    my $name;
    if ($lines[0] =~ /^\s*create\s+table\s+(\S+)\s+\(\s*$/i) {
        $self->{name} = $1;
        debug(4,"got table name '$self->{name}'");
        shift @lines;
    } else {
        write_log('tables_log', $lines[0], 1);
        croak "couldn't figure out table name ".$lines[0];
    }
    my $end_found = 0;
    my $table_end = '';
    my $prev_field = '';
    $self->{fields_links} = {};
    my $fields_order;
    my $start_order = 0;
    my $line_copy = '';
    my $prev_line = '';
    my $fk_line = 0;
    while (@lines) {
        # save full copy of line as previous line
        $prev_line = $line_copy unless $fk_line;
        $_ = shift @lines;
        $line_copy = $_;
        if (!$end_found) {
            s/^\s*(.*?),?\s*$/$1/; # trim whitespace and trailing commas 
        } else {
            s/^\s*(.*?)\s*$/$1/; # trim whitespaces 
        }
        debug(5,"line: [$_]");
        if (/^PRIMARY\s+KEY\s+(.+)$/) {
            my $primary = $1;
            croak "two primary keys in table '$self->{name}': '$primary', '$self->{primary_key}'\n"
                if $self->{primary_key};
            debug(4,"got primary key $primary");
            $self->{primary_key} = $primary;
            $primary =~ s/\((.*?)\)/$1/;
            $self->{primary}{$_} = 1    for(split(/,/, $primary));
            
            next;
        }
        
        if (/^(?:CONSTRAINT\s+(.*)?)?\s+FOREIGN\s+KEY\s+(.*)\s+REFERENCES\s+(.*?)\s+(.*)$/) {
            my ($key, $column_name, $tbl_name, $opts) = ($1, $2, $3, $4);
            croak "foreign key '$key' duplicated in table '$name'\n"
                if $self->{foreign_key}{$key};
            debug(4,"got foreign key $key with column name: $column_name, table name: $tbl_name, options: $opts");
            my $val = $column_name.' REFERENCES '.$tbl_name.' '.$opts;
            $self->{foreign_key}{$key} = $val;
            $column_name =~ s/\((.*?)\)/$1/;
            $self->{fk_by_column}{$_}{$key} = $val for(split(/,/, $column_name));
            $self->{fk_tables}{$tbl_name} = 1;
            $fk_line = 1;
            my $q_line_copy = quotemeta($line_copy);
            $self->{def} =~ s/$q_line_copy//gs;
            next;
        }

        # Also can be /^(KEY|UNIQUE(?: KEY)?)\s+(\S+?)(?:\s+USING\s+(?:BTREE|HASH|RTREE))?\s*\((.*)\)$/
        # and /^(KEY|UNIQUE(?: KEY)?)\s+(\S+?)\s+\((.*)\)(\s+USING\s+(?:BTREE|HASH|RTREE))?(.*)$/
        if (/^(KEY|UNIQUE(?: KEY)?)\s+(\S+?)\s+\((.*)\)(.*)$/) {
            my ($type, $key, $val, $opts) = ($1, $2, $3, $4);
            croak "index '$key' duplicated in table '$name'\n"
                if $self->{indices}{$key};
            $self->{indices}{$key} = $val;
            if ($opts) {
                $self->{indices_opts}{$key} = $opts;
            }
            $self->{unique}{$key} = 1   if($type =~ /unique/i);
            $self->{indices_parts}{$key}{$_} = 1 for(split(/,/, $val));
            debug(4, "got ", defined $self->{unique}{$key} ? 'unique ' : '', "index key '$key': ($val)");
            next;
        }

        if (/^(FULLTEXT(?:\s+KEY|INDEX)?)\s+(\S+?)\s*\((.*)\)$/) {
            my ($type, $key, $val) = ($1, $2, $3);
            croak "FULLTEXT index '$key' duplicated in table '$name'\n"
                if $self->{fulltext}{$key};
            $self->{indices}{$key} = $val;
            $self->{fulltext}{$key} = 1;
            debug(4,"got FULLTEXT index '$key': ($val)");
            next;
        }

        if (/^\)\s*(.*?)$/) { # end of table definition
            $end_found = 1;
            my $opt = $1;
            # strip AUTO_INCREMENT option from table definition and from options variable content
            my $opt_stripped = $opt;
            $opt_stripped =~ s/ AUTO_INCREMENT=(.*?) / /gs;
            $opt = quotemeta($opt);
            $self->{def} =~ s/$opt/$opt_stripped/gs;
            # quote previous line
            my $q_prev_line = quotemeta($prev_line);
            # strip orphan commas from previous line
            $prev_line =~ s/^(.*?),?$/$1/;
            $self->{def} =~ s/$q_prev_line/$prev_line/gs;
            $opt = $opt_stripped;
            $table_end .= $opt;
            debug(4,"got table options '$opt'");
            next;
        }

        if (/^(\S+)\s*(.*)/) {
            my ($field, $fdef) = ($1, $2);
            if (!$end_found) {
                $self->{fields}{$field} = $fdef;
                debug(4,"got field def '$field': $fdef");   
                if ($prev_field) {
                    $self->{fields_links}{$field}{'prev_field'} = $prev_field;
                    $self->{fields_links}{$prev_field}{'next_field'} = $field;
                }
                $prev_field = $field;
                # save properly fields order, because hash not store it
                $self->{fields_order}{$field} = ++$start_order;
            } else {
                $table_end .= " $field $fdef";
            }
            next;
        }

        write_log('tables_log', $_, 1);
        croak "unparsable line in definition for table '$self->{name}':\n$_";
    }

    debug(6, "Table's fields links: ".Dumper($self->{fields_links}));

    if ($table_end =~ /^\s*(.*?);$/s) {
        $self->{options} = $table_end;
        $self->{options} =~ s/;//gs;
    } else {
        warn "table '$self->{name}' didn't have terminator: \n", $self->{def} 
            unless defined $self->{options};
    }

    @lines = grep ! m{^/\*!40\d{3} .*? \*/;}, @lines;
    @lines = grep ! m{^(SET |DROP TABLE)}, @lines;

    warn "table '$self->{name}' had trailing garbage:\n", join '', @lines
        if @lines;
        
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2000-2011 Adam Spiers. All rights reserved. This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<mysqldiff>, L<MySQL::Diff>, L<MySQL::Diff::Database>, L<MySQL::Diff::Utils>

=head1 AUTHOR

Adam Spiers <mysqldiff@adamspiers.org>

=cut
