# vim: set et ts=4 sw=4:
package ManaTools::Shared::GUI::ButtonBoxSelection;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::GUI::ButtonBoxSelection - Class to manage a yui YSelectionBox properly

=head1 SYNOPSIS

use ManaTools::Shared::GUI::ButtonBoxSelection;

my $extlist = ManaTools::Shared::GUI::ButtonBoxSelection->new(name => "ButtonBox1", eventHandler => $dialog, parentWidget => $widget, callback => { my $self = shift; my $yevent = shift; my $backenditem = $_; ... });

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

perldoc ManaTools::Shared::GUI::ButtonBoxSelection

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

extends 'ManaTools::Shared::GUI::CustomSelectionWidget';

has 'buttonWidths' => (
    is => 'ro',
    isa => 'ArrayRef[Int]',
    default => sub {
        return [];
    },
);

has 'replacepoint' => (
    is => 'ro',
    isa => 'ManaTools::Shared::GUI::ReplacePoint',
    init_arg => undef,
    lazy => 1,
    default => sub {
        my $self = shift;
        my $eventHandler = $self->eventHandler();
        my $dialog = $eventHandler->parentDialog();
        my $factory = $dialog->factory();
        my $rpl = ManaTools::Shared::GUI::ReplacePoint->new(eventHandler => $self->eventHandler(), parentWidget => $self->parentWidget());
        $dialog->D("$self: built replacepoint $rpl in parent ". $self->parentWidget());
        $factory->createVStretch($rpl->container());
        $rpl->finished();
        return $rpl;
    },
);

#=============================================================

=head2 _buildSelectionWidget

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    builds the SelectionWidget structure

=cut

#=============================================================
override('_buildSelectionWidget', sub {
    my $self = shift;
    my $parentWidget = $self->parentWidget();
    my $eventHandler = $self->eventHandler();
    my $dialog = $eventHandler->parentDialog();
    my $factory = $dialog->factory();
    # Force replacepoint to be first
    $dialog->D("$self: force replacepoint creation.");
    my $rpl = $self->replacepoint();
    $dialog->D("$self: clear replacepoint $rpl.");
    $rpl->clear();
    $dialog->D("$self: cleared $rpl, build HBox in it");
#    $rpl->container()->setStretchable(0, 1);

    # container should be a hbox in an rpl
    my $container = $factory->createHBox($rpl->container());
    $dialog->D("$self: HBox is $container, return it");
    # need to set it manually, even if it will be set due to it being a builder; because we trigger this function manually sometimes too, and otherwise the hbox will be cleared and redone and be different.
    $self->{'container'} = $container;
    return $container;
});

#=============================================================

=head2 _buildItem

=head3 INPUT

    $self: this object
    $item: yui::YItem

=head3 DESCRIPTION

    build an Item into the SelectionWidget

=cut

#=============================================================
override('_buildItem', sub {
    my $self = shift;
    my $yitem = shift;
    my $index = shift;
    my $eventHandler = $self->eventHandler();
    my $dialog = $eventHandler->parentDialog();
    my $factory = $dialog->factory();
    my $rpl = $self->replacepoint();
    $dialog->D("$self: forcing container...");
    my $container = $self->container();
    $dialog->D("$self: container is $container");
    my $buttonWidths = $self->buttonWidths();
    $dialog->D("$self: build button in $container");

    $dialog->D("$self: create the button: ". $yitem->label() ." in container $container with factory $factory");
    # add a pushbutton inside the container
    my $button = $factory->createPushButton($container, $yitem->label());
    $dialog->D("$self: button $button created in parent $container with label: ". $yitem->label() .".");
    $rpl->addWidget($yitem->label(), $button, sub {
        my $self = shift;
        my $yevent = shift;
        my $backendItem = shift;
        my $buttonbox = $backendItem->[0];
        my $yitem = $backendItem->[1];
        $buttonbox->lastItem($yitem);
        my $eventHandler = $self->eventHandler();
        my $dialog = $eventHandler->parentDialog();
        $dialog->D("$self: builder function to select item $yitem in $backendItem");

        # make sure the event isn't caught and is carried on
        return -1;
    }, [$self, $yitem]);
    # take care of the width
    $dialog->D("$self: set weight: ". $buttonWidths->[$index] ." on button $button.");
    $button->setWeight(0, $buttonWidths->[$index]) if (defined $buttonWidths->[$index]);
    $button->setStretchable(1, 1); # vert stretch
});

#=============================================================

=head2 _finishSelectionWidget

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    builds the SelectionWidget structure

=cut

#=============================================================
override('_finishSelectionWidget', sub {
    my $self = shift;
    my $rpl = $self->replacepoint();
    my $eventHandler = $self->eventHandler();
    my $dialog = $eventHandler->parentDialog();
    $dialog->D("$self: finish replacepoint $rpl");
    $rpl->finished();
});

#=============================================================

no Moose;
__PACKAGE__->meta->make_immutable;


1;
