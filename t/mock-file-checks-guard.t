#!perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;

use Overload::FileCheck '-e' => \&my_custom_check, qw(:check);

my $fake_file = '/this/file/does/not/exist.for" ~ testing';

sub my_custom_check {
    my ($file) = @_;
    return CHECK_IS_TRUE  if $file eq $fake_file;
    return FALLBACK_TO_REAL_OP;
}

# Sanity: single-check mock from import is active
ok( -e $fake_file, "-e mock from import is active" );

# --- Test: basic multi-check guard ---
{
    my $guard = Overload::FileCheck::mock_file_checks_guard(
        '-f' => sub {
            my ($file) = @_;
            return CHECK_IS_TRUE if $file eq $fake_file;
            return FALLBACK_TO_REAL_OP;
        },
        '-d' => sub {
            my ($file) = @_;
            return CHECK_IS_FALSE if $file eq $fake_file;
            return FALLBACK_TO_REAL_OP;
        },
    );

    ok(  -f $fake_file, "-f is mocked inside guard scope" );
    ok( !-d $fake_file, "-d is mocked inside guard scope" );

    # Real files still work via FALLBACK_TO_REAL_OP
    ok( -f $0, "real file (-f \$0) still works" );
}

# After guard goes out of scope, mocks are removed
{
    # -f and -d should now fall back to real ops (file doesn't exist)
    ok( !-f $fake_file, "-f unmocked after guard scope" );
    ok( !-d $fake_file, "-d unmocked after guard scope" );
}

# --- Test: guard cancel prevents unmocking ---
{
    my $guard = Overload::FileCheck::mock_file_checks_guard(
        '-z' => sub { CHECK_IS_TRUE },
    );

    ok( -z $fake_file, "-z mocked via guard" );
    $guard->cancel;
}

# After cancel + scope exit, mock should still be active
ok( -z $fake_file, "-z still mocked after cancel" );

# Clean up manually
Overload::FileCheck::unmock_file_check('-z');

# --- Test: error on odd number of args ---
like(
    dies { Overload::FileCheck::mock_file_checks_guard('-f') },
    qr/even number of arguments/,
    "croaks on odd argument count",
);

# --- Test: error on empty args ---
like(
    dies { Overload::FileCheck::mock_file_checks_guard() },
    qr/at least one/,
    "croaks on zero arguments",
);

# --- Test: error on duplicate mock ---
like(
    dies {
        Overload::FileCheck::mock_file_checks_guard(
            '-e' => sub { CHECK_IS_TRUE },
        )
    },
    qr/already mocked/,
    "croaks when check is already mocked",
);

# --- Test: three checks with mixed dash/no-dash ---
{
    my $guard = Overload::FileCheck::mock_file_checks_guard(
        '-f' => sub { CHECK_IS_TRUE },
        'd'  => sub { CHECK_IS_TRUE },   # no dash
        '-S' => sub { CHECK_IS_FALSE },
    );

    ok(  -f $fake_file, "-f mocked (dash)" );
    ok(  -d $fake_file, "-d mocked (no dash)" );
    ok( !-S $fake_file, "-S mocked (false)" );
}
ok( !-f $fake_file, "-f unmocked after multi-check guard" );
ok( !-d $fake_file, "-d unmocked after multi-check guard" );

# Clean up the import mock
Overload::FileCheck::unmock_file_check('-e');

done_testing;
