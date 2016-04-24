# vim: set et ts=4 sw=4:
package ManaTools::Shared::GUI::ActionList;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::GUI::ActionList - Class to visualize ActionsRole

=head1 SYNOPSIS

package FooActions;

with 'ManaTools::Shared::ActionsRole';

...


use ManaTools::Shared::GUI::ActionList;

my $hbox = ...
my $foo = FooActions->new();
my $actionlist = ManaTools::Shared::GUI::ActionList->new(parentWidget => $hbox, actions => $foo);
$foo->add_action('bar', sub {...});
$actionlist->refresh();
...

=head1 DESCRIPTION

This class is a GUI helper for ActionsRole classes


=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Shared::GUI::ActionList

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

use ManaTools::Shared::GUI::ReplacePoint;

#=============================================================

=head2 new

=head3 INPUT

    hash ref containing
        parentWidget: the parent widget
        properties: the properties object

=head3 DESCRIPTION

    new is inherited from Moose, to create a ActionList object

=cut

#=============================================================

has 'eventHandler' => (
    is => 'ro',
    does => 'ManaTools::Shared::GUI::EventHandlerRole',
    required => 1,
);

has 'parentWidget' => (
    is => 'ro',
    isa => 'yui::YWidget',
    required => 1,
);

has 'actions' => (
    is => 'rw',
    does => 'ManaTools::Shared::ActionsRole',
    trigger => \&refresh,
    default => undef,
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
        $factory->createVStretch($rpl->container());
        $rpl->finished();
        return $rpl;
    },
);

#=============================================================

=head2 refresh

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    rebuilds the properties

=cut

#=============================================================
sub refresh {
    my $self = shift;
    my $eventHandler = $self->eventHandler();
    my $dialog = $eventHandler->parentDialog();
    my $factory = $dialog->factory();
    my $parentWidget = $self->parentWidget();
    my $replacepoint = $self->replacepoint();
    my $actions = $self->actions();

    # clear and start new changes on replacepoint
    $replacepoint->clear();
    if (defined $actions) {
        my $hsquash = $factory->createHSquash($replacepoint->container());
        my $vbox = $factory->createVBox($hsquash);
        # rebuild for all actions a Button
        for my $key (sort $actions->get_actions()) {
            my $button = $factory->createPushButton($vbox, $key);
            $button->setStretchable(0, 1);
            $replacepoint->addWidget($key, $button, sub {
                my $self = shift;
                my $yevent = shift;
                my $args = shift;
                my $actions = shift(@{$args});
                my $key = shift(@{$args});
                my @args = @_;
                return $actions->act($key, @args);
            }, [$actions, $key]);
        }
    }
    # finished
    $replacepoint->finished();
}

#=============================================================

no Moose;
__PACKAGE__->meta->make_immutable;


1;
