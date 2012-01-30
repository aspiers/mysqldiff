package MySQL::Diff::Utils;

=head1 NAME

MySQL::Diff::Utils - Supporting functions for MySQL:Diff

=head1 SYNOPSIS

  use MySQL::Diff::Utils qw(debug_level debug);

=head1 DESCRIPTION

Currently contains the debug message handling routines.

=cut

use warnings;
use strict;

our $VERSION = '0.43';

# ------------------------------------------------------------------------------
# Libraries

use IO::File;

# ------------------------------------------------------------------------------
# Export Components

use base qw(Exporter);
our @EXPORT_OK = qw(debug_file debug_level debug set_save_quotes get_save_quotes save_logdir get_logdir write_log generate_random_string);

# ------------------------------------------------------------------------------

=head1 FUNCTIONS

=head2 Public Functions

Fuller documentation will appear here in time :)

=over 4

=item * debug_file( $file )

Accessor to set/get the current debug log file.

=item * debug_level( $level )

Accessor to set/get the current debug level for messages.

Current levels range from 1 to 4, with 1 being very brief processing messages,
2 providing high level process flow messages, 3 providing low level process
flow messages and 4 providing data dumps, etc where appropriate.

=item * debug

Writes to debug log file (if specified) and STDERR the given message, provided
is equal to or lower than the current debug level.

=item * set_save_quotes

Save choice about save saving quotes

=item * get_save_quotes

Get choice about save saving quotes

=back

=cut

{
    my $debug_file;
    my $debug_level = 0;
    my $choice = 0;
    my $log_dir = '';
    my $random_string = '';

    sub debug_file {
        my ($new_debug_file) = @_;
        $debug_file = $new_debug_file if defined $new_debug_file;
        return $debug_file;
    }

    sub debug_level {
        my ($new_debug_level) = @_;
        $debug_level = $new_debug_level if defined $new_debug_level;
        return $debug_level;
    }

    sub debug {
        my $level = shift;
        return  unless($debug_level >= $level && @_);

        if($debug_file) {
            if(my $fh = IO::File->new($debug_file, 'a+')) {
                print $fh @_,"\n";
                $fh->close;
                return;
            }
        }
        my $padding = '';
        for (my $i = 0; $i < $level; $i++) {
            $padding .= '    ';
        }
        print STDERR $padding,@_,"\n";
    }
    
    sub set_save_quotes {
        $choice = @_;
    }
    
    sub get_save_quotes {
        return $choice;
    }

    sub save_logdir {
        $log_dir = shift;
    }

    sub get_logdir {
        return $log_dir;
    }

    sub generate_random_string {
        my @chars=('a'..'z','A'..'Z','0'..'9');
        my $random_string = '';
        foreach (1..5) 
        {
            # rand @chars will generate a random 
            # number between 0 and scalar @chars
            $random_string.=$chars[rand @chars];
        }
        return $random_string;
    }

    sub write_log {
        my ($filename, $content, $append) = @_;
        if ($log_dir && $filename && $content) {
            my @chars=('a'..'z','A'..'Z','0'..'9','_');
            if (!$random_string) {
                $random_string = generate_random_string();
            }
            $filename = $log_dir . '/' . $random_string . '_' . $filename ;
            if ($append) {
                open(LOG_FILE, '>>'.$filename);
            } else {
                open(LOG_FILE, '>'.$filename);
            }
            print LOG_FILE $content;
            close (LOG_FILE);
        }
    }
    
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2000-2011 Adam Spiers. All rights reserved. This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<mysqldiff>, L<MySQL::Diff>, L<MySQL::Diff::Database>, L<MySQL::Diff::Table>

=head1 AUTHOR

Adam Spiers <mysqldiff@adamspiers.org>

=cut
