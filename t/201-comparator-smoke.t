#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Data::Criteria;

$SIG{__DIE__} =\&Carp::confess;

is number, "1=1", "Trivial condition";

is number < 5, "number < ? [5]", "Basic constr ok";

# TODO for now and/or cannot validate numbers properly, so this is broken
# is number->between(3, 5), "number >= ? AND number <= ? [3 5]", "Between works";
is number->between(3, 5), "string >= ? AND string <= ? [3 5]", "Between works";

my $in = number->in(1..3);
my $in_str = "$in";
note "in returned: $in_str";

like $in_str, qr/\((.*)\)\s*\[(.*)\]/, "in barely number";

note "TESTING EXECUTION";

my $crit = (number < 5) & (number > -100);

ok ($crit == 4, "4 < 5");
ok (!($crit == 6), "6 < 5 is false");

my $complex = ((number < 1) & (number >= -1) | (number->in(10, 20)) | (number >100));

note "Complex cond: ", $complex;

ok (!$complex->match("foo"), "String = no go");
ok ( $complex->match(0), "0 = ok");
ok ( $complex->match(1000), "very large");
ok (!$complex->match(15), "miss the interval" );
ok (!$complex->match(1), "miss open interval" );
ok ( $complex->match(-1), "hit closed interval" );
ok ( $complex->match(20), "hit whitelist" );

done_testing;
