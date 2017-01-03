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

First ensure you have File::Slurp installed.

Then there are two options:

1) Install via Module::Build (recommended)
--------------------------------------------

Ensure that Module::Build is installed, e.g.

	$ perl -MCPAN -e 'install Module::Build'

or

	$ perl -MCPANPLUS -e 'install Module::Build'

Then run these commands:

	perl Build.PL
	perl Build
	perl Build test
	perl Build install

2) Install via ExtUtils::MakeMaker (deprecated but simpler)
-------------------------------------------------------------

You can install MySQL::Diff in the traditional way by running these commands:

	perl Makefile.PL
	make
	make test
	make install

And finally ...
=========================================================================

Note that the test suite will not run properly unless you have
a MySQL server which it can connect to.

