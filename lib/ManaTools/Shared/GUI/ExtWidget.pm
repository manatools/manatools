# vim: set et ts=4 sw=4:
package ManaTools::Shared::GUI::ExtWidget;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::GUI::ExtWidget - Class to manage a selection widget which has different controls

=head1 SYNOPSIS

use ManaTools::Shared::GUI::ExtWidget;

my $extwidget = ManaTools::Shared::GUI::ExtWidget->new(name => "Selection1", eventHandler => $dialog, parentWidget => $widget, callback => { my $self = shift; my $yevent = shift; my $backenditem = $_; ... });

$extwidget->addSelectorItem("Label 1", $backenditem1, sub {
    my ($self, $parent, $backendItem) = @_;
    my $dialog = $self->parentDialog();
    my $factory = $dialog->factory();
    my $vbox = $factory->createVBox($parent);
    my $button1 = $self->addWidget($backendItem->label() .'_button1', $factory->createPushButton('Button 1', $vbox), sub {
        my $self = shift;
        my $yevent = shift;
        my $backendItem = shift;
        my $selectorWidget = $self->eventHandler();
        ...
    }, $backendItem);
    my $button2 = $self->addWidget($backendItem->label() .'_button2', $factory->createPushButton('Button 2', $vbox), sub {...}, $backendItem);
    ...
});
$extwidget->addSelectorItem("Label 2", $backenditem2, sub { my ($self, $parent, $backendItem) = @_; my $factory = $self->parentDialog()->factory(); my $vbox = $factory->createVBox($parent); ... } );
$extwidget->addSelectorItem("Label 3", $backenditem3, sub { my ($self, $parent, $backendItem) = @_; my $factory = $self->parentDialog()->factory(); my $vbox = $factory->createVBox($parent); ... } );
$extwidget->addSelectorItem("Label 4", $backenditem4, sub { my ($self, $parent, $backendItem) = @_; my $factory = $self->parentDialog()->factory(); my $vbox = $factory->createVBox($parent); ... } );
$extwidget->finishedSelectorItems();


=head1 DESCRIPTION

This class wraps a selector Widget with backend items to handle


=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Shared::GUI::ExtWidget

=head1 SEE ALSO

yui::YSelectionWidget

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

has 'basename' => (
    is => 'ro',
    isa => 'Str',
    default => 'ExtWidget',
);

with 'ManaTools::Shared::GUI::EventRole';

use yui;
use ManaTools::Shared::GUI::ReplacePoint;

#=============================================================

=head2 new

=head3 INPUT

    hash ref containing
        name:               a name for the widget to add event to the eventHandler
        eventHandler:       the parent that does eventHandlerRole
        parentWidget:       the parent widget
        callback:           optional parameter to execute a callback when an item has changed


=head3 DESCRIPTION

    new is inherited from Moose, to create a ExtWidget object

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
    isa => 'ArrayRef[ManaTools::Shared::GUI::ExtWidget::Item]',
    lazy => 1,
    init_arg => undef,
    default => sub {
        return [];
    }
);

has 'itemEventType' => (
    is => 'ro',
    isa => 'Int',
    init_arg => 0,
    default => $yui::YEvent::MenuEvent,
);

# TODO: eventHandler from event Role should react with replacepoint!!!
has 'replacepoint' => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Shared::GUI::ReplacePoint]',
    init_arg => undef,
    handles => ['addEvent', 'delEvent', 'getEvent', 'addWidget', 'delWidget', 'widget', 'addItem', 'delItem', 'item'],
    default => sub {
        return undef;
    }
);

has 'selector' => (
    is => 'ro',
    does => 'yui::YWidget',
    init_arg => undef,
    lazy => 1,
    builder => 'buildSelectionWidget',
);

has 'lastItem' => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Shared::GUI::ExtWidget::Item]',
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

=head2 _buildSelectorWidget

=head3 INPUT

    $self: this object

=head3 OUTPUT

    ($selector, $parent): $selector is the YSelectionWidget; $parent is the replacepoint's parent

=head3 DESCRIPTION

    builds the selection widget, needs to be overridden in subclasses

=cut

#=============================================================
sub _buildSelectorWidget {
    my $self = shift;
    my $parentWidget = shift;
    return (undef, $parentWidget);
}

#=============================================================

=head2 buildSelectionWidget

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    builds the selection widget

=cut

#=============================================================
sub buildSelectionWidget {
    my $self = shift;

    # this builds the actual widget in subclasses
    my ($selectorWidget, $parentWidget) = $self->_buildSelectorWidget($self->parentWidget());

    # create a replacepoint on the selectionWidget
    $self->{replacepoint} = ManaTools::Shared::GUI::ReplacePoint->new(parentWidget => $parentWidget);

    # because this Event's processEvent also takes care of the replacepoints
    # processEvents, it means we cannot set the replacepoint's (being an
    # eventHandler) eventHandler -- which would add (next to setting the
    # parentEventHandler) the replacepoint as a child, and thus also call
    # processEvents from the parent down. Therefor, we'll set the
    # parentEventHandler directly, so that any parent referrals still work.
    $self->{replacepoint}->parentEventHandler($self->{eventHandler});

    # don't add any children right away
    $self->{replacepoint}->finished();

    return $selectorWidget;
}

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
    return undef;
}

#=============================================================

=head2 processEvent

=head3 INPUT

    $self: this object
    $yevent: yui::YEvent

=head3 DESCRIPTION

    handles the SelectorWidget events and executes callback if necessary

=cut

#=============================================================
sub processEvent {
    my $self = shift;
    my $yevent = shift;
    my $replacepoint = $self->replacepoint();
    my $items = $self->items();

    # call subevents
    my $processed = $replacepoint->processEvents($yevent);
    return $processed if $processed >= 0;

    # filter out the item event type...
    return -1 if ($yevent->eventType() != $self->itemEventType());

    # only items from *this* selected Item
    my $yitem = $self->_selectorItem($yevent);
    my $item = $self->findSelectorItem($yitem);
    return -1 if !defined($item);

    # build the children
    $self->buildSelectorItem($item);

    # execute callback if needed
    my $callback = $self->callback();
    my $result = -1;
    $result = $callback->($self, $yevent, $item->backend()) if defined($callback);

    # mark last item as this one
    $self->lastItem($item);

    # return result of callback
    return $result;
}

#=============================================================

=head2 addSelectorItem

=head3 INPUT

    $self: this object
    $label: a label for the YItem
    $backendItem: a backendItem needed to identify and/or handle the event
    $buildWidget: a CodeRef to rebuild the widget when required

=head3 OUTPUT

    the created ManaTools::Shared::GUI::ExtWidget::Item

=head3 DESCRIPTION

    Creates an item and adds it to the ExtWidget. Internally, it creates a
    yui::YItem and adds it to the YItemCollection. If it's the first item,
    mark it as the lastitem.

=cut

#=============================================================
sub addSelectorItem {
    my $self = shift;
    my $label = shift;
    my $backendItem = shift;
    my $buildWidget = shift;
    my $items = $self->items();
    my $item = ManaTools::Shared::GUI::ExtWidget::Item->new(backend => $backendItem, builder => $buildWidget);
    push @{$items}, $item;
    $item->setLabel($label);
    $item->addToCollection($self->itemcollection());
    if (scalar(@{$items}) == 1) {
        $self->lastItem($item);
    }
    return $item;
}

#=============================================================

=head2 findSelectorItem

=head3 INPUT

    $self: this object
    $yitem: the YItem to be found

=head3 DESCRIPTION

    returns a ManaTools::Shared::GUI::ExtWidget::Item that has the YItem

=cut

#=============================================================
sub findSelectorItem {
    my $self = shift;
    my $yitem = shift;
    # loop all the items
    for my $i (@{$self->items()}) {
        return $i if ($i->equals($yitem));
    }
    return undef;
}

#=============================================================

=head2 buildSelectorItem

=head3 INPUT

    $self: this object
    $item: the item to be built (child widgets from this SelectorWidget will be recreated inside the associated replacepoint)

=head3 DESCRIPTION

    builds an item on the internal replace point

=cut

#=============================================================
sub buildSelectorItem {
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

=head2 clearSelectorItems

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    clears the selectorWidget of items to prepare for re-adding new items, call finishedSelectorItems() afterwards

=cut

#=============================================================
sub clearSelectorItems {
    my $self = shift;
    my $items = $self->items();

    # remove all events before deleting all items
    $self->clearEvents();

    for (my $i = 0; $i < scalar(@{$items}); $i = $i + 1) {
        delete $items->[$i];
    }
}

#=============================================================

=head2 finishedSelectorItems

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    finalizes the items on the ExtWidget

=cut

#=============================================================
sub finishedSelectorItems {
    my $self = shift;
    my $selector = $self->selector();

    # remove all Items before adding
    $selector->deleteAllItems();

    # add items from collection
    $selector->addItems($self->itemcollection);

    # set last item to know the active item
    my $item = $self->lastItem();

    # show the current one if there is one
    $self->buildSelectorItem($item) if defined($item);

    # create a new itemcollection for adding new items
    $self->itemcollection(new yui::YItemCollection());
}

#=============================================================

no Moose;
__PACKAGE__->meta->make_immutable;


1;

#=============================================================

package ManaTools::Shared::GUI::ExtWidget::Item;

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
