#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use SQL::Decorate;
use Data::Criteria;

my $dec = SQL::Decorate->new;

my $crit = {
    missing => undef,
    numeric => (number > 0) & (number != 42),
    plain   => 137,
    string  => (string < "Ozzy") | (string == "Uriah"),
};

my ($sql, @arg) = $dec->decorate( "t=???", $crit );

is $sql, join( " AND ", "t.missing IS NULL", "t.numeric > ?", "t.numeric <> ?"
    , "t.plain = ?", "(t.string < ? OR t.string = ?)" )
    , "Criteria as expected";

is_deeply( \@arg, [0, 42, 137, "Ozzy", "Uriah"], "Argument as expected" );

done_testing;
