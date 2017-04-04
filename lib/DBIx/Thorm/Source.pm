package DBIx::Thorm::Source;

use strict;
use warnings;
our $VERSION = 0.0101;

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

sub new {
    my ($class, %opt) = @_;
    $opt{class_prefix} ||= 'DBIx::Thorm::Record';
    return bless \%opt, $class;
};

sub get_class {
    my $self = shift;
    return $self->{class} ||= $self->make_class;
};

sub get_key {
    my $self = shift;
    return $self->{key};
};

sub spawn {
    my $self = shift;
    $self->get_class->new(@_);
};



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

my $id;
sub create_class_id {
    my $self = shift;

    return join "::", $self->{class_prefix}, "generated", ++$id;
};

sub _set_parent {
    my ($self, $target, $parent) = @_;

    $parent = [$parent] unless ref $parent eq 'ARRAY';
    no strict 'refs';
    push @{ join "::", $target, 'ISA' }, @$parent;
};

sub _set_method {
    my ($self, $target, $name, $code) = @_;

    croak ("Attempt to set duplicate method ${target}->${name}")
        if $target->can($name);

    no strict 'refs';
    *{ join "::", $target, $name } = $code;
};

1;
