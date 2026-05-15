#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Overload::FileCheck qw(
  mock_virtual_filesystem
  get_basetime
  stat_as_file stat_as_directory stat_as_symlink
  CHECK_IS_TRUE CHECK_IS_FALSE FALLBACK_TO_REAL_OP
  ST_SIZE ST_MTIME ST_MODE
);

# --- get_basetime is exportable and matches $^T ---
is get_basetime(), $^T, "get_basetime() returns script start time";

# --- Basic virtual filesystem with guard ---
{
    my $guard = mock_virtual_filesystem(
        '/mock/file.txt' => stat_as_file( size => 42 ),
        '/mock/dir'      => stat_as_directory( perms => 0755 ),
        '/mock/link'     => stat_as_symlink(),
        '/mock/gone'     => [],                          # file not found
    );

    ok $guard, "mock_virtual_filesystem returns a guard";

    # Existence
    ok -e '/mock/file.txt',  "-e mocked file";
    ok -e '/mock/dir',       "-e mocked directory";
    ok !-e '/mock/gone',     "-e returns false for missing file";

    # File types
    ok -f '/mock/file.txt',  "-f mocked file";
    ok !-d '/mock/file.txt', "-d false for mocked file";
    ok -d '/mock/dir',       "-d mocked directory";
    ok !-f '/mock/dir',      "-f false for mocked directory";

    # Size
    is -s '/mock/file.txt', 42, "-s returns mocked size";

    # Stacked ops with _
    ok -e '/mock/file.txt' && -f _, "-e && -f _ works";

    # Fallback to real filesystem
    ok -e $^X, "real perl binary still accessible via fallback";
}

# Guard out of scope — mocks should be unmocked now
{
    # After guard destruction, file checks use real filesystem again.
    # A path that never existed shouldn't be mockable anymore.
    ok !-e '/mock/file.txt', "mocks cleaned up after guard goes out of scope";
}

# --- Nested guards ---
{
    my $guard1 = mock_virtual_filesystem(
        '/vfs/a' => stat_as_file( size => 10 ),
    );
    ok -e '/vfs/a', "first guard active";

    # Note: mock_virtual_filesystem calls mock_all_from_stat which will
    # fail if already mocked. This tests that the guard cleanup works.
}

# After first guard destroyed, we can create a new one
{
    my $guard2 = mock_virtual_filesystem(
        '/vfs/b' => stat_as_file( size => 20 ),
    );
    ok -e '/vfs/b',  "second guard active";
    ok !-e '/vfs/a', "first guard's files not present";
}

# --- Guard cancel ---
{
    my $guard = mock_virtual_filesystem(
        '/cancel/test' => stat_as_file(),
    );
    ok -e '/cancel/test', "mock active before cancel";
    $guard->cancel();
}
# After cancel, mocks persist (guard didn't clean up)
ok -e '/cancel/test', "mock persists after cancelled guard";
# Manual cleanup
Overload::FileCheck::unmock_all_file_checks();
Overload::FileCheck::unmock_stat();
ok !-e '/cancel/test', "manual cleanup works after cancel";

# --- stat() returns mocked data ---
{
    my $now = time();
    my $guard = mock_virtual_filesystem(
        '/stat/test' => stat_as_file( size => 999, mtime => $now ),
    );

    my @st = stat('/stat/test');
    ok scalar(@st), "stat() returns data for mocked file";
    is $st[ST_SIZE],  999,  "stat size matches";
    is $st[ST_MTIME], $now, "stat mtime matches";

    my @empty = stat('/stat/missing');
    ok !scalar(@empty), "stat() returns empty for unmocked nonexistent file";
}

done_testing;
