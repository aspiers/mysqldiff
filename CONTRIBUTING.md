# Good reading

- https://www.igvita.com/2011/12/19/dont-push-your-pull-requests/
- http://blog.adamspiers.org/2012/11/10/7-principles-for-contributing-patches-to-software-projects/

# How to contribute

Contributing is easy.

First check your issue hasn't already been reported on
(CPAN)[https://rt.cpan.org/Public/Dist/Display.html?Name=MySQL-Diff]
or (GitHub)[https://github.com/aspiers/mysqldiff/issues].  Then
proceed appropriately:

1. (File a new issue)[https://github.com/aspiers/mysqldiff/issues/new]
2. Fork the main repo
3. Create an issue branch, e.g., "Issue-XX-blah-foo-derp"
4. Make commits of logical units (see below).
5. Check for unnecessary whitespace with `git diff --check` before committing.
6. Make sure your commit messages summarize your changes well enough.
7. Make sure you have added the necessary tests for your changes.
8. Issue a proper pull request.

# Commits, pull request, and commit message format

See [this page](https://wiki.openstack.org/wiki/GitCommitMessages#Structural_split_of_changes)
for some excellent advice on structuring commits correctly.

1. Please squash commits which relate to the same thing.
2. Do not mix new features together, or with bug fixes.
3. Use a structured commit messsage.

For example,

    Fixed the foobar bug with the flim-flam.

    Issue-XX: Made changes to the flux memristor so
    that the space time continuum would remain consisitent
    for the key constraint mechanism.  Added a few unit tests
    to ensure the inversion of time remained consistent in
    all past and future versions of this utility.

# Please add/update tests

All new features should include new tests to exercise them thoroughly.

If fixing a bug, please add a regression test.

# Questions

When in doubt, issue a pull request. Feel free to email be, B. Estrade <estrabd@gmail.com>.
