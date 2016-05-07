# vim: set et ts=4 sw=4:
package ManaTools::Shared::GUI::ExtButtonBox;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::GUI::ExtButtonBox - Class to manage a yui YSelectionBox properly

=head1 SYNOPSIS

use ManaTools::Shared::GUI::ExtButtonBox;

my $extlist = ManaTools::Shared::GUI::ExtButtonBox->new(name => "ButtonBox1", eventHandler => $dialog, parentWidget => $widget, callback => { my $self = shift; my $yevent = shift; my $backenditem = $_; ... });

$extlist->addSelectorItem("Label 1", $backenditem1, sub {
    my ($self, $parent, $backendItem) = @_;
    my $dialog = $self->parentDialog();
    my $factory = $dialog->factory();
    my $vbox = $factory->createVBox($parent);
    my $button1 = $self->addWidget($backendItem->label() .'_button1', $factory->createPushButton('Button 1', $vbox), sub {
        my $self = shift;
        my $yevent = shift;
        my $backendItem = shift;
        my $list = $self->eventHandler();
        ...
    }, $backendItem);
    my $button2 = $self->addWidget($backendItem->label() .'_button2', $factory->createPushButton('Button 2', $vbox), sub {...}, $backendItem);
    ...
});
$extlist->addSelectorItem("Label 2", $backenditem2, sub { my ($self, $parent, $backendItem) = @_; my $factory = $self->parentDialog()->factory(); my $vbox = $factory->createVBox($parent); ... } );
$extlist->addSelectorItem("Label 3", $backenditem3, sub { my ($self, $parent, $backendItem) = @_; my $factory = $self->parentDialog()->factory(); my $vbox = $factory->createVBox($parent); ... } );
$extlist->addSelectorItem("Label 4", $backenditem4, sub { my ($self, $parent, $backendItem) = @_; my $factory = $self->parentDialog()->factory(); my $vbox = $factory->createVBox($parent); ... } );
$extlist->finishedSelectorItems();


=head1 DESCRIPTION

This class wraps YSelectionBox with backend items to handle


=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Shared::GUI::ExtButtonBox

=head1 SEE ALSO

yui::YSelectionBox

=head1 AUTHOR

Maarten Vanraes <alien@rmail.be>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2015-2016, Maarten Vanraes.

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

use ManaTools::Shared::GUI::ButtonBoxSelection;

has '+basename' => (
    default => 'ExtButtonBox',
);

has '+itemEventType' => (
    default => $yui::YEvent::WidgetEvent,
);

has 'buttonWidths' => (
    is => 'ro',
    isa => 'ArrayRef[Int]',
    required => 1,
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

    new is inherited from ExtWidget, to create a ExtButtonBox object

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
    my $buttonbox = $self->selector();
    return $buttonbox->selectedItem();
}

#=============================================================

=head2 _buildSelectorWidget

=head3 INPUT

    $self: this object

=head3 OUTPUT

    ($selector, $parent): $selector is the YSelectionWidget; $parent is the replacepoint's parent

=head3 DESCRIPTION

    builds the YSelectionBox widget

=cut

#=============================================================
override('_buildSelectorWidget', sub {
    my $self = shift;
    my $parentWidget = shift;
    my $dialog = $self->parentDialog();
    my $factory = $dialog->factory();

    # create the buttonbox
    my $vbox = $factory->createVBox($parentWidget);
    $dialog->D("$self: make buttonbox in $vbox");
    my $bb = ManaTools::Shared::GUI::ButtonBoxSelection->new(parentWidget => $vbox, eventHandler => $self->eventHandler(), buttonWidths => $self->buttonWidths());
    # force visualising the container first
    $dialog->D("$self: force visualization, by accessing $bb container()");
    $bb->container();
    return ($bb, $vbox);
});

#=============================================================

=head2 _finishSelectorWidget

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    finalizes the selection widget, needs to be overridden in subclasses

=cut

#=============================================================
override('_finishSelectorWidget', sub {
    my $self = shift;
    my $selectorWidget = shift;
    my $dialog = $self->parentDialog();
    $dialog->D("$self: setting Weight distribution to ". $selectorWidget->replacepoint()->container() ." & ". $self->{replacepoint}->container());
    # set weight for both replacepoints
    $selectorWidget->replacepoint()->container()->setWeight(1, 3);
    $self->{replacepoint}->container()->setWeight(1, 15);
});

#=============================================================

no Moose;
__PACKAGE__->meta->make_immutable;


1;
