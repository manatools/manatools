# vim: set et ts=4 sw=4:
package ManaTools::Module::Disk;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Module::Disk - This module aims to configure system disk and time

=head1 SYNOPSIS

    my $diskSettings = ManaTools::Module::Disk->new();
    $diskSettings->start();

=head1 DESCRIPTION

Long_description

=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Module::Disk

=head1 SEE ALSO

SEE_ALSO

=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2014-2015, Angelo Naselli.

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

use Moose::Util::TypeConstraints;
use MooseX::ClassAttribute;

use ManaTools::Shared::PropertiesRole;
use ManaTools::Shared::GUI;
use ManaTools::Shared::GUI::Dialog;
use ManaTools::Shared::GUI::ReplacePoint;
use ManaTools::Shared::GUI::Properties;
use ManaTools::Shared::GUI::ExtTab;
use File::ShareDir ':ALL';
use ManaTools::Shared::Locales;
use ManaTools::Shared::disk_backend;

use yui;

extends qw( ManaTools::Module );

has '+icon' => (
    default => File::ShareDir::dist_file(ManaTools::Shared::distName(), 'images/manadisk.png'),
);

has 'sh_gui' => (
    is => 'rw',
    lazy => 1,
    init_arg => undef,
    builder => '_SharedGUIInitialize'
);

has 'backend' => (
    is => 'ro',
    lazy => 1,
    init_arg => undef,
    default => sub {
        return ManaTools::Shared::disk_backend->new();
    }
);

subtype 'PartBaseType'
    => as Int
    => where {($_ > 0 && $_ <= 3)};

class_has 'baseTypeDisks' => (
    is => 'ro',
    isa => 'PartBaseType',
    init_arg => undef,
    default => sub {return 1;},
);

class_has 'baseTypeUnused' => (
    is => 'ro',
    isa => 'PartBaseType',
    init_arg => undef,
    default => sub {return 2;},
);

class_has 'baseTypeMount' => (
    is => 'ro',
    isa => 'PartBaseType',
    init_arg => undef,
    default => sub {return 3;},
);

has baseType => (
    is => 'rw',
    isa => 'PartBaseType',
    default => ManaTools::Module::Disk->baseTypeDisks,
    trigger => \&_rebuildParts,
);

has simplified => (
    is => 'rw',
    isa => 'Bool',
    default => 1,
    trigger => \&_rebuildParts,
);

has mainDialog => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Shared::GUI::Dialog]',
    default => sub {
        return undef;
    },
);

has replacepoint => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Shared::GUI::ReplacePoint]',
    default => undef,
    init_arg => undef,
);

has partProperties => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Shared::GUI::Properties]',
    default => undef,
    init_arg => undef,
    handles => {
        set_properties => 'properties',
    },
);

sub _SharedGUIInitialize {
    my $self = shift;

    $self->sh_gui(ManaTools::Shared::GUI->new() );
}


=head1 VERSION

Version 1.0.1

=cut

our $VERSION = '1.0.1';

#=============================================================

=head2 BUILD

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    The BUILD method is called after a Moose object is created,
    in this methods Services loads all the service information.

=cut

#=============================================================
sub BUILD {
    my $self = shift;

    if (! $self->name) {
        $self->name ($self->loc->N("Storage partitioning & Mounts"));
    }
}

#=============================================================

=head2 start

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method extends Module::start and is invoked to
    start admin disk

=cut

#=============================================================
sub start {
    my $self = shift;

    $self->_adminDiskPanel();
}

sub _rebuildTab {
    my $self = shift;
    my $eventHandler = shift;
    my $container = shift;
    my @items = @_;
    my $tab = ManaTools::Shared::GUI::ExtTab->new(eventHandler => $eventHandler, parentWidget => $container);
    for my $i (@items) {
        $tab->addTabItem($i->label(), $i, sub {
            my $self = shift;
            my $parent = shift;
            my $backendItem = shift;
            my $dialog = $self->parentDialog();
            my $module = $dialog->module();
            my $factory = $dialog->factory();
            my $vbox = $factory->createVBox($parent);
            $self->addWidget($backendItem->label() .': button 1', $factory->createPushButton($vbox, $backendItem->label() .': button 1'), sub { my $backendItem = shift; print STDERR "backendItem: ". $backendItem->label() ."::button1\n"; });
            $self->addWidget($backendItem->label() .': button 2', $factory->createPushButton($vbox, $backendItem->label() .': button 2'), sub { my $backendItem = shift; print STDERR "backendItem: ". $backendItem->label() ."::button2\n"; });
            $self->addWidget($backendItem->label() .': button 3', $factory->createPushButton($vbox, $backendItem->label() .': button 3'), sub { my $backendItem = shift; print STDERR "backendItem: ". $backendItem->label() ."::button3\n"; });
            $factory->createHStretch($vbox);
            $factory->createVStretch($vbox);
            # update the properties
            $module->set_properties($i);
        });
    }
    $tab->finishedTabItems();
}

sub _rebuildList {
    my $self = shift;
    my $eventHandler = shift;
    my $container = shift;
    my @items = @_;
}

sub _rebuildTree {
    my $self = shift;
    my $eventHandler = shift;
    my $container = shift;
    my @items = @_;
}

sub _rebuildItems {
    my $self = shift;
    my $info = shift;
    my $eventHandler = shift;
    my $container = shift;
    if ($info->{type} eq 'tab') {
        return $self->_rebuildTab($eventHandler, $container, @{$info->{items}});
    }
    if ($info->{type} eq 'list') {
        return $self->_rebuildList($eventHandler, $container, @{$info->{items}});
    }
    if ($info->{type} eq 'tree') {
        return $self->_rebuildTree($eventHandler, $container, @{$info->{items}});
    }
    return undef;
}

sub _rebuildParts {
    my $self = shift;
    my $dialog = $self->mainDialog();
    my $baseType = $self->baseType();
    my $simplified = $self->simplified();
    my $info = $dialog->info();

    my $rpl = $self->replacepoint();
    # TODO: rebuild Tabs according to baseType and simplified, instead of always disks
    $rpl->clear();
    $self->_rebuildItems($info->{disks}, $rpl, $rpl->container());
    $rpl->finished();
}

sub _rebuildSimplified {
    my $self = shift;
    my $dialog = $self->mainDialog();
    my $baseType = $self->baseType();
    my $simplified = $self->simplified();
}

sub _switchBaseType {
    my $event = shift;
    my $yevent = shift;
    my $baseType = shift;
    my $dialog = $event->parentDialog();
    my $module = $dialog->module();

    ## setting baseType will trigger rebuild
    $module->baseType($baseType);
    return 1;
}

sub _switchSimplified {
    my $event = shift;
    my $yevent = shift;
    my $dialog = $event->parentDialog();
    my $module = $dialog->module();

    ## setting simplified will triggere rebuild
    ## TODO: handle Checkbox widget event to determine true or false
    #$self->simplified(...);
    return 1;
}

sub _adminDiskPanel {
    my $self = shift;
    
    $self->mainDialog(ManaTools::Shared::GUI::Dialog->new(
        dialogType => ManaTools::Shared::GUI::Dialog->mainDialog, ## or popupDialog
        module => $self,
        title => $self->name,
        icon => $self->icon,
        optFields => [
            ManaTools::Shared::GUI::Dialog->TabField,
        ],
        buttons => {
            ManaTools::Shared::GUI::Dialog->aboutButton => sub {return 1;},
            ManaTools::Shared::GUI::Dialog->resetButton => sub {return 1;},
            ManaTools::Shared::GUI::Dialog->cancelButton => sub {return 0;},
            ManaTools::Shared::GUI::Dialog->okButton => sub {return 0;},
        },
        layout => sub {
            my $self = shift;
            my $layoutstart = shift;
            my $dlg = $self->dialog();
            my $factory = $self->factory();
            my $optFactory = $self->optFactory();
            my $info = $self->info();
            my $module = $self->module();

            #    MainDialog
            # +---------------------------VBOX------------------------+
            # |  +------------------------HBOX---------------------+  |
            # |  | +--------------------+           +------------+ |  |
            # |  | |_________HBOX_______|           |__CHECKBOX__| |  |
            # |  +-------------------------------------------------+  |
            # |  +------------------------HBOX---------------------+  |
            # |  | +----------VBOX-----------+  +------VBOX------+ |  |
            # |  | | +---------------------+ |  |                | |  |
            # |  | | |                     | |  |                | |  |
            # |  | | |________TAB__________| |  |                | |  |
            # |  | | +---------------------+ |  |                | |  |
            # |  | | |________HBOX_________| |  |                | |  |
            # |  | +-------------------------+  +----------------+ |  |
            # |  |_______________________HBOX______________________|  |
            # +-------------------------------------------------------+

            # Structure:
            # layoutstart
            # - vbox
            #   - align: Left
            #     - hbox1
            #       - selectDisksButton
            #       - selectUnusedButton
            #       - selectMountButton
            #       - align: Right
            #         - hideselectMountButton
            #   - align: Left
            #     - hbox2
            #       - align: Top
            #         - vbox1
            #           - ReplacePoint (force stretched ?)
            #           - align: Bottom
            #             - align: Left
            #               - propertyFrame
            #       - align: Right
            #         - align: Top
            #           - actionFrame
            # basic VBOX containing 2 HBOX's
            my $vbox = $factory->createVBox($layoutstart);
            my $align = $factory->createLeft($vbox);
            my $hbox1 = $factory->createHBox($align);

            ## 3 small buttons
            $self->addWidget('selectDisksButton', $factory->createPushButton($hbox1, $self->loc->N("&Disks")), sub { my ($event,$yevent,$basePart)=@_; $module->baseType($$basePart);}, \ManaTools::Module::Disk->baseTypeDisks);
            $self->addWidget('selectUnusedButton', $factory->createPushButton($hbox1, $self->loc->N("&Unused")), sub { my ($event,$yevent,$basePart)=@_; $module->baseType($$basePart);}, \ManaTools::Module::Disk->baseTypeUnused);
            $self->addWidget('selectMountButton', $factory->createPushButton($hbox1, $self->loc->N("&FS")), sub { my ($event,$yevent,$basePart)=@_; $module->baseType($$basePart);}, \ManaTools::Module::Disk->baseTypeUnused);

            ## checkbox
            $align = $factory->createRight($hbox1);
            $self->addWidget('hideselectMountButton', $factory->createCheckBox($align, $self->loc->N("&Simplify partitions")), sub { my ($event,$yevent)=@_; $module->_rebuildSimplified();});

            ## main horizontal part
            $align = $factory->createLeft($vbox);
            my $hbox2 = $factory->createHBox($align);
            my $vbox1 = $factory->createVBox($hbox2);

            my $actionFrame = $self->addWidget('actionFrame', $factory->createFrame($hbox2, $self->loc->N("&Actions")));
            $factory->createVStretch($self->widget('actionFrame'));
            ## TODO: buttons with actions (dynamically)

            my $hbox3 = $factory->createHBox($vbox1);

            ## properties
            my $propframe = $factory->createFrame($vbox1, $self->loc->N("&Properties"));
            my $vbox2 = $factory->createVBox($propframe);
            $align = $factory->createLeft($vbox2);
            $module->partProperties(ManaTools::Shared::GUI::Properties->new(parentDialog => $self, parentWidget => $align));

            ## in this vbox is the Tabs with all the data
            my $replacepoint = ManaTools::Shared::GUI::ReplacePoint->new(eventHandler => $self, parentWidget => $hbox3);
            # don't add children right away
            $replacepoint->finished();

            # set the replacepoint in module
            $module->replacepoint($replacepoint);

            ## TODO: buttons to be initialized dynamically
            $module->_rebuildParts();
        },
        restoreValues => sub {
            my $self = shift;
            my $module = $self->module();
            my $backend = $module->backend();
            $backend->load();
            $backend->probe();

            ## fill in info
            # disks has a list of IOs (from Parts without in)
            # unused has a list of IOs not being an in for a Part
            # fs has a list of endpoints and in a tree (mount/swap?): ie: Parts without out

            ## start the info structure
            my $info = {disks => {type => 'tab', items => []}, unused => {type => 'list', items => []}, fs => {type => 'tree', items => []}};

            ## disks Part, and others
            my @items = $backend->findnoin();
            # merge all outs from these Parts
            for my $i (@items) {
                for my $j (sort {$a->label() cmp $b->label()} $i->out_list()) {
                    push @{$info->{disks}->{items}}, $j;
                }
            }

            ## unused, i donno yet, parts without out? or ins without part?

            ## fs Part should be linked to all the mounts (hierarchial)

            return $info;
        },
    ));

    $self->mainDialog->call();

    return 1;
}


