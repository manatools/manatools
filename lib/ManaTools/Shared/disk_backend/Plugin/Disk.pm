# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::Plugin::Disk;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::Plugin::Disk - disks object

=head1 SYNOPSIS

    use ManaTools::Shared::disk_backend::Plugin::Disk;

    my $db_man = ManaTools::Shared::disk_backend::Plugin::Disk->new($parent);
    ...


=head1 DESCRIPTION

    This plugin is a disk plugin for the backend to manadisk

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::Plugin::Disk


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
use ManaTools::Shared::disk_backend::Part;

extends 'ManaTools::Shared::disk_backend::Plugin';

#=============================================================

=head2 probe

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this method will call probe for all plugins and merge results of the probe

=cut

#=============================================================
override ('probe', sub {
    my $self = shift;
    my $part = undef;
    $self->D('starting probe for %s', $self);
    my @parts = $self->parent->findpart('Disks');
    if (scalar(@parts) > 0) {
        $part = $parts[0];
    }
    else {
        $part = $self->parent->mkpart('Disks', {plugin => $self});
        if (!defined($part)) {
            return 0;
        }
    }
    for my $dfile (glob("/sys/bus/scsi/devices/[0-9]*")) {
        for my $bdfile (glob($dfile ."/block/*")) {
            # try or create child as a disk
            my $p = $part->trychild(ManaTools::Shared::disk_backend::Part->CurrentState, sub {
                my $part = shift;
                my $parameters = shift;
                return ($part->devicepath() =~ s'^.+/''r eq $parameters->{devicepath} =~ s'^.+/''r);
            }, 'Disk', {plugin => $self, devicepath => $bdfile, loaded => undef, saved => undef});

            # trigger the changedpart
            $p->changedpart(ManaTools::Shared::disk_backend::Part->CurrentState);
        }
    }
    return 1;
});

package ManaTools::Shared::disk_backend::Part::Disks;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

use MooseX::ClassAttribute;

class_has '+type' => (
    default => 'Disks'
);

class_has '+restrictions' => (
    default => sub {
        return {
            child => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Disk');
            },
            parent => sub {
                return 0;
            },
            sibling => sub {
                return 0;
            },
        }
    }
);

override('label', sub {
    my $self = shift;
    my $label = super;
    my @children = $self->children();
    if (scalar(@children) < 1) {
        return $label;
    }
    return $label .'('. join(',', sort map { $_->label(); } @children) .')';
});

package ManaTools::Shared::disk_backend::Part::Disk;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

use MooseX::ClassAttribute;

with 'ManaTools::Shared::disk_backend::BlockDevice';
with 'ManaTools::Shared::disk_backend::PurposeLabelRole';

class_has '+type' => (
    default => 'Disk'
);

has '+devicepath' => (
    trigger => sub {
        my $self = shift;
        my $value = shift;
        $self->prop_from_file('ro', $value .'/ro');
        $self->prop_from_file('removable', $value .'/removable');
        $self->prop_from_file('size', $value .'/size');
        $self->prop('present', ($self->prop('removable') == 0 || $self->prop('size') > 0) ? 1 : 0);
        $self->prop_from_file('dev', $value .'/dev');
        $self->sync_majorminor();

        # additional data
        my $dpath = $value =~ s,/[^/]+/[^/]+$,,r;
        $self->prop_from_file('vendor', $dpath .'/vendor');
        $self->prop_from_file('model', $dpath .'/model');
        $self->prop_from_file('type', $dpath .'/type');
    }
);

class_has '+order' => (
    default => sub {
        sub {
            my $self = shift;
            my $part = shift;
            return ($self->devicepath() =~ s'^.+/''r cmp $part->devicepath() =~ s'^.+/''r);
        }
    }
);

class_has '+restrictions' => (
    default => sub {
        return {
            parent => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Disks');
            },
            sibling => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Disk');
            },
            previous => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Disk');
            },
            next => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Disk');
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
