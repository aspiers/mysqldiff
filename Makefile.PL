#!/usr/bin/perl -w

require 5.005;

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		    => 'MySQL::Diff',
    'VERSION_FROM'	=> 'lib/MySQL/Diff.pm', # finds $VERSION
    'PREREQ_PM'		=> {
      'Carp'            => 0,
      'File::Slurp'     => 0,
      'IO::File'        => 0,
    },
    'EXE_FILES'         => [ 'bin/mysqldiff' ],
);
