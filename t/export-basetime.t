use strict;
use warnings;

use Test2::V0;

use Overload::FileCheck qw(get_basetime);

# get_basetime should be importable and return $^T (PL_basetime)
ok( defined get_basetime(), 'get_basetime returns a defined value' );
is( get_basetime(), $^T, 'get_basetime matches $^T' );

# verify it's a positive integer (epoch time)
ok( get_basetime() > 0, 'get_basetime is a positive epoch timestamp' );

done_testing;
