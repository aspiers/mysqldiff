use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'MySQL::Diff',
    'DISTNAME'		=> 'mysqldiff',
    'VERSION_FROM'	=> 'Diff.pm', # finds $VERSION
    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
);

sub MY::postamble {
  <<'EOF';
# Nasty hack for getting the code to co-exist with guideguide CVS;
# needn't concern anyone else.
mysqldiff.pl: ../mysqldiff
	ln -s $< $@
EOF
}
