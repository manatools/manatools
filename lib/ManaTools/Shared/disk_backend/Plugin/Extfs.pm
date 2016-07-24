# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::Plugin::Extfs;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::Plugin::Extfs - disks object

=head1 SYNOPSIS

    use ManaTools::Shared::disk_backend::Plugin::Extfs;

    my $db_man = ManaTools::Shared::disk_backend::Plugin::Extfs->new($parent);
    ...


=head1 DESCRIPTION

    This plugin is a disk plugin for the backend to manadisk

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::Plugin::Extfs


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

with 'ManaTools::Shared::disk_backend::FileSystem';

has '+fstypes' => (
    default => sub { return ['ext2', 'ext3', 'ext4']; },
);

has '+dependencies' => (
    default => sub {
        return ['Partition', 'Loop'];
    }
);

has '+tools' => (
    default => sub {
        return {dumpe2fs => '/usr/sbin/dumpe2fs'};
    }
);

#=============================================================

=head2 changedpart

=head3 INPUT

    $part: ManaTools::Shared::disk_backend::Part
    $partstate: PartState

=head3 OUTPUT

    0 if failed, 1 if success or unneeded

=head3 DESCRIPTION

    this overridden method will load/probe/save a partition table when it's called

=cut

#=============================================================
override ('changedpart', sub {
    my $self = shift;
    my $part = shift;
    my $partstate = shift;
    $self->D("$self: called changepart for extfs: $part, $partstate");

    ## LOAD
    # read the partition table
    if ($partstate == ManaTools::Shared::disk_backend::Part->LoadedState) {
        # only BlockDevices for loading
        return 1 if (!$part->does('ManaTools::Shared::disk_backend::BlockDevice'));
        # TODO: fstab handles loading
    }

    ## PROBE
    # check in the kernel partition table by reading /sys
    if ($partstate == ManaTools::Shared::disk_backend::Part->CurrentState) {
        $self->D("$self: called changepart for probing extfs on $part");
        # only BlockDevices for loading
        return 1 if (!$part->does('ManaTools::Shared::disk_backend::BlockDevice'));

        # only devices that are present
        return 1 if ($part->has_prop('present') && !$part->prop('present'));

        $self->D("$self: called changepart for probing extfs on $part: size ". $part->prop('size'));
        # only devices with positive size
        return 1 if ($part->prop('size') <= 0);

        # try with dump2fs if this is actually an extfs filesystem
        my %fields = $self->tool_fields('dumpe2fs', ':', '-h', '/dev/'. $part->devicepath() =~ s'^.+/''r);

        # get uuid
        my $uuid = $fields{'Filesystem UUID'};

        # this is probably not an extfs filesystem
        return undef if (!defined $uuid || !$uuid);

        # look or create part for extfs
        my $p = $part->trychild($partstate, sub {
            my $self = shift;
            my $parameters = shift;
            return ($self->uuid() eq $parameters->{uuid});
        },'Extfs', {plugin => $self, uuid => $uuid, loaded => undef, saved => undef});

        # extra properties
        $p->prop('label', $fields{'Filesystem volume name'} =~ s'<none>''r);
        $p->prop('features', split(' ', $fields{'Filesystem features'}));
        $p->prop('options', split(' ', $fields{'Default mount options'}));
        $p->prop('state', $fields{'Filesystem state'});
        $p->prop('block_size', $fields{'Block size'});
        $p->prop('block_count', $fields{'Block count'});
        $p->prop('size', $fields{'Block size'} * $fields{'Block count'});

        $self->D("$self: created Extfs Part $p, calling changepart now.");
        $p->changedpart($partstate);
    }

    ## SAVE
    # save the partition table
    if ($partstate == ManaTools::Shared::disk_backend::Part->FutureState) {
        # in all child parts, find PartitionTable entries and trigger ->save();
        for my $p ($part->find_parts(undef, 'child')) {
            # TODO: need to be able to abort during save!!!
            $p->save();
        }
    }

    return 1;
});

package ManaTools::Shared::disk_backend::Part::Extfs;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

use MooseX::ClassAttribute;

with 'ManaTools::Shared::disk_backend::Mountable';

class_has '+type' => (
    default => 'Extfs'
);

has 'uuid' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    trigger => sub {
        my $self = shift;
        my $value = shift;
        $self->prop('uuid', $value);
    }
);

class_has '+restrictions' => (
    default => sub {
        return {
            parent => sub {
                my $self = shift;
                my $part = shift;
                return $part->does('ManaTools::Shared::disk_backend::BlockDevice');
            },
            child => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Mount');
            },
            sibling => sub {
                my $self = shift;
                my $part = shift;
                return 0;
            },
        }
    }
);

1;
