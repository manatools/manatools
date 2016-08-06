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
        return ['Partition', 'Loop'];
    }
);

#=============================================================

=head2 _makemount

=head3 INPUT

    $parent: Part
    $partstate: PartState
    $fields: ArrayRef

=head3 OUTPUT

    Part|undef

=head3 DESCRIPTION

    this function create a mount Part from the parent and set the properties.

=cut

#=============================================================
sub _makemount {
    my $self = shift;
    my $parent = shift;
    my $partstate = shift;
    my $fields = shift;

    ## from this parent, create the mount point
    # look or create the child with id based on the path
    my $child = $parent->trychild($partstate, sub {
        my $self = shift;
        my $parameters = shift;
        return ($self->path() eq $parameters->{path});
    },'Mount', {plugin => $self, path => $fields->[4], loaded => undef, saved => undef});

    $child->prop('options', $fields->[5]);
    $child->prop('dev', $fields->[2]);
    $child->prop('id', $fields->[0]);
    $child->prop('parent', $fields->[1]);
    $child->prop('srcdevpath', $fields->[3]);
    $child->prop('fstype', $fields->[8]);
    $child->prop('srcmount', $fields->[9]);

    # add an unmount action
    $child->add_action('unmount', 'Unmount', undef, sub {
        my $self = shift;
        print STDERR "Unmount is not implemented...\n";
        return 1;
    });

    ## take care of family
    # finding parent mount
    if ($fields->[1] != $fields->[0]) {
        # find parent and put into parentmount field
        my @parts = $self->parent->findpartprop('Mount', 'id', $fields->[1]);
        $child->parentmount($parts[0]) if scalar(@parts) > 0;
    }

    # find missing children Mount Part
    my @parts = $self->parent->findpartprop('Mount', 'parent', $fields->[0]);
    for my $p (@parts) {
        my $pm = $p->parentmount();
        $p->parentmount($child) if (!defined $pm);
    }

    return $child;
}

#=============================================================

=head2 findfields

=head3 INPUT

    $code: CodeRef
    @params: Array

=head3 OUTPUT

    Array|undef

=head3 DESCRIPTION

    this function finds the correct mount fields for a device and returns it.

=cut

#=============================================================
sub findfields {
    my $self = shift;
    my $code = shift;
    my @params = @_;

    # check the part dev with current mounts
    open F, '</proc/self/mountinfo' or return 0;
    while (my $line = <F>) {
        my $fields = undef;
        @{$fields} = split(/ /, $line);
        my $ret = $code->($self, $fields, @params);
        if ($ret != 0) {
            close F;
            return $fields;
        }
    }
    close F;
    return undef;
}

#=============================================================

=head2 findpath

=head3 INPUT

    $dev: Str
    $partstate: PartState

=head3 OUTPUT

    Str|undef

=head3 DESCRIPTION

    this function finds a suitable path for a device and returns it.

=cut

#=============================================================
sub findpath {
    my $self = shift;
    my $dev = shift;
    my $partstate = shift;
    my $code = shift;
    my @params = @_;
    # TODO: need some more filters
    $self->D("$self: called findpath for mount: $dev, $partstate");

    ## LOAD
    if ($partstate == ManaTools::Shared::disk_backend::Part->LoadedState) {
        # TODO: i donno yet
        return undef;
    }

    ## PROBE
    if ($partstate == ManaTools::Shared::disk_backend::Part->CurrentState) {
        $self->D("$self: called findpath for probing paths for $dev");

        my $fields = $self->findfields(sub {
            my $self = shift;
            my $fields = shift;
            my $dev = shift;
            my $code = shift;
            my @params = @_;
            # identify first
            # check device as fallback
            if (defined $code) {
                my $ret = $code->($dev, $fields, @params);
                $self->D("$self: after code execution for $fields->[2] ($fields->[9]), return value is $ret, looking for $dev");
                if ($ret != 0) {
                    close F;
                    return 1;
                }
            }
            elsif ($fields->[2] eq $dev) {
                close F;
                return 1;
            }
            return 0;
        }, $dev, $code, @params);
        return $fields->[4] if defined($fields);
        return undef;
    }

    ## SAVE
    if ($partstate == ManaTools::Shared::disk_backend::Part->FutureState) {
        # TODO: i donno yet
        return undef;
    }

    return undef;
}

#=============================================================

=head2 changedpart

=head3 INPUT

    $part: ManaTools::Shared::disk_backend::Part
    $partstate: PartState

=head3 OUTPUT

    0 if failed, 1 if success or unneeded

=head3 DESCRIPTION

    this overridden method will load/probe/save a mount point when it's called

=cut

#=============================================================
override ('changedpart', sub {
    my $self = shift;
    my $part = shift;
    my $partstate = shift;
    $self->D("$self: called changepart for mount: $part, $partstate");

    ## LOAD
    # read the partition table
    if ($partstate == ManaTools::Shared::disk_backend::Part->LoadedState) {
        # only BlockDevices for loading
    }

    ## PROBE
    # check in the kernel partition table by reading /sys
    if ($partstate == ManaTools::Shared::disk_backend::Part->CurrentState) {
        $self->D("$self: called changepart for probing partitiontable on $part");
        # only BlockDevices for loading
        return 1 if (!$part->does('ManaTools::Shared::disk_backend::Mountable'));

        # TODO: we should look for changes wrt mounts
        # we should check if this part is mounted or not and change accordingly

        # keep in mind that the probe will have done all mounts already, and made a link to the original device if not the filesystem itself
        # a filesystem could be mounted several times to different paths
        # NOTE: this may not be necessary and probe could've already done everything

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
        ## try to find the filesystem
        #
        ## try to find device
        # if not found, create an UnknownBlockDevice for it
        my $bd = $self->parent();
        my $devpart = undef;
        # TODO: what about --bind mount points
        # TODO: keep in mind loopbacked files!
        my @parts = grep { $_->type() ne 'Mount' } $bd->findpartprop(undef, 'dev', $fields[2]);
        if (scalar(@parts) == 0) {
            $devpart = $bd->mkpart('UnknownBlockDevice', {plugin => $self, devicepath => $fields[4], loaded => undef, saved => undef});
            $devpart->prop('dev', $fields[2]);
        }
        else {
            $devpart = $parts[0];
        }

        ## try to find filesystem
        # if not found, create an UnknownFS for it
        $self->D('find dev %s with fstype %s (srcmount %s)', $fields[2], $fields[8], $fields[9]);
        my $fs = $devpart->trychild(ManaTools::Shared::disk_backend::Part->CurrentState, sub {
            my $self = shift;
            my $parameters = shift;
            my $dev = shift;
            my $fstype = shift;

            # only filesystems
            return 0 if !$self->does('ManaTools::Shared::disk_backend::FileSystem');
            $self->plugin()->D('part is a FileSystem with type %s', $self->prop('fstype'));

            # needs to be this fstype
            return 0 if ($self->prop('fstype') ne $fields[8]);

            # TODO: need to check srcmount $fields[9] as well

            # if one of the parent matches dev $field[2], then it's ok
            my @parents = $self->find_parts(undef, 'parent');
            $self->plugin()->D('FileSystem part has %d parents', scalar(@parents));
            for my $parent (@parents) {
                # check state
                next if !$parent->is_state(ManaTools::Shared::disk_backend::Part->CurrentState);
                # check dev
                $self->plugin()->D('parent of part has dev %s', $parent->prop('dev'));
                return 1 if $parent->prop('dev') eq $fields[2];
            }

            # not found
            return 0;
        }, 'UnknownFS', {plugin => $self, loaded => undef, saved => undef});
        $fs->prop('fstype', $fields[8]);

        ## TODO: check filesystem and sourcepath options to select the actual parent
        my $child = $self->_makemount($fs, ManaTools::Shared::disk_backend::Part->CurrentState, \@fields);

        # TODO: look up device with this
        # TODO: find the end of the options, and store them
        # TODO: also the super options and mount source (may have UUID or whatnot)
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

use MooseX::ClassAttribute;

class_has '+type' => (
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

class_has '+restrictions' => (
    default => sub {
        return {
            sibling => sub {
                my $self = shift;
                my $part = shift;
                return 0;
            },
            parentmount => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Mount');
            },
            childmount => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Mount');
            },
            parent => sub {
                my $self = shift;
                my $part = shift;
                return $part->does('ManaTools::Shared::disk_backend::FileSystem');
            },
            child => sub {
                my $self = shift;
                my $part = shift;
                return $part->does('ManaTools::Shared::disk_backend::FileRole') || $part->does('ManaTools::Shared::disk_backend::DirectoryRole');
            },
        }
    }
);

override('_reverse_tag', sub {
    my $tag = shift;
    return 'childmount' if ($tag eq 'parentmount');
    return 'parentmount' if ($tag eq 'childmount');
    return super;
});

package ManaTools::Shared::disk_backend::Part::UnknownBlockDevice;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

use MooseX::ClassAttribute;

with 'ManaTools::Shared::disk_backend::BlockDevice';

class_has '+type' => (
    default => 'UnknownBlockDevice'
);

class_has '+restrictions' => (
    default => sub {
        return {
            sibling => sub {
                my $self = shift;
                my $part = shift;
                return 0;
            },
            parent => sub {
                my $self = shift;
                my $part = shift;
                return 0;
            },
        }
    }
);

package ManaTools::Shared::disk_backend::Part::UnknownFS;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

use MooseX::ClassAttribute;

with 'ManaTools::Shared::disk_backend::FileSystem';
with 'ManaTools::Shared::disk_backend::Mountable';

class_has '+type' => (
    default => 'UnknownFS'
);

class_has '+restrictions' => (
    default => sub {
        return {
            sibling => sub {
                my $self = shift;
                my $part = shift;
                return 0;
            },
            parent => sub {
                my $self = shift;
                my $part = shift;
                return $part->does('ManaTools::Shared::disk_backend::BlockDevice');
            },
        }
    }
);

sub _get_mount_source {
    my $self = shift;

    # get parent partlink (which should be a blockdevice anyway)
    my $parent = $self->find_part(undef, 'parent');
    return undef if (!defined $parent);

    # return parent's devicepath
    return $parent->devicepath();
}

1;
