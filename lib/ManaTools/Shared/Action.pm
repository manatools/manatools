# vim: set et ts=4 sw=4:
package ManaTools::Shared::Action;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::Action - an Action helper class

=head1 SYNOPSIS

    use ManaTools::Shared::Action;

    my $action = ManaTools::Shared::Action->new(name => 'addPartition', label => 'Add a partition', item => $foo, action => sub {
        my $self = shift;
        my $item = $self->item();
        my @args = @_;
        ...
        return 'return value';
    }, valid => sub {
        my $self = shift;
        my $item = $self->item();
        ...
        return 0;
    });
    my $res = $action->act(@_);
    $action->is_valid();


=head1 DESCRIPTION

    This helper class is used to abstract an action

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::Action


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

use Moose::Util::TypeConstraints;
use MooseX::ClassAttribute;

has 'name' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has 'label' => (
    is => 'rw',
    isa => 'Str',
    required => 1
);

has 'item' => (
    is => 'rw',
    isa => 'Item',
    required => 0,
    default => undef
);

has 'action' => (
    traits => ['Code'],
    is => 'ro',
    isa => 'CodeRef',
    required => 1,
    handles => {
        act => 'execute'
    }
);

has 'valid' => (
    traits => ['Code'],
    is => 'ro',
    isa => 'CodeRef',
    required => 0,
    default => sub {
        return sub { return 1; };
    },
    handles => {
        is_valid => 'execute'
    }
);

subtype 'LevelType'
    => as Int
    => where {($_ > 0 && $_ <= 3)};

has 'level' => (
    traits => ['Code'],
    is => 'ro',
    isa => 'CodeRef',
    required => 0,
    default => sub {
        return sub { return 1; };
    },
    handles => {
        is_level => 'execute'
    }
);

class_has 'beginnerLevel' => (
    is => 'ro',
    isa => 'LevelType',
    init_arg => undef,
    default => sub {return 1;},
);

class_has 'advancedLevel' => (
    is => 'ro',
    isa => 'LevelType',
    init_arg => undef,
    default => sub {return 2;},
);

class_has 'expertLevel' => (
    is => 'ro',
    isa => 'LevelType',
    init_arg => undef,
    default => sub {return 3;},
);

1;

