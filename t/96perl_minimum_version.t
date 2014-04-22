# -*- perl -*-

# Test that our declared minimum Perl version matches our syntax
use strict;
BEGIN {
  $|  = 1;
  $^W = 1;
}

my @MODULES = (
  'Perl::MinimumVersion 1.20',
  'Test::MinimumVersion 0.008',
);

# Don't run tests during end-user installs
use Test::More;
unless (-d '.git' || $ENV{AUTOMATED_TESTING}) {
  plan( skip_all => "Author tests not required for installation" );
}

# Load the testing modules
foreach my $MODULE ( @MODULES ) {
  eval "use $MODULE";
  if ( $@ ) {
    plan( skip_all => "$MODULE not available for testing" );
    die "Failed to load required release-testing module $MODULE"
      if -d '.git' || $ENV{AUTOMATED_TESTING};
  }
}

# false positive use_base_exporter works ok with 5.6.2
all_minimum_version_ok("5.006", {skip => ['lib/MySQL/Diff/Utils.pm']});

1;
