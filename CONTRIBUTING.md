# Good reading

  https://www.igvita.com/2011/12/19/dont-push-your-pull-requests/

# How to contribute

Contributing is easy.

1. first create an Issue - https://github.com/aspiers/mysqldiff/issues;
2. fork the main repo
3. create an Issue branch, e.g., "Issue-XX-blah-foo-derp"
4. make commits of logical units.
5. check for unnecessary whitespace with `git diff --check` before committing.
6. make sure your commit messages summarize your changes well enough.
7. make sure you have added the necessary tests for your changes.
8. issue a proper pull request

# Commits, pull request, and commit message format

1. please squash commits
2. do not mix new features together, or with bug fixes
3. use a structured commit messsage;

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
