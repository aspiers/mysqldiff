package MySQL::Utils;

use strict;

use base qw(Exporter);
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(auth_args debug_level debug);

sub auth_args {
  my %auth = @_;
  my $args = '';
  for my $arg (qw/host user password/) {
    $args .= " --$arg=$auth{$arg}" if $auth{$arg};
  }
  return $args;
}

{
  my $debug_level = 0;

  sub debug_level {
    my ($new_debug_level) = @_;
    $debug_level = $new_debug_level if defined $new_debug_level;
    return $debug_level;
  }

  sub debug {
    my $level = shift;
    print STDERR @_ if ($debug_level >= $level) && @_;
  }
}


1;
