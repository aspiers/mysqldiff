FROM yobasystems/alpine-mariadb

# from https://github.com/scottw/alpine-perl/blob/master/Dockerfile
RUN apk update && apk upgrade && apk add alpine-sdk curl tar make gcc build-base wget gnupg vim
RUN apk add perl perl-utils perl-dev mariadb-dev
RUN curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm && \
    chmod +x cpanm && \
    ./cpanm App::cpanminus && \
    rm -fr ./cpanm /root/.cpanm /usr/src/perl

## from tianon/perl
ENV PERL_CPANM_OPT --verbose --mirror https://cpan.metacpan.org --mirror-only
RUN cpanm Digest::SHA Module::Signature && rm -rf ~/.cpanm
ENV PERL_CPANM_OPT $PERL_CPANM_OPT --verify

# mysqdiff prereq
RUN cpanm String::ShellQuote File::Slurp

# adding this because someone will ask
RUN cpanm --noverify Mock::Config
RUN cpanm DBD::Mock Mock::Config DBD::mysql DBI DBI::Shell

# add test user
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home /home/test \
    test 

# switch to 'test' user, create director for later mounting
USER test
RUN mkdir -p /home/test/git/mysqldiff
WORKDIR /home/test

# switch to root so entrypoint can run as root
USER root
