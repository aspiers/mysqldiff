#!/usr/bin/perl -w

require 5.005;

warn <<EOF;
ExtUtils::MakeMaker is old, crufty, evil and broken.
Please use Build.PL instead (see the INSTALL file).
EOF

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'MySQL::Diff',
    'VERSION_FROM'	=> 'lib/MySQL/Diff.pm', # finds $VERSION
    'PREREQ_PM'		=> {
      'Class::MakeMethods::Template' => 0,
    },
    'EXE_FILES'         => [ 'mysqldiff' ],
);
