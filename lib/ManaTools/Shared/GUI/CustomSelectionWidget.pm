# vim: set et ts=4 sw=4:
package ManaTools::Shared::GUI::CustomSelectionWidget;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::GUI::CustomSelectionWidget - Class to manage a yui YSelectionBox properly

=head1 SYNOPSIS

use ManaTools::Shared::GUI::CustomSelectionWidget;

my $extlist = ManaTools::Shared::GUI::CustomSelectionWidget->new(name => "ButtonBox1", eventHandler => $dialog, parentWidget => $widget, callback => { my $self = shift; my $yevent = shift; my $backenditem = $_; ... });

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

perldoc ManaTools::Shared::GUI::CustomSelectionWidget

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

with 'ManaTools::Shared::GUI::SelectionWidgetRole';

use yui;

has 'eventHandler' => (
    is => 'ro',
    does => 'ManaTools::Shared::GUI::EventHandlerRole',
    required => 1,
    handles => [ 'parentDialog' ],
);

has 'items' => (
    is => 'rw',
    isa => 'ArrayRef[yui::YItem]',
    default => sub { return [] },
);

has 'lastItem' => (
    is => 'rw',
    isa => 'Maybe[yui::YItem]',
);

has 'parentWidget' => (
    is => 'ro',
    isa => 'yui::YWidget',
    required => 1,
);

has 'container' => (
    is => 'ro',
    isa => 'yui::YWidget',
    required => 0,
    lazy => 1,
    init_arg => undef,
    builder => '_buildSelectionWidget',
);

#=============================================================

=head2 new

=head3 INPUT

    hash ref containing
        name:               a name for the widget to add event to the eventHandler
        eventHandler:       the parent that does eventHandlerRole
        parentWidget:       the parent widget
        callback:           optional parameter to execute a callback when an item has changed


=head3 DESCRIPTION

    new is inherited from ExtWidget, to create a CustomSelectionWidget object

=cut

#=============================================================

=head2 selectedItem

=head3 INPUT

    $self: this object

=head3 OUTPUT

    YItem: the selected item

=head3 DESCRIPTION

    returns the item that is selected when an event fires

=cut

#=============================================================
sub selectedItem {
    my $self = shift;
    return $self->lastItem();
}

#=============================================================

=head2 _buildSelectionWidget

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    builds the SelectionWidget structure

=cut

#=============================================================
sub _buildSelectionWidget {
    my $self = shift;
    my $parentWidget = $self->parentWidget();
    my $dialog = $self->parentDialog();
    my $factory = $dialog->factory();

    return undef;
};

#=============================================================

=head2 buildSelectionWidget

=head3 INPUT

    $self: this object

=head3 OUTPUT

    yui::YWidget

=head3 DESCRIPTION

    builds the SelectionWidget structure according to current Items

=cut

#=============================================================
sub buildSelectionWidget {
    my $self = shift;
    my $dialog = $self->parentDialog();

    $dialog->D("$self: trigger _buildSelectionWidget");
    my $container = $self->_buildSelectionWidget();
    $dialog->D("$self: triggered _buildSelectionWidget");

    my $i = 0;
    for my $yitem (@{$self->items()}) {
        $dialog->D("$self: trigger buildItem($yitem, $i)");
        $self->buildItem($yitem, $i);
        $i = $i + 1;
    }

    return $container;
};

#=============================================================

=head2 _buildItem

=head3 INPUT

    $self: this object
    $item: yui::YItem

=head3 DESCRIPTION

    build an Item into the SelectionWidget

=cut

#=============================================================
sub _buildItem {
    my $self = shift;
    my $yitem = shift;
    my $index = shift;
    my $dialog = $self->parentDialog();
    my $factory = $dialog->factory();
    # force the presence of the container
    my $container = $self->container();

};

#=============================================================

=head2 buildItem

=head3 INPUT

    $self: this object
    $item: yui::YItem

=head3 DESCRIPTION

    build an Item into the SelectionWidget and sets lastItem

=cut

#=============================================================
sub buildItem {
    my $self = shift;
    my $yitem = shift;
    my $index = shift;
    my $dialog = $self->parentDialog();

    # add stuff according to container
    $dialog->D("$self: trigger _buildItem");
    $self->_buildItem($yitem, $index);
    if (!defined $self->lastItem()) {
        # set first item as lastItem();
        $self->lastItem($yitem);
    }
};

#=============================================================

=head2 _finishSelectionWidget

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    finishes the SelectionWidget structure

=cut

#=============================================================
sub _finishSelectionWidget {
    my $self = shift;
    my $parentWidget = $self->parentWidget();
    my $dialog = $self->parentDialog();
    my $factory = $dialog->factory();

};

#=============================================================

=head2 finishSelectionWidget

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    finishes the SelectionWidget structure

=cut

#=============================================================
sub finishSelectionWidget {
    my $self = shift;
    my $dialog = $self->parentDialog();
    $dialog->D("$self: trigger _finishSelectionWidget");
    $self->_finishSelectionWidget();
};

#=============================================================

=head2 addItems

=head3 INPUT

    $self: this object
    $items: yui::YItemCollection

=head3 DESCRIPTION

    adds the items

=cut

#=============================================================
sub addItems {
    my $self = shift;
    my $yitemcollection = shift;

    # check we're adding nothing
    if ($yitemcollection->size() == 0) {
        # no change, just bail out
        return ;
    }
    my $dialog = $self->parentDialog();

    # start rebuild if needed
    $dialog->D("$self: maybe needed: buildSelectionWidget()");
    my $container = $self->buildSelectionWidget();
    $dialog->D("$self: container is $container");

    my $i = 0;
    while ($i < $yitemcollection->size()) {
        my $yitem = $yitemcollection->get($i);
        push @{$self->items()}, $yitem;

    $dialog->D("$self: trigger buildItem($yitem, $i)");
        $self->buildItem($yitem, $i);
        $i = $i + 1;
    }

    # finish building SelectionWidget
    $dialog->D("$self: trigger finishSelectionWidget()");
    $self->finishSelectionWidget();
};

#=============================================================

=head2 deleteAllItems

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    clears all items

=cut

#=============================================================
sub deleteAllItems {
    my $self = shift;
    my $items = $self->items();

    # check if it's empty already
    if (scalar(@{$items}) == 0) {
        # no change, just bail out
        return ;
    }

    my $dialog = $self->parentDialog();
    # clear the inner dialogs and update
    @{$items} = ();

    # start rebuild if needed (and clear it)
    $dialog->D("$self: trigger buildSelectionWidget()");
    my $container = $self->buildSelectionWidget();

    # clear lastItem
    $self->lastItem(undef);

    # finish building SelectionWidget
    $dialog->D("$self: trigger finishSelectionWidget()");
    $self->finishSelectionWidget();
};

#=============================================================

no Moose;
__PACKAGE__->meta->make_immutable;


1;
