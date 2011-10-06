use strict;
use warnings;

use Module::Build;
#created by eumm-migrate.pl

my $build = Module::Build->new(
    module_name => 'MySQL::Diff',
    keywords    => [ qw/mysql diff compare schema tables structure database/ ],
    license     => 'perl',
    meta => {
        resources => {
            license => [ 'http://dev.perl.org/licenses/' ],
            homepage => 'http://adamspiers.org/computing/mysqldiff/',
            bugtracker => {
                web    => 'http://rt.cpan.org/Public/Dist/Display.html?Name=MySQL-Diff',
                mailto => 'mysqldiff@adamspiers.org',
            },
            repository => {
                url  => 'git:github.com/aspiers/mysqldiff.git',
                web  => 'http://github.com/aspiers/mysqldiff',
                type => 'git',
            },
            #repository => 'http://github.com/aspiers/mysqldiff',
        },
    },
    requires => {
        'perl'        => '5.006',
        'Carp'        => 0,
        'File::Slurp' => 0,
        'IO::File'    => 0,
    },
    script_files => [ 'bin/mysqldiff' ],
    all_from => 'lib/MySQL/Diff.pm',
    configure_requires => {
        'Module::Build' => 0,
    },
);

$build->create_build_script();
