package DBIx::Thorm::Record;

use strict;
use warnings;
our $VERSION = 0.0102;

=head1 NAME

DBIx::Thorm::Record - dumb record base class.

=cut

=head2 new( %hash )

Create object from hash. No checks whatsoever.

=cut

sub new {
    use warnings FATAL => 'all';
    my $class = shift;
    return bless {@_}, $class;
};

1;
