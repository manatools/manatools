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
    $f->add('aname', sub { my @params = @_; ... ; return 'foo'; });
    my $res = $f->act('aname', 'param1', 'param2', @params);
    $f->remove('aname');


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

## Class DATA
has 'actions' => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    isa => 'HashRef[CodeRef]',
    default => sub {return {};}
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

    return keys %{$self->actions};
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
    return $self->actions->{$key}(@_);
}

#=============================================================

=head2 add

=head3 INPUT

    $key: string
    $action: sub

=head3 DESCRIPTION

    this method adds an action

=cut

#=============================================================
sub add {
    my $self = shift;
    my $key = shift;
    my $action = shift;

    $self->actions->{$key} = $action;
}

#=============================================================

=head2 remove

=head3 INPUT

    $key: string

=head3 DESCRIPTION

    this method removes an action

=cut

#=============================================================
sub remove {
    my $self = shift;
    my $key = shift;

    delete $self->actions->{$key};
}

1;

