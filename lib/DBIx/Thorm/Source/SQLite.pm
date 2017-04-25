package DBIx::Thorm::Source::SQLite;

use strict;
use warnings;
our $VERSION = 0.0106;

=head1 NAME

DBIx::Thorm::Source::SQLite - SQL-based storage for Thorm.

=head1 SYNOPSIS

    my $table = DBIx::Thorm::Source::SQLite->new(
        dbh    => $dbi_connect,
        table  => 'foobar',
        key    => foobar_id,
        fields => [qw[ foo bar baz ]],
    );

=head1 methods

=cut

use Carp;
use Scalar::Util qw(blessed);

use parent qw(DBIx::Thorm::Source);
use SQL::Decorate;

=head2 new( %options )

%options MUST include: dbh, table, key, fields=[]

=cut

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

    # prepare for SQL::Decorate
    $opt{sql_lookup} = join " ",
        SELECT => $opt{names_select},
        FROM   => $opt{table} => "t",
        WHERE  => "t=???";

    return $class->SUPER::new(%opt);
};

=head2 dbh

Get database handle.

=cut

sub dbh {
    my $self = shift;
    return $self->{dbh};
};

=head2 save( $record || \%hash )

Save an object. If key is present, try updating first; otherwise insert.
A plain hash may be supplied as well.

Returned is always an object of contained class, key is guaranteed on return.

=cut

# upsert
sub save {
    my ($self, $item) = @_;

    my $key = $self->{key};
    my $id = $item->{$key};

    if ($id) {
        # TODO only update needed fields - when SQL::Decorate can do it
        my $sth = $self->_prepare(
            UPDATE => $self->{table},
            SET    => $self->{quest_update},
            WHERE  => $self->{key}, '= ?'
        );
        my @arg = map { $item->{$_} } @{ $self->{fields} };
        push @arg, $id;
        $sth->execute(@arg);
        if ($sth->rows < 1) {
            # TODO decide later - maybe create still
            croak("save(): No such row, cannot update");
        };
        return blessed $item ? $item : $self->get_class->new(%$item);
    };

    # ELSE - create a new record from scratch
    my $sth = $self->_prepare(
        INSERT => INTO => $self->{table},
        $self->{names_insert},
        VALUES => $self->{quest_insert},
    );
    $sth->execute( map { $item->{$_} } @{ $self->{fields} } );
    # TODO check & die here

    if (defined wantarray) {
        $id = $self->{dbh}->last_insert_id('', '', $self->{table}, $self->{key});

        # TODO check already blessed
        return $self->get_class->new( %$item, $key => $id );
    };
};

=head2 load( $id )

Load a record by key value, if present.

=cut

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

=head2 lookup( %options )

%options may include:

=over

=item * criteria - a \%hash of values, undefs, or Data::Criteria objects

=item * order - a \@list of "field" or "-field" (for DESC).

=item * limit - a \@list for limit (this MAY change in the foture)

=back

=cut

sub lookup {
    my ($self, %opt) = @_;

    my $dec = SQL::Decorate->new;
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
    my ($sql, @arg) = $dec->decorate( $self->{sql_lookup}, $opt{criteria} );

    my $sth = $self->_prepare( $sql." ".$order );
    $sth->execute( @arg );
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
