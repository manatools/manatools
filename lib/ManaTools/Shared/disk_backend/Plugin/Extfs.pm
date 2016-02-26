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
    my $part = $self->parent->mkpart('Extfs', { uuid => $uuid, plugin => $self});

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

1;
