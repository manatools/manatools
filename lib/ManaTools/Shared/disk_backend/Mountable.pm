# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::Mountable;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::Mountable - a Mountable Moose Role

=head1 SYNOPSIS
    package Foo;

    with 'ManaTools::Shared::disk_backend::Mountable';

    1;

    ...

    my $f = Foo->new();
    $f->prop('dev', 'maj:min');
    $f->sync_majorminor();
    my $major = $f->major();
    my $minor = $f->minor();


=head1 DESCRIPTION

    This Role is an collection of Mountable in the backend to manadisk

=head1 SUPPORT

    You can find documentation for this Role with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::Mountable


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

requires '_get_mount_source';

has 'mountsource' => (
    is => 'ro',
    isa => 'Maybe[Str]',
);

around 'mountsource' => sub {
    my $orig = shift;
    my $self = shift;

    return $self->_get_mount_source();
};

has 'mountsourcepath' => (
    is => 'ro',
    isa => 'Str',
    default => '/',
);

sub mountsourcedevice {
    my $self = shift;
    my $mountsource = $self->mountsource();
    my @s = stat($mountsource);
    # check if found and blockdevice
    return $mountsource if (scalar(@s) < 7 || ($s[2] >> 12) != 6);

    # get the major and minor
    my $minor = $s[6] % 256;
    my $major = int (($s[6] - $minor) / 256);
    return $major .':'. $minor;
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
