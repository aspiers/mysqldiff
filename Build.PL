use strict;
use warnings;

use Module::Build;
#created by eumm-migrate.pl

my $build = Module::Build->new(
    module_name => 'MySQL::Diff',
    keywords    => [ qw/mysql diff compare schema tables structure database/ ],
    license     => 'perl',

    # Module::Build forces us to use v1.4 of the CPAN Meta Spec:
    # https://rt.cpan.org/Ticket/Display.html?id=71502
    # 'meta-spec' =>  {
    #     version => '2.0',
    #     url     => 'http://search.cpan.org/perldoc?CPAN::Meta::Spec',
    # },
    meta_add => {
        resources => {
            license => 'http://dev.perl.org/licenses/' ,
            homepage => 'http://adamspiers.org/computing/mysqldiff/',

            # Module::Build forces us to use v1.4 of the CPAN Meta Spec:
            # https://rt.cpan.org/Ticket/Display.html?id=71502
            # bugtracker => {
            #     web    => 'http://rt.cpan.org/Public/Dist/Display.html?Name=MySQL-Diff',
            #     mailto => 'mysqldiff@adamspiers.org',
            # },
            bugtracker => 'http://rt.cpan.org/Public/Dist/Display.html?Name=MySQL-Diff',

            # Module::Build forces us to use v1.4 of the CPAN Meta Spec:
            # https://rt.cpan.org/Ticket/Display.html?id=71502
            # repository => {
            #     url  => 'git:github.com/aspiers/mysqldiff.git',
            #     web  => 'http://github.com/aspiers/mysqldiff',
            #     type => 'git',
            # },
            repository => 'http://github.com/aspiers/mysqldiff',
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
