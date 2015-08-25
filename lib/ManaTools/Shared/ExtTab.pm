# vim: set et ts=4 sw=4:
package ManaTools::Shared::ExtTab;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::ExtTab - Class to manage a yui YDumbTab properly

=head1 SYNOPSIS

use ManaTools::Shared::ExtTab;

my $exttab = ManaTools::Shared::ExtTab->new(parentWidget => $widget, factory => $factory, optFactory => $optFactory, callback => { my $backenditem = $_; ... });

$exttab->addItem("Label 1", $backenditem1, sub { my ($factory, $optFactory, $parent, $backendItem) = @_; ... } );
$exttab->addItem("Label 2", $backenditem2, sub { my ($factory, $optFactory, $parent, $backendItem) = @_; ... } );
$exttab->addItem("Label 3", $backenditem3, sub { my ($factory, $optFactory, $parent, $backendItem) = @_; ... } );
$exttab->addItem("Label 4", $backenditem4, sub { my ($factory, $optFactory, $parent, $backendItem) = @_; ... } );
$exttab->finishedItems();

...

while {
  ...
  $exttab->processEvents();
  ...
}


=head1 DESCRIPTION

This class wraps YDumbTab with backend items to handle


=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Shared::ExtTab

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

use yui;

#=============================================================

=head2 new

=head3 INPUT

    hash ref containing
        optfactory:         optfactory needed to create a YDumbTab
        callback:           optional parameter to execute a callback


=head3 DESCRIPTION

    new is inherited from Moose, to create a ExtTab object

=cut

#=============================================================

has 'factory' => (
    is => 'ro',
    isa => 'yui::YWidgetFactory',
    required => 1,
);

has 'optFactory' => (
    is => 'ro',
    isa => 'yui::YOptionalWidgetFactory',
    required => 1,
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
    isa => 'HashRef',
    lazy => 1,
    init_arg => undef,
    default => sub {
        return {};
    }
);

has 'widgetBuilders' => (
    is => 'ro',
    isa => 'HashRef[CodeRef]',
    lazy => 1,
    init_arg => undef,
    default => sub {
        return {};
    }
);

has 'container' => (
    is => 'rw',
    isa => 'Maybe[yui::YReplacePoint]',
    init_arg => undef,
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
    isa => 'Maybe[yui::YItem]',
    init_arg => undef,
    default => sub {
        return undef;
    }
);

has 'itemcollection' => (
    is => 'ro',
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
    my $tab = $self->optFactory->createDumbTab($self->parentWidget);
    $self->{container} = $self->factory->createReplacePoint($tab);
    return $tab;
}

#=============================================================

=head2 processEvents

=head3 INPUT

    $self: this object
    $event: yui::YEvent from $dlg->waitForEvent();

=head3 DESCRIPTION

    handles the YDumbTab events and executes callback if necessary

=cut

#=============================================================
sub processEvents {
    my $self = shift;
    my $event = shift;
    my $items = $self->items();
    return if ($event->eventType() != $yui::YEvent::MenuEvent);
    my $item = $event->item();
    for my $i (keys %{$items}) {
        if ($i == $item) {
            $self->buildItem($i);
            $self->callback()->($items->{$i});
        }
    }
}

#=============================================================

=head2 addItem

=head3 INPUT

    $self: this object
    $label: a label for the YItem
    $backendItem: a backendItem needed to identify and/or handle the event
    $buildWidget: a CodeRef to rebuild the widget when required

=head3 OUTPUT

    the created yui::YItem

=head3 DESCRIPTION

    adds an item to the ExtTab

=cut

#=============================================================
sub addItem {
    my $self = shift;
    my $label = shift;
    my $backendItem = shift;
    my $buildWidget = shift;
    my $item = new yui::YItem($label, 0);
    $self->items->{$item} = $backendItem;
    $self->widgetBuilders->{$item} = $buildWidget;
    $item->DISOWN();
    print STDERR "processEvent: add item: $item\n";
    $self->itemcollection->push($item);
    if (scalar(keys $self->items) == 1) {
        $self->lastItem($item);
    }
    return $item;
}

#=============================================================

=head2 buildItem

=head3 INPUT

    $self: this object
    $item: the item to be built

=head3 DESCRIPTION

    builds an item on the internal replace point

=cut

#=============================================================
sub buildItem {
    my $self = shift;
    my $item = shift;
    # clear out replacepoint
    $self->container->deleteChildren();
    # build item's widgetbuilder
    for my $i (keys %{$self->widgetBuilders}) {
        if ($i == $item) {
            my $builder = $self->widgetBuilders->{$i};
            $builder->($self->factory, $self->optFactory, $self->container, $self->items->{$i}) if (defined $builder);
        }
    }
    $self->container->showChild();
}

#=============================================================

=head2 finishedItems

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    finalizes the items on the ExtTab

=cut

#=============================================================
sub finishedItems {
    my $self = shift;
    $self->tab->addItems($self->itemcollection);
    $self->buildItem($self->tab->selectedItem());
}

#=============================================================

no Moose;
__PACKAGE__->meta->make_immutable;


1;
