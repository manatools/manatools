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
        print STDERR "$self: called changepart for probing extfs on $part\n";
        $self->D("$self: called changepart for probing extfs on $part");
        # only BlockDevices for loading
        return 1 if (!$part->does('ManaTools::Shared::disk_backend::BlockDevice'));

        # only devices that are present
        return 1 if ($part->has_prop('present') && !$part->prop('present'));

        print STDERR "$self: called changepart for probing extfs on $part: size ". $part->prop('size') ."\n";
        $self->D("$self: called changepart for probing extfs on $part: size ". $part->prop('size'));
        # only devices with positive size
        return 1 if ($part->prop('size') <= 0);

        print STDERR "$self: called changepart for probing extfs on $part: devicepath /dev/". $part->devicepath() =~ s'^.+/''r ."\n";
        # try with dump2fs if this is actually an extfs filesystem
        my %fields = $self->tool_fields('dumpe2fs', ':', '-h', '/dev/'. $part->devicepath() =~ s'^.+/''r);

        # get uuid
        my $uuid = $fields{'Filesystem UUID'};
        print STDERR "$self: called changepart for probing extfs on $part: uuid ". $uuid ."\n";

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

#=============================================================

=head2 fsprobe

=head3 INPUT

    $io: ManaTools::Shared::disk_backend::IO | Str
    $mount: ManaTools::Shared::disk_backend::Part::Mount

=head3 OUTPUT

    ManaTools::Shared::disk_backend::IO or undef

=head3 DESCRIPTION

    this method probes the IO to see if it fits for this
    filesystem, if it does, create a new Part with this IO as in.
    also create an IO (linked as the out) and return that one.
    The resulting one can then be used as an in to eg: a Mount Part.

=cut

#=============================================================
sub fsprobe {
    my $self = shift;
    my $io = shift;
    my $mount = shift;

    # gather fields from dumpe2fs
    my %fields = $self->tool_fields('dumpe2fs', ':', '-h', '/dev/'. $io->id());

    # get uuid
    my $uuid = $fields{'Filesystem UUID'};

    return undef if (!defined $uuid || !$uuid);

    # create part
    # TODO: look or create part
    my $part = $self->parent->mkpart('Extfs', { uuid => $uuid, plugin => $self});
    $part->prop('label', $fields{'Filesystem volume name'} =~ s'<none>''r);
    $part->prop('features', split(' ', $fields{'Filesystem features'}));
    $part->prop('options', split(' ', $fields{'Default mount options'}));
    $part->prop('state', $fields{'Filesystem state'});
    $part->prop('block_size', $fields{'Block size'});
    $part->prop('block_count', $fields{'Block count'});
    $part->prop('size', $fields{'Block size'} * $fields{'Block count'});

    # link in the in IO
    $part->in_add($io);

    # create the out IO and set properties
    my $fs = $self->parent->mkio('Extfs', {id => $uuid});
    $fs->prop('label', $fields{'Filesystem volume name'} =~ s'<none>''r);
    $fs->prop('features', split(' ', $fields{'Filesystem features'}));
    $fs->prop('options', split(' ', $fields{'Default mount options'}));
    $fs->prop('state', $fields{'Filesystem state'});
    $fs->prop('block_size', $fields{'Block size'});
    $fs->prop('block_count', $fields{'Block count'});
    $fs->prop('size', $fields{'Block size'} * $fields{'Block count'});
    $part->out_add($fs);

    # return $fs to be link as an in IO into $mount Part
    return $fs;
}

package ManaTools::Shared::disk_backend::IO::Extfs;

use Moose;

extends 'ManaTools::Shared::disk_backend::IO';

with 'ManaTools::Shared::disk_backend::IOFS';

has '+type' => (
    default => 'Extfs'
);

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

class_has '+in_restriction' => (
    default => sub {
        return sub {
            my $self = shift;
            my $io = shift;
            my $del = shift;
            if (defined $del && !$del) {
                return ($self->in_length() > 0);
            }
            # multiple device allowed
            return $io->does('ManaTools::Shared::disk_backend::BlockDevice');
        };
    }
);

class_has '+out_restriction' => (
    default => sub {
        return sub {
            my $self = shift;
            my $io = shift;
            my $del = shift;
            if (!defined $del) {
                $del = 0;
            }
            if ($del != 0) {
                return ($self->out_length() > 0);
            }
            return ($self->out_length() == 0 && ref($io) eq 'ManaTools::Shared::disk_backend::IO::Extfs');
        };
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
