#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use SQL::Decorate;

my $sql = <<'SQL';
SELECT * 
FROM table t JOIN table q 
    ON t.id = q.id AND q.status = ?
WHERE %s AND t.id > ?
LIMIT 101
SQL

my $sql_dec = sprintf $sql, "t.??? AND t.???";
my $sql_hand = sprintf $sql, "t.foo = ? AND t.bar IS NULL";

note $sql_dec;

is_deeply
    [ decorate_query( $sql_dec, 42, { foo => 137 }, { bar => undef }, 1337 ) ],
    [ $sql_hand, 42, 137, 1337 ],
    "Decorate worked";




done_testing;
