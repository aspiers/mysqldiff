#Installation instructions

First please consult the [README](README.md) to check that you have a new enough
version of Perl.

(N.B. the rest of this document looks a great deal more complicated
than it actually is, mainly because I'm trying to encourage people to
do the Right Things by using CPANPLUS instead of CPAN, and
Module::Build instead of ExtUtils::MakeMaker.)


"Automatic" installation via CPANPLUS.pm or CPAN.pm
=========================================================================

Installation from either of the recommended installers can be performed at the
command line, with either of the two following commands:

	$ perl -MCPANPLUS -e 'install MySQL::Diff'

	$ perl -MCPAN -e 'install MySQL::Diff'

Although CPAN.pm is the default installer for many, with the release of Perl
5.10, CPANPLUS.pm is now also available in core. However, if you use an earlier
version of Perl, you can install CPANPLUS from the CPAN with the following
command:

	$ perl -MCPAN -e 'install CPANPLUS'


"Manual" installation
=========================================================================

First ensure you have `File::Slurp` installed. Install also
`Dist::Zilla` via

	cpanm install Dist::Zilla
	
Install dependencies with

	dzil authordeps --missing | cpanm
	
And then

	dzil listdeps --missing | cpanm
	
Build and test

	dzil build 
	dzil test
	
Please bear in mind that this module needs a working Mysql
installation; those tests needing it will be skipped if it is not
present. 

And if everything is OK, 

	dzil install



And finally ...
=========================================================================

Note that the test suite will not run properly unless you have
a MySQL server which it can connect to.

