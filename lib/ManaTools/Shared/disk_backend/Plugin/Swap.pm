# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::Plugin::Swap;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::Plugin::Swap - disks object

=head1 SYNOPSIS

    use ManaTools::Shared::disk_backend::Plugin::Swap;

    my $db_man = ManaTools::Shared::disk_backend::Plugin::Swap->new($parent);
    ...


=head1 DESCRIPTION

    This plugin is a disk plugin for the backend to manadisk

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::Plugin::Swap


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

    this method will probe the current swaps

=cut

#=============================================================
override ('probe', sub {
    my $self = shift;
    # check current swaps and create a Swap Part for each one
    # TODO: find the in device (create if needed?)
    open F, '</proc/swaps' or return 0;
    # skip columns line
    <F>;
    while (my $line = <F>) {
        my @fields = split(/[ \t\r\n]+/, $line);
        my $part = $self->parent->mkpart('Swap', {path => $fields[0]});
        $part->prop('filename', $fields[0]);
        $part->prop('swaptype', $fields[1]);
        $part->prop('size', $fields[2]);
        $part->prop('used', $fields[3]);
        $part->prop('priority', $fields[4]);
        # check first if it's a device, then find the define
        my @stat = stat($fields[0]);
        # if device: then...
        if ($stat[2] >> 12 == 6) {
            my $dev = $stat[6];
            my $minor = $dev % 256;
            my $major = int (($dev - $minor) / 256);
            my @ios = $self->parent->findioprop('dev', $major .':'. $minor);
            if (scalar(@ios) > 0) {
                $part->in_add($ios[0]);
            }
            else {
                # TODO: create the IO ? try to probe parent? or ???
                # think of XEN where you may have device partition files without an actual disk?
            }
        }
        else {
            # TODO the in should be the mount point containing the filename
        }
    }
# /proc/swaps:
#
# Filename				Type		Size	Used	Priority
# /dev/sda3                    partition	8388604	2739584	-1

    1;
});


package ManaTools::Shared::disk_backend::Part::Swap;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

has '+type' => (
    default => 'Swap'
);

has 'path' => (
    is => 'rw',
    isa => 'Str',
    required => 1
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
            return $self->in_length() < 1 && ($io->does('ManaTools::Shared::disk_backend::BlockDevice') || $io->does('ManaTools::Shared::disk_backend::FileRole'));
        };
    }
);

has '+out_restriction' => (
    default => sub {
        return sub {return 0;};
    }
);

1;
