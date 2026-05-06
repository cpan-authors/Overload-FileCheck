use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;

use Overload::FileCheck qw(
  mock_stat_guard mock_all_file_checks_guard mock_all_from_stat_guard
  mock_file_check unmock_file_check
  stat_as_file stat_as_directory
  CHECK_IS_TRUE CHECK_IS_FALSE FALLBACK_TO_REAL_OP
  ST_SIZE
);

my $fake = "/guard-variants/test/file";

# ===========================================================
# mock_stat_guard
# ===========================================================

subtest 'mock_stat_guard: active inside scope, removed after' => sub {
    my @got;
    {
        my $guard = mock_stat_guard( sub {
            my ( $op, $file ) = @_;
            return stat_as_file( size => 99 ) if $file eq $fake;
            return FALLBACK_TO_REAL_OP;
        });
        isa_ok( $guard, 'Overload::FileCheck::Guard' );
        @got = stat($fake);
        is( $got[ST_SIZE], 99, "stat returns mocked size inside guard scope" );
    }
    @got = stat($fake);
    ok( !@got, "stat falls back to real op after guard destroyed" );
};

subtest 'mock_stat_guard: cancel preserves mock' => sub {
    {
        my $guard = mock_stat_guard( sub {
            my ( $op, $file ) = @_;
            return stat_as_file() if $file eq $fake;
            return FALLBACK_TO_REAL_OP;
        });
        $guard->cancel;
    }
    my @got = stat($fake);
    ok( scalar @got, "stat still mocked after cancelled guard" );
    Overload::FileCheck::unmock_stat();
};

subtest 'mock_stat_guard: cleanup on die' => sub {
    eval {
        my $guard = mock_stat_guard( sub {
            my ( $op, $file ) = @_;
            return stat_as_file() if $file eq $fake;
            return FALLBACK_TO_REAL_OP;
        });
        die "simulated failure";
    };
    my @got = stat($fake);
    ok( !@got, "stat unmocked after die inside eval" );
};

# ===========================================================
# mock_all_file_checks_guard
# ===========================================================

subtest 'mock_all_file_checks_guard: active inside scope' => sub {
    {
        my $guard = mock_all_file_checks_guard( sub {
            my ( $check, $file ) = @_;
            return CHECK_IS_TRUE if $file eq $fake;
            return FALLBACK_TO_REAL_OP;
        });
        isa_ok( $guard, 'Overload::FileCheck::Guard' );
        ok( -e $fake, "-e mocked" );
        ok( -f $fake, "-f mocked" );
        ok( -d $fake, "-d mocked" );
    }
    ok( !-e $fake, "-e unmocked after guard destroyed" );
    ok( !-f $fake, "-f unmocked after guard destroyed" );
    ok( !-d $fake, "-d unmocked after guard destroyed" );
};

subtest 'mock_all_file_checks_guard: cleanup on die' => sub {
    eval {
        my $guard = mock_all_file_checks_guard( sub {
            my ( $check, $file ) = @_;
            return CHECK_IS_TRUE if $file eq $fake;
            return FALLBACK_TO_REAL_OP;
        });
        ok( -e $fake, "-e mocked inside eval" );
        die "simulated failure";
    };
    ok( !-e $fake, "-e unmocked after die" );
};

# ===========================================================
# mock_all_from_stat_guard
# ===========================================================

subtest 'mock_all_from_stat_guard: active inside scope' => sub {
    {
        my $guard = mock_all_from_stat_guard( sub {
            my ( $op, $file ) = @_;
            return stat_as_file( size => 42 ) if $file eq $fake;
            return stat_as_directory()        if $file eq "${fake}.dir";
            return FALLBACK_TO_REAL_OP;
        });
        isa_ok( $guard, 'Overload::FileCheck::Guard' );

        # file checks work
        ok( -e $fake, "-e mocked" );
        ok( -f $fake, "-f mocked" );
        is( -s $fake, 42, "-s returns mocked size" );

        # directory works
        ok( -d "${fake}.dir", "-d mocked for directory" );

        # stat works
        my @st = stat($fake);
        is( $st[ST_SIZE], 42, "stat returns mocked size" );
    }
    ok( !-e $fake, "-e unmocked after guard destroyed" );
    my @st = stat($fake);
    ok( !@st, "stat unmocked after guard destroyed" );
};

subtest 'mock_all_from_stat_guard: cancel preserves all mocks' => sub {
    {
        my $guard = mock_all_from_stat_guard( sub {
            my ( $op, $file ) = @_;
            return stat_as_file() if $file eq $fake;
            return FALLBACK_TO_REAL_OP;
        });
        $guard->cancel;
    }
    ok( -e $fake, "-e still mocked after cancelled guard" );
    my @st = stat($fake);
    ok( scalar @st, "stat still mocked after cancelled guard" );
    Overload::FileCheck::unmock_all_file_checks();
};

subtest 'mock_all_from_stat_guard: cleanup on die' => sub {
    eval {
        my $guard = mock_all_from_stat_guard( sub {
            my ( $op, $file ) = @_;
            return stat_as_file() if $file eq $fake;
            return FALLBACK_TO_REAL_OP;
        });
        ok( -e $fake, "-e mocked inside eval" );
        die "simulated failure";
    };
    ok( !-e $fake, "-e unmocked after die" );
    my @st = stat($fake);
    ok( !@st, "stat unmocked after die" );
};

# ===========================================================
# edge case: sequential guards in same scope
# ===========================================================

subtest 'sequential guards: second guard after first expires' => sub {
    {
        my $guard1 = mock_all_from_stat_guard( sub {
            my ( $op, $file ) = @_;
            return stat_as_file( size => 10 ) if $file eq $fake;
            return FALLBACK_TO_REAL_OP;
        });
        is( -s $fake, 10, "first guard active" );
    }
    ok( !-e $fake, "first guard cleaned up" );
    {
        my $guard2 = mock_all_from_stat_guard( sub {
            my ( $op, $file ) = @_;
            return stat_as_file( size => 20 ) if $file eq $fake;
            return FALLBACK_TO_REAL_OP;
        });
        is( -s $fake, 20, "second guard active with different value" );
    }
    ok( !-e $fake, "second guard cleaned up" );
};

done_testing;
