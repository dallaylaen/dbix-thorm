package DBIx::Thorm::Source;

use strict;
use warnings;
our $VERSION = 0.0102;

=head1 NAME

DBIx::Thorm::Source - Data source base class of Thorm.

=head1 SYNOPSIS

This is actually going to happen to a subclass.

    my $source = DBIx::Thorm::Source->new( ... );
    my $data = $source->spawn( ... );
    $data->save;

=head1 DESCRIPTION

This class describes a source of stored data.
For each new source, a new B<package> based on L<DBIx::Thorm::Record>
will be generated.

=head1 METHODS

=cut

use Carp;

use DBIx::Thorm::Record;

=head2 new( %options )

%options may include:

=over

=item * key (required) - the identifier field in record;

=item * class_prefix - prefix for generated class name
(default = DBIx::Thorm::Record);

=item * class - override class name altogether
(default = <prefix>::generated::$uniq_integer_id;

=back

=cut

sub new {
    my ($class, %opt) = @_;
    $opt{class_prefix} ||= 'DBIx::Thorm::Record';
    $opt{key}
        or croak "$class->new: required parameter missing: 'key'";
    return bless \%opt, $class;
};

=head2 get_class

Returns class of contained objects.
Class generation happens here if needed.

=cut

sub get_class {
    my $self = shift;
    return $self->{class} ||= $self->make_class;
};

=head2 get_key

Return the key field.

=cut

sub get_key {
    my $self = shift;
    return $self->{key};
};

=head2 spawn( %options )

Create a new record with desired fields. Not saved anywhere by default.

=cut

sub spawn {
    my $self = shift;
    $self->get_class->new(@_);
};

=head2 make_class( %options )

Generate methods for record class. Dragons be here, use with caution.

=cut

sub make_class {
    my ($self, %opt) = @_;

    my $name       = $opt{name} || $self->create_class_id;
    confess "No name!" unless $name;
    $opt{parent} ||= ['DBIx::Thorm::Record'];
    $opt{fields} ||= $self->{fields};
    $opt{key}    ||= $self->{key};

    $self->_set_parent( $name, $opt{parent} );
    $self->_set_method( $name, save => sub { $self->save( shift ) });

    # get+set
    foreach ($opt{key}, @{ $opt{fields} }) {
        my $method = $_;
        $self->_set_method( $name, $method, sub {
            return $_[0]->{ $method } if @_ == 1;
            $_[0]->{ $method } = $_[1];
            return $_[0];
        } );
    };

    return $name;
};

=head2 create_class_id

Autogenerate unique class name.

=cut

my $id;
sub create_class_id {
    my $self = shift;

    return join "::", $self->{class_prefix}, "generated", ++$id;
};

sub _set_parent {
    my ($self, $target, $parent) = @_;

    $parent = [$parent] unless ref $parent eq 'ARRAY';
    no strict 'refs'; ## no critic
    push @{ join "::", $target, 'ISA' }, @$parent;
};

sub _set_method {
    my ($self, $target, $name, $code) = @_;

    croak ("Attempt to set duplicate method ${target}->${name}")
        if $target->can($name);

    no strict 'refs'; ## no critic
    *{ join "::", $target, $name } = $code;
};

1;
