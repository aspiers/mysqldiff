use Test::More;
use MySQL::Diff;

# Skip if doing a regular install
plan skip_all => "Author tests not required for installation"
    unless ( $ENV{AUTOMATED_TESTING} );

eval "use Test::CPAN::Meta 0.16";
plan skip_all => "Test::CPAN::Meta 0.16 required for testing META.yml" if $@;

plan no_plan;

my $yaml = meta_spec_ok(undef,undef,@_);

is($yaml->{version},$MySQL::Diff::VERSION,
    'META.yml distribution version matches');

if($yaml->{provides}) {
    for my $mod (keys %{$yaml->{provides}}) {
        is($yaml->{provides}{$mod}{version},$MySQL::Diff::VERSION,
            "META.yml entry [$mod] version matches");
    }
}
