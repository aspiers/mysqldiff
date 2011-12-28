package MySQL::Diff::Routine;

=head1 NAME

MySQL::Diff::Routine - Routine Definition Class

=head1 SYNOPSIS

  use MySQL::Diff::Routine

=head1 DESCRIPTION

Parses a routine definition into component parts.

=cut

use warnings;
use strict;

our $VERSION = '0.43';

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

    debug(3,"\nconstructing new MySQL::Diff::Routine");
    croak "MySQL::Diff::Routine::new called without def params" unless $self->{def};
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

Returns the name of the current routine.

=item * options

Returns the additional options added to the routine definition.

=back

=cut

sub def             { my $self = shift; return $self->{def};            }
sub name            { my $self = shift; return $self->{name};           }
sub options         { my $self = shift; return $self->{options};        }


# ------------------------------------------------------------------------------
# Private Methods

sub _parse {
	my $self = shift;
    debug(1,"parsing routine def '$self->{def}'");
    #warn "Routine def:\n", $self->{def};
    my $c = get_save_quotes();
    if (!$c) {
        $self->{def} =~ s/`([^`]+)`/$1/gs; # later versions quote names
    }
    $self->{def} =~ s/\n+/\n/;
    s/^\s*(.*?),?\s*$/$1/; # trim whitespace and trailing commas
    if ($self->{def} =~ /^CREATE(?:\s+DEFINER=(.*?))?\s+(TRIGGER|PROCEDURE|FUNCTION)\s+(.*?);;$/gis) {
        my ($definer, $type, $desc) = ($1, $2, $3);
        warn "$type desc: ", $desc;
        if ($type =~ /TRIGGER/i) {
            if ($desc =~ /(.*?)\s+(.*?)\s+FOR\s+EACH\s+ROW\s+(.*)/gis) {
                $self->{options} = $2;
                $self->{name} = $1;
                $self->{body} = $3;
            }
        } else {
            my @chars = split(//, $desc);
            my $brackets = -1;
            my $name = '';
            my $other_part = '';
            my $pos = 0;
            foreach my $char (@chars) {
                $name .= $char;
                if ($char eq '(') {
                    if ($brackets == -1) {
                        $brackets = 1;
                    } else {
                        $brackets++;
                    }
                }
                if ($char eq ')') {
                    $brackets--;
                }
                $pos++;
                if ($brackets == 0) {
                    $other_part = substr($desc, $pos);
                    last;
                }
            }
            $self->{name} = $name;
            my @opts_parts = ($other_part =~ /(\s+RETURNS\s+.*?\s+|\s+COMMENT\s+'.*?'|\s+LANGUAGE SQL|\s+(CONTAINS SQL|NO SQL|READS SQL DATA|MODIFIES SQL DATA)|\s+SQL\s+SECURITY\s+DEFINER|INVOKER)/gis);
            $self->{options} = join '', @opts_parts;
            $desc =~ s/$self->{options}//;
            $self->{body} = $desc;
            
        }
        $self->{def} =~ s/$definer/CURRENT_USER/s;
        #warn "Now def:\n", $self->{def};
        warn "Name: ", $self->{name};
        warn "Options: ", $self->{options};
        warn "Body: ", $self->{body};
        warn "_______\n";
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
