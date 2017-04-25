#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Data::Criteria;

our @warn;
$SIG{__WARN__} = sub {
    push @warn, $_[0];
    diag "WARN: $_[0]";
};

my $crit = (string < "Ozzy");

ok ( $crit->match("Aadvark"), "Normal match +" );
ok (!$crit->match("Uriah"), "Normal match -" );
ok (!$crit->match(undef), "Normal match undef" );

$crit |= undef;
$crit |= "Uriah";

ok ( $crit->match("Aadvark"), "Normal match +" );
ok ( $crit->match("Uriah"), "Normal match exception" );
ok ( $crit->match(undef), "Normal match undef +" );
ok (!$crit->match("Sabbath"), "Normal match -" );

ok (!@warn, "No warnings issued")
    or diag( (scalar @warn)." warnings total");

done_testing;
