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

has '+tools' => (
    default => sub {
        return {
            'swaplabel' => '/usr/sbin/swaplabel',
            'swapon' => '/usr/sbin/swapon',
            'swapoff' => '/usr/sbin/swapoff',
        };
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

        # look or create the part
        my $part = $self->parent->trypart(ManaTools::Shared::disk_backend::Part->CurrentState, sub {
            my $part = shift;
            my $parameters = shift;
            return ($part->path() eq $parameters->{path});
        }, 'Swap', {path => $fields[0], plugin => $self, loaded => undef, saved => undef});

        # look for the parent part if not set
        if (!$part->has_link(undef, 'parent')) {
            my @stat = stat($fields[0]);
            if (($stat[2] >> 13) == 3) {
                my $dev = $stat[6];
                my $minor = $dev % 256;
                my $major = int (($dev - $minor) / 256);
                my @parents = $self->parent->findpartprop(undef, 'dev', $major .':'. $minor);
                $part->add_taglink($parents[0], 'parent') if (scalar(@parents) > 0);
            }
        }

        $part->prop('filename', $fields[0]);
        $part->prop('swaptype', $fields[1]);
        $part->prop('size', $fields[2]);
        $part->prop('used', $fields[3]);
        $part->prop('priority', $fields[4]);
        $part->prop('active', 1);

        # add a swapoff action
        $part->add_action('swapoff', 'Turn off swap', $part, sub {
            my $self = shift;
            my $part = $self->item();
            my $plugin = $part->plugin();
            print STDERR "Dangerous actions are disabled: '". $self->label() ."'\n";
            return 1;
            if ($plugin->tool_exec('swapoff', $part->prop('filename')) == 0) {
                $part->prop('active', 0);
                $part->prop('priority', 0);
            }
            return 1;
        }, sub {
            my $self = shift;
            my $part = $self->item();
            return $part->prop('active') == 1;
        });

        # use swaplabel to get label and uuid
        my %labelfields = $self->tool_fields('swaplabel', ':', $fields[0]);
        $part->prop('uuid', defined($labelfields{'UUID'}) ? $labelfields{'UUID'} : '');
        $part->prop('label', defined($labelfields{'LABEL'}) ? $labelfields{'LABEL'} : '');

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

with 'ManaTools::Shared::disk_backend::PurposeLabelRole';

use MooseX::ClassAttribute;

class_has '+type' => (
    default => 'Swap'
);

has 'path' => (
    is => 'rw',
    isa => 'Str',
    required => 1
);

class_has '+order' => (
    default => sub {
        sub {
            my $self = shift;
            my $part = shift;
            return ($self->prop('priority') <=> $part->prop('priority'));
        }
    }
);

class_has '+restrictions' => (
    default => sub {
        return {
            parent => sub {
                my $self = shift;
                my $part = shift;
                return $part->does('ManaTools::Shared::disk_backend::BlockDevice') || $part->does('ManaTools::Shared::disk_backend::FileRole');
            },
            # TODO: memory Part?
            child => sub {
                my $self = shift;
                my $part = shift;
                return 0;
            },
            sibling => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Swap');
            },
            previous => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Swap');
            },
            next => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Swap');
            },
        }
    }
);

around('purpose_label', sub {
    my $orig = shift;
    my $self = shift;
    my $partstate = shift;

    return 'SWAP';
});

1;
