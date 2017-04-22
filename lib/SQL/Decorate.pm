package SQL::Decorate;

use strict;
use warnings;

use Carp;
use Exporter qw(import);
our @EXPORT = qw(decorate_query where_hash);

# ident + '='|':' + ??? + maybe [foo bar]
my $re_subst = qr/([A-Za-z_]\w*)\s*([=:])\s*\?\?\?(?:\[(.*?)\])?/;

sub decorate_query {
    my ($query, @param) = @_;

    my @join;
    my @real_param;
    my $n;
    my $saved_n = scalar @param;
    while ( $query =~ s/^(.*?)(?:$re_subst|(\?))//s ) {
        my ($plain, $prefix, $oper, $slice, $quest) = ($1, $2, $3, $4, $5);

        $n++;
        $slice &&= [ split /\s+/, $slice ];
        push @join, $plain;

        if ($quest) {
            my $sub = shift @param;
            croak "decorate_query: param $n: expected scalar, found ".ref $sub
                if ref $sub;
            push @join, $quest;
            push @real_param, $sub;
        }
        elsif ($oper eq '=') {
            my $sub = shift @param;
            croak "decorate_query: param $n: expected hash, found scalar"
                if !ref $sub;

            
            my ($sql, @list) = where_hash( $sub, $prefix, $slice );
            push @join, $sql;
            push @real_param, @list;
        }
        elsif ($oper eq ':') {
            croak "Unknown operation: '$prefix$oper???'";
        }
        else {
            die "Cannot be here";
        };
    }; # end while ( =~ )

    croak "decorate_query: expected $n positional parameters, got $saved_n"
        if $saved_n != $n;

    my $sql = join "", @join, $query;
    return ($sql, @real_param);
};

sub where_hash {
    my ($hash, $prefix, $fields) = @_;
    $prefix = (defined $prefix and length $prefix) ? "$prefix." : '';

    my @fields = $fields
        ? grep { exists $hash->{$_} } @$fields
        : sort keys %$hash; # always sort to increase cache hits
    my @sql;
    my @param;
    foreach (@fields) {
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
