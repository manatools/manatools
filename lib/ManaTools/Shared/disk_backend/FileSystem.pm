# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::FileSystem;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::FileSystem - a FileSystem Moose Role

=head1 SYNOPSIS
    package Foo;

    with 'ManaTools::Shared::disk_backend::FileSystem';

    1;

    ...

    my $f = Foo->new();
    my $in = $f->fsprobe($io);


=head1 DESCRIPTION

    This Role is an collection of FileSystem in the backend to manadisk

=head1 SUPPORT

    You can find documentation for this Role with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::FileSystem


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

#=============================================================

=head2 fsprobe

=head3 INPUT

    $io: ManaTools::Shared::disk_backend::IO

=head3 OUTPUT

    ManaTools::Shared::disk_backend::IO or undef

=head3 DESCRIPTION

    this method probes the IO to see if it fits for this
    filesystem, if it does, create a new Part with this IO as in.
    also create an IO (linked as the out) and return that one.
    The resulting one can then be used as an in to eg: a Mount Part.

=cut

#=============================================================

requires 'fsprobe';

has 'fstypes' => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    init_arg => undef,
    default => sub { return []; },
);

#=============================================================

=head2 has_type

=head3 INPUT

    $type: Str

=head3 OUTPUT

    1 | 0

=head3 DESCRIPTION

    this method checks if this particular plugin can handle
    the given filesystem.

=cut

#=============================================================

sub has_type {
    my $self = shift;
    my $type = shift;
    my $fstypes = $self->fstypes();
    for my $t (@{$fstypes}) {
        if ($t eq $type) {
            return 1;
        }
    }
    return 0;
}

package ManaTools::Shared::disk_backend::IOFS;

use Moose::Role;

package ManaTools::Shared::disk_backend::FileRole;

use Moose::Role;

has 'fs' => (
    is => 'rw',
    does => 'ManaTools::Shared::disk_backend::IOFS',
    required => 1,
);

has 'path' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

1;
