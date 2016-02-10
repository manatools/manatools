# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::Plugin::Mount;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::Plugin::Mount - disks object

=head1 SYNOPSIS

    use ManaTools::Shared::disk_backend::Plugin::Mount;

    my $db_man = ManaTools::Shared::disk_backend::Plugin::Mount->new($parent);
    ...


=head1 DESCRIPTION

    This plugin is a disk plugin for the backend to manadisk

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::Plugin::Mount


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


has '+dependencies' => (
    default => sub {
        return ['Partition'];
    }
);

#=============================================================

=head2 probe

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this method will probe the current mounts

=cut

#=============================================================
override ('probe', sub {
    my $self = shift;
    # check current mounts and create a Mount for each one
    # TODO: find the in device (create if needed?)
    open F, '</proc/self/mountinfo' or return 0;
    while (my $line = <F>) {
        my @fields = split(/ /, $line);
        my $part = $self->parent->mkpart('Mount', {path => $fields[4]});
        $part->prop('options', $fields[5]);
        $part->prop('dev', $fields[2]);
        $part->prop('id', $fields[0]);
        $part->prop('parent', $fields[1]);
        $part->prop('srcdevpath', $fields[3]);
        $part->prop('fstype', $fields[8]);
        $part->prop('srcmount', $fields[9]);

        # finding parent mount
        if ($fields[1] != $fields[0]) {
            # find parent and put into parentmount field
            my @parts = $self->parent->findpartprop('Mount', 'id', $fields[1]);
            $part->parentmount($parts[0]) if scalar(@parts) > 0;
        }
        # find missing children Mount Part
        my @parts = $self->parent->findpartprop('Mount', 'parent', $fields[0]);
        for my $p (@parts) {
            my $pm = $p->parentmount();
            $p->parentmount($part) if (!defined $pm);
        }

        # source is $fields[2] (major,minor) and $fields[3] (source path within device, default /)
        my @ios = $self->parent->findioprop('dev', $fields[2]);
        if (scalar(@ios) > 0) {
            $part->in_add($ios[0]);
        }
        # TODO: look up device with this
        # TODO: find the end of the options, and store them
        # TODO: also the super options and mount source (may have UUID or whatnot)
        # TODO: use the filesystem type to connect to the previous IO
    }
# 3.5   /proc/<pid>/mountinfo - Information about mounts
# --------------------------------------------------------
#
# This file contains lines of the form:
#
# 36 35 98:0 /mnt1 /mnt2 rw,noatime master:1 - ext3 /dev/root rw,errors=continue
# (1)(2)(3)   (4)   (5)      (6)      (7)   (8) (9)   (10)         (11)
#
# (1) mount ID:  unique identifier of the mount (may be reused after umount)
# (2) parent ID:  ID of parent (or of self for the top of the mount tree)
# (3) major:minor:  value of st_dev for files on filesystem
# (4) root:  root of the mount within the filesystem
# (5) mount point:  mount point relative to the process's root
# (6) mount options:  per mount options
# (7) optional fields:  zero or more fields of the form "tag[:value]"
# (8) separator:  marks the end of the optional fields
# (9) filesystem type:  name of filesystem of the form "type[.subtype]"
# (10) mount source:  filesystem specific information or "none"
# (11) super options:  per super block options
#
# Parsers should ignore all unrecognised optional fields.  Currently the
# possible optional fields are:
#
# shared:X  mount is shared in peer group X
# master:X  mount is slave to peer group X
# propagate_from:X  mount is slave and receives propagation from peer group X (*)
# unbindable  mount is unbindable
#
# (*) X is the closest dominant peer group under the process's root.  If
# X is the immediate master of the mount, or if there's no dominant peer
# group under the same root, then only the "master:X" field is present
# and not the "propagate_from:X" field.
#
# For more information on mount propagation see:
#
#   Documentation/filesystems/sharedsubtree.txt

    1;
});


package ManaTools::Shared::disk_backend::Part::Mount;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

has '+type' => (
    default => 'Mount'
);

has 'path' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    trigger => sub {
        my $self = shift;
        my $value = shift;
        $self->prop('path', $value);
    }
);

has 'parentmount' => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Shared::disk_backend::Part::Mount]',
    init_arg => undef,
    default => undef,
);

has '+in_restriction' => (
    default => sub {
        return sub {
            my $self = shift;
            my $io = shift;
            my $del = shift;
            if (defined $del && !$del) {
                return ($self->in_length() > 0);
            }
            # only 1 device allowed
            return $self->in_length() < 1 && ($io->does('ManaTools::Shared::disk_backend::BlockDevice') || $io->does('ManaTools::Shared::disk_backend::IOFS'));
        };
    }
);

has '+out_restriction' => (
    default => sub {
        return sub {return 0;};
    }
);

1;
