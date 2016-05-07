# vim: set et ts=4 sw=4:
package ManaTools::Shared::GUI::SelectionWidgetRole;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::GUI::SelectionWidgetRole - a Properties Moose::Role

=head1 SYNOPSIS
    package Foo;

    with 'ManaTools::Shared::GUI::SelectionWidgetRole';

    sub selectedItem {
        my $self = shift;
        ...
        return $item;
    }

    sub addItems {
        my $self = shift;
        my $yitemcollection = shift;
        ...
    }

    sub deleteAllItems {
        my $self = shift;
        ...
    }

    1;

    ...


=head1 DESCRIPTION

    This Role is to specify an SelectionWidgetRole, specifically, the need to provide a proper processSelectionWidget function

=head1 SUPPORT

    You can find documentation for this Role with the perldoc command:

    perldoc ManaTools::Shared::GUI::SelectionWidgetRole


=head1 AUTHOR

    Maarten Vanraes <alien@rmail.be>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2015-2016 Maarten Vanraes <alien@rmail.be>

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

requires 'addItems';
requires 'deleteAllItems';
requires 'selectedItem';

#=============================================================

1;

