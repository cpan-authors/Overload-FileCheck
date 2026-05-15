#!/usr/bin/perl

use strict;
use warnings;

use Config;
use Test2::V0;

BEGIN {
    plan skip_all => 'This perl is not built with ithreads support'
        unless $Config{useithreads};
}

use threads;
use Overload::FileCheck qw(:check mock_file_check unmock_file_check);

# -- Parent thread mocks -e --------------------------------------------------

mock_file_check(
    '-e' => sub {
        my ($file) = @_;
        return CHECK_IS_TRUE if $file eq '/parent/file';
        return FALLBACK_TO_REAL_OP;
    }
);

ok( -e '/parent/file', '-e mock works in parent thread' );

# -- Child thread can re-mock independently -----------------------------------

my $thr = threads->create(sub {
    # The XS CLONE resets is_mocked=0, and _clone_init clears
    # $_current_mocks.  So the child should be able to mock -e
    # without getting "already mocked" error.

    my $can_mock = eval {
        mock_file_check(
            '-e' => sub {
                my ($file) = @_;
                return CHECK_IS_TRUE if $file eq '/child/file';
                return FALLBACK_TO_REAL_OP;
            }
        );
        1;
    };

    my $mock_error = $@;
    my $child_works = $can_mock ? ( -e '/child/file' ? 1 : 0 ) : 0;

    # Parent's mock should not be active in child
    my $parent_leaked = -e '/parent/file' ? 1 : 0;

    unmock_file_check('-e') if $can_mock;

    return ( $can_mock, $mock_error, $child_works, $parent_leaked );
});

my ( $can_mock, $mock_error, $child_works, $parent_leaked ) = $thr->join;

ok( $can_mock, 'child thread can mock_file_check without "already mocked" error' )
    or diag("mock error: $mock_error");
ok( $child_works, 'child thread mock returns correct value' );
ok( !$parent_leaked, 'parent mock state does not leak into child thread' );

# -- Parent mock still works after child exits --------------------------------

ok( -e '/parent/file', 'parent mock unaffected by child thread' );

unmock_file_check('-e');

done_testing;
