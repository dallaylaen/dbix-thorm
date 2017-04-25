package SQL::Decorate;

use strict;
use warnings;
our $VERSION = 0.0101;

=head1 NAME

SQL::Decorate - SQL query templates with enhanced placeholders.

=head1 SYNOPSIS

    use SQL::Decorate;
    my $dec = SQL::Decorate->new;

    my ($query, @param) = $dec->decorate(
        "SELECT * FROM mytable t WHERE t=???" , { foo => 42, bar => undef } );
    # $query = SELECT ... WHERE t.bar IS NULL AND t.foo = ?
    # @param = [ 42 ]

=head1 METHODS

=cut

use Carp;

=head2 new()

Empty constructor, options TBD.

=cut

sub new {
    my ($class, %opt) = @_;

    return bless \%opt, $class;
};

=head2 decorate( $query_tpl, @arg_list )

Create a ($query, @param) pair.

Every '?' in the template MUST correspond to a scalar parameter in the list.

Every '???' in the template MUST correspond to a hash in the list.

The hash is processed as follows:

A t=??? is converted to a list of t.(something) = ?.

If a space-separated list in brackets follows ???, ONLY fields in the list
are taken into account.

Hash values are pushed to param list in appropriate orders.

TBD:

=over

=item * [SELECT] ALL:??? - generate a list of values to select from table.

=item * ORDER:??? - generate order and  limits

=item * [UPDATE] SET:??? - generate update query

=item * [INSERT] VALUES:??? - generate (foo,bar) VALUES (?,?)

=back

=cut

# ident + '='|':' + ??? + maybe [foo bar]
my $re_subst = qr/([A-Za-z_]\w*)\s*([=:])\s*\?\?\?(?:\[(.*?)\])?/;

sub decorate {
    my ($self, $query, @param) = @_;

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

            
            my ($sql, @list) = $self->where( $sub, $prefix, $slice );
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

=head2 where( \%criteria, "table_alias", \@fields )

Returns ($where_clause, @param_list).

Table name MAY be empty, field names will be used as is in such case.

If a hash value is blessed, try calling sql("key") method on it.

=cut

sub where {
    my ($self, $hash, $prefix, $fields) = @_;
    $prefix = (defined $prefix and length $prefix) ? "$prefix." : '';

    my @fields = $fields
        ? grep { exists $hash->{$_} } @$fields
        : sort keys %$hash; # always sort to increase cache hits
    my @sql;
    my @param;
    foreach (@fields) {
        if (ref $hash->{$_}) {
            my ($sql, $arg) = $hash->{$_}->sql("$prefix$_");
            push @sql, $sql;
            push @param, @$arg;
        }
        elsif (defined $hash->{$_}) {
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
