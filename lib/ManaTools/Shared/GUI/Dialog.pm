# vim: set et ts=4 sw=4:
package ManaTools::Shared::GUI::Dialog;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::GUI::Dialog - Class to manage a yui YDumbTab properly

=head1 SYNOPSIS

use ManaTools::Shared::GUI::Dialog;

my $dlg = ManaTools::Shared::GUI::Dialog->new(
    dialogType => ManaTools::Shared::GUI::Dialog->mainDialog, ## or popupDialog
    title => "New Title",
    icon => $icon,
    optFields => [
        ManaTools::Shared::GUI::Dialog->TimeField,
        ManaTools::Shared::GUI::Dialog->DateField,
        ManaTools::Shared::GUI::Dialog->TabField,
    ],
    buttons => [
        ManaTools::Shared::GUI::Dialog->cancelButton,
        ManaTools::Shared::GUI::Dialog->okButton,
    ],
    event_timeout => 0, # event timeout in msec during the waitForEvent()
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
with 'ManaTools::Shared::GUI::EventHandlerRole';

use diagnostics;
use utf8;

use Moose::Util::TypeConstraints;
use MooseX::ClassAttribute;

use yui;
use ManaTools::Shared::GUI::Event;
#=============================================================

=head2 new

=head3 INPUT

    hash ref containing
        module:             the parent ManaTools::Module
        dialogType:         ManaTools::Shared::GUI::Dialog->mainDialog, or popupDialog
        title:              a title
        icon:               an icon
        layout:             a callback that builds the layout of the dialog
        restoreValues:      an optional callback that restore the values to an $info HashRef
        event_timeout:      an optional and rw timeout in msec during the waitForEvent()
                            needs a ManaTools::Shared::GUI::Event to manage the $yui::YEvent::TimeoutEvent
        buttons:            an optional hashref containing
                                ManaTools::Shared::GUI::Dialog->cancelButton and/or
                                ManaTools::Shared::GUI::Dialog->okButton
        result:             an optional callback for returning a result (mostly for popupDialogs)

=head3 DESCRIPTION

    new is inherited from Moose, to create a Dialog object

=cut

#=============================================================

has 'module' => (
    is => 'ro',
    isa => 'ManaTools::Module',
    required => 1,
    handles => ['loc', 'logger', 'D', 'I', 'W', 'E'],
);

has 'factory' => (
    is => 'ro',
    isa => 'Maybe[yui::YWidgetFactory]',
    lazy => 1,
    init_arg => undef,
    default => sub {
       return yui::YUI::widgetFactory;
    },
);

has 'optFactory' => (
    is => 'ro',
    isa => 'Maybe[yui::YOptionalWidgetFactory]',
    lazy => 1,
    init_arg => undef,
    default => sub {
        return yui::YUI::optionalWidgetFactory;
    },
);

has 'mgaExternalFactory' => (
    is => 'ro',
    isa => 'Maybe[yui::YMGAWidgetFactory]',
    lazy => 1,
    init_arg => undef,
     builder => '_MGAFactoryInitialize'
);

sub _MGAFactoryInitialize {
    my $self = shift();

    $self->factory();  # just to be sure default factory is initialized first

    my $mageiaPlugin = "mga";
    my $mgaFactory   = yui::YExternalWidgets::externalWidgetFactory($mageiaPlugin);
    return yui::YMGAWidgetFactory::getYMGAWidgetFactory($mgaFactory);
}

has 'dialog' => (
    is => 'rw',
    isa => 'Maybe[yui::YDialog]',
    lazy => 1,
    init_arg => undef,
    default => sub {
        return undef;
    },
);

subtype 'TimeoutType'
    => as Int
    => where {($_ >= 0)};

has 'event_timeout' => (
    is => 'rw',
    isa => 'TimeoutType',
    lazy => 1,
    default => 0,
);

subtype 'DialogType'
    => as Int
    => where {($_ > 0 && $_<=2)};

has 'dialogType' => (
    is => 'ro',
    isa => 'DialogType',
    default => 1,
);

class_has 'mainDialog' => (
    is => 'ro',
    isa => 'DialogType',
    init_arg => undef,
    default => sub {return 1;},
);

class_has 'popupDialog' => (
    is => 'ro',
    isa => 'DialogType',
    init_arg => undef,
    default => sub {return 2;},
);

has 'title' => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->module->title();
    }
);

has 'icon' => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->module->icon();
    }
);

class_has 'cancelButton' => (
    is => 'ro',
    init_arg => undef,
    default => sub {return 'cancelButton';},
);

class_has 'okButton' => (
    is => 'ro',
    init_arg => undef,
    default => sub {return 'okButton';},
);

class_has 'closeButton' => (
    is => 'ro',
    init_arg => undef,
    default => sub {return 'closeButton';},
);

class_has 'resetButton' => (
    is => 'ro',
    init_arg => undef,
    default => sub {return 'resetButton';},
);

class_has 'aboutButton' => (
    is => 'ro',
    init_arg => undef,
    default => sub {return 'aboutButton';},
);

has 'buttons' => (
    is => 'ro',
    isa => 'HashRef[CodeRef]',
    lazy => 1,
    default => sub {
        return {};
    },
);

class_has 'DateField' => (
    is => 'ro',
    isa => 'Int',
    init_arg => undef,
    default => sub {return 1;},
);
class_has 'TimeField' => (
    is => 'ro',
    isa => 'Int',
    init_arg => undef,
    default => sub {return 2;},
);
class_has 'TabField' => (
    is => 'ro',
    isa => 'Int',
    init_arg => undef,
    default => sub {return 3;},
);

has 'optFields' => (
    is => 'ro',
    isa => 'ArrayRef[Int]',
    lazy => 1,
    default => sub {
        return [];
    },
);

has 'layoutDirty' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
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
        return 0 if ($field == ManaTools::Shared::GUI::Dialog->TimeField && !$optFactory->hasTimeField());
        return 0 if ($field == ManaTools::Shared::GUI::Dialog->DateField && !$optFactory->hasDateField());
        return 0 if ($field == ManaTools::Shared::GUI::Dialog->TabField && !$optFactory->hasDumbTab());
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
    my $buttonbox = $factory->createHBox($layout);

    ## Left side
    my $align = $factory->createLeft($buttonbox);
    my $hbox = $factory->createHBox($align);

    $self->addWidget('aboutButton',
                     $factory->createPushButton($hbox, $self->loc->N("&About")),
                     $self->getButton(ManaTools::Shared::GUI::Dialog->aboutButton)) if $self->getButton(ManaTools::Shared::GUI::Dialog->aboutButton);
    $self->addWidget('resetButton', $factory->createPushButton($hbox, $self->loc->N("&Reset")), $self->getButton(ManaTools::Shared::GUI::Dialog->resetButton)) if $self->getButton(ManaTools::Shared::GUI::Dialog->resetButton);

    ## Right side
    $align = $factory->createRight($buttonbox);
    $hbox = $factory->createHBox($align);
    $self->addWidget('cancelButton', $factory->createPushButton($hbox, $self->loc->N("&Cancel")), $self->getButton(ManaTools::Shared::GUI::Dialog->cancelButton)) if $self->getButton(ManaTools::Shared::GUI::Dialog->cancelButton);
    $self->addWidget('okButton', $factory->createPushButton($hbox, $self->loc->N("&Ok")), $self->getButton(ManaTools::Shared::GUI::Dialog->okButton)) if $self->getButton(ManaTools::Shared::GUI::Dialog->okButton);
    $self->addWidget('closeButton', $factory->createPushButton($hbox, $self->loc->N("&Close")), $self->getButton(ManaTools::Shared::GUI::Dialog->closeButton)) if $self->getButton(ManaTools::Shared::GUI::Dialog->closeButton);
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

=head2 multipleChanges

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    Start multiple changes (if required)

=cut

#=============================================================
sub multipleChanges {
    my $self = shift;
    my $ydialog = $self->dialog();
    return if ($self->layoutDirty());
    $ydialog->startMultipleChanges();
    $self->layoutDirty(1);
}

#=============================================================

=head2 recalcLayout

=head3 INPUT

    $self: this object
    $force: bool

=head3 DESCRIPTION

    Recalculates the layout and ends multiple changes (if required or if forced)

=cut

#=============================================================
sub recalcLayout {
    my $self = shift;
    my $force = shift || 0;
    my $ydialog = $self->dialog();
    return if (!$self->layoutDirty() || $force);
    $ydialog->recalcLayout();
    $ydialog->doneMultipleChanges();
    $self->layoutDirty(0);
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
    my $oldAppIcon  = yui::YUI::app()->applicationIcon();

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->title());
    ## set icon if not already set by external launcher
    yui::YUI::app()->setApplicationIcon($self->icon());

    ## required fields
    die "required widgets missing from YOptionalFactory" if (!$self->checkFields());

    ## restore values
    my $restoreValues = $self->restoreValues();
    $self->info($restoreValues->($self)) if defined($restoreValues);

    ## create the dialog
    my $factory = $self->factory();
    $self->dialog($factory->createMainDialog()) if ($self->dialogType() == ManaTools::Shared::GUI::Dialog->mainDialog);
    $self->dialog($factory->createPopupDialog()) if ($self->dialogType() == ManaTools::Shared::GUI::Dialog->popupDialog);
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
        my $yevent = $ydialog->pollEvent();
        if (!$yevent) {
            # only recalc layout after all pending events have run
            $self->recalcLayout();
            # wait for a new event
            $yevent = $ydialog->waitForEvent($self->event_timeout);
        }
        # if we have an event, process it (and possibly exit)
        last if (!$self->processEvents($yevent));
    }

    my $resultcb = $self->result();
    my $result = 1;
    $result = $resultcb->($self) if defined ($resultcb);

    # end dialog
    $ydialog->destroy();

    # restore old application title and icon
    yui::YUI::app()->setApplicationTitle($oldAppTitle) if $oldAppTitle;
    yui::YUI::app()->setApplicationIcon($self->icon()) if $oldAppIcon;

    return $result;
}

no Moose;
__PACKAGE__->meta->make_immutable;


1;
