# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::Part;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::Part - Part class

=head1 SYNOPSIS
    package ManaTools::Shared::disk_backend::Part::MBR;

    extend 'ManaTools::Shared::disk_backend::Part';

    has '+type', required => 0, default => 'MBR';
    has '+in_restriction', default => sub { my ($self, $io)=@_; return ($self->in_length() < 1 && $io->type == 'disk');};
    has '+out_restriction', default => sub { my ($self, $io)=@_; return ($self->out_length() < 4 && $io->type == 'partition');};

    override('label', sub {
        my $self = shift;
        my $label = super;
        if ($self->in_length < 1) {
            return $label;
        }
        my @ins = $self->in_list();
        return $label .= "(". $ins[0]->id() .")";
    });

    1;

    ...

    my $mbr = ManaTools::Shared::disk_backend::Part::MBR->new();
    $mbr->label();  // MBR(/dev/sda)
    $mbr->get_ins();
    $mbr->get_outs();
    $mbr->out_add($io);
    my $size = $mbr->prop('size');
    $mbr->prop('size', '20G');
    $mbr->action('format');


=head1 DESCRIPTION

    This is an abstract class for Part in the backend to manadisk

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::Part


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

with 'ManaTools::Shared::ActionsRole', 'ManaTools::Shared::PropertiesRole';

use ManaTools::Shared::disk_backend::IOs;

## Class DATA
has 'type' => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    isa => 'Str',
    default => 'Part'
);
has 'in_restriction' => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    isa => 'Maybe[CodeRef]',
    default => sub {
        sub { return 1; }
    }
);
has 'out_restriction' => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    isa => 'Maybe[CodeRef]',
    default => sub {
        sub { return 1; }
    }
);

## Object Variables
has 'db' => (
    is => 'rw',
    isa => 'ManaTools::Shared::disk_backend',
    init_arg => undef,
    lazy => 1,
    default => undef,
);

has 'ins' => (
    is => 'ro',
    isa => 'ManaTools::Shared::disk_backend::IOs',
    lazy => 1,
    default => sub {
        my $self = shift;
        return ManaTools::Shared::disk_backend::IOs->new(parent => $self, restriction => $self->in_restriction);
    },
    handles => {
        in_length => 'length',
        in_list => 'list',
        in_add => 'append'
    }
);
has 'outs' => (
    is => 'ro',
    isa => 'ManaTools::Shared::disk_backend::IOs',
    lazy => 1,
    default => sub {
        my $self = shift;
        return ManaTools::Shared::disk_backend::IOs->new(parent => $self, restriction => $self->out_restriction);
    },
    handles => {
        out_length => 'length',
        out_list => 'list',
        out_add => 'append'
    }
);

#=============================================================

=head2 label

=head3 OUTPUT

    label of the IO

=head3 DESCRIPTION

    this method returns the label for this IO

=cut

#=============================================================
sub label {
    my $self = shift;

    return $self->type;
}

#=============================================================

=head2 get_ins

=head3 OUTPUT

    array of the in IOs

=head3 DESCRIPTION

    this method returns the in IOs

=cut

#=============================================================
sub get_ins {
    my $self = shift;

    return $self->ins->list();
}

#=============================================================

=head2 get_outs

=head3 OUTPUT

    array of the out IOs

=head3 DESCRIPTION

    this method returns the out IOs

=cut

#=============================================================
sub get_outs {
    my $self = shift;

    return $self->outs->list();
}

#=============================================================

=head2 rmio

=head3 INPUT

    $io: ManaTools::Shared::disk_backend::IO

=head3 DESCRIPTION

    this method returns removes the IO from the Part

=cut

#=============================================================
sub rmio {
    my $self = shift;
    my $io = shift;
    my $ins = $self->ins();
    my $outs = $self->outs();
    # remove io from ins and outs
    $ins->remove($io);
    $outs->remove($io);
}

#=============================================================

=head2 unhook

=head3 DESCRIPTION

    this method returns removes the Part from the parent

=cut

#=============================================================
sub unhook {
    my $self = shift;
    $self->db->rmpart($self);
}

1;
