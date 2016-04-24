# vim: set et ts=4 sw=4:
package ManaTools::Shared::ActionsRole;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::ActionsRole - a Actions Moose::Role

=head1 SYNOPSIS
    package Foo;

    with 'ManaTools::Shared::ActionsRole';

    1;

    ...

    my $f = Foo->new();
    my @actionnames = $f->get_actions();
    $f->add_action('aname', 'a label', $item, sub { my $self = shift; my @params = @_; ... ; return 'foo'; }, sub { return 1; });
    my $res = $f->act('aname', 'param1', 'param2', @params);
    $f->remove_action('aname');


=head1 DESCRIPTION

    This Role is a collection of Actions

=head1 SUPPORT

    You can find documentation for this Role with the perldoc command:

    perldoc ManaTools::Shared::ActionsRole


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

use Moose::Role;

use MooseX::ClassAttribute;
use ManaTools::Shared::Action;

class_has 'acts' => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    isa => 'ArrayRef[ManaTools::Shared::Action]',
    default => sub {return [];}
);

#=============================================================

=head2 get_actions

=head3 OUTPUT

    array of string

=head3 DESCRIPTION

    this method returns a list of action names

=cut

#=============================================================
sub get_actions {
    my $self = shift;

    return map { return $_->name()} @{$self->acts()};
}

#=============================================================

=head2 act

=head3 INPUT

    $key: string
    optional action parameters

=head3 OUTPUT

    return value of the action

=head3 DESCRIPTION

    this method calls an action

=cut

#=============================================================
sub act {
    my $self = shift;
    my $key = shift;
    my $acts = $self->acts();
    for my $action (@{$self->acts()}) {
        if ($key eq $action->name()) {
            return $action->act($self, @_);
        }
    }

    return -1;
}

#=============================================================

=head2 add_action

=head3 INPUT

    $name: Str
    $label: Str
    $action: CodeRef
    $valid: CodeRef

=head3 DESCRIPTION

    this method adds an action

=cut

#=============================================================
sub add_action {
    my $self = shift;
    my $name = shift;
    my $label = shift;
    my $item = shift;
    my $action = shift;
    my $valid = shift;
    my $options = {name => $name, label => $label, item => $item, action => $action};
    $options->{valid} = $valid if defined $valid;

    push @{$self->acts()}, ManaTools::Shared::Action->new($options);
}

#=============================================================

=head2 remove_action

=head3 INPUT

    $key: string

=head3 DESCRIPTION

    this method removes an action

=cut

#=============================================================
sub remove_action {
    my $self = shift;
    my $key = shift;
    my $acts = $self->acts();
    my $index = scalar(@{$acts});
    while ($index > 0) {
        $index = $index - 1;
        if ($acts->[$index]->name() eq $key) {
            delete $acts->[$index];
        }
    }
}

1;

