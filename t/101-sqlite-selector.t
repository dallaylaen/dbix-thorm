#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use DBIx::Thorm::Source::SQLite;
use Data::Criteria;

my $set = DBIx::Thorm::Source::SQLite->new(
    fields => [qw[name age debt income]],
    key    => 'id',
    table  => 'people',
    test   => 'CREATE TABLE people(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name varchar(80),
            age INTEGER,
            debt INTEGER,
            income INTEGER
        );'
);

$set->save( {name => 'Alice',   age => 18, debt => 0, income => 1000} );
$set->save( {name => 'Bob',     age => 25, debt => 50, income => 2000} );
$set->save( {name => 'Charlie', age => 25, debt => 0, income => 0} );
$set->save( {name => 'Doug',    age => 43, debt => 1000, income => 500} );

my $data = $set->lookup( criteria => { debt => number > 100 } );

note explain $data;
is ($data->[0]->name, 'Doug', "round trip");

$data = $set->lookup(
    criteria => { age => number > 20, name => string < "D" },
    order => 'debt',
    limit => 1,
); 
note explain $data;

is scalar @$data, 1, "limit applied";
is $data->[0]->name, "Charlie", "Order applied";

done_testing;
