#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;

use Overload::FileCheck q{:stat};

# Verify that passing a nonexistent username to uid croaks
like(
    dies { stat_as_file( uid => 'zzzz_no_such_user_xyzzy' ) },
    qr/Unknown user 'zzzz_no_such_user_xyzzy'/,
    'stat_as_file croaks on unknown username',
);

# Verify that passing a nonexistent groupname to gid croaks
like(
    dies { stat_as_file( gid => 'zzzz_no_such_group_xyzzy' ) },
    qr/Unknown group 'zzzz_no_such_group_xyzzy'/,
    'stat_as_file croaks on unknown groupname',
);

# Numeric uid/gid should still work fine (no croak)
my $stat = stat_as_file( uid => 99999, gid => 99999 );
is $stat->[4], 99999, 'numeric uid passes through';
is $stat->[5], 99999, 'numeric gid passes through';

done_testing;
