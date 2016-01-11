# vim: set et ts=4 sw=4:
package ManaTools::Shared::GUI::ReplacePoint;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::GUI::ReplacePoint - Class to manage a yui YReplacePoint properly

=head1 SYNOPSIS

use ManaTools::Shared::GUI::ReplacePoint;

my $hbox = ...
my $replacepoint = ManaTools::Shared::GUI::ReplacePoint->new(eventHandler => $dialog, parentWidget => $hbox);
my $container = $replacepoint->container();
my $vbox1 = $factory->createVBox($container);
my $button1 = $self->addWidget($backendItem->label() .'_button1', $factory->createPushButton('Button 1', $vbox1), sub {
    my $self = shift;
    my $yevent = shift;
    my $backendItem = shift;
    my $replacepoint = $self->eventHandler();
    ...
}, $backendItem);
my $button2 = $self->addWidget($backendItem->label() .'_button2', $factory->createPushButton('Button 2', $vbox), sub {...}, $backendItem);
my $vbox2 = $factory->createVBox($container);
my $vbox3 = $factory->createVBox($container);
$replacepoint->finished();

...


$replacepoint->clear();
...
# start anew with adding widgets, items, etc...
...
$replacepoint->finished();


=head1 DESCRIPTION

This class wraps YReplacePoint and it's child widgets to handle


=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Shared::GUI::ReplacePoint

=head1 SEE ALSO

yui::YReplacePoint

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

with 'ManaTools::Shared::GUI::EventHandlerRole';

use yui;

#=============================================================

=head2 new

=head3 INPUT

    hash ref containing
        eventHandler:       the parent that does eventHandlerRole
        parentWidget:       the parent widget


=head3 DESCRIPTION

    new is inherited from Moose, to create a ReplacePoint object

=cut

#=============================================================

has 'eventHandler' => (
    is => 'rw',
    does => 'Maybe[ManaTools::Shared::GUI::EventHandlerRole]',
    lazy => 1,
    default => undef,
    trigger => sub {
        my $self = shift;
        my $new = shift;
        my $old = shift;
        $old->delEventHandler($self) if (defined $old);
        $new->addEventHandler($self) if (defined $new);
    }
);

has 'parentWidget' => (
    is => 'ro',
    isa => 'yui::YWidget',
    required => 1,
);

has 'container' => (
    is => 'ro',
    isa => 'yui::YReplacePoint',
    init_arg => undef,
    lazy => 1,
    builder => 'buildReplacePoint',
);

#=============================================================

=head2 buildReplacePoint

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    builds the YReplacePoint widget

=cut

#=============================================================
sub buildReplacePoint {
    my $self = shift;
    my $dialog = $self->parentDialog();
    my $ydialog = $dialog->dialog();
    my $factory = $dialog->factory();
    my $parentWidget = $self->parentWidget();

    # lock windows for multiple changes
    $ydialog->startMultipleChanges();

    # create the replacepoint
    my $replacepoint = $factory->createReplacePoint($parentWidget);

    return $replacepoint;
}

#=============================================================

=head2 clear

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    clears the replacepoint to prepare for re-adding new items, call finished() afterwards

=cut

#=============================================================
sub clear {
    my $self = shift;
    my $container = $self->container();
    my $dialog = $self->parentDialog();
    my $ydialog = $dialog->dialog();

    # clear out the events of the children
    $self->clearEvents();

    # lock windows for multiple changes (this way it becomes ready for adding new children)
    $ydialog->startMultipleChanges();

    # clear out replacepoint
    $container->deleteChildren();
}

#=============================================================

=head2 finished

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    finalizes the widgets on the ReplacePoint

=cut

#=============================================================
sub finished {
    my $self = shift;
    my $container = $self->container();
    my $dialog = $self->parentDialog();
    my $ydialog = $dialog->dialog();

    # trigger showChild on the container
    $container->showChild();

    # recalulate layout
    $ydialog->recalcLayout();

    # unlock windows for multiple changes
    $ydialog->doneMultipleChanges();
}

#=============================================================

no Moose;
__PACKAGE__->meta->make_immutable;


1;
