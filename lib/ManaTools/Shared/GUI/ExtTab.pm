# vim: set et ts=4 sw=4:
package ManaTools::Shared::GUI::ExtTab;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::GUI::ExtTab - Class to manage a yui YDumbTab properly

=head1 SYNOPSIS

use ManaTools::Shared::GUI::ExtTab;

my $exttab = ManaTools::Shared::GUI::ExtTab->new(name => "Tab1", eventHandler => $dialog, parentWidget => $widget, callback => { my $self = shift; my $yevent = shift; my $backenditem = $_; ... });

$exttab->addTabItem("Label 1", $backenditem1, sub {
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
$exttab->addTabItem("Label 2", $backenditem2, sub { my ($self, $parent, $backendItem) = @_; my $factory = $self->parentDialog()->factory(); my $vbox = $factory->createVBox($parent); ... } );
$exttab->addTabItem("Label 3", $backenditem3, sub { my ($self, $parent, $backendItem) = @_; my $factory = $self->parentDialog()->factory(); my $vbox = $factory->createVBox($parent); ... } );
$exttab->addTabItem("Label 4", $backenditem4, sub { my ($self, $parent, $backendItem) = @_; my $factory = $self->parentDialog()->factory(); my $vbox = $factory->createVBox($parent); ... } );
$exttab->finishedTabItems();


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

Copyright (C) 2015, Maarten Vanraes.

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

with 'ManaTools::Shared::GUI::EventRole';

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

    new is inherited from Moose, to create a ExtTab object

=cut

#=============================================================

has '+eventType' => (
    required => 0,
    default => $yui::YEvent::WidgetEvent,
);

has 'parentWidget' => (
    is => 'ro',
    isa => 'yui::YWidget',
    required => 1,
);

has 'callback' => (
    is => 'ro',
    isa => 'Maybe[CodeRef]',
    lazy => 1,
    default => sub {
        return undef;
    }
);

has 'items' => (
    is => 'ro',
    isa => 'ArrayRef[ManaTools::Shared::GUI::ExtTab::Item]',
    lazy => 1,
    init_arg => undef,
    default => sub {
        return [];
    }
);

has 'replacepoint' => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Shared::GUI::ReplacePoint]',
    init_arg => undef,
    handles => ['addEvent', 'delEvent', 'getEvent', 'addWidget', 'delWidget', 'widget', 'addItem', 'delItem', 'item'],
    default => sub {
        return undef;
    }
);

has 'tab' => (
    is => 'ro',
    isa => 'yui::YDumbTab',
    init_arg => undef,
    lazy => 1,
    builder => 'buildTab',
);

has 'lastItem' => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Shared::GUI::ExtTab::Item]',
    init_arg => undef,
    default => sub {
        return undef;
    }
);

has 'itemcollection' => (
    is => 'rw',
    isa => 'yui::YItemCollection',
    init_arg => undef,
    default => sub {
        return new yui::YItemCollection();
    }
);

#=============================================================

=head2 buildTab

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    builds the YDumbTab widget

=cut

#=============================================================
sub buildTab {
    my $self = shift;
    my $dialog = $self->parentDialog();
    my $optFactory = $dialog->optFactory();
    my $parentWidget = $self->parentWidget();

    # create the tab
    my $tab = $optFactory->createDumbTab($parentWidget);

    # create a replacepoint on the tab
    $self->{replacepoint} = ManaTools::Shared::GUI::ReplacePoint->new(parentWidget => $tab);
    # don't add any children right away
    $self->{replacepoint}->finished();

    return $tab;
}

#=============================================================

=head2 processEvent

=head3 INPUT

    $self: this object
    $yevent: yui::YEvent

=head3 DESCRIPTION

    handles the YDumbTab events and executes callback if necessary

=cut

#=============================================================
sub processEvent {
    my $self = shift;
    my $yevent = shift;
    my $replacepoint = $self->replacepoint();
    my $items = $self->items();

    # call subevents
    return 0 if (!$replacepoint->processEvents($yevent));

    # only MenuEvents here...
    return 1 if ($yevent->eventType() != $yui::YEvent::MenuEvent);

    # only items from *this* tab
    my $yitem = $yevent->item();
    my $item = $self->findTabItem($yitem);
    return 1 if !defined($item);

    # build the children
    $self->buildTabItem($item);

    # execute callback if needed
    my $callback = $self->callback();
    my $result = 1;
    $result = $callback->($self, $yevent, $item->backend()) if defined($callback);

    # mark last item as this one
    $self->lastItem($item);

    # return result of callback
    return $result;
}

#=============================================================

=head2 addTabItem

=head3 INPUT

    $self: this object
    $label: a label for the YItem
    $backendItem: a backendItem needed to identify and/or handle the event
    $buildWidget: a CodeRef to rebuild the widget when required

=head3 OUTPUT

    the created ManaTools::Shared::GUI::ExtTab::Item

=head3 DESCRIPTION

    Creates an item and adds it to the ExtTab. Internally, it creates a
    yui::YItem and adds it to the YItemCollection. If it's the first item,
    mark it as the lastitem.

=cut

#=============================================================
sub addTabItem {
    my $self = shift;
    my $label = shift;
    my $backendItem = shift;
    my $buildWidget = shift;
    my $items = $self->items();
    my $item = ManaTools::Shared::GUI::ExtTab::Item->new(backend => $backendItem, builder => $buildWidget);
    push @{$items}, $item;
    $item->setLabel($label);
    $item->addToCollection($self->itemcollection());
    if (scalar(@{$items}) == 1) {
        $self->lastItem($item);
    }
    return $item;
}

#=============================================================

=head2 findTabItem

=head3 INPUT

    $self: this object
    $yitem: the YItem to be found

=head3 DESCRIPTION

    returns a ManaTools::Shared::GUI::ExtTab::Item that has the YItem

=cut

#=============================================================
sub findTabItem {
    my $self = shift;
    my $yitem = shift;
    # loop all the items
    for my $i (@{$self->items()}) {
        return $i if ($i->equals($yitem));
    }
    return undef;
}

#=============================================================

=head2 buildTabItem

=head3 INPUT

    $self: this object
    $item: the item to be built (widgets from this tab will be recreated in the tab)

=head3 DESCRIPTION

    builds an item on the internal replace point

=cut

#=============================================================
sub buildTabItem {
    my $self = shift;
    my $item = shift;
    my $replacepoint = $self->replacepoint();
    my $container = $replacepoint->container();

    # clear out any previous children/events
    $replacepoint->clear();

    # build item's widgetbuilder
    my $builder = $item->builder();
    $builder->($self, $container, $item->backend()) if (defined $builder);

    # finished with replacepoint children
    $replacepoint->finished();
}

#=============================================================

=head2 clearTabItems

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    clears the tab to prepare for re-adding new items, call finishedTabItems() afterwards

=cut

#=============================================================
sub clearTabItems {
    my $self = shift;
    my $items = $self->items();

    # remove all events before deleting all items
    $self->clearEvents();

    for (my $i = 0; $i < scalar(@{$items}); $i = $i + 1) {
        delete $items->[$i];
    }
}

#=============================================================

=head2 finishedTabItems

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    finalizes the items on the ExtTab

=cut

#=============================================================
sub finishedTabItems {
    my $self = shift;

    # remove all Items before adding
    $self->tab->deleteAllItems();

    # add items from collection
    $self->tab->addItems($self->itemcollection);

    # set last item to know the active item
    my $item = $self->lastItem();

    # show the current one if there is one
    $self->buildTabItem($item) if defined($item);

    # create a new itemcollection for adding new items
    $self->itemcollection(new yui::YItemCollection());
}

#=============================================================

no Moose;
__PACKAGE__->meta->make_immutable;


1;

#=============================================================

package ManaTools::Shared::GUI::ExtTab::Item;

use Moose;
use diagnostics;
use utf8;

use yui;

has 'builder' => (
    is => 'ro',
    isa => 'Maybe[CodeRef]',
    lazy => 1,
    default => sub {
        return undef;
    }
);

has 'item' => (
    is => 'ro',
    isa => 'yui::YItem',
    init_arg => undef,
    default => sub {
        return new yui::YItem('', 0);
    }
);

has 'backend' => (
    is => 'rw',
    isa => 'Maybe[Ref]',
    lazy => 1,
    default => sub {
        return undef;
    }
);

#=============================================================

sub setLabel {
    my $self = shift;
    my $label = shift;
    my $yitem = $self->item();
    $yitem->setLabel($label);
}

sub equals {
    my $self = shift;
    my $item = shift;
    return ($self->item() == $item);
}

sub addToCollection {
    my $self = shift;
    my $collection = shift;
    my $yitem = $self->item();
    $yitem->DISOWN();
    $collection->push($yitem);
}

#=============================================================

no Moose;
__PACKAGE__->meta->make_immutable;

1;
