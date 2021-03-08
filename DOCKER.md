The `Dockerfile` is provided as the basis for development and running
a thorough set of tests.

The general workflow is to use a combination of the `Dockerfile` and the
`docker-compose.yml` file.

Base Image Information
---------------------- 

The current image is builting using Alpine and associated `perl` packages
and other development packages.

The database engine is the one most recently installed by Alpine's package
manager `apk` under the name `mariadb`.

All Perl modules required by `MySQL::Diff` are installed, but `MySQL::Diff`
is not. Instead, the building of the Docker image is expected to be executed
and run from inside of the top level of the upstream git repository.

Given this assumption, the current working directory on the host computer is
mounted as `/home/test/git/mysqldiff`.

NOTE: This container is not intended to roll releases using `Dist::Zilla` - the
build would take a very long time and the image size would not worth it.

Building the Docker Image
-------------------------

The `Makefile.docker` contains that actual `docker build` command, but to
run it:

   $ make -f ./Makefile.docker

This will run a while. 

Starting the Container
----------------------

Using `docker-compose`, launch the container in the background. To see what's
happing, inspect the `docker-compose.yml` file:

   $ docker-compose up -d 

See the container running (will be named `mysqldiff`):

   $ docker ps

Running Tests
-------------

The following command will enter a running container named `mysqldiff` as the
`test` user and run the test suite:

   $ make -f ./Makefile.docker test

Interactive Container Access
----------------------------

   $ make -f ./Makefile.docker shell


Building a Release Container
----------------------------

The only thing one must do is install `Dist::Zilla` while on the running container
as root:

   $ docker exec -it mysqldiff sh
   (as root on container)$ cpanm Dist::Zilla

