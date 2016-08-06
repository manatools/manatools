# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::BlockDevice;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::BlockDevice - a BlockDevice Moose Role

=head1 SYNOPSIS
    package Foo;

    with 'ManaTools::Shared::disk_backend::BlockDevice';

    1;

    ...

    my $f = Foo->new();
    $f->prop('dev', 'maj:min');
    $f->sync_majorminor();
    my $major = $f->major();
    my $minor = $f->minor();


=head1 DESCRIPTION

    This Role is an collection of BlockDevice in the backend to manadisk

=head1 SUPPORT

    You can find documentation for this Role with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::BlockDevice


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

## object DATA
has 'devicemm' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
        return [];
    }
);

has 'devicepath' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

#=============================================================

=head2 major

=head3 OUTPUT

    Int or undef

=head3 DESCRIPTION

    this method returns the major

=cut

#=============================================================
sub major {
    my $self = shift;
    my $mm = $self->devicemm();
    if (scalar(@{$mm}) > 1) {
        return $mm->[0];
    }
    return undef;
}

#=============================================================

=head2 minor

=head3 OUTPUT

    Int or undef

=head3 DESCRIPTION

    this method returns the minor

=cut

#=============================================================
sub minor {
    my $self = shift;
    my $mm = $self->devicemm();
    if (scalar(@{$mm}) > 1) {
        return $mm->[1];
    }
    return undef;
}

#=============================================================

=head2 is_device

=head3 OUTPUT

    1 if equal, 0 if not

=head3 DESCRIPTION

    this method checks if it's a certain device

=cut

#=============================================================
sub is_device {
    my $self = shift;
    my $major = shift;
    my $minor = shift;

    return $self->major() == $major && $self->minor() == $minor;
}

#=============================================================

=head2 clear_device

=head3 DESCRIPTION

    this method clears the devicemm

=cut

#=============================================================
sub clear_device {
    my $self = shift;
    my $mm = $self->devicemm();
    # clear out the array, keep the ref
    while (scalar(@{$mm}) > 0) {
        pop @{$mm};
    }
}

#=============================================================

=head2 sync_majorminor

=head3 DESCRIPTION

    this method resets the major and minor from the dev Property

=cut

#=============================================================
sub sync_majorminor {
    my $self = shift;
    # clear out the array, keep the ref
    $self->clear_device();
    if ($self->has_prop('dev')) {
        my @mm = split(':', $self->prop('dev'));
        if (scalar(@mm) > 1) {
            push @{$self->devicemm()}, $mm[0], $mm[1];
        }
    }
}

#=============================================================

=head2 find_path

=head3 DESCRIPTION

    this method finds in descendants the Mount part and gets the path from it

=cut

#=============================================================
sub find_path {
    my $self = shift;
    my $partstate = shift;
    # finding a path only works if one has a Mount or Mountable child,
    my @children = $self->children($partstate);
    for my $child (@children) {
        return $child->path() if ($child->isa('ManaTools::Shared::disk_backend::Part::Mount'));
        return $child->find_path($partstate) if ($child->does('ManaTools::Shared::disk_backend::Mountable'));
    }
    return undef;
}

1;
