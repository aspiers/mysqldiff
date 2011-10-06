use strict;
use warnings;

use Module::Build;
#created by eumm-migrate.pl

my $build = Module::Build->new(
  'script_files' => [
    'bin/mysqldiff'
  ],
  'module_name' => 'MySQL::Diff',
  'configure_requires' => {
    'Module::Build' => 0,
  },
  'requires' => {
    'perl' => '5.005003',
    'Carp' => 0,
    'File::Slurp' => 0,
    'IO::File' => 0,
  },
  'meta_merge' => {
    'resources' => {
      'repository' => 'http://github.com/aspiers/mysqldiff'
    }
  },
  'license' => 'perl',
  'all_from' => 'lib/MySQL/Diff.pm'
);

$build->create_build_script();
