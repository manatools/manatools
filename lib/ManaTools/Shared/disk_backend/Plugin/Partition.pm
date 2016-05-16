# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::Plugin::Partition;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::Plugin::Partition - Partition object

=head1 SYNOPSIS

    use ManaTools::Shared::disk_backend::Plugin::Partition;

    my $db_man = ManaTools::Shared::disk_backend::Plugin::Partition->new($parent);
    ...


=head1 DESCRIPTION

    This plugin is an Partition plugin for the backend to manadisk

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::Plugin::Partition


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
use ManaTools::Shared::disk_backend::PartitionTable;

extends 'ManaTools::Shared::disk_backend::Plugin';

has '+dependencies' => (
    default => sub {
        return ['Disk', 'Loop'];
    }
);

has '+tools' => (
    default => sub {
        return {parted => '/usr/sbin/parted'};
    }
);

sub _mkparttable {
    my $self = shift;
    my $part = shift;

    return ManaTools::Shared::disk_backend::PartitionTable->new(parted => $self->tool('parted'), disk => $part->file());
}

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

    ## LOAD
    # read the partition table
    if ($partstate == ManaTools::Shared::disk_backend::Part->PastState) {
        # only BlockDevices for loading
        return 1 if (!$part->does('ManaTools::Shared::disk_backend::BlockDevice'));
        my $pt = $self->_mkparttable($part);

        # exit if there is no detected PartitionTable
        return 1 if (!defined($pt));

        # look or make the PartitionTable as a child of the BlockDevice
        my $parttable = $part->trychild($partstate, undef, 'PartitionTable', {probed => undef, saved => undef});
        my @changedparts = ($parttable);

        # make the PartitionElement children
        for my $p (values %{$pt->partitions()}) {
            # look or create the child with id based on the filename
            my $child = $part->trychild($partstate, sub {
                my $self = shift;
                my $parameters = shift;
                return ($self->id() eq $parameters->{id});
            },'PartitionElement', {id => $p->{'file'} =~ s'^.+/''r, probed => undef, saved => undef});

            # set the necessary properties
            my @stat = stat($p->{'file'});
            my $dev = $stat[6];
            my $minor = $dev % 256;
            my $major = int (($dev - $minor) / 256);
            $child->prop('dev', $major .':'. $minor);
            $child->sync_majorminor();
            $child->prop('start', $p->{'start'});
            $child->prop('size', $p->{'size'});
            $child->prop('num', $p->{'num'});

            # add the child to the changedparts
            push @changedparts, $child;
        }

        # trigger changedpart on all children for other plugins to load further
        for my $part (@changedparts) {
            $part->changedpart($partstate);
        }
    }

    ## PROBE
    # check in the kernel partition table by reading /sys
    if ($partstate == ManaTools::Shared::disk_backend::Part->PresentState) {
        # only BlockDevices for loading
        return 1 if (!$part->does('ManaTools::Shared::disk_backend::BlockDevice'));

        # only devices that are present
        return 1 if (!$part->prop('present'));

        # only devices with positive size
        return 1 if (!$part->prop('size') <= 0);

        # there is no way to differentiate between an in-kernel empty partition table and no partition table
        # so, we're not making an empty partition table entry for probed state
        # since there is none, it'll just recreate the partition table (probably with the loaded state settings) anyway
        #
        # in any case, if there are no partition entries (in-kernel), we exit early.
        my @devices = glob($part->path(). "/". $part->id() ."*");
        return 1 if (!scalar(@devices));

        # look or make the PartitionTable as a child of the BlockDevice
        my $parttable = $part->trychild($partstate, undef, 'PartitionTable', {loaded => undef, saved => undef});
        my @changedparts = ($parttable);

        # find subdevices in /sys/
        my $prevchild = undef;
        for my $pf (@devices) {
            # look or create the child with id based on the filename
            my $child = $part->trychild($partstate, sub {
                my $self = shift;
                my $parameters = shift;
                return ($self->id() eq $parameters->{id});
            },'PartitionElement', {id => $pf =~ s'^.+/''r, loaded => undef, saved => undef});

            $child->prop_from_file('sectors', $pf . '/size');
            # sectors are always 512 bytes here!
            $child->prop('size', $child->prop('sectors') * 512);
            $child->prop_from_file('start', $pf . '/start');
            $child->prop_from_file('ro', $pf . '/ro');
            $child->prop_from_file('dev', $pf . '/dev');
            $child->sync_majorminor();
            $child->prop('num', $pf =~ s/^.+([0-9]+)$/$1/r);

            # add the child to the changedparts
            push @changedparts, $child;
        }

        # trigger changedpart on all children for other plugins to load further
        for my $part (@changedparts) {
            $part->changedpart($partstate);
        }
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

=head2 load

=head3 OUTPUT

    0 if failed, 1 if success or unneeded

=head3 DESCRIPTION

    this method will load all disks partition tables

=cut

#=============================================================
override ('loadio', sub {
    my $self = shift;
    my $io = shift;
    # get the partition table
    my $pt = ManaTools::Shared::disk_backend::PartitionTable->new(parted => $self->tool('parted'), disk => $io->file());
    # get partitions and mkio them all
    for my $p (values %{$pt->partitions()}) {
        my @stat = stat($p->{'file'});
        my $dev = $stat[6];
        my $minor = $dev % 256;
        my $major = int (($dev - $minor) / 256);
        my $io = $self->parent->mkio('Partition', {id => $p->{'file'} =~ s'^.+/''r});
        $io->prop('dev', $major .':'. $minor);
        $io->sync_majorminor();
        $io->prop('start', $p->{'start'});
        $io->prop('size', $p->{'size'});
        $io->prop('num', $p->{'num'});
        # TODO: also create the Part (if it doesn't already exists) and link it
    }
    return 1;
});

#=============================================================

=head2 probeio

=head3 OUTPUT

    0 if failed, 1 if success or unneeded

=head3 DESCRIPTION

    this method will try to probe the specific disk IO and get partitions

=cut

#=============================================================
override ('probeio', sub {
    my $self = shift;
    my $io = shift;
    my $part = undef;
    # return if $io is not the correct type
    if ($io->type() ne 'Disk') {
        return 1;
    }
    if ($io->prop('present') == 0) {
        return 1;
    }
    # find out if the IO already has a part, if not: make a part
    my @parts = $self->parent->findin($io);
    if (scalar(@parts) > 0) {
        $part = $parts[0];
    }
    else {
        $part = $self->parent->mkpart('PartitionTable', {plugin => $self});
        if (!defined($part)) {
            return 0;
        }
        # assign this IO to the ins
        if (!$part->in_add($io)) {
            return 0;
        }
        # add properties
        # TODO: partition table type, size and position, logical alignment, etc...
        # default partition is always 1 sector ?
        $part->prop('size', 1);
        # add an action
        $part->add_action('addPartition', 'Add a partition', $part, sub {
            my $self = shift;
            my $part = $self->item();
            print STDERR "Add partition is not implemented...\n";
            return 1;
        }, sub {
            my $self = shift;
            my $part = $self->item();
            return 1;
        });
    }
    @parts = $self->parent->findin($io);
    my $err =  0;
    my $partitions = 0;
    # find subdevices in /sys/
    for my $pf (glob($io->path(). "/". $io->id() ."*")) {
        my $io = $self->parent->mkio('Partition', {id => $pf =~ s'^.+/''r});
        $io->prop_from_file('sectors', $pf . '/size');
        # sectors are always 512 bytes here!
        $io->prop('size', $io->prop('sectors') * 512);
        $io->prop_from_file('start', $pf . '/start');
        $io->prop_from_file('ro', $pf . '/ro');
        $io->prop_from_file('dev', $pf . '/dev');
        $io->sync_majorminor();
        $io->prop('num', $pf =~ s/^.+([0-9]+)$/$1/r);
        $partitions = $partitions + 1;
        if (!$part->out_add($io)) {
            $err = 1;
        }
    }
    $part->prop('partitions', $partitions);
    # find out how to differentiate between an empty partition table and no partition table
    return $err == 0;
});

package ManaTools::Shared::disk_backend::IO::Partition;

use Moose;

extends 'ManaTools::Shared::disk_backend::IO';

with 'ManaTools::Shared::disk_backend::BlockDevice';

has '+type' => (
    default => 'Partition'
);

package ManaTools::Shared::disk_backend::Part::PartitionTable;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

use MooseX::ClassAttribute;

class_has '+type' => (
    default => 'PartitionTable'
);

class_has '+restrictions' => (
    default => sub {
        return {
            child => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::PartitionElement');
            },
            parent => sub {
                my $self = shift;
                my $part = shift;
                return $part->does('ManaTools::Shared::disk_backend::BlockDevice');
            },
            sibling => sub { return 0; },
            previous => sub { return 0; },
            next => sub { return 0; },
        }
    }
);

class_has '+in_restriction' => (
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
            return ($self->in_length() == 0 && ref($io) eq 'ManaTools::Shared::disk_backend::IO::Disk');
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
            return ($self->out_length() < 4 && ref($io) eq 'ManaTools::Shared::disk_backend::IO::Partition');
        };
    }
);

package ManaTools::Shared::disk_backend::Part::PartitionElement;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

with 'ManaTools::Shared::disk_backend::BlockDevice';

use MooseX::ClassAttribute;

class_has '+type' => (
    default => 'PartitionElement'
);

class_has '+order' => (
    default => sub {
        return sub {
            my $self = shift;
            my $part = shift;
            return $self->prop('offset') <=> $part->prop('offset');
        }
    }
);

class_has '+restrictions' => (
    default => sub {
        return {
            parent => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::PartitionTable');
            },
            sibling => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::PartitionElement');
            },
            previous => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::PartitionElement');
            },
            next => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::PartitionElement');
            },
        }
    }
);

1;
