# vim: set et ts=4 sw=4:
package ManaTools::Shared::PropertiesRole;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::PropertiesRole - a Properties Moose::Role

=head1 SYNOPSIS
    package Foo;

    with 'ManaTools::Shared::PropertiesRole';

    1;

    ...

    my $f = Foo->new();
    my @props = $f->properties();
    my $vendor = $f->prop('vendor');
    $f->prop('vendor', 'myself');
    $f->remove('vendor');
    $f->prop_from_file('vendor', '/sys/bus/scsi/2:0:0:0/vendor');


=head1 DESCRIPTION

    This Role is a collection of Properties

=head1 SUPPORT

    You can find documentation for this Role with the perldoc command:

    perldoc ManaTools::Shared::PropertiesRole


=head1 AUTHOR

    Maarten Vanraes <alien@rmail.be>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2015 Maarten Vanraes <alien@rmail.be>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2, as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=head1 METHODS

=cut

use Moose::Role;

has 'props', is => 'ro', isa => 'HashRef[Item]', lazy => 1, default => sub {return {};};

#=============================================================

=head2 properties

=head3 OUTPUT

    array of string

=head3 DESCRIPTION

    this method returns a list of Property keys

=cut

#=============================================================
sub properties {
    my $self = shift;

    return keys %{$self->props()};
}

#=============================================================

=head2 has_prop

=head3 INPUT

    $key: string

=head3 OUTPUT

    1 if Property is assigned, 0 otherwise

=head3 DESCRIPTION

    this method checks if it has the properties assigned

=cut

#=============================================================
sub has_prop {
    my $self = shift;
    my $key = shift;
    return defined $self->props()->{$key};
}

#=============================================================

=head2 prop

=head3 INPUT

    $key: string
    $value: optional value to set

=head3 OUTPUT

    value of the Property

=head3 DESCRIPTION

    this method gets the value of a Property and optionally sets it

=cut

#=============================================================
sub prop {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    if (defined $value) {
        $self->props()->{$key} = $value;
    }
    if (defined $self->props()->{$key}) {
        return $self->props()->{$key};
    }
    return undef;
}

#=============================================================

=head2 prop_from_file

=head3 INPUT

    $key: string
    $file: file with value to set

=head3 OUTPUT

    value of the Property, or undef if failed

=head3 DESCRIPTION

    this method sets the value of a Property from a file and returns the value

=cut

#=============================================================
sub prop_from_file {
    my $self = shift;
    my $key = shift;
    my $file = shift;
    open F, '<'. $file or return undef;
    my $value = <F>;
    close F;
    chomp($value) if defined $value;
    return $self->prop($key, $value);
}

#=============================================================

=head2 remove

=head3 INPUT

    $key: string

=head3 DESCRIPTION

    this method removes a property

=cut

#=============================================================
sub remove {
    my $self = shift;
    my $key = shift;

    delete $self->props()->{$key};
}

1;

