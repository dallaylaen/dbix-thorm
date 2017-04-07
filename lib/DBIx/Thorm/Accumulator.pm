package DBIx::Thorm::Accumulator;

use strict;
use warnings;
our $VERSION = 0.0101;

sub new {
    return bless { list => [] }, shift;
};

sub where {
    my ($self, $crit) = @_;

    my @ret;
    foreach (keys %$crit) {
        # TODO add >=, <=, IN, BETWEEN etc
        if (defined $crit->{$_}) {
            push @ret, "$_ = ?";
            push @{ $self->{list} }, $crit->{$_};
        } else {
            push @ret, "$_ IS NULL";
        };
    };

    @ret = '1=1' unless @ret;
    return '('.(join ' AND ', @ret).')';
};

sub list {
    my $self = shift;
    return @{ $self->{list} };
};


1;
