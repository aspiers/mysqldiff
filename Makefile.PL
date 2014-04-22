#!/usr/bin/perl -w

use strict;

require 5.006; #use_base_exporter in MySQL::Diff::Utils is usable with 5.6

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile1(
    NAME     => 'MySQL::Diff',
    #KEYWORDS    => [ qw/mysql diff compare schema tables structure database/ ],
    LICENSE  => 'perl',
    META_ADD => {
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
        },
    },
    MIN_PERL_VERSION => '5.006',
    PREREQ_PM => {
        'Carp'        => 0,
        'File::Slurp' => 0,
        'IO::File'    => 0,
    },
    EXE_FILES    => [ 'bin/mysqldiff' ],
    VERSION_FROM => 'lib/MySQL/Diff.pm', # finds $VERSION
);

sub WriteMakefile1 {  #Written by Alexandr Ciornii, version 0.21. Added by eumm-upgrade.
    my %params = @_;
    my $eumm_version = $ExtUtils::MakeMaker::VERSION;
    $eumm_version = eval $eumm_version;
    die "EXTRA_META is deprecated" if exists $params{EXTRA_META};
    die "License not specified" if not exists $params{LICENSE};
    if ($params{BUILD_REQUIRES} and $eumm_version < 6.5503) {
        #EUMM 6.5502 has problems with BUILD_REQUIRES
        $params{PREREQ_PM}={ %{$params{PREREQ_PM} || {}} , %{$params{BUILD_REQUIRES}} };
        delete $params{BUILD_REQUIRES};
    }
    delete $params{CONFIGURE_REQUIRES} if $eumm_version < 6.52;
    delete $params{MIN_PERL_VERSION} if $eumm_version < 6.48;
    delete $params{META_MERGE} if $eumm_version < 6.46;
    delete $params{META_ADD} if $eumm_version < 6.46;
    delete $params{LICENSE} if $eumm_version < 6.31;
    delete $params{AUTHOR} if $] < 5.005;
    delete $params{ABSTRACT_FROM} if $] < 5.005;
    delete $params{BINARY_LOCATION} if $] < 5.005;

    WriteMakefile(%params);
}

