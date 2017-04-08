#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use DBIx::Thorm::Comparator;

is smth, "1=1", "Trivial condition";

is smth < 5, "smth < ? [5]", "Basic constr ok";

is smth->between(3, 5), "smth >= ? AND smth <= ? [3 5]", "Between works";

my $in = smth->in(1..3);
my $in_str = "$in";
note "in returned: $in_str";

like $in_str, qr/\((.*)\)\s*\[(.*)\]/, "in barely smth";

note "TESTING EXECUTION";

my $crit = (smth < 5) & (smth > -100);

ok ($crit == 4, "4 < 5");
ok (!($crit == 6), "6 < 5 is false");

done_testing;
