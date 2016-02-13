# vim: set et ts=4 sw=4:
package ManaTools::Shared::GUI::Event;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::GUI::Event - Class to manage various events

=head1 SYNOPSIS

use ManaTools::Shared::GUI::Event;

my $event = ManaTools::Shared::GUI::Event->new(
    name => "Event1",
    parentDialog => $dialog,
    eventType => $yui::YEvent::YWidgetEvent,
    widget => $widget,
    backend => $backend,
    event => sub {
        my $self = shift;
        my $yevent = shift;
        my $backend = shift;
        my $dialog = $self->parentDialog();
        my $ydialog = $dialog->dialog();
        ...
        return 1;
    }
);


=head1 DESCRIPTION

This class wraps the most common dialog functionality


=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Shared::GUI::Event

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
    default => 'Event',
);

with 'ManaTools::Shared::GUI::EventRole';

use yui;

#=============================================================

=head2 new

=head3 INPUT

    hash ref containing
        name:               a name to identify it
        parentDialog:       the parent Dialog
        eventType:          a yui::YEventType
        widget:             an optional widget
        item:               an optional item
        event:              an optional CodeRef that returns 0 if event is
                            not correctly processed
        backend:            an optional backend to be used in the event handler

=head3 DESCRIPTION

    new is inherited from Moose, to create an Event object

=cut

has 'widget' => (
    is => 'ro',
    isa => 'Maybe[yui::YWidget]',
    default => sub {
        return undef;
    }
);

has 'item' => (
    is => 'ro',
    isa => 'Maybe[yui::YItem]',
    default => sub {
        return undef;
    }
);

has 'event' => (
    is => 'rw',
    isa => 'Maybe[CodeRef]',
    lazy => 1,
    default => sub {
        return undef;
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

sub processEvent {
    my $self = shift;
    my $yevent = shift;
    return -1 if ($yevent->eventType != $self->eventType);
    return -1 if ($yevent->eventType == $yui::YEvent::WidgetEvent && !$self->equalsWidget($yevent->widget));
    return -1 if ($yevent->eventType == $yui::YEvent::MenuEvent && !$self->equalsItem($yevent->item));
    my $event = $self->event();
    return $event->($self, $yevent, $self->backend()) if defined($event);
    return -1;
}

sub equalsWidget {
    my $self = shift;
    my $widget = shift;
    return ($self->widget() == $widget);
}

sub equalsItem {
    my $self = shift;
    my $item = shift;
    return ($self->item() == $item);
}

#=============================================================

no Moose;
__PACKAGE__->meta->make_immutable;

1;
