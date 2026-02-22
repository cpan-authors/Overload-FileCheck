#!/usr/bin/perl

# Test that file check operators do not retain references to filehandles
# passed as arguments. This prevents garbage collection of the filehandle,
# which can cause resource leaks (e.g. sockets staying open).
#
# See: https://github.com/cpanel/Test-MockFile/issues/179

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;

use Scalar::Util qw(weaken);
use Overload::FileCheck -from_stat => \&my_stat, qw{:check};

sub my_stat {
    my ( $stat_or_lstat, $f ) = @_;
    return FALLBACK_TO_REAL_OP();
}

# Test that filehandle references are not retained by $_last_call_for
{
    my $weak_ref;

    {
        open my $fh, '<', '/dev/null' or die "Cannot open /dev/null: $!";
        $weak_ref = $fh;
        weaken($weak_ref);

        ok( defined $weak_ref, "weak ref is defined before scope exit" );

        # Trigger a file check on the filehandle — this used to store $fh
        # in $_last_call_for, preventing garbage collection.
        no warnings;
        -f $fh;
    }

    ok( !defined $weak_ref, "filehandle is garbage collected after -f check (no ref leak)" );
}

# Test with -S (the operator from the original bug report)
{
    my $weak_ref;

    {
        open my $fh, '<', '/dev/null' or die "Cannot open /dev/null: $!";
        $weak_ref = $fh;
        weaken($weak_ref);

        no warnings;
        -S $fh;
    }

    ok( !defined $weak_ref, "filehandle is garbage collected after -S check (no ref leak)" );
}

# Test that string filenames still work for _ caching (no regression)
{
    no warnings;
    ok( -f $0,  "-f \$0 works" );
    ok( -e _,   "-e _ works after -f on string filename" );
}

done_testing;
