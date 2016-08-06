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
    $self->D("$self: called changepart for partitions: $part, $partstate");

    ## LOAD
    # read the partition table
    if ($partstate == ManaTools::Shared::disk_backend::Part->LoadedState) {
        # only BlockDevices for loading
        return 1 if (!$part->does('ManaTools::Shared::disk_backend::BlockDevice'));
        my $pt = $self->_mkparttable($part);

        # exit if there is no detected PartitionTable
        return 1 if (!defined($pt));

        # look or make the PartitionTable as a child of the BlockDevice
        my $parttable = $part->trychild($partstate, undef, 'PartitionTable', {plugin => $self, probed => undef, saved => undef});
        my @changedparts = ($parttable);

        # make the PartitionElement children
        for my $p (values %{$pt->partitions()}) {
            # look or create the child with id based on the filename
            my $child = $parttable->trychild($partstate, sub {
                my $self = shift;
                my $parameters = shift;
                return ($self->devicepath() =~ s'^.+/''r eq $parameters->{devicepath} =~ s'^.+/''r);
            },'PartitionElement', {plugin => $self, devicepath => $p->{'file'}, probed => undef, saved => undef});

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
        for my $p (@changedparts) {
            $p->changedpart($partstate);
        }
    }

    ## PROBE
    # check in the kernel partition table by reading /sys
    if ($partstate == ManaTools::Shared::disk_backend::Part->CurrentState) {
        $self->D("$self: called changepart for probing partitiontable on $part");
        # only BlockDevices for loading
        return 1 if (!$part->does('ManaTools::Shared::disk_backend::BlockDevice'));

        # only devices that are present
        return 1 if ($part->has_prop('present') && !$part->prop('present'));

        $self->D("$self: called changepart for probing partitiontable on $part: size ". $part->prop('size'));
        # only devices with positive size
        return 1 if ($part->prop('size') <= 0);

        # there is no way to differentiate between an in-kernel empty partition table and no partition table
        # so, we're not making an empty partition table entry for probed state
        # since there is none, it'll just recreate the partition table (probably with the loaded state settings) anyway
        #
        # in any case, if there are no partition entries (in-kernel), we exit early.
        my @devices = map { $_ =~ s'/size$''r } glob($part->devicepath(). "/*/size");
        return 1 if (!scalar(@devices));

        # look or make the PartitionTable as a child of the BlockDevice
        my $parttable = $part->trychild($partstate, undef, 'PartitionTable', {plugin => $self, loaded => undef, saved => undef});
        my @changedparts = ($parttable);

        # find subdevices in /sys/
        my $prevchild = undef;
        for my $pf (@devices) {
            # look or create the child with id based on the filename
            my $child = $parttable->trychild($partstate, sub {
                my $self = shift;
                my $parameters = shift;
                return ($self->devicepath() =~ s'^.+/''r eq $parameters->{devicepath} =~ s'^.+/''r);
            },'PartitionElement', {plugin => $self, devicepath => $pf, loaded => undef, saved => undef});

            # add the child to the changedparts
            push @changedparts, $child;
        }

        # trigger changedpart on all children for other plugins to load further
        for my $p (@changedparts) {
            $p->changedpart($partstate);
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

package ManaTools::Shared::disk_backend::Part::PartitionElement;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

with 'ManaTools::Shared::disk_backend::BlockDevice';
with 'ManaTools::Shared::disk_backend::PurposeLabelRole';

use MooseX::ClassAttribute;

class_has '+type' => (
    default => 'PartitionElement'
);

class_has '+order' => (
    default => sub {
        return sub {
            my $self = shift;
            my $part = shift;
            $self->plugin->D("compare for ordering: $self(". join(',', $self->properties()) .") and $part(". join(',', $part->properties()) .")");
            return $self->prop('start') <=> $part->prop('start');
        }
    }
);

has '+devicepath' => (
    trigger => sub {
        my $self = shift;
        my $value = shift;
        $self->prop_from_file('sectors', $value . '/size');
        # sectors are always 512 bytes here!
        $self->prop('size', $self->prop('sectors') * 512);
        $self->prop_from_file('start', $value . '/start');
        $self->prop_from_file('ro', $value . '/ro');
        $self->prop_from_file('dev', $value . '/dev');
        $self->sync_majorminor();
        $self->prop('num', $value =~ s/^.+([0-9]+)$/$1/r);
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

override('label', sub {
    my $self = shift;
    my $label = super;
    return $label if $label ne $self->type();

    # get the name from the devicepath
    return $self->devicepath() =~ s'^.+/''r;
});

1;
