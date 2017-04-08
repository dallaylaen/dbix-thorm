use strict;
use warnings;

package DBIx::Thorm::Comparator;

our $VERSION = 0.0101;

use Carp;
use Exporter qw(import);
our @EXPORT = qw(smth);

use overload 
    '""' => "as_string",
    eq   => sub { $_[0]->as_string eq $_[1] },
    bool => sub { !$_[0]->is_empty },
    '&'  => sub { $_[0]->bit_and( $_[1] ) },
    '&&'  => sub { $_[0]->bit_and( $_[1] ) },
    '==' => sub { 
        DBIx::Thorm::Comparator::Whitelist->new($_[1])->bit_and($_[0]) },
    map { $_ => "xxx$_" } qw(< <= > >= lt le gt ge);

foreach (qw(< <= > >= lt le gt ge)) {
    my $sign = $_;
    my $method = "xxx$_";

    my $code = sub {
            my $self = shift;
            return $self->bit_and( 
                DBIx::Thorm::Comparator::Sign->new($sign, @_) );
    };
    no strict 'refs';
    *$method = $code;
};
# OOPS no new() here

sub smth () { ## no critic
    return bless {}, 'DBIx::Thorm::Comparator::True';
        # return class that matches everything
};

sub between {
    my ($self, $from, $to) = @_;

    return $self->bit_and( DBIx::Thorm::Comparator::Sign->new( ge => $from ) )
                ->bit_and( DBIx::Thorm::Comparator::Sign->new( le => $to ) );
};

sub in {
    my $self = shift;
    return DBIx::Thorm::Comparator::Whitelist->new(@_)->bit_and($self);
};

sub as_string {
    my $self = shift;
    my ($expr, $data) = $self->sql('smth');
    return @$data ? "$expr [@$data]" : $expr;
};

sub filter {
    my $self = shift;
    return grep { $self->match($_) } @_;
};

sub bit_and {
    my ($self, $other) = @_;
    return DBIx::Thorm::Comparator::And->new( $self, $other );
};

package DBIx::Thorm::Comparator::True;

our @ISA = qw(DBIx::Thorm::Comparator);

sub new {
    return bless {}; # no subclass here
};

sub bit_and {
    my ($self, $other) = @_;
    return $other;
};

sub match {
    return 1;
};

sub sql {
    return ('1=1', []);
};

sub is_empty {
    return '';
};


package DBIx::Thorm::Comparator::Whitelist;

our @ISA = qw(DBIx::Thorm::Comparator);

sub new {
    my $class = shift;
    my %white;
    $white{$_}++ for @_;
    return bless \%white;
};

sub bit_and {
    my ($self, $other) = @_;
    return DBIx::Thorm::Comparator::Whitelist->new( 
        $other->filter( keys %$self ));
};

sub match {
    my ($self, $x) = @_;
    return $self->{$x} || '';
};

sub sql {
    my ($self, $name) = @_;

    my $n = scalar keys %$self;
    return '1=0' unless $n;

    my $str = join ' OR ', ("$name = ?") x $n;
    $str = "($str)" if $n > 1;

    return ($str, [keys %$self]);
};

sub is_empty {
    my $self = shift;
    return !%$self;
};

package DBIx::Thorm::Comparator::Sign;

use Carp;
our @ISA = qw(DBIx::Thorm::Comparator);

my %comp_inv = (
    '<=' => '>=',
    '<'  => '>',
    'le' => 'ge',
    'lt' => 'gt',
);
%comp_inv = (%comp_inv, reverse %comp_inv);

sub new {
    my ($class, $sign, $arg, $inverse) = @_;

    croak "Unsupported operation $sign"
        unless $comp_inv{$sign};
    $sign = $comp_inv{$sign} if $inverse;

    return bless {
        sign => $sign,
        arg  => $arg,
        code => eval "sub { return \$_[0] $sign \$arg }",
    };
};

sub match {
    my ($self, $x) = @_;
    return $self->{code}->($x);
};

my %unperl = (
    ge   => '>=',
    gt   => '>',
    le   => '<=',
    lt   => '<',
    '>=' => '>=',
    '>'  => '>',
    '<=' => '<=',
    '<'  => '<',
);

sub sql {
    my ($self, $name) = @_;
    return ( "$name $unperl{$self->{sign}} ?", [$self->{arg}] );
};

sub is_empty {
    return '';
};

package DBIx::Thorm::Comparator::And;

our @ISA = qw(DBIx::Thorm::Comparator);

sub new {
    my $class = shift;

    my @comp = @_;
    # TODO compact list if possible

    return DBIx::Thorm::Comparator->new unless @comp;
    return bless { part => \@comp };
};

sub match {
    my ($self, $x) = @_;

    foreach my $check( @{ $self->{part} } ) {
        return '' unless $check->match($x);
    };

    return 1;
};

sub sql {
    my ($self, $name) = @_;

    my (@sql, @param);
    foreach my $part (@{ $self->{part} }) {
        my ($sql, $data) = $part->sql($name);
        push @sql, $sql;
        push @param, @$data;
    };
    my $str = join ' AND ', @sql;
    return ($str, \@param);
};

1;
