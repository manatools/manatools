# vim: set et ts=4 sw=4:
package ManaTools::Shared::GUI::EventRole;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::GUI::EventRole - a Properties Moose::Role

=head1 SYNOPSIS
    package Foo;

    with 'ManaTools::Shared::GUI::EventRole';

    sub processEvent {
        my $self = shift;
        my $yevent = shift;
        my $eventHandler = shift;
        ...
        ## return 0 if you want to exit the eventloop
        return 1;
    }

    1;

    ...

    my $dialog = ManaTools::Shared::GUI::Dialog->new(...);
    Foo->new(name => 'Foo #1', eventHandler => $dialog, eventType => $yui::YEvent::WidgetEvent, ...);
    Foo->new(name => 'Foo #2', eventHandler => $dialog, eventType => $yui::YEvent::WidgetEvent, ...);
    return $dialog->call();


=head1 DESCRIPTION

    This Role is to specify an EventRole, specifically, the need to provide a proper processEvent function

=head1 SUPPORT

    You can find documentation for this Role with the perldoc command:

    perldoc ManaTools::Shared::GUI::EventRole


=head1 AUTHOR

    Maarten Vanraes <alien@rmail.be>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2015-2016 Maarten Vanraes <alien@rmail.be>

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

requires 'processEvent';
requires 'basename';

has 'eventHandler' => (
    is => 'ro',
    does => 'ManaTools::Shared::GUI::EventHandlerRole',
    required => 1,
    handles => [ 'parentDialog' ],
);

has 'name' => (
    is => 'rw',
    isa => 'Maybe[Str]',
    lazy => 1,
    default => undef,
);

around 'name' => sub {
    my $orig = shift;
    my $self = shift;
    my $name = undef;
    my $setting = 0;

    # set name if requested
    if (scalar(@_) > 0) {
        $name = shift;
        $setting = 1;
    }
    else {
        $name = $self->$orig();
        $setting = 1 if (!defined $name);
    }

    # return the current name
    # if it's undef, we need to change this...
    if (!defined $name) {
        # generate a unique Event name
        $name = $self->uniqueName($self->eventHandler());
    }

    # set the name if we were setting it
    $name = $self->$orig($name) if ($setting);
    return $name;
};

sub uniqueName {
    my $self = shift;
    my $eventHandler = shift;
    my $name = $self->basename();
    my $i = 1;
    while ($eventHandler->hasEvent($name . $i)) {
        $i = $i + 1;
    }
    return $name . $i;
}

has 'eventType' => (
    is => 'ro',
    isa => 'Int',
    required => 1,
);

sub BUILD {
    my $self = shift;
    my $name = $self->name();
    my $eventHandler = $self->eventHandler();
    # add yourself to the dialog's event handlers
    $eventHandler->addEvent($name, $self);
}

sub DEMOLISH {
    my $self = shift;
    my $name = $self->name();
    my $eventHandler = $self->eventHandler();
    # remove yourself from the event handler
    $eventHandler->delEvent($name) if defined($eventHandler);
}

#=============================================================

1;

