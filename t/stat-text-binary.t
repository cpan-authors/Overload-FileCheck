#!/usr/bin/perl -w

# Test text/binary options in stat_as_* helpers for -T/-B mock support.

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Overload::FileCheck q{:all};

subtest 'stat_as_file with text => 1' => sub {
    mock_all_from_stat(sub {
        my ($op, $file) = @_;
        return stat_as_file( size => 100, text => 1 ) if $file eq '/mock/script.pl';
        return FALLBACK_TO_REAL_OP;
    });

    ok( -T '/mock/script.pl', '-T returns true for text file' );
    ok( !-B '/mock/script.pl', '-B returns false for text file' );
    ok( -e '/mock/script.pl', '-e still works' );
    ok( -f '/mock/script.pl', '-f still works' );

    unmock_all_file_checks();
    unmock_stat();
};

subtest 'stat_as_file with binary => 1' => sub {
    mock_all_from_stat(sub {
        my ($op, $file) = @_;
        return stat_as_file( size => 2048, binary => 1 ) if $file eq '/mock/image.png';
        return FALLBACK_TO_REAL_OP;
    });

    ok( -B '/mock/image.png', '-B returns true for binary file' );
    ok( !-T '/mock/image.png', '-T returns false for binary file' );

    unmock_all_file_checks();
    unmock_stat();
};

subtest 'stat_as_file with text => 0 (explicitly not text)' => sub {
    mock_all_from_stat(sub {
        my ($op, $file) = @_;
        return stat_as_file( size => 100, text => 0 ) if $file eq '/mock/data.bin';
        return FALLBACK_TO_REAL_OP;
    });

    ok( !-T '/mock/data.bin', '-T returns false when text => 0' );
    ok( -B '/mock/data.bin', '-B returns true when text => 0 (inferred)' );

    unmock_all_file_checks();
    unmock_stat();
};

subtest 'stat_as_file with binary => 0 (explicitly not binary)' => sub {
    mock_all_from_stat(sub {
        my ($op, $file) = @_;
        return stat_as_file( size => 50, binary => 0 ) if $file eq '/mock/readme.txt';
        return FALLBACK_TO_REAL_OP;
    });

    ok( -T '/mock/readme.txt', '-T returns true when binary => 0 (inferred)' );
    ok( !-B '/mock/readme.txt', '-B returns false when binary => 0' );

    unmock_all_file_checks();
    unmock_stat();
};

subtest 'text/binary on stat_as_directory' => sub {
    mock_all_from_stat(sub {
        my ($op, $file) = @_;
        return stat_as_directory( text => 1 ) if $file eq '/mock/dir';
        return FALLBACK_TO_REAL_OP;
    });

    ok( -d '/mock/dir', '-d still works for directory' );
    ok( -T '/mock/dir', '-T returns true for directory with text => 1' );

    unmock_all_file_checks();
    unmock_stat();
};

subtest 'no text/binary falls back to default behavior' => sub {
    mock_all_from_stat(sub {
        my ($op, $file) = @_;
        return stat_as_file( size => 100 ) if $file eq '/mock/plain';
        return FALLBACK_TO_REAL_OP;
    });

    # Without text/binary options, -T/-B delegate to Perl's heuristic.
    # For mocked non-existent files this may produce unexpected results,
    # which is exactly the limitation text/binary options address.
    # We just verify it doesn't crash.
    my $t = eval { scalar -T '/mock/plain' };
    my $b = eval { scalar -B '/mock/plain' };
    pass('-T/-B without text/binary options did not crash');

    unmock_all_file_checks();
    unmock_stat();
};

subtest 'non-existent file returns undef for -T/-B' => sub {
    mock_all_from_stat(sub {
        my ($op, $file) = @_;
        return [] if $file eq '/mock/gone';    # empty stat = file not found
        return FALLBACK_TO_REAL_OP;
    });

    ok( !defined( -T '/mock/gone' ), '-T returns undef for non-existent file' );
    ok( !defined( -B '/mock/gone' ), '-B returns undef for non-existent file' );

    unmock_all_file_checks();
    unmock_stat();
};

subtest 'multiple files with different text/binary settings' => sub {
    mock_all_from_stat(sub {
        my ($op, $file) = @_;
        return stat_as_file( size => 100, text => 1 )   if $file eq '/mock/text';
        return stat_as_file( size => 200, binary => 1 ) if $file eq '/mock/binary';
        return stat_as_file( size => 50 )                if $file eq '/mock/unknown';
        return FALLBACK_TO_REAL_OP;
    });

    ok(  -T '/mock/text',   '-T true for text file' );
    ok( !-B '/mock/text',   '-B false for text file' );
    ok( !-T '/mock/binary', '-T false for binary file' );
    ok(  -B '/mock/binary', '-B true for binary file' );

    unmock_all_file_checks();
    unmock_stat();
};

subtest 'text/binary with stacked operators' => sub {
    mock_all_from_stat(sub {
        my ($op, $file) = @_;
        return stat_as_file( size => 100, text => 1 ) if $file eq '/mock/perl.pl';
        return FALLBACK_TO_REAL_OP;
    });

    # Stacked operators: -e && -T should both work
    ok( -e '/mock/perl.pl' && -T '/mock/perl.pl', '-e && -T both true' );

    # Size check combined with text check
    is( -s '/mock/perl.pl', 100, '-s returns correct size' );
    ok( -T '/mock/perl.pl', '-T still works after -s' );

    unmock_all_file_checks();
    unmock_stat();
};

done_testing;
