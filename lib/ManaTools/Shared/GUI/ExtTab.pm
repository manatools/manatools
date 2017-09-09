# vim: set et ts=4 sw=4:
package ManaTools::Shared::GUI::ExtTab;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::GUI::ExtTab - Class to manage a yui YDumbTab properly

=head1 SYNOPSIS

use ManaTools::Shared::GUI::ExtTab;

my $exttab = ManaTools::Shared::GUI::ExtTab->new(name => "Tab1", eventHandler => $dialog, parentWidget => $widget, callback => { my $self = shift; my $yevent = shift; my $backenditem = $_; ... });

$exttab->addSelectorItem("Label 1", $backenditem1, sub {
    my ($self, $parent, $backendItem) = @_;
    my $dialog = $self->parentDialog();
    my $factory = $dialog->factory();
    my $vbox = $factory->createVBox($parent);
    my $button1 = $self->addWidget($backendItem->label() .'_button1', $factory->createPushButton('Button 1', $vbox), sub {
        my $self = shift;
        my $yevent = shift;
        my $backendItem = shift;
        my $tab = $self->eventHandler();
        ...
    }, $backendItem);
    my $button2 = $self->addWidget($backendItem->label() .'_button2', $factory->createPushButton('Button 2', $vbox), sub {...}, $backendItem);
    ...
});
$exttab->addSelectorItem("Label 2", $backenditem2, sub { my ($self, $parent, $backendItem) = @_; my $factory = $self->parentDialog()->factory(); my $vbox = $factory->createVBox($parent); ... } );
$exttab->addSelectorItem("Label 3", $backenditem3, sub { my ($self, $parent, $backendItem) = @_; my $factory = $self->parentDialog()->factory(); my $vbox = $factory->createVBox($parent); ... } );
$exttab->addSelectorItem("Label 4", $backenditem4, sub { my ($self, $parent, $backendItem) = @_; my $factory = $self->parentDialog()->factory(); my $vbox = $factory->createVBox($parent); ... } );
$exttab->finishedSelectorItems();


=head1 DESCRIPTION

This class wraps YDumbTab with backend items to handle


=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Shared::GUI::ExtTab

=head1 SEE ALSO

yui::YDumbTab

=head1 AUTHOR

Maarten Vanraes <alien@rmail.be>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2015-2017, Maarten Vanraes.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2, as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA

=head1 FUNCTIONS

=cut


use Moose;
use diagnostics;
use utf8;

extends 'ManaTools::Shared::GUI::ExtWidget';

has '+basename' => (
    default => 'ExtTab',
);

has '+eventType' => (
    required => 0,
    default => $yui::YEvent::WidgetEvent,
);

use yui;

#=============================================================

=head2 new

=head3 INPUT

    hash ref containing
        name:               a name for the widget to add event to the eventHandler
        eventHandler:       the parent that does eventHandlerRole
        parentWidget:       the parent widget
        callback:           optional parameter to execute a callback when an item has changed


=head3 DESCRIPTION

    new is inherited from ExtWidget, to create a ExtTab object

=cut

#=============================================================

=head2 _selectorItem

=head3 INPUT

    $self: this object
    $yevent: yui::YEvent

=head3 OUTPUT

    YItem: the selected item

=head3 DESCRIPTION

    returns the items that is selected when an event fires

=cut

#=============================================================
sub _selectorItem {
    my $self = shift;
    my $yevent = shift;
    return $yevent->item();
}

#=============================================================

=head2 _buildSelectorWidget

=head3 INPUT

    $self: this object

=head3 OUTPUT

    ($selector, $parent): $selector is the YSelectionWidget; $parent is the replacepoint's parent

=head3 DESCRIPTION

    builds the YDumbTab widget

=cut

#=============================================================
override('_buildSelectorWidget', sub {
    my $self = shift;
    my $parentWidget = shift;
    my $dialog = $self->parentDialog();
    my $optFactory = $dialog->optFactory();

    # create the tab
    my $tab = $optFactory->createDumbTab($parentWidget);
    return ($tab, $tab);
});

#=============================================================

no Moose;
__PACKAGE__->meta->make_immutable;


1;
