#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use DBIx::Thorm;

thorm connect => dbi => 'dbi:SQLite:dbname=:memory:';

thorm->dbh->do( <<"SQL" );
CREATE TABLE foobar(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    foo INTEGER,
    bar INTEGER,
    baz INTEGER
);
SQL

my $source = thorm table => 'foobar', key => 'id', fields => [qw[foo bar baz]];
$source->save( {foo => 101} );
$source->save( {foo => 102, bar => 137 } );

my $data = $source->lookup( criteria => { bar => number > 100 } );

is scalar @$data, 1, "1 elt selected";

is $data->[0]->foo, 102, "Data round trip";
like $data->[0]->id, qr/^\d+$/, "Id selected";

$data->[0]->baz( 42 );
note explain $data;
$data->[0]->save;

$data = $source->lookup( criteria => { baz => 42 } );

is $data->[0]->foo, 102, "Data round trip";

done_testing;
