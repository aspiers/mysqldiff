require 5.005;

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'MySQL::Diff',
    'VERSION_FROM'	=> 'Diff.pm', # finds $VERSION
    'PREREQ_PM'		=> {
      'Class::MakeMethods::Template' => 0,
    },
);

sub MY::postamble {
  # Nasty hacks for getting the code to co-exist with guideguide CVS;
  # needn't concern anyone else.
  return '' unless -e '../mysqldiff';

  <<'EOF';
mysqldiff.pl: ../mysqldiff
	ln -s $< $@

ChangeLog: $(TO_INST_PM)
	-rm -f $@
	cd .. && rcs2log mysqldiff MySQL > MySQL/$@
EOF
}
