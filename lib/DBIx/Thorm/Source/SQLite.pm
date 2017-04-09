package DBIx::Thorm::Source::SQLite;

use strict;
use warnings;
our $VERSION = 0.0103;

=head1 NAME

DBIx::Thorm::Source::SQLite - SQL-based storage for Thorm.

=head1 SYNOPSIS

    my $table = DBIx::Thorm::Source::SQLite->new(
        dbh    => $dbi_connect,
        table  => 'foobar',
        key    => foobar_id,
        fields => [qw[ foo bar baz ]],
    );

=cut

use Carp;

use parent qw(DBIx::Thorm::Source);
use DBIx::Thorm::Accumulator;

my $testbase;
sub new {
    my ($class, %opt) = @_;

    if ($opt{test}) {
        require DBI;
        require DBD::SQLite;
        $opt{dbh} = $testbase ||= DBI->connect(
            'dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1} );

        if ($opt{test} =~ /[A-Za-z]/) {
            /\S/ and $opt{dbh}->do($_) for split /;/, $opt{test};
        };
    };

    my @missing = grep { !$opt{$_} } qw(dbh table key);
    croak "$class->new: missing parameters @missing"
        if @missing;

    # some cache. fields* = array, names* = text, questions* = ?,?,...
    $opt{names_insert} = "(".join( ",", @{ $opt{fields} }).")";
    $opt{quest_insert} = "(".join( ",", ("?") x @{ $opt{fields} } ).")";
    $opt{quest_update} = join ",", map { "$_=?" } @{ $opt{fields} };
    $opt{names_select} = join ",", $opt{key}, @{ $opt{fields} };

    return $class->SUPER::new(%opt);
};

sub dbh {
    my $self = shift;
    return $self->{dbh};
};

# upsert
sub save {
    my ($self, $item) = @_;

    my $key = $self->{key};
    my $id = $item->{$key};

    if ($id) {
        my $sth = $self->_prepare(
            UPDATE => $self->{table},
            SET    => $self->{quest_update},
            WHERE  => $self->{key}, '= ?'
        );
        $sth->execute($id);
        if (!$sth->rows) {  
            # TODO decide later - maybe create still
            croak("save(): No such row, cannot update");
        };
        return $item;
    };

    # ELSE - create a new record from scratch
    my $sth = $self->_prepare(
        INSERT => INTO => $self->{table},
        $self->{names_insert},
        VALUES => $self->{quest_insert},
    );
    $sth->execute( map { $item->{$_} } @{ $self->{fields} } );
    $id = $self->{dbh}->last_insert_id('', '', $self->{table}, $self->{key});

    # TODO check & die here
    # TODO check already blessed
    return defined wantarray &&
        $self->get_class->new( %$item, $key => $id );
};

sub load {
    my ($self, $id) = @_;

    my $sth = $self->_prepare(
        SELECT => $self->{names_select},
        FROM   => $self->{table},
        WHERE  => "$self->{key} = ?");
    $sth->execute( $id );
    my $raw = $sth->fetchrow_hashref;
    if (!$raw) {
        # TODO die?
        return;
    };

    $sth->finish;
    return $self->get_class->new( %$raw );
};

sub lookup {
    my ($self, %opt) = @_;

    my $accum = DBIx::Thorm::Accumulator->new;
    my @order;
    foreach( ref $opt{order} ? @{$opt{order}} : $opt{order} ) {
        defined $_ or next;
        push @order, /^-(.*)/ ? "$1 DESC" : "$_";
    };
    my $order = @order ? "ORDER BY ".join ", ", @order : '';
    if ($opt{limit}) {
        $order .= " LIMIT ".(ref $opt{limit} ? join ",", @{$opt{limit}} : $opt{limit});
    };

    # TODO check that keys are within allowed

    my $sth = $self->_prepare(
        SELECT => $self->{names_select},
        FROM   => $self->{table},
        WHERE  => $accum->where($opt{criteria}),
        $order,
    );

    $sth->execute( $accum->list );
    my @ret;
    while (my $row = $sth->fetchrow_hashref) {
        push @ret, $self->get_class->new( %$row );
    };
    return \@ret;
};

sub _prepare {
    my ($self, @sql) = @_;

    return $self->{dbh}->prepare_cached(join " ", @sql);
};

1;
