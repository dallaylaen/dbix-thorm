package SQL::Decorate;

use strict;
use warnings;

use Carp;
use Exporter qw(import);
our @EXPORT = qw(decorate_query where_hash);

sub decorate_query {
    my ($query, @param) = @_;

    my @join;
    my @real_param;
    my $n;
    my $saved_n = scalar @param;
    while ( $query =~ s/(.*?)(?:([A-Za-z_]\w*)\.\?\?\?|(\?))//s ) {
        my ($plain, $prefix, $quest) = ($1, $2, $3);

        $n++;

        push @join, $plain;

        if ($quest) {
            my $sub = shift @param;
            croak "decorate_query: param $n: expected scalar, found ".ref $sub
                if ref $sub;
            push @join, $quest;
            push @real_param, $sub;
        }
        elsif ($prefix) {
            my $sub = shift @param;
            croak "decorate_query: param $n: expected hash, found scalar"
                if !ref $sub;

            my ($sql, @list) = where_hash( $sub, $prefix );
            push @join, $sql;
            push @real_param, @list;
        }
        else {
            die "Cannot be here";
        };
    };

    croak "decorate_query: expected $n positional parameters, got $saved_n"
        if $saved_n != $n;

    my $sql = join "", @join, $query;
    return ($sql, @real_param);
};

sub where_hash {
    my ($hash, $prefix) = @_;
    $prefix = (defined $prefix and length $prefix) ? "$prefix." : '';

    my @sql;
    my @param;
    foreach (keys %$hash) {
        if (defined $hash->{$_}) {
            push @sql, "$prefix$_ = ?";
            push @param, $hash->{$_};
        }
        else {
            push @sql, "$prefix$_ IS NULL";
        };
    };

    @sql = ('1=1') unless @sql;

    return (join( " AND ", @sql), @param);
};

1;
