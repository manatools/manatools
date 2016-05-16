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
use ManaTools::Shared::GUI::ActionList;
use ManaTools::Shared::GUI::Dialog;
use ManaTools::Shared::GUI::ReplacePoint;
use ManaTools::Shared::GUI::Properties;
use ManaTools::Shared::GUI::ExtList;
use ManaTools::Shared::GUI::ExtTab;
use ManaTools::Shared::GUI::ExtButtonBox;
use File::ShareDir ':ALL';
use ManaTools::Shared::Locales;
use ManaTools::Shared::disk_backend;

use yui;

extends qw( ManaTools::Module );

has '+name' => (
    default => 'manadisk',
    required => 0,
    init_arg => undef,
);

override('_titleInitializer', sub {
    my $self = shift;

    return $self->loc->N("%s - Storage partitioning & Mounts", $self->name());
});

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
        my $self = shift;
        return ManaTools::Shared::disk_backend->new(logger => $self->logger());
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

has content => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Shared::GUI::ReplacePoint]',
    default => undef,
    init_arg => undef,
);

has propertiesBox => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Shared::GUI::ReplacePoint]',
    default => undef,
    init_arg => undef,
);

has actionsBox => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Shared::GUI::ReplacePoint]',
    default => undef,
    init_arg => undef,
);

has ioProperties => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Shared::GUI::Properties]',
    default => undef,
    init_arg => undef,
    handles => {
        set_properties => 'properties',
    },
);

has selectedItem => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Shared::disk_backend::IO]',
    default => undef,
    init_arg => undef,
);

around 'selectedItem' => \&_selectedItem;

sub _SharedGUIInitialize {
    my $self = shift;

    $self->sh_gui(ManaTools::Shared::GUI->new() );
}


=head1 VERSION

Version 1.0.1

=cut

our $VERSION = '1.0.1';

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

    $self->logger()->trace(1);
    $self->_adminDiskPanel();
}

sub _selectItem {
    my $orig = shift;
    my $self = shift;
    my $old = $self->$orig();

    return $old unless @_;

    my $new = shift;
    my @parts = $new->findin();
    while (scalar(@parts) > 0) {
    }
    # if $new has children, get the first one instead
    # if $new is an ancestor of $old, we're not gonna change it
    return $self->$orig($new);
};

sub _showSelectedItem {
    my $self = shift;
    my $module = $self->module();
    my $io = $self->selectedItem();
    my $ioProperties = $module->ioProperties();
    $ioProperties->properties($io);

    my $propbox = $module->propertiesBox();
    # properties
    # parent properties

    my $actionbox = $module->actionsBox();
    # actions
    # parent actions
}

sub _rebuildTab {
    my $self = shift;
    my $eventHandler = shift;
    my $container = shift;
    my $parent = shift;
    my @items = @_;
    my $tab = ManaTools::Shared::GUI::ExtTab->new(eventHandler => $eventHandler, parentWidget => $container);
    for my $io (@items) {
        $tab->addSelectorItem($io->label(), $io, sub {
            my $self = shift;# tab
            my $parent = shift;
            my $io = shift;
            my $dialog = $self->parentDialog();
            my $module = $dialog->module();
            my $factory = $dialog->factory();

            # create content
            my $vbox = $factory->createVBox($parent);
            $module->_rebuildItem($io, $self->replacepoint(), $vbox);
            #$self->addWidget($io->label() .': button 1', $factory->createPushButton($vbox, $io->label() .': button 1'), sub { my $backendItem = shift; print STDERR "backendItem: ". $backendItem->label() ."::button1\n"; });
            #$self->addWidget($io->label() .': button 2', $factory->createPushButton($vbox, $io->label() .': button 2'), sub { my $backendItem = shift; print STDERR "backendItem: ". $backendItem->label() ."::button2\n"; });
            #$self->addWidget($io->label() .': button 3', $factory->createPushButton($vbox, $io->label() .': button 3'), sub { my $backendItem = shift; print STDERR "backendItem: ". $backendItem->label() ."::button3\n"; });
            $factory->createHStretch($vbox);
            #$factory->createVStretch($vbox);

            # update the properties
            my $ioProperties = $module->ioProperties();
            $ioProperties->properties($io);
            my $db = $io->db();
            my $propbox = $module->propertiesBox();
            my $actionbox = $module->actionsBox();

            # clear children of propbox and actionbox
            $propbox->clear();
            $actionbox->clear();

            # loop all connected parts
            my @parts = $db->findin($io);
            for my $part (@parts) {

                # add properties for each part in a frame with label
                my $frame = $factory->createFrame($propbox->container(), $part->label() ." properties");
                my $align = $factory->createLeft($frame);
                ManaTools::Shared::GUI::Properties->new({eventHandler => $propbox, parentWidget => $align, properties => $part});

                # add actions for each part in a frame with label
                $frame = $factory->createFrame($actionbox->container(), $part->label() ." actions");
                ManaTools::Shared::GUI::ActionList->new({eventHandler => $actionbox, parentWidget => $frame, actions => $part});
            }

            # finalize propbox and actionbox
            $propbox->finished();
            $actionbox->finished();

            # stretch vertically if no children are there
            $factory->createVStretch($vbox) if (scalar(@parts) == 0);
        });
    }
    $tab->finishedSelectorItems();
    return $tab;
}

sub _rebuildList {
    my $self = shift;
    my $eventHandler = shift;
    my $container = shift;
    my $parent = shift;
    my @items = @_;
    my $list = ManaTools::Shared::GUI::ExtList->new(eventHandler => $eventHandler, parentWidget => $container);
    for my $i (@items) {
        $list->addSelectorItem($i->label(), $i, sub {
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
        });
    }
    $list->finishedSelectorItems();
    return $list;
}

sub _rebuildButtonBox {
    my $self = shift;
    my $eventHandler = shift;
    my $container = shift;
    my $parent = shift;
    my @items = sort {$a->prop('start') <=> $b->prop('start')} @_;
    my $minsize = 2;        # min DISPLAY size
    my $maxparts = 128;     # max GPT partitions
    my $boundary = 34;      # GPT sector boundaries
    my $alignment = 2048;   # current Disk partition alignment convention
    $maxparts = 8; # TODO: fix it so that the actions don't disappear when this is removed!!!!!!!!
    my $offset = $boundary;
    my $totalWeight = $maxparts * $minsize;
    # TODO: dependant upon disk types, etc...
    $offset = $alignment;
    my $totalWidth = $parent->prop('size') - $boundary - $offset; # offset at beginning, boundary at end
    my $start = $offset;
    my $buttonWidths = [];
    my $count = 0;
    my $currentWeight = 0;
    $self->D("$self: make a new ExtButtonBox inside $container with eventHandler $eventHandler");
    my $buttonbox = ManaTools::Shared::GUI::ExtButtonBox->new(eventHandler => $eventHandler, parentWidget => $container, buttonWidths => $buttonWidths);
    for my $i (@items) {
        # handle overlaps
        $start = $i->prop('start') if ($start > $i->prop('start'));
        # fill in gaps
        if ($start < $i->prop('start')) {
            $self->D("$self: add a gap SelectorItem to $buttonbox");
            my $item = $buttonbox->addSelectorItem('', { prop => sub { my $prop = shift; return $start if ($prop eq 'start'); return $i->prop('start') - $start if ($prop eq 'sectors'); return 0 if ($prop eq 'size'); return undef; } }, sub {
                my $self = shift;
                my $parent = shift;
                my $backendItem = shift;
                my $dialog = $self->parentDialog();
                my $factory = $dialog->factory();
                my $vbox = $factory->createVBox($parent);
                $dialog->D("$self: build the gap SelectorItem");
                $factory->createHStretch($vbox);
                $factory->createVStretch($vbox);
            });
            my $width = int(($i->prop('start') - $start) * $totalWeight / $totalWidth);
            if ($width < $minsize) {
                $width = $minsize;
            }
            $buttonWidths->[$count] = $width;
            $currentWeight = $currentWeight + $buttonWidths->[$count];
            $count = $count + 1;
            $start = $i->prop('start');
        }
        # get part type (path)
        my $label = '';
        my @p = $i->findin();
        if (scalar(@p) > 0) {
            $label = join ',', map { ($_->type() eq 'Mount') && $_->prop('path') || $_->type() } @p;
        }
        $self->D("$self: add a button SelectorItem to $buttonbox with label $label and backend $i");
        my $item = $buttonbox->addSelectorItem($label, $i, sub {
            my $self = shift;
            my $parent = shift;
            my $backendItem = shift;
            my $dialog = $self->parentDialog();
            $dialog->D("$self: build the button SelectorItem with backend $backendItem");
            my $factory = $dialog->factory();
            my $vbox = $factory->createVBox($parent);
            $self->addWidget($backendItem->label() .': button 1', $factory->createPushButton($vbox, $backendItem->label() .': button 1'), sub { my $backendItem = shift; print STDERR "backendItem: ". $backendItem->label() ."::button1\n"; });
            $self->addWidget($backendItem->label() .': button 2', $factory->createPushButton($vbox, $backendItem->label() .': button 2'), sub { my $backendItem = shift; print STDERR "backendItem: ". $backendItem->label() ."::button2\n"; });
            $self->addWidget($backendItem->label() .': button 3', $factory->createPushButton($vbox, $backendItem->label() .': button 3'), sub { my $backendItem = shift; print STDERR "backendItem: ". $backendItem->label() ."::button3\n"; });
            $factory->createHStretch($vbox);
            $factory->createVStretch($vbox);
        });
        my $backendItem = $item->backend();
        my $width = $backendItem->prop('sectors') * $totalWeight / $totalWidth;
        if ($width < $minsize) {
            $width = $minsize;
        }
        $buttonWidths->[$count] = int($width);
        $currentWeight = $currentWeight + $buttonWidths->[$count];
        $count = $count + 1;
        $start = $start + $backendItem->prop('sectors');
    }
    # fill in gaps
    if ($start < ($totalWidth + $offset)) {
        my $item = $buttonbox->addSelectorItem('', { prop => sub { my $prop = shift; return $start if ($prop eq 'start'); return $totalWidth + $offset - $start if ($prop eq 'sectors'); return 0 if ($prop eq 'size'); return undef; } }, sub {
            my $self = shift;
            my $parent = shift;
            my $backendItem = shift;
            my $dialog = $self->parentDialog();
            $dialog->D("$self: build the gap SelectorItem (at the end)");
            my $factory = $dialog->factory();
            my $vbox = $factory->createVBox($parent);
            $factory->createHStretch($vbox);
            $factory->createVStretch($vbox);
        });
        my $width = $totalWeight - $currentWeight;
        if ($width < $minsize) {
            $width = $minsize;
        }
        $buttonWidths->[$count] = $width;
    }
    $buttonbox->finishedSelectorItems();
    $self->D("$self: finished $buttonbox SelectorItems");
    return $buttonbox;
}

sub _rebuildTree {
    my $self = shift;
    my $eventHandler = shift;
    my $container = shift;
    my $parent = shift;
    my @items = @_;
    my $tree = undef;
    return $tree;
}

sub _rebuildItems {
    my $self = shift;
    my $info = shift;
    my $eventHandler = shift;
    my $container = shift;
    for my $i (@{$info}) {
        if ($i->{type} eq 'tab') {
            return $self->_rebuildTab($eventHandler, $container, $i->{io}, @{$i->{items}});
        }
        if ($i->{type} eq 'buttonbox') {
            return $self->_rebuildButtonBox($eventHandler, $container, $i->{io}, @{$i->{items}});
        }
        if ($i->{type} eq 'list') {
            return $self->_rebuildList($eventHandler, $container, $i->{io}, @{$i->{items}});
        }
        if ($i->{type} eq 'tree') {
            return $self->_rebuildTree($eventHandler, $container, $i->{io}, @{$i->{items}});
        }
    }
    return undef;
}

sub _expandItem {
    my $self = shift;
    my $io = shift;
    my $infos = [];
    my $type = 'list';
    my @items;

    # get parts
    if (defined $io) {
        @items = $io->findin();
    }
    else {
        my $backend = $self->backend();
        @items = $backend->findnoin();
    }

    # merge all outs from these Parts
    for my $p (@items) {
        push @{$infos}, {io => $io, part => $p, type => ( $p->type() eq 'Disks' ? 'tab' : $p->type() eq 'PartitionTable' ? 'buttonbox' : $type ), items => [sort {$a->label() cmp $b->label()} $p->out_list()]};
    }
    return $infos;
}

sub _rebuildItem {
    my $self = shift;
    my $item = shift;
    my $eventHandler = shift;
    my $container = shift;
    return $self->_rebuildItems($self->_expandItem($item), $eventHandler, $container);
}

sub _rebuildParts {
    my $self = shift;
    my $dialog = $self->mainDialog();
    my $baseType = $self->baseType();
    my $simplified = $self->simplified();
    my $info = $dialog->info();
    my $rpl = $self->content();

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
        module => $self,
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

            ## actions
            my $vbox2 = $factory->createVBox($hbox2);
            my $replacepoint = ManaTools::Shared::GUI::ReplacePoint->new(eventHandler => $self, parentWidget => $vbox2);
            # don't add children right away
            $factory->createVStretch($replacepoint->container());
            $replacepoint->finished();
            $module->actionsBox($replacepoint);
            $factory->createVStretch($vbox2);

            my $hbox3 = $factory->createHBox($vbox1);

            ## properties
            my $propframe = $factory->createFrame($vbox1, $self->loc->N("&Device properties"));
            my $vbox3 = $factory->createVBox($propframe);
            $align = $factory->createLeft($vbox3);
            # properties from IO first, and then the applicable Parts
            $module->ioProperties(ManaTools::Shared::GUI::Properties->new(eventHandler => $self, parentWidget => $align));
            $replacepoint = ManaTools::Shared::GUI::ReplacePoint->new(eventHandler => $self, parentWidget => $vbox1);
            $factory->createVStretch($replacepoint->container());
            # don't add children right away
            $replacepoint->finished();
            $module->propertiesBox($replacepoint);

            ## in this replacepoint is the Tabs with all the data
            $replacepoint = ManaTools::Shared::GUI::ReplacePoint->new(eventHandler => $self, parentWidget => $hbox3);
            $factory->createVStretch($replacepoint->container());
            # don't add children right away
            $replacepoint->finished();

            # set the replacepoint in module
            $module->content($replacepoint);

            ## build the parts
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
            my $info = {
                disks => $module->_expandItem(),
                unused => {type => 'list', items => sort {$a->label() cmp $b->label()} grep {scalar($_->findin()) == 0} values %{$backend->ios()}},
                fs => {type => 'tree', items => []}
            };

            ## fs Part should be linked to all the mounts (hierarchial)

            return $info;
        },
    ));

    $self->D("$self: call mainDialog");
    $self->mainDialog->call();
    $self->D("$self: done calling mainDialog");

    return 1;
}



