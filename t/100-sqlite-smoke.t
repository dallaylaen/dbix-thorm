#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use DBI;

use DBIx::Thorm::Source::SQLite;

$SIG{__WARN__} = \&Carp::cluck;

my $dbh = DBI->connect(
    "dbi:SQLite:dbname=:memory:", '', '', { RaiseError => 1} );

$dbh->do( <<"SQL" );
CREATE TABLE foobar (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    foo varchar(80),
    bar varchar(80)
);
SQL

my $set = DBIx::Thorm::Source::SQLite->new(
    dbh => $dbh,
    table => 'foobar',
    key => 'id',
    fields => [qw[foo bar]],
);

my $raw = { foo => 42 };

my $foo1 = $set->save($raw);
note "After insert: ", explain $foo1;
is ($foo1->foo, 42, "foo as expected");
ok ($foo1->id, "id present");


my $foo2 = $set->load( $foo1->id );
note explain $foo2;

is( $foo1->id , $foo2->id , "Data round trip (id)" );
is( $foo1->foo, $foo2->foo, "Data round trip (foo)" );
is( $foo1->bar, $foo2->bar, "Data round trip (bar)" );


done_testing;
