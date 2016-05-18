# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::Plugin::Loop;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::Plugin::Loop - loops object

=head1 SYNOPSIS

    use ManaTools::Shared::disk_backend::Plugin::Loop;

    my $db_man = ManaTools::Shared::disk_backend::Plugin::Loop->new($parent);
    ...


=head1 DESCRIPTION

    This plugin is a loop plugin for the backend to manaloop

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::Plugin::Loop


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

## Requires /usr/sbin/losetup

extends 'ManaTools::Shared::disk_backend::Plugin';


has '+dependencies' => (
    default => sub {
        return ['Disk'];
    }
);

has '+tools' => (
    default => sub {
        return {'losetup' => '/usr/sbin/losetup'};
    }
);

#=============================================================

=head2 _sanitize_string

=head3 OUTPUT

    Str

=head3 DESCRIPTION

    this method will call sanitize raw losetup strings

=cut

#=============================================================

sub _sanitize_string {
    my $self = shift;
    my $string = shift;
    # convert \xHH to binary
    $string =~ s/\\x([0-9A-Fa-f]{2})/chr hex $1/eg;
    # then trim
    $string =~ s/^\s+|\s+$//g;
    return $string;
}

#=============================================================

=head2 probe

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this method will call probe for all plugins and merge results of the probe

=cut

# /usr/sbin/losetup --list --noheadings --raw --output MAJ:MIN,NAME,SIZELIMIT,OFFSET,AUTOCLEAR,RO,BACK-MAJ:MIN,BACK-INO,BACK-FILE
# \x20\x207:0\x20\x20 /dev/loop0 0 0 1 1 \x20\x20\x20\x20\x20\x20\x200:19\x20 10148981 /home/alien/Carmageddon/Carmageddon.iso


#=============================================================
override ('probe', sub {
    my $self = shift;
    my $part = undef;
    my $err =  0;
    my @parts = $self->parent->findpart('Loops');
    if (scalar(@parts) > 0) {
        $part = $parts[0];
    }
    else {
        $part = $self->parent->mkpart('Loops', {plugin => $self});
        if (!defined($part)) {
            return 0;
        }
    }
    @parts = ();
    my @lines = $self->tool_lines('losetup', '--list', '--noheadings', '--raw', '--output', 'MAJ:MIN,NAME,SIZELIMIT,OFFSET,AUTOCLEAR,RO,BACK-FILE,BACK-MAJ:MIN,BACK-INO');
    for my $line (@lines) {
        chomp($line);
        my @fields = split(' ', $line);
        print STDERR "fields in line '$line': ". scalar(@fields) ."\n";
        (scalar(@fields) == 7 || scalar(@fields) == 9) or die('unexpected losetup output...');
        my $loopfile = $self->_sanitize_string($fields[1]);
        my $bdfile = '/sys/block/'. basename($loopfile);

        # look or create Loop part
        my $p = $self->parent->trypart(ManaTools::Shared::disk_backend::Part->CurrentState, sub {
            my $part = shift;
            my $parameters = shift;
            return ($part->devicepath() eq $parameters->{devicepath});
        }, 'Loop', {devicepath => $bdfile, plugin => $self, loaded => undef, saved => undef});
        $p->prop('sizelimit', $self->_sanitize_string($fields[2]));
        $p->prop('offset', $self->_sanitize_string($fields[3]));
        $p->prop('autoclear', $self->_sanitize_string($fields[4]));
        $p->prop('back-file', $self->_sanitize_string($fields[6]));
        $p->prop('back-dev', $self->_sanitize_string($fields[7])) if (defined $fields[7]);
        $p->prop('back-ino', $self->_sanitize_string($fields[8])) if (defined $fields[8]);
        push @parts, $p;

        # TODO: add sibling tags to the other parts
        # TODO: parent that is filerole? if parent is create, we can do the child/first/last thing

        # io stuff
        my $io = $self->parent->mkio('Disk', {id => basename($loopfile), path => $bdfile, devicepath => $bdfile});
        if (!defined($io) || !$part->out_add($io)) {
            $err = 1;
        }
        else {
            $io->prop('sizelimit', $self->_sanitize_string($fields[2]));
            $io->prop('offset', $self->_sanitize_string($fields[3]));
            $io->prop('autoclear', $self->_sanitize_string($fields[4]));
            $io->prop('back-file', $self->_sanitize_string($fields[6]));
            $io->prop('back-dev', $self->_sanitize_string($fields[7])) if (defined $fields[7]);
            $io->prop('back-ino', $self->_sanitize_string($fields[8])) if (defined $fields[8]);
        }
    }

    # trigger changed parts
    for my $p (@parts) {
        $self->parent->changedpart($p, ManaTools::Shared::disk_backend::Part->CurrentState);
    }
    return $err == 0;
});

package ManaTools::Shared::disk_backend::Part::Loops;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

use MooseX::ClassAttribute;

class_has '+type' => (
    default => 'Loops'
);

class_has '+in_restriction' => (
    default => sub {
        return sub {return 0;};
    }
);

class_has '+out_restriction' => (
    default => sub {
        return sub {
            my $self = shift;
            my $io = shift;
            my $del = shift;
            return $io->does('ManaTools::Shared::disk_backend::BlockDevice');
        };
    }
);

package ManaTools::Shared::disk_backend::Part::Loop;

use Moose;

extends 'ManaTools::Shared::disk_backend::Part';

with 'ManaTools::Shared::disk_backend::BlockDevice';

use MooseX::ClassAttribute;

class_has '+type' => (
    default => 'Loop'
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
    }
);


class_has '+restrictions' => (
    default => sub {
        return {
            parent => sub {
                my $self = shift;
                my $part = shift;
                return $part->does('ManaTools::Shared::disk_backend::FileRole');
            },
            sibling => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Loop');
            },
            previous => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Loop');
            },
            next => sub {
                my $self = shift;
                my $part = shift;
                return $part->isa('ManaTools::Shared::disk_backend::Part::Loop');
            },
        }
    }
);

1;
