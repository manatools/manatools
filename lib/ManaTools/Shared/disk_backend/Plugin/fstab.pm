# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::Plugin::fstab;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::Plugin::fstab - fstab object

=head1 SYNOPSIS

    use ManaTools::Shared::disk_backend::Plugin::fstab;

    my $db_man = ManaTools::Shared::disk_backend::Plugin::fstab->new($parent);
    ...


=head1 DESCRIPTION

    This plugin is a fstab plugin for the backend to manadisk

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::Plugin::fstab


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

use Moose;

use File::Basename;

extends 'ManaTools::Shared::disk_backend::Plugin';

has 'lines', is => 'rw', isa => 'ArrayRef[Str]', lazy => 1, default => sub {return [];};
has 'index', is => 'rw', isa => 'ArrayRef[Maybe[ManaTools::Shared::disk_backend::Part::Mount]]', lazy => 1, default => sub {return {};};

#=============================================================

=head2 load

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this method will load and parse the fstab file

=cut

#=============================================================
override ('load', sub {
    my $self = shift;
    $self->lines([]);
    $self->index([]);
    my $i = 0;
    # TODO: maybe lock the file?
    open F, '</etc/fstab' or return 0;
    while (my $line = <F>) {
        $self->lines->[$i] = $line;
        # watch out for trailing #
        # split properly
        # device/UUID/LABEL/PARTUUID path type options dump fscheck
        if ($line =~ m'^\s+(/dev/|(LABEL|(PART)?UUID)=("[^"]+"|[^\s]+))\s+(.+)\s+([^\s]+)\s+(.+)\s+(\d+)\s+(\d+)\s*(#.*)?$') {
            # $self->index->[$i] = part
        }
        $i = $i + 1;
    }
    close F;

    1;
});

#=============================================================

=head2 save

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this method will save the (modified) fstab file

=cut

#=============================================================
override ('save', sub {
    my $self = shift;
    open F, ">/tmp/fstab.$$" or return 0;
    close F;
    # mv "/tmp/fstab.$$" "/etc/fstab"

    1;
});

1;
