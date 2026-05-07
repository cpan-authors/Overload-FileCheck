#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Plugin::NoWarnings;

use Overload::FileCheck qw(:all);

# Mocked stat returning empty array (file not found) should behave
# identically to Perl's real stat in scalar context: return a defined
# false value, not undef.  A stack imbalance in the XS failure path
# previously caused scalar stat to return undef or a stale stack value.

mock_stat(sub {
    my ($opname, $file) = @_;
    return []                          if $file eq '/missing';
    return stat_as_file(size => 1024)  if $file eq '/present';
    return FALLBACK_TO_REAL_OP;
});

# --- Scalar context: missing file ---

{
    my $result = stat('/missing');
    ok( defined($result), 'scalar stat on missing mocked file returns a defined value' );
    ok( !$result, 'scalar stat on missing mocked file is false' );
}

# --- Boolean context: missing file ---

{
    if ( stat('/missing') ) {
        fail('stat(/missing) should be falsy');
    }
    else {
        pass('stat(/missing) is falsy in boolean context');
    }
}

# --- Scalar context: existing file ---

{
    my $result = stat('/present');
    ok( $result, 'scalar stat on existing mocked file is truthy' );
}

# --- List context: missing file (regression) ---

{
    my @r = stat('/missing');
    is( scalar @r, 0, 'list stat on missing mocked file returns empty list' );
}

# --- List context: existing file (regression) ---

{
    my @r = stat('/present');
    is( scalar @r, 13, 'list stat on existing mocked file returns 13 elements' );
}

# --- Stack integrity: scalar stat failure must not corrupt surrounding values ---

{
    my $before = 'sentinel';
    my $s      = stat('/missing');
    my $after  = 'sentinel';
    is( $before, 'sentinel', 'stack not corrupted before stat call' );
    is( $after,  'sentinel', 'stack not corrupted after stat call' );
}

unmock_stat();
done_testing;
