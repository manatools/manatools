# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::Plugin::Btrfs;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::Plugin::Btrfs - disks object

=head1 SYNOPSIS

    use ManaTools::Shared::disk_backend::Plugin::Btrfs;

    my $db_man = ManaTools::Shared::disk_backend::Plugin::Btrfs->new($parent);
    ...


=head1 DESCRIPTION

    This plugin is a disk plugin for the backend to manadisk

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::Plugin::Btrfs


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
    default => sub {
        return {
            'btrfs' => 'Btrfs',
        };
    },
);

has '+dependencies' => (
    default => sub {
        return ['Partition', 'Loop'];
    }
);

has '+tools' => (
    default => sub {
        return {
            'btrfs' => '/usr/sbin/btrfs',
            'btrfs-show-super' => '/usr/sbin/btrfs-show-super',
        };
    }
);

has 'filesystems' => (
    is => 'ro',
    isa => 'HashRef[ManaTools::Shared::disk_backend::Part::Btrfs]',
    init_arg => undef,
    default => sub { return {};}
);

sub create_subvolume {
    my $self = shift;
    my $part = shift;
    my $partstate = shift;
    my $fields = shift;
    my $quotas = shift;
    my $subvolumes = shift;

    # look or create part for btrfsvol
    my $p = $part->trychild($partstate, sub {
        my $self = shift;
        my $parameters = shift;
        return ($self->uuid() eq $parameters->{uuid});
    }, 'BtrfsVol', {plugin => $self, fs => $part, mountsourcepath => $fields->{path} =~ s'<FS_TREE>''r, uuid => $fields->{uuid}, loaded => undef, saved => undef});

    # set properties
    $p->prop('label', $fields->{path} =~ s'<FS_TREE>/?''r);
    $p->prop('uuid', $fields->{uuid});
    $p->prop('parent_uuid', $fields->{parent_uuid});
    $p->prop('subvolid', $fields->{ID});
    $p->prop('gen', $fields->{gen});
    $p->prop('cgen', $fields->{cgen});
    $p->prop('parent', $fields->{parent});
    $p->prop('top_level', $fields->{top_level});

    # set quota information
    if (defined($quotas->{'0/'. $fields->{ID}})) {
        my $item = $quotas->{'0/'. $fields->{ID}};
        $p->prop('referred', $item->{rfer});
        $p->prop('exclusive', $item->{excl});
        $p->prop('quota_referred', $item->{max_rfer});
        $p->prop('quota_exclusive', $item->{max_excl});
    }

    # trace parenting and fill in subvolumes in all the BtrfsVol Parts
    # create missing parents too!

    $self->D("$self: trigger changepart for BTRFS Volume $p: ". $p->mountsourcepath());
    $p->changedpart($partstate);

    # if it has a mount point, get readonly state
    # find Mount child (for subvolumes, might need to check the parent and base the path from there)
    my $path = $p->find_path($partstate);
    if (defined($path)) {
        # if it's mounted, we can get readonly status with properties
        my %fields = $self->tool_fields('btrfs', '=', 'property', 'get', "'$path'");
        $p->prop('readonly', $fields{ro} eq 'true');
    }

    # set up children subvolumes
    for my $id (keys %{$fields->{subvolumes}}) {
        if (defined($subvolumes->{$id})) {
            # TODO: add childvol tag for this one
            $p->add_taglink($subvolumes->{$id}, 'childsubvol');
        }
    }

    if (defined($subvolumes->{$p->prop('parent')})) {
        # add a parent link
        $p->add_taglink($subvolumes->{$p->prop('parent')}, 'parentsubvol');
    }

    $subvolumes->{$p->prop('subvolid')} = $p;

    return $p;
}

#=============================================================

=head2 probe

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this method will probe the active btrfs filesystems and volumes

=cut

#=============================================================
override ('probe', sub {
    my $self = shift;
    my $fss = $self->filesystems();
    # check in sysfs and create a Btrfs for each one
    for my $fs (glob("/sys/fs/btrfs/*")) {
        next if ($fs !~ m'/[-0-9a-f]+$'i);
        my $part = $self->parent->mkpart('Btrfs', {uuid => $fs =~ s'^.+/''r, plugin => $self});
        $part->prop_from_file('label', "$fs/label");
        $part->prop('features', join(',', map {$_ =~ s'^.+/''r} glob("$fs/features/*")));
        $part->prop_from_file('used', "$fs/allocation/data/disk_used");
        $part->prop_from_file('total', "$fs/allocation/data/disk_total");
        $part->prop_from_file('flags', "$fs/allocation/data/flags");

        # TODO: find base mount point in order to find volumes
        # TODO: quotas ...? pathbased?
    }
    1;
});

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
    $self->D("$self: called changepart for btrfs: $part, $partstate");

    ## LOAD
    # read the raw disk? or no loading filesystems? or is this more with fstab?
    if ($partstate == ManaTools::Shared::disk_backend::Part->LoadedState) {
        # only BlockDevices for loading
        return 1 if (!$part->does('ManaTools::Shared::disk_backend::BlockDevice'));
        # TODO: fstab handles loading
    }

    ## PROBE
    # check in /sys the currently in use btrfs systems --> should be in probe
    if ($partstate == ManaTools::Shared::disk_backend::Part->CurrentState) {
        $self->D("$self: called changepart for probing btrfs on $part");
        if ($part->isa('ManaTools::Shared::disk_backend::Part::Btrfs')) {
            # get all volumes and create parts for them if they don't exist yet.

            # To get volumes, we need to have the mount path
            # 1. get the device first
            # 2. ask mount plugin about the path depending on device
            # 3. use the path to query volumes

            # get the closest BlockDevice ancestor and get the dev prop
            my $p = $part->find_closest($partstate, sub {
                my $self = shift;
                my $parameters = shift;
                return $self->does('ManaTools::Shared::disk_backend::BlockDevice');
            }, undef, {}, 'parent');
            return 1 if !defined ($p);

            # get the dev property
            my $dev = $p->prop('dev');
            return 1 if !defined ($dev);

            # get the Mount plugin from backend!
            my $db = $self->parent();
            my $mp = $db->findplugin('Mount');

            # No mount path means no volumes ...
            return 1 if !defined ($mp);

            # ask mount plugin for the path
            my $path = $mp->findpath($dev, $partstate, sub {
                my $dev = shift;
                my $fields = shift;
                my $srcdev = $fields->[2];
                my $devtype = $fields->[8];
                my $devfile = $fields->[9];
                if ($devfile ne $devtype) {
                    my @s = stat($devfile);
                    if (scalar(@s) > 6) {
                        my $minor = $s[6] % 256;
                        my $major = int (($s[6] - $minor) / 256);
                        $srcdev = $major .':'. $minor;
                    }
                }
                return ($srcdev eq $dev);
            });

            # We cannot get volumes if it's not mounted!
            return 1 if !defined ($path);

            # get quota informations for when we need it below
            # [ ]# btrfs qgroup show '/' -re --raw
            # qgroupid                 rfer                 excl     max_rfer     max_excl 
            # --------                 ----                 ----     --------     -------- 
            # 0/5                    385024                16384         none         none 
            # 0/264              4589723648            419004416         none         none 
            # 0/265            144602763264         144602763264         none         none 
            my $quotas = $self->tool_columns('btrfs', 1, 1, 'qgroupid', '\s+', 'qgroup', 'show', "'$path'", '-re', '--raw');

            # use the btrfs tool with the path to find the subvolumes and sync them with what is here already
            # this only works on mounted filesystems
            # [ ]# btrfs subvolume list / -agcpuq
            # ID 264 gen 1090157 cgen 255 parent 5 top level 5 parent_uuid - uuid ab6d48f8-6d65-6b43-b792-dd31d93018be path <FS_TREE>/backup-@
            my @lines = $self->tool_lines('btrfs', 'subvolume', 'list', "'$path'", '-agcpuq');
            my %subvolumes = ();
            for my $line (@lines) {
                my $fields = {};
                # top level is 2 strings, so combine them, so that the fields can be nicely splitted
                %{$fields} = split(/[ \t\r\n]+/, $line =~ s'top level'top_level'r);
                $subvolumes{$fields->{ID}} = $fields;
                $subvolumes{$fields->{ID}}->{subvolumes} = {};
            }

            # move the subvolumes to their parent if they have it, and list them for later removal
            for my $id (keys %subvolumes) {
                if (defined($subvolumes{$subvolumes{$id}->{parent}})) {
                    $subvolumes{$subvolumes{$id}->{parent}}->{subvolumes}->{$id} = $subvolumes{$id};
                }
            }

            # create the parts from the parent btrfs
            my %subvolparts = ();
            for my $id (keys %subvolumes) {
                $self->create_subvolume($part, $partstate, $subvolumes{$id}, $quotas, \%subvolparts);
            }

            # remove any parts that are not there anymore
            my @children = $part->children();
            for my $child (@children) {
                if (defined ($subvolumes{$child->prop('subvolid')})) {
                    # TODO: remove it (also from parent and possible children etc...)
                }
            }
            return 1;
        }

        # only BlockDevices for loading
        return 1 if (!$part->does('ManaTools::Shared::disk_backend::BlockDevice'));

        # only devices that are present
        return 1 if ($part->has_prop('present') && !$part->prop('present'));

        $self->D("$self: called changepart for probing btrfs on $part: size ". $part->prop('size'));
        # only devices with positive size
        return 1 if ($part->prop('size') <= 0);

        # try with btrfs-show-super if this is actually an btrfs filesystem
        my %fields = $self->tool_fields('btrfs-show-super', ' ', '/dev/'. $part->devicepath() =~ s'^.+/''r);

        # get uuid
        my $uuid = $fields{'fsid'};
        $self->D("$self: called changepart for probing btrfs on $part: uuid ". $uuid) if defined($uuid);

        # this is probably not an btrfs filesystem
        return undef if (!defined $uuid || !$uuid);

        # look or create part for btrfs
        my $p = $part->trychild($partstate, sub {
            my $self = shift;
            my $parameters = shift;
            return ($self->uuid() eq $parameters->{uuid});
        },'Btrfs', {plugin => $self, uuid => $uuid, loaded => undef, saved => undef});

        # extra properties
        $p->prop('label', $fields{'label'});
        $p->prop('incompat_flags', $fields{'incompat_flags'});
        $p->prop('flags', $fields{'flags'});
        $p->prop('block_size', $fields{'sectorsize'});
        $p->prop('size', $fields{'total_bytes'});
        $p->prop('used', $fields{'bytes_used'});
        $p->prop('generation', $fields{'generation'});
        $p->prop('root_level', $fields{'root_level'});
        $p->prop('root_dir', $fields{'root_dir'});

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

package ManaTools::Shared::disk_backend::Part::Btrfs;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

with 'ManaTools::Shared::disk_backend::PurposeLabelRole';

use MooseX::ClassAttribute;

class_has '+type' => (
    default => 'Btrfs'
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

has 'subvolumes' => (
    is => 'rw',
    isa => 'ArrayRef[ManaTools::Shared::disk_backend::Part::BtrfsVol]',
    init_arg => undef,
    default => sub { return [];},
);

package ManaTools::Shared::disk_backend::Part::BtrfsVol;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

use MooseX::ClassAttribute;

with 'ManaTools::Shared::disk_backend::Mountable';
with 'ManaTools::Shared::disk_backend::PurposeLabelRole';

sub _get_mount_source {
    my $self = shift;
    my $fs = $self->fs();

    # TODO: multiple parents
    # get parent partlink (which should be a blockdevice anyway)
    my $parent = $fs->find_part(undef, 'parent');
    return undef if (!defined $parent);

    # return parent's devicepath
    return $parent->devicepath();
}

class_has '+type' => (
    default => 'BtrfsVol'
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

has 'fs' => (
    is => 'rw',
    isa => 'ManaTools::Shared::disk_backend::Part::Btrfs',
    required => 1,
);

has 'subvolumes' => (
    is => 'rw',
    isa => 'ArrayRef[ManaTools::Shared::disk_backend::Part::BtrfsVol]',
    init_arg => undef,
    default => sub { return [];},
);

class_has '+restrictions' => (
    default => sub {
        return {
            sibling => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::BtrfsVol');;
            },
            parentsubvol => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::BtrfsVol');
            },
            childsubvol => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::BtrfsVol');
            },
            parent => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Btrfs');
            },
            child => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Mount');
            },
        }
    }
);

augment('_reverse_tag', sub {
    my $self = shift;
    my $tag = shift;
    my $rtag = inner($tag);
    return $rtag if (defined($rtag) && $tag ne $rtag);
    return 'childsubvol' if ($tag eq 'parentsubvol');
    return 'parentsubvol' if ($tag eq 'childsubvol');
    return $tag;
});

around('find_path', sub {
    my $orig = shift;
    my $self = shift;
    my $partstate = shift;

    # first try the standard method
    my $path = $self->$orig($partstate);
    return $path if (defined $path);

    # subvolumes can check parent subvolumes and add the relative path
    my @parents = $self->find_parts($partstate, 'parent');
    for my $parent (@parents) {
        if ($parent->isa('ManaTools::Shared::disk_backend::Part::BtrfsVol')) {
            $path = $parent->find_path($partstate);
            return $path . substr($self->prop('label'), length($parent->prop('label'))) if defined($path);
        }
    }
    return undef;
});

1;
