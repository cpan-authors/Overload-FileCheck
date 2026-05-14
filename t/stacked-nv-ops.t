#!/usr/bin/perl -w

# Test stacked file test operators with NV ops (-M, -A, -C).
#
# Verifies that using _ (PL_defgv) after a mocked file test works correctly
# for NV-returning operators.  This exercises the PL_statcache population
# path in pp_overload_stat and the real Perl NV op fallback via
# RETURN_CALL_REAL_OP_IF_CALL_WITH_DEFGV.

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Overload::FileCheck -from_stat => \&my_stat, qw{:check :stat};

my $NOW       = time();
my $ONE_DAY   = 86400;
my $basetime  = Overload::FileCheck::get_basetime();

# Set up files with specific timestamps so we can verify NV calculations.
my $fake_files = {
    'recent.file' => stat_as_file(
        size  => 100,
        mtime => $NOW - $ONE_DAY,        # 1 day old (from wall clock)
        atime => $NOW - 2 * $ONE_DAY,    # 2 days old
        ctime => $NOW - 3 * $ONE_DAY,    # 3 days old
    ),
    'old.file' => stat_as_file(
        size  => 200,
        mtime => $NOW - 30 * $ONE_DAY,   # 30 days old
        atime => $NOW - 10 * $ONE_DAY,   # 10 days old
        ctime => $NOW - 20 * $ONE_DAY,   # 20 days old
    ),
    'empty.dir' => stat_as_directory(
        mtime => $NOW - 5 * $ONE_DAY,
        atime => $NOW - 5 * $ONE_DAY,
        ctime => $NOW - 5 * $ONE_DAY,
    ),
    'no.such.file' => [],                 # file does not exist
};

sub my_stat {
    my ( $stat_or_lstat, $f ) = @_;

    if ( defined $f && defined $fake_files->{$f} ) {
        return $fake_files->{$f};
    }

    return FALLBACK_TO_REAL_OP();
}

# Helper: expected -M value for a given mtime
sub expected_M { return ( $basetime - $_[0] ) / 86400.0 }
sub expected_A { return ( $basetime - $_[0] ) / 86400.0 }
sub expected_C { return ( $basetime - $_[0] ) / 86400.0 }

my $tolerance = 0.01;    # allow small float tolerance

###
### Direct NV ops (no stacking) — baseline sanity
###

subtest 'direct -M/-A/-C on mocked file' => sub {
    my $got_M = -M 'recent.file';
    ok defined $got_M, '-M recent.file is defined';
    ok abs( $got_M - expected_M( $NOW - $ONE_DAY ) ) < $tolerance,
        "-M recent.file is close to expected value"
        or diag "got=$got_M expected=", expected_M( $NOW - $ONE_DAY );

    my $got_A = -A 'recent.file';
    ok defined $got_A, '-A recent.file is defined';
    ok abs( $got_A - expected_A( $NOW - 2 * $ONE_DAY ) ) < $tolerance,
        "-A recent.file is close to expected value"
        or diag "got=$got_A expected=", expected_A( $NOW - 2 * $ONE_DAY );

    my $got_C = -C 'recent.file';
    ok defined $got_C, '-C recent.file is defined';
    ok abs( $got_C - expected_C( $NOW - 3 * $ONE_DAY ) ) < $tolerance,
        "-C recent.file is close to expected value"
        or diag "got=$got_C expected=", expected_C( $NOW - 3 * $ONE_DAY );
};

###
### Stacked NV ops using _ after boolean op
###

subtest 'stacked: -e file && -M _' => sub {
    ok -e 'recent.file', '-e recent.file (priming _)';

    my $got = -M _;
    ok defined $got, '-M _ is defined after -e';
    ok abs( $got - expected_M( $NOW - $ONE_DAY ) ) < $tolerance,
        "-M _ matches expected mtime"
        or diag "got=$got expected=", expected_M( $NOW - $ONE_DAY );
};

subtest 'stacked: -e file && -A _' => sub {
    ok -e 'recent.file', '-e recent.file (priming _)';

    my $got = -A _;
    ok defined $got, '-A _ is defined after -e';
    ok abs( $got - expected_A( $NOW - 2 * $ONE_DAY ) ) < $tolerance,
        "-A _ matches expected atime"
        or diag "got=$got expected=", expected_A( $NOW - 2 * $ONE_DAY );
};

subtest 'stacked: -e file && -C _' => sub {
    ok -e 'recent.file', '-e recent.file (priming _)';

    my $got = -C _;
    ok defined $got, '-C _ is defined after -e';
    ok abs( $got - expected_C( $NOW - 3 * $ONE_DAY ) ) < $tolerance,
        "-C _ matches expected ctime"
        or diag "got=$got expected=", expected_C( $NOW - 3 * $ONE_DAY );
};

###
### Stacked NV ops in one-liner chains
###

subtest 'one-liner: -e && -M _ in single expression' => sub {
    my $m = do { -e 'recent.file' && -M _ };
    ok defined $m, 'chain returned defined value';
    ok abs( $m - expected_M( $NOW - $ONE_DAY ) ) < $tolerance,
        "chain value matches expected"
        or diag "got=$m expected=", expected_M( $NOW - $ONE_DAY );
};

subtest 'triple chain: -e && -f _ && -M _' => sub {
    my $m = do { -e 'recent.file' && -f _ && -M _ };
    ok defined $m, 'triple chain returned defined value';
    ok abs( $m - expected_M( $NOW - $ONE_DAY ) ) < $tolerance,
        "triple chain value matches expected"
        or diag "got=$m expected=", expected_M( $NOW - $ONE_DAY );
};

###
### File switching: _ refers to the LAST file tested
###

subtest 'file switching: _ tracks the most recent file' => sub {
    # Prime with recent.file
    ok -e 'recent.file', '-e recent.file';
    my $m1 = -M _;
    ok defined $m1, '-M _ after recent.file is defined';

    # Switch to old.file
    ok -e 'old.file', '-e old.file';
    my $m2 = -M _;
    ok defined $m2, '-M _ after old.file is defined';

    # old.file is 30 days old, recent.file is 1 day old
    # so m2 should be significantly larger than m1
    ok $m2 > $m1, "-M _ for old.file ($m2) > recent.file ($m1)"
        or diag "m1=$m1 m2=$m2";

    ok abs( $m2 - expected_M( $NOW - 30 * $ONE_DAY ) ) < $tolerance,
        "old.file -M _ matches expected"
        or diag "got=$m2 expected=", expected_M( $NOW - 30 * $ONE_DAY );
};

###
### NV stacking on directory (not just regular files)
###

subtest 'stacked NV on directory' => sub {
    ok -e 'empty.dir', '-e empty.dir';
    ok -d _, '-d _ confirms directory';

    my $m = -M _;
    ok defined $m, '-M _ on directory is defined';
    ok abs( $m - expected_M( $NOW - 5 * $ONE_DAY ) ) < $tolerance,
        "-M _ on directory matches expected"
        or diag "got=$m expected=", expected_M( $NOW - 5 * $ONE_DAY );
};

###
### Non-existent file: -M returns undef
###

subtest 'non-existent file: -M returns undef' => sub {
    my $m = -M 'no.such.file';
    ok !defined $m, '-M on non-existent mocked file returns undef';
};

###
### Stacking across int and NV ops
###

subtest 'mixed stack: -e && -s _ && -M _' => sub {
    ok -e 'recent.file', '-e recent.file';

    my $size = -s _;
    is $size, 100, '-s _ returns expected size';

    my $m = -M _;
    ok defined $m, '-M _ after -s _ is defined';
    ok abs( $m - expected_M( $NOW - $ONE_DAY ) ) < $tolerance,
        "-M _ value correct after int op"
        or diag "got=$m expected=", expected_M( $NOW - $ONE_DAY );
};

###
### Multiple NV ops stacked on same file
###

subtest 'all three NV ops stacked' => sub {
    ok -e 'recent.file', '-e recent.file';

    my $m = -M _;
    my $a = -A _;
    my $c = -C _;

    ok defined $m, '-M _ defined';
    ok defined $a, '-A _ defined';
    ok defined $c, '-C _ defined';

    # atime (2 days) > mtime (1 day) in age
    ok $a > $m, "-A _ ($a) > -M _ ($m) as expected (atime older)";

    # ctime (3 days) > atime (2 days) in age
    ok $c > $a, "-C _ ($c) > -A _ ($a) as expected (ctime older)";
};

done_testing;
