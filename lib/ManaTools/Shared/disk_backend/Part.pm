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

use MooseX::ClassAttribute;
use Moose::Util::TypeConstraints qw/subtype as where/;

use ManaTools::Shared::disk_backend::IOs;

## Class DATA

subtype 'PartState'
    => as Int
    => where {($_ > 0 && $_<=3)};

class_has 'LoadedState' => (
    is => 'ro',
    isa => 'PartState',
    init_arg => undef,
    default => sub {return 1;},
);

class_has 'CurrentState' => (
    is => 'ro',
    isa => 'PartState',
    init_arg => undef,
    default => sub {return 2;},
);

class_has 'FutureState' => (
    is => 'ro',
    isa => 'PartState',
    init_arg => undef,
    default => sub {return 3;},
);

class_has 'type' => (
    is => 'ro',
    init_arg => undef,
    isa => 'Str',
    default => 'Part'
);

class_has 'in_restriction' => (
    is => 'ro',
    init_arg => undef,
    isa => 'Maybe[CodeRef]',
    default => sub {
        sub { return 1; }
    }
);

class_has 'out_restriction' => (
    is => 'ro',
    init_arg => undef,
    isa => 'Maybe[CodeRef]',
    default => sub {
        sub { return 1; }
    }
);

## Object Variables
has 'loaded' => (
    is => 'rw',
    init_arg => undef,
    lazy => 1,
    isa => 'Maybe[ManaTools::Shared::disk_backend::Part]',
    default => sub {
        my $self = shift;
        return $self;
    }
);

has 'probed' => (
    is => 'rw',
    init_arg => undef,
    lazy => 1,
    isa => 'Maybe[ManaTools::Shared::disk_backend::Part]',
    default => sub {
        my $self = shift;
        return $self;
    }
);

has 'saved' => (
    is => 'rw',
    init_arg => undef,
    lazy => 1,
    isa => 'Maybe[ManaTools::Shared::disk_backend::Part]',
    default => sub {
        my $self = shift;
        return $self;
    }
);

has 'db' => (
    is => 'rw',
    isa => 'ManaTools::Shared::disk_backend',
    init_arg => undef,
    lazy => 1,
    default => undef,
);

has 'plugin' => (
    is => 'rw',
    isa => 'ManaTools::Shared::disk_backend::Plugin',
    required => 1,
    handles => ['tool', 'tool_lines', 'tool_fields'],
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

=head2 is_equal

=head3 INPUT

    $part: ManaTools::Shared::disk_backend::Part

=head3 OUTPUT

    bool

=head3 DESCRIPTION

    this method checks if the given part is equal to self

=cut

#=============================================================
sub is_equal {
    my $self = shift;
    my $part = shift;

    return 0 if ($self->label() ne $part->label());
    return 0 if ($self->type() ne $part->type());
    return 0 if (!$self->ins()->is_equal($part->ins()));
    return 0 if (!$self->outs()->is_equal($part->outs()));

    return 1;
}

#=============================================================

=head2 is_state

=head3 INPUT

    $state: PartState

=head3 OUTPUT

    bool

=head3 DESCRIPTION

    this method returns true if this part is in this particular state

=cut

#=============================================================
sub is_state {
    my $self = shift;
    my $state = shift;
    return $self->is_loaded() if ($state == ManaTools::Shared::disk_backend::Part->LoadedState);
    return $self->is_current() if ($state == ManaTools::Shared::disk_backend::Part->CurrentState);
    return $self->to_be_saved() if ($state == ManaTools::Shared::disk_backend::Part->FutureState);
    return undef;
}

#=============================================================

=head2 is_loaded

=head3 OUTPUT

    bool

=head3 DESCRIPTION

    this method returns true if this part has been loaded like this (past state)

=cut

#=============================================================
sub is_loaded {
    my $self = shift;
    return ($self->loaded == $self);
}

#=============================================================

=head2 is_current

=head3 OUTPUT

    bool

=head3 DESCRIPTION

    this method returns true if this part is how it actually currently is (current state)

=cut

#=============================================================
sub is_current {
    my $self = shift;
    return ($self->probed == $self);
}

#=============================================================

=head2 to_be_saved

=head3 OUTPUT

    bool

=head3 DESCRIPTION

    this method returns true if this part has changed and is awaiting saving (future state)

=cut

#=============================================================
sub to_be_saved {
    my $self = shift;
    return ($self->saved == $self);
}

#=============================================================

=head2 check_merge

=head3 DESCRIPTION

    this method checks if the other Part States are actually equal and merge back

=cut

#=============================================================
sub check_merge {
    my $self = shift;
    my $db = $self->db();

    $db->rmpart($self->loaded()) && $self->loaded($self) if !$self->is_loaded() && $self->equal($self->loaded());
    $db->rmpart($self->probed()) && $self->probed($self) if !$self->is_current() && $self->equal($self->probed());
    $db->rmpart($self->saved()) && $self->saved($self) if !$self->to_be_saved() && $self->equal($self->saved());
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
