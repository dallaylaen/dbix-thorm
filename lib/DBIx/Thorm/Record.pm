package DBIx::Thorm::Record;

use strict;
use warnings;
our $VERSION = 0.0101;

sub new {
    use warnings FATAL => 'all';
    my $class = shift;
    return bless {@_}, $class;
};

# Just an empty class for isa check so far...

1;
