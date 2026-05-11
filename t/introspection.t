#!perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;

use Overload::FileCheck qw(:all);

# ---- is_mocked ----

ok( !is_mocked('-e'), '-e is not mocked initially' );
ok( !is_mocked('e'),  'also works without leading dash' );
ok( !is_mocked('stat'), 'stat is not mocked initially' );

mock_file_check( '-e' => sub { CHECK_IS_TRUE } );
ok( is_mocked('-e'),  '-e is mocked after mock_file_check' );
ok( is_mocked('e'),   'is_mocked works without dash too' );
ok( !is_mocked('-f'), '-f is still not mocked' );

unmock_file_check('-e');
ok( !is_mocked('-e'), '-e is no longer mocked after unmock' );

# ---- get_mocked_checks ----

is( [ get_mocked_checks() ], [], 'no checks mocked initially' );

mock_file_check( '-f' => sub { CHECK_IS_TRUE } );
mock_file_check( '-e' => sub { CHECK_IS_TRUE } );

is( [ get_mocked_checks() ], [ 'e', 'f' ], 'returns sorted list of mocked checks' );

unmock_file_check('-e');
is( [ get_mocked_checks() ], [ 'f' ], 'list updates after unmock' );

unmock_file_check('-f');
is( [ get_mocked_checks() ], [], 'empty after all unmocked' );

# ---- stat/lstat exclusion from get_mocked_checks ----

mock_stat( sub { FALLBACK_TO_REAL_OP } );
ok( is_mocked('stat'),  'stat is mocked after mock_stat' );
ok( is_mocked('lstat'), 'lstat is mocked after mock_stat' );
is( [ get_mocked_checks() ], [], 'stat/lstat excluded from get_mocked_checks' );

unmock_stat();
ok( !is_mocked('stat'),  'stat unmocked' );
ok( !is_mocked('lstat'), 'lstat unmocked' );

# ---- mock_all_from_stat ----

mock_all_from_stat( sub { FALLBACK_TO_REAL_OP } );
ok( is_mocked('-e'), '-e is mocked via mock_all_from_stat' );
ok( is_mocked('-f'), '-f is mocked via mock_all_from_stat' );
ok( is_mocked('-d'), '-d is mocked via mock_all_from_stat' );
ok( is_mocked('stat'), 'stat is mocked via mock_all_from_stat' );

my @checks = get_mocked_checks();
ok( scalar @checks > 20, 'mock_all_from_stat mocks many checks (got ' . scalar(@checks) . ')' );

unmock_all_file_checks();
is( [ get_mocked_checks() ], [], 'all cleared after unmock_all_file_checks' );

# ---- guard interaction ----

{
    my $guard = mock_file_check_guard( '-d' => sub { CHECK_IS_TRUE } );
    ok( is_mocked('-d'), '-d is mocked inside guard scope' );
}
ok( !is_mocked('-d'), '-d is unmocked after guard goes out of scope' );

# ---- invalid check ----

like(
    dies { is_mocked('-Q') },
    qr/Unknown check/,
    'is_mocked croaks on unknown check'
);

done_testing;
