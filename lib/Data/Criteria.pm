use strict;
use warnings;

package Data::Criteria;

our $VERSION = 0.0102;

use Carp;
use Exporter qw(import);
our @EXPORT = qw(string number);
our @EXPORT_OK = qw(whitelist blacklist);

# prototyped sugar
sub string () {
    return __PACKAGE__->new;
};

sub number () {
    return Data::Criteria::Number->new;
};

sub blacklist {
    return Data::Criteria->new(@_);
};

sub whitelist {
    return Data::Criteria::Whitelist->new(@_);
};

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

# some basic funs

sub bit_and {
    return Data::Criteria::And->new( $_[0], $_[1] );
};

sub bit_or {
    return Data::Criteria::Or->new( $_[0], $_[1] );
};

sub between {
    my ($self, $from, $to) = @_;
    return $self->and_ge( $from )->and_le( $to );
};

sub in {
    my $self = shift;
   return Data::Criteria::Whitelist->new(@_)->bit_and($self);
};

sub filter {
    my $self = shift;
    return grep { $self->match($_) } @_;
};

sub as_string {
    my $self = shift;
    my ($expr, $data) = $self->sql('string');
    return @$data ? "$expr [@$data]" : $expr;
};


# implement blacklist as default
sub new {
    my $class = shift;
    my %black;
    $black{$_}++ for grep defined, @_;
    return bless { black => \%black }, $class;
};

sub match {
    my ($self, $x) = @_;
    return !$self->{black}{$x};
};

sub sql {
    my ($self, $name) = @_;
    my @arg = keys %{ $self->{black} };
    my @sql = ("$name <> ?") x @arg;
    my $sql = @sql ? join ' AND ', @sql : '1=1';
    return ($sql, \@arg );
};

sub is_nonempty {
    return 1;
};

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

    no strict 'refs';
    @{"${pkg}::ISA"} = $basic;
    *{"${pkg}::new"} = $new;
    *{"${pkg}::match"} = $code;
    *{"${pkg}::sql"} = $sql;
    *{"${pkg}::is_true"} = \&_false;
    *{"${basic}::and_$op"} = $add_op;

    return $basic;
};

__PACKAGE__->_subclass_op( lt => '<'  => sub { $_[1] lt $_[0]->{arg} } );
__PACKAGE__->_subclass_op( le => '<=' => sub { $_[1] le $_[0]->{arg} } );
__PACKAGE__->_subclass_op( ge => '>=' => sub { $_[1] ge $_[0]->{arg} } );
__PACKAGE__->_subclass_op( gt => '>'  => sub { $_[1] gt $_[0]->{arg} } );

package Data::Criteria::Number;

use Scalar::Util qw(looks_like_number);
our @ISA = qw(Data::Criteria);

sub match {
    my ($self, $arg) = @_;
    return looks_like_number($arg) && !$self->{black}{$arg};
};

sub new {
    my $self = shift;
    return $self->SUPER::new( grep { defined $_ and looks_like_number $_ } @_ );
};

sub as_string {
    my $self = shift;

    my ($expr, $data) = $self->sql('number');
    return @$data ? "$expr [@$data]" : $expr;
};

__PACKAGE__->_subclass_op( lt => '<'  => sub { looks_like_number $_[1] and $_[1] <  $_[0]->{arg} } );
__PACKAGE__->_subclass_op( le => '<=' => sub { looks_like_number $_[1] and $_[1] <= $_[0]->{arg} } );
__PACKAGE__->_subclass_op( ge => '>=' => sub { looks_like_number $_[1] and $_[1] >= $_[0]->{arg} } );
__PACKAGE__->_subclass_op( gt => '>'  => sub { looks_like_number $_[1] and $_[1] >  $_[0]->{arg} } );

package Data::Criteria::Whitelist;

our @ISA = qw(Data::Criteria);

sub new {
    my $class = shift;
    my %white;
    $white{$_}++ for @_;
    return bless { white => \%white}, $class;
};

sub bit_and {
    my ($self, @other) = @_;

    my @white = keys %{ $self->{white} };
    @white = $_->filter(@white) for @other;

    return Data::Criteria::Whitelist->new( @white );
};

sub match {
    my ($self, $x) = @_;
    return $self->{white}{$x} || '';
};

sub sql {
    my ($self, $name) = @_;

    my $n = scalar keys %{ $self->{white} };
    return '1=0' unless $n;

    my $str = join ' OR ', ("$name = ?") x $n;
    $str = "($str)" if $n > 1;

    return ($str, [keys %{ $self->{white} }]);
};

sub is_nonempty {
    my $self = shift;
    return !! %{ $self->{white} };
};

sub is_true {
    return '';
};

package Data::Criteria::And;

our @ISA = qw(Data::Criteria);

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

sub match {
    my ($self, $x) = @_;

    $_->match($x) or return '' for @{ $self->{part} };
    return 1;
};

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

sub is_true {
    return '';
};

package Data::Criteria::Or;

our @ISA = qw(Data::Criteria);

sub new {
    my $class = shift;
    my @args;

    # first, filter out args & short circuit, if possible
    foreach (@_) {
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

sub match {
    my ($self, $x) = @_;

    $_->match($x) and return 1 for @{ $self->{part} };
    return '';
};

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

sub is_true {
    return '';
};

1;
