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
        return {'btrfs' => '/usr/sbin/btrfs'};
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


package ManaTools::Shared::disk_backend::Part::Btrfs;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

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
