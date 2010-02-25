#!/usr/bin/perl -w

require 5.005;

use Module::Build;

Module::Build->new(
  module_name   => 'MySQL::Diff',
  license       => 'perl',
  requires      => {
    Carp            => 0,
    File::Slurp     => 0,
    IO::File        => 0,
  },
  script_files  => [ 'mysqldiff' ],
)->create_build_script;

