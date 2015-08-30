# vim: set et ts=4 sw=4:
package ManaTools::Shared::GUI::Dialog;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::GUI::Dialog - Class to manage a yui YDumbTab properly

=head1 SYNOPSIS

use ManaTools::Shared::GUI::Dialog;

my $dlg = ManaTools::Shared::GUI::Dialog->new(
    dialogType => $ManaTools::Shared::GUI::Dialog::mainDialog, ## or popupDialog
    title => "New Title",
    icon => $icon,
    optFields => [
        $ManaTools::Shared::GUI::Dialog::TimeField,
        $ManaTools::Shared::GUI::Dialog::DateField,
        $ManaTools::Shared::GUI::Dialog::TabField,
    ],
    buttons => [
        $ManaTools::Shared::GUI::Dialog::cancelButton,
        $ManaTools::Shared::GUI::Dialog::okButton,
    ],
    layout => sub { my $self = shift; my $layoutstart = shift; my $dlg = $self->dialog(); my $info = $self->info(); ... $self->addWidget('button1', $button, sub{...}, $backendItem1); },
    restoreValues => sub { my $self = shift; $info = {}; ...; return $info },
    result => sub { my $self = shift; ... },
);

my $result = $dlg->call();

## you should call this from the Module, and not directly from here...

=head1 DESCRIPTION

This class wraps the most common dialog functionality


=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Shared::GUI::Dialog

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

with 'ManaTools::Shared::GUI::EventHandlerRole';
use Moose::Util::TypeConstraints;

use yui;
use ManaTools::Shared::GUI::Event;
#=============================================================

=head2 new

=head3 INPUT

    hash ref containing
        module:             the parent ManaTools::Module
        dialogType:         $ManaTools::Shared::GUI::Dialog::mainDialog, or popupDialog
        title:              a title
        icon:               an icon
        layout:             a callback that builds the layout of the dialog
        restoreValues:      an optional callback that restore the values to an $info HashRef
        buttons:            an optional hashref containing 
                                $ManaTools::Shared::GUI::Dialog::cancelButton and/or
                                $ManaTools::Shared::GUI::Dialog::okButton
        result:             an optional callback for returning a result (mostly for popupDialogs)

=head3 DESCRIPTION

    new is inherited from Moose, to create a Dialog object

=cut

#=============================================================

has 'module' => (
    is => 'ro',
    isa => 'ManaTools::Module',
    required => 1,
);

has 'factory' => (
    is => 'rw',
    isa => 'Maybe[yui::YWidgetFactory]',
    lazy => 1,
    init_arg => undef,
    default => sub {
        return undef;
    },
);

has 'optFactory' => (
    is => 'rw',
    isa => 'Maybe[yui::YOptionalWidgetFactory]',
    lazy => 1,
    init_arg => undef,
    default => sub {
        return undef;
    },
);

has 'dialog' => (
    is => 'rw',
    isa => 'Maybe[yui::YDialog]',
    lazy => 1,
    init_arg => undef,
    default => sub {
        return undef;
    },
);

our $mainDialog = 1;
our $popupDialog = 2;

subtype 'DialogType'
    => as Int
    => where {($_ > 0 && $_<=2)};

has 'dialogType' => (
    is => 'ro',
    isa => 'DialogType',
    required => 1,
);

has 'title' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has 'icon' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

our $cancelButton = 1;
our $okButton = 2;
our $closeButton = 3;
our $resetButton = 4;
our $aboutButton = 5;

has 'buttons' => (
    is => 'ro',
    isa => 'HashRef[CodeRef]',
    lazy => 1,
    default => sub {
        return {};
    },
);

our $DateField = 1;
our $TimeField = 2;
our $TabField = 3;

has 'optFields' => (
    is => 'ro',
    isa => 'ArrayRef[Int]',
    lazy => 1,
    default => sub {
        return [];
    },
);

has 'info' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub {
        return {};
    }
);

has 'layout' => (
    is => 'ro',
    isa => 'CodeRef',
    required => 1,
);

has 'restoreValues' => (
    is => 'ro',
    isa => 'Maybe[CodeRef]',
    lazy => 1,
    default => sub {
        return undef;
    },
);

has 'result' => (
    is => 'ro',
    isa => 'Maybe[CodeRef]',
    lazy => 1,
    default => sub {
        return undef;
    }
);

sub loc {
    my $self = shift;
    return $self->module->loc(@_);
}

#=============================================================

=head2 checkFields

=head3 INPUT

    $self: this object

=head3 OUTPUT

    returns true or false depending on success

=head3 DESCRIPTION

    helper function to check if the optional factory has the optFields

=cut

#=============================================================
sub checkFields {
    my $self = shift;
    my $fields = $self->optFields();
    my $optFactory = $self->optFactory();
    for my $field (@{$fields}) {
        return 0 if ($field == $ManaTools::Shared::GUI::Dialog::TimeField && !$optFactory->hasTimeField());
        return 0 if ($field == $ManaTools::Shared::GUI::Dialog::DateField && !$optFactory->hasDateField());
        return 0 if ($field == $ManaTools::Shared::GUI::Dialog::TabField && !$optFactory->hasdumbTab());
    }
    return 1;
}

#=============================================================

=head2 getButton

=head3 INPUT

    $self: this object
    $buttonType: a buttonType

=head3 OUTPUT

    returns the CodeRef associated with the buttonType, or undef

=head3 DESCRIPTION

    gets the CodeRef associated with a buttontype

=cut

#=============================================================
sub getButton {
    my $self = shift;
    my $buttonType = shift;
    my $buttons = $self->buttons;

    return $buttons->{$buttonType} if (defined($buttons->{$buttonType}));
    return undef;
}

#=============================================================

=head2 addButtons

=head3 INPUT

    $self: this object
    $ylayout: a layout widget to base the buttons on

=head3 DESCRIPTION

    add buttons to the layout according to $self->buttons()

=cut

#=============================================================
sub addButtons {
    my $self = shift;
    my $layout = shift;
    my $buttons = $self->buttons;
    return if scalar(keys %{$buttons}) == 0;
    my $factory = $self->factory();
    
    ### buttons on the last line
    $factory->createVSpacing($layout, 1.0);
    my $buttonbox = $factory->createHBox($layout);

    ## Left side
    my $align = $factory->createLeft($buttonbox);
    my $hbox = $factory->createHBox($align);
    $self->addWidget('aboutButton', $factory->createPushButton($hbox, $self->loc->N("&About")), $self->getButton($ManaTools::Shared::GUI::Dialog::aboutButton)) if $self->getButton($ManaTools::Shared::GUI::Dialog::aboutButton);
    $self->addWidget('resetButton', $factory->createPushButton($hbox, $self->loc->N("&Reset")), $self->getButton($ManaTools::Shared::GUI::Dialog::resetButton)) if $self->getButton($ManaTools::Shared::GUI::Dialog::resetButton);

    ## Right side
    $align = $factory->createRight($buttonbox);
    $hbox = $factory->createHBox($align);
    $self->addWidget('cancelButton', $factory->createPushButton($hbox, $self->loc->N("&Cancel")), $self->getButton($ManaTools::Shared::GUI::Dialog::cancelButton)) if $self->getButton($ManaTools::Shared::GUI::Dialog::cancelButton);
    $self->addWidget('okButton', $factory->createPushButton($hbox, $self->loc->N("&Ok")), $self->getButton($ManaTools::Shared::GUI::Dialog::okButton)) if $self->getButton($ManaTools::Shared::GUI::Dialog::okButton);
    $self->addWidget('closeButton', $factory->createPushButton($hbox, $self->loc->N("&Close")), $self->getButton($ManaTools::Shared::GUI::Dialog::closeButton)) if $self->getButton($ManaTools::Shared::GUI::Dialog::closeButton);
    $factory->createHSpacing($hbox, 1.0);

    ## no changes by default
    my $ydialog = $self->dialog();
    if (defined($self->widget('closeButton'))) {
        $ydialog->setDefaultButton($self->widget('closeButton'));
    }
    elsif (defined($self->widget('cancelButton'))) {
        $ydialog->setDefaultButton($self->widget('cancelButton'));
    }
    elsif (defined($self->widget('okButton'))) {
        $ydialog->setDefaultButton($self->widget('okButton'));
    }
}

#=============================================================

=head2 call

=head3 INPUT

    $self: this object

=head3 OUTPUT

    the result from the dialog

=head3 DESCRIPTION

    Creates a dialog (either popup or main) and handles it's events and resturns the proper result.

=cut

#=============================================================
sub call {
    my $self = shift;
    my $oldAppTitle = yui::YUI::app()->applicationTitle();

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->title());
    ## set icon if not already set by external launcher
    yui::YUI::app()->setApplicationIcon($self->icon());

    $self->factory(yui::YUI::widgetFactory);
    $self->optFactory(yui::YUI::optionalWidgetFactory);

    ## required fields
    die "required widgets missing from YOptionalFactory" if (!$self->checkFields());

    ## restore values
    my $restoreValues = $self->restoreValues();
    $self->info($restoreValues->($self)) if defined($restoreValues);

    ## create the dialog
    my $factory = $self->factory();
    $self->dialog($factory->createMainDialog()) if ($self->dialogType() == $ManaTools::Shared::GUI::Dialog::mainDialog);
    $self->dialog($factory->createPopupDialog()) if ($self->dialogType() == $ManaTools::Shared::GUI::Dialog::popupDialog);
    my $ydialog = $self->dialog();
    my $layoutstart = $ydialog;
    my $vbox = undef;
    if (scalar(keys %{$self->buttons()}) > 0) {
        # we have buttons, so, we need a vbox + hbox basic layout to start with
        $vbox = $factory->createVBox($ydialog);
        $layoutstart = $factory->createHBox($vbox);
    }
    ## if layout returns a YWidget, we can define buttons on it
    $self->addButtons($vbox) if defined($vbox);

    ## build the whole layout
    my $layout = $self->layout->($self, $layoutstart);


    ## add a cancelEvent
    ManaTools::Shared::GUI::Event->new(name => 'cancelEvent', eventHandler => $self, eventType => $yui::YEvent::CancelEvent, event => sub { return 0; });

    # main loop
    while(1) {
        my $yevent = $ydialog->waitForEvent(1000);
        last if (!$self->processEvents($yevent));
    }

    my $resultcb = $self->result();
    my $result = 1;
    $result = $resultcb->($self) if defined ($resultcb);

    # end dialog
    $ydialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($oldAppTitle) if $oldAppTitle;
    return $result;
}

no Moose;
__PACKAGE__->meta->make_immutable;


1;
