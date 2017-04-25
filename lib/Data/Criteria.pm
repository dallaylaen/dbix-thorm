use strict;
use warnings;

package Data::Criteria;

our $VERSION = 0.0104;

=head1 NAME

Data::Criteria - generate string & number sets using overloaded comparisons

=head1 SYNOPSIS

    use Data::Criteria;

    my $other_user = (number > 0) & (number != $uid);

    0 =~ $other_user; # false
    $uid =~ $other_user; # false
    100500 =~ $other_user; # true unless == $uid

    # generate 'user_id > 0 AND user_id <> ?
    my ($sql, @param) = $other_user->sql("user_id");

=cut

use Carp;
use Exporter qw(import);
our @EXPORT = qw(string number);
our @EXPORT_OK = qw(whitelist blacklist);

=head1 PROTOTYPED SUGAR

=head2 string()

Returns an empty criterion object matching any string.

=cut

sub string () {
    return __PACKAGE__->new;
};

=head2 number()

Returns a criterion object matching any number.

=cut

sub number () {
    return Data::Criteria::Number->new;
};

=head2 whitelist

=head2 blacklist

=cut

sub blacklist {
    return Data::Criteria->new(@_);
};

sub whitelist {
    return Data::Criteria::Whitelist->new(@_);
};

=head2 operators

=cut

use overload
    '""' => "as_string",
    bool => "is_nonempty",
    'eq' => sub { $_[0]->as_string eq $_[1] }, # this is for Test::More's is() to work
    '&'  => 'bit_and',
    '|'  => 'bit_or',
    '==' => sub { whitelist($_[1])->bit_and($_[0]) },
    '!=' => sub { blacklist($_[1])->bit_and($_[0]) },
    '<'  => 'and_lt',
    '<=' => 'and_le',
    '>'  => 'and_gt',
    '>=' => 'and_ge',
    ;

=head1 METHODS

=head2 new

=cut

# implement blacklist as default
sub new {
    my $class = shift;
    my %black;
    $black{$_}++ for grep defined, @_;
    return bless { black => \%black }, $class;
};

=head2 bit_and( $other )

Overloaded &.

=cut

sub bit_and {
    return Data::Criteria::And->new( $_[0], $_[1] );
};

=head2 bit_or( $other )

Overloaded |.

=cut

sub bit_or {
    return Data::Criteria::Or->new( $_[0], $_[1] );
};

=head2 between( $min, $max )

=cut

sub between {
    my ($self, $from, $to) = @_;
    return $self->and_ge( $from )->and_le( $to );
};

=head2 in (@whitelist)

Create whitelist. Arguments will be filtered using current criteria.

=cut

sub in {
    my $self = shift;
   return Data::Criteria::Whitelist->new(@_)->bit_and($self);
};

=head2 match( $value )

Return true if value matches criteria.
Overloaded =~.

=cut

sub match {
    my ($self, $x) = @_;
    return !$self->{black}{$x};
};

=head2 filter( @array )

Return array of matching values.

=cut

sub filter {
    my $self = shift;
    return grep { $self->match($_) } @_;
};

=head2 as_string

Currently returns SQL with sane default as field name.

=cut

sub as_string {
    my $self = shift;
    my ($expr, $data) = $self->sql('string');
    return @$data ? "$expr [@$data]" : $expr;
};

=head2 sql( "field_name" )

Returns SQL Statement suitable for WHERE.

=cut

sub sql {
    my ($self, $name) = @_;
    my @arg = keys %{ $self->{black} };
    my @sql = ("$name <> ?") x @arg;
    my $sql = @sql ? join ' AND ', @sql : '1=1';
    return ($sql, \@arg );
};

=head2 is_nonempty

Returns true iff any value COULD match given criteria.

=cut

sub is_nonempty {
    return 1;
};

=head2 is_true

Returns true iff ANY value matches given criteria.
CAUTION: A true numeric criteria is still going to only match numbers.

=cut

sub is_true {
    my $self = shift;
    return !keys %{ $self->{black} };
};

# subclass generator

my %inv = (
    lt => 'gt',
    le => 'ge',
);
%inv = (%inv, reverse %inv);

sub _false { return '' };
sub _subclass_op {
    my ($basic, $op, $sign, $code) = @_;

    my $new = sub {
        my ($class, $arg) = @_;
        return $basic->new unless defined $arg;
        croak "Bad argument $arg for class $class"
            unless $basic->new->match($arg);
        return bless { arg => $arg }, $class;
    };
    my $sql = sub {
        my ($self, $name) = @_;
        return ("$name $sign ?", [$self->{arg}]);
    };
    my $pkg = "${basic}::$op";
    my $add_op = sub {
        my ($self, $arg) = @_;
        return $self->bit_and( $pkg->new($arg) );
    };
    if ($inv{$op}) {
        my $inv_pkg = "${basic}::$inv{$op}";
        $add_op = sub {
            my ($self, $arg, $inverse) = @_;
            return $self->bit_and( ($inverse ? $inv_pkg : $pkg)->new($arg) );
        };
    };

    no strict 'refs'; ## no critic # monkeypatch...
    @{"${pkg}::ISA"} = $basic;
    *{"${pkg}::new"} = $new;
    *{"${pkg}::match"} = $code;
    *{"${pkg}::sql"} = $sql;
    *{"${pkg}::is_true"} = \&_false;
    *{"${basic}::and_$op"} = $add_op;

    return $basic;
};

=head2 and_lt( $value )

=head2 and_le( $value )

=head2 and_ge( $value )

=head2 and_gt( $value )

Add corresponding operator to criteria.

=cut

__PACKAGE__->_subclass_op( lt => '<'  => sub { defined $_[1] and $_[1] lt $_[0]->{arg} } );
__PACKAGE__->_subclass_op( le => '<=' => sub { defined $_[1] and $_[1] le $_[0]->{arg} } );
__PACKAGE__->_subclass_op( ge => '>=' => sub { defined $_[1] and $_[1] ge $_[0]->{arg} } );
__PACKAGE__->_subclass_op( gt => '>'  => sub { defined $_[1] and $_[1] gt $_[0]->{arg} } );

package Data::Criteria::Number;

=head1 NAME

Data::Criteria::Number - numeric criteria

=head1 METHODS

=cut

use Scalar::Util qw(looks_like_number);
our @ISA = qw(Data::Criteria);

=head2 new

Create new numeric criteria.

=cut

sub new {
    my $self = shift;
    return $self->SUPER::new( grep { defined $_ and looks_like_number $_ } @_ );
};

=head2 match

Matches any number that satisfies given criteria.

=cut

sub match {
    my ($self, $arg) = @_;
    return looks_like_number($arg) && !$self->{black}{$arg};
};

=head2 as_string

Overloaded stringify, currently uses SQL.

=cut

sub as_string {
    my $self = shift;

    my ($expr, $data) = $self->sql('number');
    return @$data ? "$expr [@$data]" : $expr;
};

=head2 and_lt( $value )

=head2 and_le( $value )

=head2 and_ge( $value )

=head2 and_gt( $value )

Add corresponding operator to criteria.

=cut

{
    no warnings 'uninitialized'; ## no critic
    # undef doesn't look like number anyway, so it would yield false
    __PACKAGE__->_subclass_op( lt => '<'  => sub { looks_like_number $_[1] and $_[1] <  $_[0]->{arg} } );
    __PACKAGE__->_subclass_op( le => '<=' => sub { looks_like_number $_[1] and $_[1] <= $_[0]->{arg} } );
    __PACKAGE__->_subclass_op( ge => '>=' => sub { looks_like_number $_[1] and $_[1] >= $_[0]->{arg} } );
    __PACKAGE__->_subclass_op( gt => '>'  => sub { looks_like_number $_[1] and $_[1] >  $_[0]->{arg} } );
}

package Data::Criteria::Whitelist;

=head1 NAME

Data::Criteria::Whitelist - a fixed list of data to be matched against.

=cut

our @ISA = qw(Data::Criteria);

=head2 new( @list )

=cut

sub new {
    my $class = shift;
    my %white;
    $white{$_}++ for @_;
    return bless { white => \%white}, $class;
};

=head2 bit_and( $other )

For speed, filter data through $other and return a new whitelist.

=cut

sub bit_and {
    my ($self, @other) = @_;

    my @white = keys %{ $self->{white} };
    @white = $_->filter(@white) for @other;

    return Data::Criteria::Whitelist->new( @white );
};

=head2 match ($value)

=cut

sub match {
    my ($self, $x) = @_;
    return $self->{white}{$x} || '';
};

=head2 sql( "field_name" )

=cut

sub sql {
    my ($self, $name) = @_;

    my $n = scalar keys %{ $self->{white} };
    return '1=0' unless $n;

    my $str = join ' OR ', ("$name = ?") x $n;
    $str = "($str)" if $n > 1;

    return ($str, [keys %{ $self->{white} }]);
};

=head2 is_nonempty

=cut

sub is_nonempty {
    my $self = shift;
    return !! %{ $self->{white} };
};

=head2 is_true

Always false.

=cut

sub is_true {
    return '';
};

package Data::Criteria::And;

=head1 NAME

Data::Criteria::And - set intersection.

=cut

our @ISA = qw(Data::Criteria);

=head2 new( @list_of_criteria )

MAY return other types depending on arguments (empty list etc.)

=cut

sub new {
    my $class = shift;
    my @args;

    # first, filter out args & short circuit, if possible
    foreach (@_) {
        $_->is_nonempty or return $_;
        $_->is_true and next;
        ref $_ eq 'Data::Criteria::Whitelist'
            and return $_->bit_and(@_);
        push @args, $_;
    };

    # if 0-1 args, && op is trivial
    return Data::Criteria->new unless @args;
    return $args[0] if @args == 1;

    # ok, the hard part
    return bless { part => \@args }, $class;
};

=head2 match( $value )

=cut

sub match {
    my ($self, $x) = @_;

    $_->match($x) or return '' for @{ $self->{part} };
    return 1;
};

=head2 sql( "field_name" )

=cut

sub sql {
    my ($self, $name) = @_;

    my @sql;
    my @data;

    foreach (@{ $self->{part} }) {
        my ($sql, $arg) = $_->sql($name);
        push @sql, $sql;
        push @data, @$arg;
    };

    push @sql, '1=1' unless @sql;
    return ((join ' AND ', @sql), \@data);
};

=head2 is_true

Always false.

=cut

sub is_true {
    return '';
};

package Data::Criteria::Or;

=head1 NAME

Data::Criteria::Or - set union.

=cut

use Scalar::Util qw(blessed);

our @ISA = qw(Data::Criteria);

=head2 new( @list_of_criteria )

MAY return other types depending on arguments (empty list etc.)

=cut

sub new {
    my $class = shift;
    my @args;

    # first, filter out args & short circuit, if possible
    foreach (@_) {
        if (!ref $_) {
            push @args, defined $_
                ? Data::Criteria::Whitelist->new($_)
                : Data::Criteria::Null->new;
            next;
        };
        $_->is_true and return $_;
        $_->is_nonempty or next;
        push @args, $_;
    };

    # if 0-1 args, && op is trivial
    return Data::Criteria::Whitelist->new unless @args;
    return $args[0] if @args == 1;

    # ok, the hard part
    return bless { part => \@args }, $class;
};

=head2 match( $value )

=cut

sub match {
    my ($self, $x) = @_;

    $_->match($x) and return 1 for @{ $self->{part} };
    return '';
};

=head2 sql( "field_name" )

=cut

sub sql {
    my ($self, $name) = @_;

    my @sql;
    my @data;

    foreach (@{ $self->{part} }) {
        my ($sql, $arg) = $_->sql($name);
        $sql =~ /^\((.*)\)$/ and $sql = $1;
        push @sql, $sql;
        push @data, @$arg;
    };

    push @sql, '1=0' unless @sql;
    my $str = join ' OR ', @sql;
    $str = "($str)" if @sql > 1;

    return ($str, \@data);
};


=head2 is_true

Always false.

=cut

sub is_true {
    return '';
};

package Data::Criteria::Null;

our @ISA = qw(Data::Criteria);

my $Inst = bless {}, __PACKAGE__;
sub new {
    return $Inst;
};

sub is_true {
    return '';
};

sub is_nonempty {
    return 1;
};

sub match {
    return !defined $_[1];
};

sub sql {
    return "$_[1] IS NULL";
};

1;
