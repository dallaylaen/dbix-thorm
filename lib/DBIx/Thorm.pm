package DBIx::Thorm;

use 5.006;
use strict;
use warnings;
our $VERSION = 0.0101;

=head1 NAME

DBIx::Thorm - ORM that doesn't get in the way.

=head1 SYNOPSIS

    use DBIx::Thorm;

    thorm connect dbi => 'dbi:SQLite:dbname=...';
    my $ds = thorm table => 'foobar',
        key => 'id',
        fields => [qw[foo bar baz]];

    $ds->save({ foo => 42, bar => 137});
    $ds->save({ foo => 42 });
    my $data = $ds->lookup( order => '-foo', criteria => { bar => number > 100 } );
    forach (@$data) {
        ...
    };

=head1 EXPORT

=cut

use Carp;
use Exporter qw(import);

use Data::Criteria;
our @EXPORT = qw(thorm string number);

=head2 thorm operation => options ...

Shorthand frontend to DBIx::Thorm->operation( ... );

=cut

our $Inst = bless {};
sub thorm (@) {
    return $Inst unless @_;
    my $todo = shift;
    return $Inst->$todo(@_);
};

=head2 connect

=cut

sub connect {
    my ($self, %opt) = @_;

    $opt{name} ||= 'default'; # default conn
    $opt{dbi} or croak "thorm->connect: dbi is required";

    $self->{dbh}{ $opt{name} }
        and croak "thorm->connect: trying to set connection '$opt{name}' again";

    require DBI;
    my %extra = ( RaiseError => 1 );
    $extra{sqlite_unicode}++ if $opt{dbi} =~ /^dbi:SQLite/;

    $self->{dbh}{ $opt{name} } = DBI->connect(
        $opt{dbi}, $opt{user}, $opt{pass}, \%extra
    );

    return $self;
};

sub table {
    my ($self, $name, %opt) = @_;

    $opt{dbh} = $self->{dbh}{ $opt{dbh} || 'default' };

    # TODO lazy dbh
    # TODO save table inside
    require DBIx::Thorm::Source::SQLite;
    return DBIx::Thorm::Source::SQLite->new( %opt, table => $name );
};

sub dbh {
    my ($self, $name) = @_;
    $name ||= 'default';
    return $self->{dbh}{$name};
};

=head1 AUTHOR

Konstantin S. Uvarin, C<< <khedin at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-dbix-thorm at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBIx-Thorm>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DBIx::Thorm


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=DBIx-Thorm>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DBIx-Thorm>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DBIx-Thorm>

=item * Search CPAN

L<http://search.cpan.org/dist/DBIx-Thorm/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2017 Konstantin S. Uvarin.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of DBIx::Thorm
