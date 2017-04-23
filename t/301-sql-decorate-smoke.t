#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use SQL::Decorate;

my $dec = SQL::Decorate->new;

my $sql = <<'SQL';
SELECT * 
FROM table t JOIN table q 
    ON t.id = q.id AND q.status = ?
WHERE %s AND t.id > ?
LIMIT 101
SQL

my $sql_dec = sprintf $sql, "t = ???";
my $sql_hand = sprintf $sql, "t.bar IS NULL AND t.foo = ?";

note " --- Template: \n$sql_dec";
note " --- Must become: \n$sql_hand";
note " ---";

is_deeply
    [ $dec->decorate( $sql_dec, 42, { foo => 137, bar => undef }, 1337 ) ],
    [ $sql_hand, 42, 137, 1337 ],
    "Decorate worked";

note "TESTING SLICE";
$sql_dec = sprintf $sql, "t = ???[bar baz foo]";

is_deeply
    [ $dec->decorate( $sql_dec, 42, { foo => 137, bar => undef, guest => -1 }, 1337 ) ],
    [ $sql_hand, 42, 137, 1337 ],
    "Decorate with slice worked";

done_testing;
