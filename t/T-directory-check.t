#!/usr/bin/perl -w

# Verify that the -T handler in _check_from_stat correctly short-circuits
# for directories (returning true) without attempting to open the path on
# disk for a heuristic check.  This matches the -B handler behavior —
# in Perl, both -T and -B return true for directories.

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Overload::FileCheck q(:all);

my $stat_call_count = 0;

mock_all_from_stat(
    sub {
        my ( $op, $file ) = @_;

        return FALLBACK_TO_REAL_OP unless defined $file;
        return FALLBACK_TO_REAL_OP unless $file =~ m{^MOCK/};

        $stat_call_count++;

        if ( $file eq 'MOCK/a-directory' ) {
            return stat_as_directory();
        }

        if ( $file eq 'MOCK/regular-file' ) {
            return stat_as_file( size => 100 );
        }

        return [];    # file not found
    }
);

# -T on a mocked directory: should return true (directories are "text" in Perl)
# and should NOT attempt to open the path for heuristic content check
$stat_call_count = 0;
my $result = -T 'MOCK/a-directory';
is $stat_call_count, 1, '-T on directory triggers stat callback exactly once';
ok $result, '-T on directory returns true (Perl convention: dirs are text)';

# -B on a mocked directory: same behavior for symmetry verification
$stat_call_count = 0;
$result = -B 'MOCK/a-directory';
is $stat_call_count, 1, '-B on directory triggers stat callback exactly once';
ok $result, '-B on directory returns true';

# -T on a non-existent mocked file: should return undef (CHECK_IS_NULL)
$stat_call_count = 0;
$result = -T 'MOCK/no-such-file';
is $stat_call_count, 1, '-T on non-existent file triggers stat callback exactly once';
ok !defined($result) || !$result, '-T on non-existent file is falsy';

# -s on a non-existent mocked file: should return undef (CHECK_IS_NULL)
$stat_call_count = 0;
$result = -s 'MOCK/no-such-file';
is $stat_call_count, 1, '-s on non-existent file triggers stat callback exactly once';
ok !defined($result), '-s on non-existent file returns undef';

unmock_all_file_checks();
unmock_stat();

done_testing;
