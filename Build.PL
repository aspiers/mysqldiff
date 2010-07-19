use strict;
use Module::Build;
#created by eumm-migrate.pl

my $build = Module::Build->new(
  'script_files' => [
    'mysqldiff'
  ],
  'module_name' => 'MySQL::Diff',
  'requires' => {
    'perl' => '5.005003',
    'Class::MakeMethods::Template' => 0
  },
  'meta_merge' => {
    'resources' => {
      'repository' => 'http://github.com/aspiers/mysqldiff'
    }
  },
  'license' => 'perl',
  'dist_version_from' => 'lib/MySQL/Diff.pm'
);

$build->create_build_script();
