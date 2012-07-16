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

    debug(6,"\nconstructing new MySQL::Diff::Routine");
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

=item * body

Return routine's body

=item * type

Return routine's type (trigger, function or procedure)

=item * params

Return routine's parameters list

=back

=cut

sub def             { my $self = shift; return $self->{def};            }
sub name            { my $self = shift; return $self->{name};           }
sub options         { my $self = shift; return $self->{options};        }
sub body            { my $self = shift; return $self->{body};           }
sub type            { my $self = shift; return $self->{type};           }
sub params          { my $self = shift; return $self->{params};         }


# ------------------------------------------------------------------------------
# Private Methods

sub _str_replace {
    my $self = shift;
    my $replace_this = shift;
    my $with_this  = shift; 
    my $string   = shift;
    my $length = length($string);
    my $target = length($replace_this);
    
    for(my $i=0; $i<$length - $target + 1; $i++) {
        if(substr($string,$i,$target) eq $replace_this) {
            $string = substr($string,0,$i) . $with_this . substr($string,$i+$target);
            return $string; #Comment this if you what a global replace
        }
    }
    return $string;
}

sub _parse {
	my $self = shift;
    debug(5,"parsing routine def '$self->{def}'");
    my $c = get_save_quotes();
    if (!$c) {
        $self->{def} =~ s/`([^`]+)`/$1/gs; # later versions quote names
    }
    my $copy_def = $self->{def};
    my $l = [ grep ! /^\s*$/, split /(?=^)/m, $self->{def} ];
    my @lines =  @{$l};
    for (@lines) {
        s/^\s+//;
        s/\s+$//;
    }
    $self->{def} = join "\n", @lines;
    if ($self->{def} =~ /^CREATE(?:\s+DEFINER=(.*?))?\s+(TRIGGER|PROCEDURE|FUNCTION)\s+(.*?)$/gis) {
        my ($definer, $type, $desc) = ($1, $2, $3);
        $self->{type} = $type;
        my $params = '';
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
                if ($brackets == -1) {
                    $name .= $char;
                } else {
                    $params .= $char;
                }
                $pos++;
                if ($brackets == 0) {
                    $other_part = substr($desc, $pos);
                    last;
                }
            }
            $self->{name} = $name;
            my @opts_parts = ($other_part =~ /(\s+RETURNS\s+.*?\s+|\s+COMMENT\s+'.*?'|\s+LANGUAGE\s+SQL|\s+CONTAINS\s+SQL|NO\s+SQL|READS\s+SQL\s+DATA|MODIFIES\s+SQL\s+DATA|\s+SQL\s+SECURITY\s+DEFINER|INVOKER|\s+(?:NOT\s+)DETERMINISTIC)/gis);
            $self->{options} = join '', @opts_parts;
            $desc = $self->_str_replace($name, '', $desc);
            $desc = $self->_str_replace($params, '', $desc);
            $desc = $self->_str_replace($self->{options}, '', $desc);
            $self->{body} = $desc;
        }
        $self->{def} = $copy_def;
        $self->{def} =~ s/$definer/CURRENT_USER/s;
        $self->{params} = $params;
        debug(4, "Routine name: $self->{name}; type: $type");
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
