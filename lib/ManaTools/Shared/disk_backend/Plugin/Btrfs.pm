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
    default => sub { return ['btrfs'] },
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

sub get_fsdev {
    my $self = shift;
    my $io = shift;
    my $rio = ref($io);

    # if it's a reference, it'll be an object, so return the mm property
    return $io->prop('mm') if defined($rio) && $rio;

    my @stat = stat($io);
    # if it's not a block device, it's no use
    return undef if (($stat[2] >> 12) != 6);

    # find the device
    my $dev = $stat[6];
    my $minor = $dev % 256;
    my $major = int (($dev - $minor) / 256);
    return $major .':'. $minor;
}

sub get_subvolumes {
    my $self = shift;
    my $io = shift;
    my $path = shift;

    # get the dev numbering
    my $mm = $self->get_fsdev($io);

    # no device, get out now
    return undef if !defined($mm);

    my $fs = $self->filesystems();
    # no filesystem, get out now
    return undef if !defined($fs->{$mm});

    # this is the filesystem part
    my $btrfs = $fs->{$mm};

    my $vols = $btrfs->subvolumes();

    $vols = $btrfs->refresh($path) if scalar(@{$vols}) == 0;

    return $vols;
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
        # create an io for out
        my $io = $self->parent->mkio('Btrfs', {id => $fs =~ s'^.+/''r});
        $io->prop('uuid', $fs =~ s'^.+/''r);
        $part->out_add($io);

        # TODO: find the in devices (create if needed?)
        for my $df (glob("$fs/devices/*")) {
            open F, '<'. $df .'/dev';
            my $value = <F>;
            close F;
            chomp($value);
            my @ios = $self->parent->findioprop('dev', $value);
            if (scalar(@ios) > 0) {
                $part->in_add($ios[0]);
                $fss->{$ios[0]->prop('dev')} = $part;
            }
        }

        # TODO: find base mount point in order to find volumes
        # TODO: quotas ...? pathbased?
    }
    1;
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
    my $vols = $self->get_subvolumes($io, $mount->path());
    # return undef if there are not subvolumes
    return undef if !defined($vols);

    for my $vol (@{$vols}) {
        # return when we find the one with the correct srcpath
        return $vol if ($vol->prop('srcpath') eq $mount->prop('srcdevpath'));
    }
    return undef;
}

package ManaTools::Shared::disk_backend::IO::Btrfs;

use Moose;

extends 'ManaTools::Shared::disk_backend::IO';

has '+type' => (
    default => 'Btrfs'
);

package ManaTools::Shared::disk_backend::IO::BtrfsVol;

use Moose;

extends 'ManaTools::Shared::disk_backend::IO';

with 'ManaTools::Shared::disk_backend::IOFS';

has '+type' => (
    default => 'BtrfsVol'
);


package ManaTools::Shared::disk_backend::Part::Btrfs;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

has '+type' => (
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

has '+in_restriction' => (
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

has '+out_restriction' => (
    default => sub {
        return sub {
            my $self = shift;
            my $io = shift;
            my $del = shift;
            if (!defined $del) {
                $del = 0;
            }
            if ($del != 0) {
                return ($self->in_length() > 0);
            }
            return ($self->in_length() == 0 && ref($io) eq 'ManaTools::Shared::disk_backend::IO::Btrfs');
        };
    }
);

sub refresh {
    my $self = shift;
    my $path = shift;
    my $subvols = $self->subvolumes();

    # first, clean up all Volume stuff
    my @parts = $self->db->findpart('BtrfsVol');
    for my $part (@parts) {
        $part->unhook();
    }
    # loop all BtrfsVol IO and remove safely
    for my $vol (@{$subvols}) {
        # this should also unhook from any Part
        $vol->unhook();
    }
    # clear subvols from list
    @{$subvols} = ();

    # find the IO::Btrfs
    my @outs = $self->get_outs();
    if (scalar(@outs) == 0) {
        # make an IO::Btrfs for this one
        @outs = ($self->db->mkio('Btrfs', {id => $self->uuid()}));
    }

    return $subvols if !defined($path) || !$path;

    # btrfs subvolume list / -agcpuq
    # ID 264 gen 1090157 cgen 255 parent 5 top level 5 parent_uuid - uuid ab6d48f8-6d65-6b43-b792-dd31d93018be path <FS_TREE>/backup-@
    open (F, '-|', "/usr/sbin/btrfs subvolume list '$path' -agcpuq") or die('some error happened');
    while (my $line = <F>) {
        # top level is 2 strings, so combine them, so that the fields can be nicely splitted
        my %fields = split(/[ \t\r\n]+/, $line =~ s'top level'top_level'r);
        # create the volume part
        my $part = $self->db->mkpart('BtrfsVol', {fs => $self, uuid => $fields{uuid}, plugin => $self->plugin()});
        # add the IO::Btrfs filesystem
        $part->in_add($outs[0]);
        # create a IO::BtrfsVol
        my $vol = $self->db->mkio('BtrfsVol', {id => $fields{ID}});
        # TODO: trace parenting and fill in subvolumes in all the BtrfsVol Parts
        # set properties
        $vol->prop('srcpath', $fields{path} =~ s'<FS_TREE>''r);
        $vol->prop('uuid', $fields{uuid});
        $vol->prop('parent_uuid', $fields{parent_uuid});
        $vol->prop('gen', $fields{gen});
        $vol->prop('cgen', $fields{cgen});
        $vol->prop('parent', $fields{parent});
        $vol->prop('top_level', $fields{top_level});
        $part->out_add($vol);
        push @{$subvols}, $vol;
    }
    close F;
    return $subvols;
}


package ManaTools::Shared::disk_backend::Part::BtrfsVol;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

has '+type' => (
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

has '+in_restriction' => (
    default => sub {
        return sub {
            my $self = shift;
            my $io = shift;
            my $del = shift;
            if (!defined $del) {
                $del = 0;
            }
            if ($del != 0) {
                return ($self->in_length() > 0);
            }
            return ($self->in_length() == 0 && ref($io) eq 'ManaTools::Shared::disk_backend::IO::Btrfs');
        };
    }
);

has '+out_restriction' => (
    default => sub {
        return sub {
            my $self = shift;
            my $io = shift;
            my $del = shift;
            if (!defined $del) {
                $del = 0;
            }
            if ($del != 0) {
                return ($self->in_length() > 0);
            }
            # multiple device allowed
            return (ref($io) eq 'ManaTools::Shared::disk_backend::IO::BtrfsVol');
        };
    }
);

1;
