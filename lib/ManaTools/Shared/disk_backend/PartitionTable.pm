# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::PartitionTable;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::PartitionTable - a parted PartitionTable module

=head1 SYNOPSIS

    use ManaTools::Shared::disk_backend::PartitionTable;

    my $pt = ManaTools::Shared::disk_backend::PartitionTable->new(disk => '/dev/sda');
    my $type = $pt->type();
    my @parts = $pt->partitions();


=head1 DESCRIPTION

    This plugin is an PartitionTable module in the backend to manadisk

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::PartitionTable


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

use ManaTools::Shared::RunProgram;

# requires /usr/sbin/parted
has 'parted' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has 'disk' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    trigger => sub {
        my $self = shift;
        my $value = shift;
        my @lines = ManaTools::Shared::RunProgram::get_stdout($self->parted() ." -ms $value unit s print 2>/dev/null");
        if (scalar(@lines) < 2) {
            # the disk was not detected
            return undef;
        }
        my @fields = split(':', $lines[1]);
        # set the partition table device file
        $self->device($fields[0]);
        # set the partition table sectors
        $self->sectors($fields[1] =~ s/s$//r);
        # set the partition table device type
        $self->devicetype($fields[2]);
        # set the partition table sectorsize
        $self->sectorsize()->[0] = $fields[3];
        $self->sectorsize()->[1] = $fields[4];
        # set the partition table type
        $self->type($fields[5]);
        # set the partition table name
        $self->name($fields[6]);
        # add all partitions read
        my $parts = $self->partitions();
        my $i = 2;
        while (defined($lines[$i])) {
            @fields = split(':', $lines[$i]);
            $parts->{$fields[0]} = {
                file => $self->device() . $fields[0],
                begin => $fields[1] =~ s/s$//r,
                end => $fields[2] =~ s/s$//r,
                size => $fields[3] =~ s/s$//r,
                fs => $fields[4],
                type => $fields[5],
                flags => split(',', $fields[6])
            };
            $i = $i + 1;
        }
    }
);

has 'type' => (
    is => 'rw',
    isa => 'Maybe[Str]',
    default => undef
);

has 'sectorsize' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub {
        return [512, 512];
    }
);

has 'sectors' => (
    is => 'rw',
    isa => 'Maybe[Int]',
    default => undef
);

has 'name' => (
    is => 'rw',
    isa => 'Maybe[Str]',
    default => undef
);

has 'device' => (
    is => 'rw',
    isa => 'Maybe[Str]',
    default => undef
);

has 'devicetype' => (
    is => 'rw',
    isa => 'Maybe[Str]',
    default => undef
);

has 'partitions' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub {
        return {};
    }
);

1;
