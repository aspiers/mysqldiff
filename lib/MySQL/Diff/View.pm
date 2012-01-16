package MySQL::Diff::View;

=head1 NAME

MySQL::Diff::View - View Definition Class

=head1 SYNOPSIS

  use MySQL::Diff::View

  my $db = MySQL::View::Database->new(%options);
  my $def           = $db->def();
  my $name          = $db->name();
  my $field         = $db->field();
  my $fields        = $db->fields();                # %$fields
  my $options       = $db->options();

  my $isfield       = $db->isa_field($field);

=head1 DESCRIPTION

Parses a view definition into component parts.

=cut

use warnings;
use strict;

our $VERSION = '0.46';

# ------------------------------------------------------------------------------
# Libraries

use Carp qw(:DEFAULT);
use MySQL::Diff::Utils qw(debug get_save_quotes);

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

    debug(6,"\nconstructing new MySQL::Diff::View");
    croak "MySQL::Diff::View::new called without def params" unless $self->{def};
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

=item * fields

Returns an array reference to a list of fields.

=item * options

Returns the additional options added to the table definition.

=item * select

Returns select in AS clause

=back

=cut

sub def             { my $self = shift; return $self->{def};            }
sub name            { my $self = shift; return $self->{name};           }
sub fields          { my $self = shift; return $self->{fields};         }
sub options         { my $self = shift; return $self->{options};        }
sub select          { my $self = shift; return $self->{select};         }


# ------------------------------------------------------------------------------
# Private Methods

sub _parse {
    my $self = shift;
    debug(5,"parsing view def '$self->{def}'");
    my $c = get_save_quotes();
    if (!$c) {
        $self->{def} =~ s/`([^`]+)`/$1/gs; # later versions quote names
    }
    $self->{def} =~ s/\n+/\n/gs;
    s/^\s*(.*?),?\s*$/$1/; # trim whitespace and trailing commas
    if ($self->{def} =~ /^CREATE(?:\s+ALGORITHM=(.*?))?(?:\s+DEFINER=(.*?))?(?:\s+SQL\s+SECURITY\s+(DEFINER|INVOKER))?\s+VIEW\s+(.*?)\s+(\(.*?\)\s+)?AS\s+\(?(.*?)\)?\s+(?:WITH\s+(.*?))?;$/gis) {
        my ($alg, $definer, $security, $view_name, $view_def, $select, $options) = ($1, $2, $3, $4, $5, $6, $7);
        $self->{name} = $view_name; 
        $self->{select} = $select;
        $self->{fields} = '';
        $self->{options}{'algorithm'} = 'UNDEFINED';
        $self->{options}{'definer'} = 'CURRENT_USER';
        $self->{options}{'security'} = 'DEFINER';
        $self->{options}{'trail'} = '';
        if ($view_def) {
          $self->{fields} = $view_def;
        }
        if ($alg) {
          $self->{options}{'algorithm'} = $alg;
        }
        if ($security) {
          $self->{options}{'security'} = $security;
        }
        if ($definer) {
          $self->{options}{'definer'} = $definer;
        }
        if ($options) {
          $self->{options}{'trail'} = $options;
        }
        $self->{def} =~ s/$definer/CURRENT_USER/s;
        debug(4, "View name: $view_name");
    }
        
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
