#!/usr/bin/perl -w
use strict;

use Test::More tests => 4;

# checks for regression to https://rt.cpan.org/Public/Bug/Display.html?id=79976

BEGIN {
    use_ok('MySQL::Diff::Database');
}

can_ok 'MySQL::Diff::Database', 'auth_args';

SKIP: {
    if ( my $reason = check_setup() ) {
        skip $reason, 2;
    }

    my $db = new_ok 'MySQL::Diff::Database' => [ db => 'foo' ];
    can_ok $db, 'auth_args';
}

sub check_setup {
    my $failure_string = "Cannot proceed with tests without ";
    _output_matches( "mysqldump foo", qr/Got error:/ ) or
        return $failure_string . 'mysqldump';
    return '';
}

sub _output_matches {
    my ($cmd, $re) = @_;
    my ($exit, $out) = _run($cmd);

    my $issue;
    if (defined $exit) {
        if ($exit == 0) {
            $issue = "Output from '$cmd' didn't match /$re/:\n$out" if $out !~ $re;
        }
        else {
            $issue = "'$cmd' exited with status code $exit";
        }
    }
    else {
        $issue = "Failed to execute '$cmd'";
    }

    if ($issue) {
        warn $issue, "\n";
        return 0;
    }
    return 1;
}

sub _run {
    my ($cmd) = @_;
    unless (open(CMD, "$cmd|")) {
        return (undef, "Failed to execute '$cmd': $!\n");
    }
    my $out = join '', <CMD>;
    close(CMD);
    return ($?, $out);
}

__END__
