# vim: set et ts=4 sw=4:
package ManaTools::Shared::GUI::EventHandlerRole;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::GUI::EventHandlerRole - a Properties Moose::Role

=head1 SYNOPSIS
    package Foo;

    with 'ManaTools::Shared::GUI::EventHandlerRole';

    1;

    ...

    my $f = Foo->new(...);
    $f->addEvent($event);
    ...
    while(1) {
        ...
        last if (!$f->processEvents($yevent));
    }
    ...
    $f->clearEvents();


=head1 DESCRIPTION

    This Role is to specify an EventHandler Role, specifically, to handle multiple sub-Events

=head1 SUPPORT

    You can find documentation for this Role with the perldoc command:

    perldoc ManaTools::Shared::GUI::EventHandlerRole


=head1 AUTHOR

    Maarten Vanraes <alien@rmail.be>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2015 Maarten Vanraes <alien@rmail.be>

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

has 'events' => (
    is => 'ro',
    isa => 'HashRef[ManaTools::Shared::GUI::EventRole]',
    default => sub {
        return {};
    }
);

#=============================================================

=head2 addEvent

=head3 INPUT

    $self: this object
    $name: a name to identify the event
    $event: an EventRole to be added
    @args: extra optional arguments

=head3 DESCRIPTION

    add an Event to the events list

=cut

#=============================================================
sub addEvent {
    my $self = shift;
    my $name = shift;
    my $event = shift;
    my $events = $self->events();
    die "event named '$name' already exists!" if defined($events->{$name});
    $events->{$name} = $event;
}

#=============================================================

=head2 delEvent

=head3 INPUT

    $self: this object
    $name: a name to identify the event

=head3 DESCRIPTION

    del an event from the events list

=cut

#=============================================================
sub delEvent {
    my $self = shift;
    my $name = shift;
    my $events = $self->events();
    delete $events->{$name} if (defined $events->{$name});
}

#=============================================================

=head2 hasEvent

=head3 INPUT

    $self: this object
    $name: the event identified by $name

=head3 DESCRIPTION

    1 if the event exists, 0 otherwise

=cut

#=============================================================
sub hasEvent {
    my $self = shift;
    my $name = shift;
    my $events = $self->events();
    return defined($events->{$name});
}

#=============================================================

=head2 getEvent

=head3 INPUT

    $self: this object
    $name: the event identified by $name

=head3 OUTPUT

    an ManaTools::Shared::GUI::EventRole

=head3 DESCRIPTION

    returns an event, depending on the name

=cut

#=============================================================
sub getEvent {
    my $self = shift;
    my $name = shift;
    my $events = $self->events();
    die "event named '$name' does not exist!" if !defined($events->{$name});
    return $events->{$name};
}

#=============================================================

=head2 clearEvents

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    clears all events

=cut

#=============================================================
sub clearEvents {
    my $self = shift;
    my $events = $self->events();
    for my $name (keys %{$events}) {
        $self->delEvent($name);
    }
}

#=============================================================

=head2 findEvent

=head3 INPUT

    $self: this object
    $callback: CodeRef to be executed for each event
    @args: extra arguments for the callback

=head3 OUTPUT

    an event if it's found, or undef otherwise

=head3 DESCRIPTION

    returns an Event from the list, according to a callback function, or undef

=cut

#=============================================================
sub findEvent {
    my $self = shift;
    my $callback = shift;
    my @args = @_;
    my $events = $self->events();
    # loop all the items
    for my $event (values %{$events}) {
        return $event if ($callback->($event, @args));
    }
    return undef;
}

#=============================================================

=head2 addWidget

=head3 INPUT

    $self: this object
    $name: a name to identify the widget
    $widget: a yui widget
    $event: an optional CodeRef that will be executed when an Event triggers
    $backend: an optional backend object that will be present in the event handler

=head3 DESCRIPTION

    add a widget event handler to the events list

=cut

#=============================================================
sub addWidget {
    my $self = shift;
    my $name = shift;
    my $widget = shift;
    my $event = shift;
    my $backend = shift;
    return ManaTools::Shared::GUI::Event->new(name => $name, eventHandler => $self, eventType => $yui::YEvent::WidgetEvent, widget => $widget, event => $event, backend => $backend);
}

#=============================================================

=head2 delWidget

=head3 INPUT

    $self: this object
    $widget: a yui widget

=head3 DESCRIPTION

    del a widget event handler from the events list

=cut

#=============================================================
sub delWidget {
    my $self = shift;
    my $widget = shift;
    my $event = $self->findWidget($widget);
    $self->delEvent($event) if (defined $event);
}

#=============================================================

=head2 widget

=head3 INPUT

    $self: this object
    $name: the widget identified by $name

=head3 DESCRIPTION

    returns a yui::YWidget

=cut

#=============================================================
sub widget {
    my $self = shift;
    my $name = shift;
    return undef if (!$self->hasEvent($name));
    my $event = $self->getEvent($name);
    return undef if ($event->eventType() != $yui::YEvent::WidgetEvent);
    return undef if (!$event->isa('ManaTools::Shared::GUI::Event'));
    return $event->widget();
}

#=============================================================

=head2 findWidget

=head3 INPUT

    $self: this object
    $widget: the yui::YWidget to be found

=head3 DESCRIPTION

    returns a ManaTools::Shared::GUI::Dialog::Event that has the widget

=cut

#=============================================================
sub findWidget {
    my $self = shift;
    my $widget = shift;
    return $self->findEvent(sub {
        my $event = shift;
        my $widget = shift;
        return 0 if ($event->eventType() != $yui::YEvent::WidgetEvent);
        return 0 if (!$event->isa('ManaTools::Shared::GUI::Event'));
        return $event->equalsWidget($widget);
    }, $widget);
}

#=============================================================

=head2 processEvents

=head3 INPUT

    $self: this object
    $yevent: the yui::YEvent

=head3 OUTPUT

    0 if the loop should end, 1 otherwise

=head3 DESCRIPTION

    returns an Event from the list, according to a callback function, or undef

=cut

#=============================================================
sub processEvents {
    my $self = shift;
    my $yevent = shift;
    my $events = $self->events();
    # loop all the items
    for my $event (values %{$events}) {
        return 0 if(!$event->processEvent($yevent));
    }
    return 1;
}

#=============================================================

1;

