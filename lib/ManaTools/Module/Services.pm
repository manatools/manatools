# vim: set et ts=4 sw=4:

package ManaTools::Module::Services;

#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Module::Services - This module aims to manage service
                               with GUI

=head1 SYNOPSIS

    my $serviceMan = ManaTools::Module::Services->new();
    $serviceMan->start();

=head1 DESCRIPTION

    This module presents all the system service status and gives
    the availability to administrator to stop, start and active at boot
    them.

    From the original code drakx services.

=head1 SUPPORT

    You can find documentation for this module with the perldoc command:

    perldoc ManaTools::Module::Services

=head1 SEE ALSO

   ManaTools::Module

=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2014-2017, Angelo Naselli.

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

=cut


use Moose;
use English;
use Time::HiRes qw(usleep);
use File::ShareDir ':ALL';

use MDK::Common::String qw(formatAlaTeX);
use MDK::Common::DataStructure qw(member);

use yui;
use ManaTools::Shared::GUI;
use ManaTools::Shared::Locales;
use ManaTools::Shared::Services;


use File::Basename;

extends qw( ManaTools::Module );

has '+name' => (
    default => 'manaservice',
    required => 0,
    init_arg => undef,
);

sub _titleInitializer {
    my $self = shift;

    return ($self->loc->N("%s - Services and daemons", $self->name()));
};

has '_services' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    init_arg  => undef,
    handles => {
        all_services    => 'elements',
        add_service     => 'push',
        map_service     => 'map',
        service_count   => 'count',
        sorted_services => 'sort',
    },
);

has '_xinetd_services' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    init_arg  => undef,
    handles => {
        all_xinetd_services    => 'elements',
        add_xinetd_service     => 'push',
        map_xinetd_service     => 'map',
        xinetd_service_count   => 'count',
        sorted_xinetd_services => 'sort',
    },
);

has 'on_services' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    init_arg  => undef,
    handles => {
        all_on_services    => 'elements',
        add_on_service     => 'push',
        map_on_service     => 'map',
        on_service_count   => 'count',
        sorted_on_services => 'sort',
    },
);


has 'sh_gui' => (
        is => 'rw',
        init_arg => undef,
        builder => '_SharedUGUIInitialize'
);

sub _SharedUGUIInitialize {
    my $self = shift();

    $self->sh_gui(ManaTools::Shared::GUI->new() );
}

has 'sh_services' => (
        is => 'rw',
        init_arg => undef,
        lazy     => 1,
        builder => '_SharedServicesInitialize'
);

sub _SharedServicesInitialize {
    my $self = shift();

    $self->sh_services(ManaTools::Shared::Services->new(loc => $self->loc) );
}


=head1 METHODS

=cut

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

    $self->loadServices();
}


#=============================================================

=head2 start

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method extends Module::start and is invoked to
    start  adminService

=cut

#=============================================================
sub start {
    my $self = shift;

    $self->_servicePanel();
};


#=============================================================

=head2 loadServices

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

   This methonds load service info into local attributes such
   as xinetd_services, on_services and all the available,
   services

=cut

#=============================================================
sub loadServices {
    my $self = shift;

    my $refresh = 1;
    my ($l, $on_services) = $self->sh_services->services($refresh);
    my @xinetd_services = map { $_->[0] } $self->sh_services->xinetd_services();

    $self->_xinetd_services();
    $self->_xinetd_services(\@xinetd_services);
    $self->_services(\@$l);
    $self->on_services(\@$on_services);

}

## _waitUnitStatus wait unit status is reached for
##                 a while (10 secs max)
sub _waitUnitStatus {
    my ($self, $service, $running) = @_;

    for (my $i=0; $i < 100; $i++) {
        $self->loadServices();
        if ($running) {
            last if $self->sh_services->is_service_running($service);
        }
        else {
            last if !$self->sh_services->is_service_running($service);
        }
        usleep(100);
    }
}

## _serviceInfo sets service description accordingly to
##              selected service status
## param
##   'service'     service name
##   'infoPanel'   service information widget
sub _serviceInfo {
    my ($self, $service, $infoPanel) = @_;

    yui::YUI::ui()->blockEvents();
    ## infoPanel
    $infoPanel->setValue(MDK::Common::String::formatAlaTeX($self->sh_services->description($service)));
    yui::YUI::ui()->unblockEvents();
}


sub _serviceStatusString {
    my ($self, $serviceName) = @_;

    my $started;

    if (MDK::Common::DataStructure::member($serviceName, $self->all_xinetd_services)) {
        $started = $self->loc->N("Start when requested");
    }
    else {
        $started = ($self->sh_services->is_service_running($serviceName)? $self->loc->N("running") : $self->loc->N("stopped"));
    }

    return $started;
}

## _serviceStatus sets status label accordingly to selected item
## param
##   'service'  yui CB table (service table)
##   'item'     selected item (service)
sub _serviceStatus {
    my ($self, $tbl, $item) = @_;

    my $started = $self->_serviceStatusString($item->label());

    # TODO add icon green/red led
    my $cell   = $tbl->toCBYTableItem($item)->cell(1);
    if ($cell) {
        $cell->setLabel($started);
        $tbl->cellChanged($cell);
    }
}


## fill service table with service info
## param
##  'tbl' yui table
sub _fillServiceTable {
    my ($self, $tbl) = @_;

    $tbl->startMultipleChanges();
    $tbl->deleteAllItems();
    my $itemCollection = new yui::YItemCollection;
    foreach (sort $self->all_services) {

        my $serviceName = $_;

        my $item = new yui::YCBTableItem($serviceName);
        my $started = $self->_serviceStatusString($serviceName);

        # TODO add icon green/red led
        my $cell   = new yui::YTableCell($started);
        $item->addCell($cell);

        $item->check(MDK::Common::DataStructure::member($serviceName, $self->all_on_services));
        $item->setLabel($serviceName);
        $itemCollection->push($item);
        $item->DISOWN();
    }
    $tbl->addItems($itemCollection);
    $tbl->doneMultipleChanges();
}

## draw service panel and manage it (main dialog)
sub _servicePanel {
    my $self = shift;

    my $appTitle = yui::YUI::app()->applicationTitle();

    ## TODO remove title and icon when using Shared::Module::GUI::Dialog
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->name());
    ## set icon if not already set by external launcher
    yui::YUI::app()->setApplicationIcon($self->icon());

    my $mageiaPlugin = "mga";
    my $factory      = yui::YUI::widgetFactory;
    my $mgaFactory   = yui::YExternalWidgets::externalWidgetFactory($mageiaPlugin);
    $mgaFactory      = yui::YMGAWidgetFactory::getYMGAWidgetFactory($mgaFactory);

    my $dialog  = $factory->createMainDialog;
    my $vbox    = $factory->createVBox( $dialog );

    #Line for logo and title
    my $hbox_iconbar  = $factory->createHBox($vbox);
    my $head_align_left  = $factory->createLeft($hbox_iconbar);
    $hbox_iconbar     = $factory->createHBox($head_align_left);
    $factory->createImage($hbox_iconbar, $self->icon);

    $factory->createHeading($hbox_iconbar, $self->loc->N("Manage system services by enabling or disabling them"));

    my $frame   = $factory->createFrame ($vbox, "");

    my $frmVbox = $factory->createVBox( $frame );
    my $hbox = $factory->createHBox( $frmVbox );

    my $yTableHeader = new yui::YTableHeader();
    $yTableHeader->addColumn($self->loc->N("Service"), $yui::YAlignBegin);
    $yTableHeader->addColumn($self->loc->N("Status"),  $yui::YAlignCenter);
    $yTableHeader->addColumn($self->loc->N("On boot"), $yui::YAlignBegin);

    ## service list (serviceBox)
    my $serviceTbl = $mgaFactory->createCBTable($hbox, $yTableHeader, $yui::YCBTableCheckBoxOnLastColumn);

    $self->_fillServiceTable($serviceTbl);

    $serviceTbl->setImmediateMode(1);
    $serviceTbl->setWeight(0, 50);

    ## info panel (infoPanel)
    $frame   = $factory->createFrame ($hbox, $self->loc->N("Information"));
    $frame->setWeight(0, 30);
    $frmVbox = $factory->createVBox( $frame );
    my $infoPanel = $factory->createRichText($frmVbox, "--------------"); #, 0, 0);
    $infoPanel->setAutoScrollDown();

    ### Service Start button ($startButton)
    $hbox = $factory->createHBox( $frmVbox );
    my $startButton = $factory->createPushButton($hbox, $self->loc->N("&Start"));

    ### Service Stop button ($stopButton)
    my $stopButton  = $factory->createPushButton($hbox, $self->loc->N("S&top"));

    # dialog buttons
    $factory->createVSpacing($vbox, 1.0);
    ## Window push buttons
    $hbox = $factory->createHBox( $vbox );
    my $align = $factory->createLeft($hbox);
    $hbox     = $factory->createHBox($align);
    my $aboutButton = $factory->createPushButton($hbox, $self->loc->N("&About") );
    $align = $factory->createRight($hbox);
    $hbox     = $factory->createHBox($align);

    ### Service Refresh button ($refreshButton)
    my $refreshButton  = $factory->createPushButton($hbox, $self->loc->N("&Refresh"));
    my $closeButton = $factory->createPushButton($hbox, $self->loc->N("&Quit") );

    #first item status
    my $item = $serviceTbl->selectedItem();
    if ($item) {
        $self->_serviceInfo($item->label(), $infoPanel);
        if (MDK::Common::DataStructure::member($item->label(), $self->all_xinetd_services)) {
            $stopButton->setDisabled();
            $startButton->setDisabled();
        }
        else {
            $stopButton->setEnabled(1);
            $startButton->setEnabled(1);
        }
    }

    while(1) {
        my $event       = $dialog->waitForEvent();
        my $eventType   = $event->eventType();

        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            # widget selected
            my $widget = $event->widget();
            my $wEvent = yui::toYWidgetEvent($event);

            if ($widget == $closeButton) {
                last;
            }
            elsif ($widget == $aboutButton) {
                my $translators = ManaTools::Shared::i18NTranslators($self->loc->N("_: Translator(s) name(s) & email(s)\n"));
                $self->sh_gui->AboutDialog({ name => $self->name,
                                             version => $self->Version(),
                         credits => $self->loc->N("Copyright (C) %s Mageia community", '2013-2016'),
                         license => $self->loc->N("GPLv2"),
                         description => $self->loc->N("manaservice is the Mageia service and daemon management tool\n
                                                       (from the original idea of Mandriva drakxservice)."),
                         authors => $self->loc->N("<h3>Developers</h3>
                                                    <ul><li>%s</li>
                                                           <li>%s</li>
                                                       </ul>
                                                       <h3>Translators</h3>
                                                       <ul>%s</ul>",
                                                      "Angelo Naselli &lt;anaselli\@linux.it&gt;",
                                                      "Matteo Pasotti &lt;matteo.pasotti\@gmail.com&gt;",
                                                      $translators
                                                     ),
                            }
                );
            }
            elsif ($widget == $serviceTbl) {

                # service selection changed
                $item = $serviceTbl->selectedItem();
                if ($item) {
                    $self->_serviceInfo($item->label(), $infoPanel);
                    if (MDK::Common::DataStructure::member($item->label(), $self->all_xinetd_services)) {
                        $stopButton->setDisabled();
                        $startButton->setDisabled();
                    }
                    else {
                        $stopButton->setEnabled(1);
                        $startButton->setEnabled(1);
                    }
                }
# TODO fix libyui-mga-XXX item will always be changed after first one
                if ($wEvent->reason() == $yui::YEvent::ValueChanged) {
                    $item = $serviceTbl->changedItem();
                    if ($item) {
                        yui::YUI::app()->busyCursor();
                        eval {
                            $self->sh_services->set_service($item->label(), $item->checked());
                        };
                        my $errors = $@;
                        $self->loadServices();
                        yui::YUI::app()->normalCursor();

                        if ($errors) {
                            $self->sh_gui->warningMsgBox({
                                title =>  $self->loc->N($item->checked() ? "Enabling %s" : "Disabling %s", $item->label()),
                                text  => "$errors",
                                richtext => 1,
                            });
                            $dialog->startMultipleChanges();
                            $self->_fillServiceTable($serviceTbl);
                            $dialog->recalcLayout();
                            $dialog->doneMultipleChanges();
                        }
                    }
                }
            }
            elsif ($widget == $startButton) {
                $item = $serviceTbl->selectedItem();
                if ($item) {
                    my $serviceName = $item->label();
                    yui::YUI::app()->busyCursor();
                    eval {
                        $self->sh_services->restart_or_start($serviceName);
                        $self->_waitUnitStatus($serviceName, 1);
                    };
                    my $errors = $@;
                    yui::YUI::app()->normalCursor();
                    $self->_serviceStatus($serviceTbl, $item);

                    $self->sh_gui->warningMsgBox({
                        title => $self->loc->N("Starting %s", $serviceName),
                        text  => "$errors",
                        richtext => 1,
                    }) if $errors;
                }
            }
            elsif ($widget == $stopButton) {
                $item = $serviceTbl->selectedItem();
                if ($item) {
                    my $serviceName = $item->label();
                    yui::YUI::app()->busyCursor();
                    eval {
                        $self->sh_services->stopService($serviceName);
                        $self->_waitUnitStatus($serviceName, 0);
                    };
                    my $errors = $@;
                    yui::YUI::app()->normalCursor();
                    $self->_serviceStatus($serviceTbl, $item);

                    $self->sh_gui->warningMsgBox({
                        title => $self->loc->N("Stopping %s", $serviceName),
                        text  => "$errors",
                        richtext => 1,
                    }) if $errors;
                }
            }
            elsif ($widget == $refreshButton) {
                yui::YUI::app()->busyCursor();
                $self->loadServices();
                $dialog->startMultipleChanges();
                $self->_fillServiceTable($serviceTbl);
                $dialog->recalcLayout();
                $dialog->doneMultipleChanges();
                yui::YUI::app()->normalCursor();
            }
        }
    }
    $dialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle) if $appTitle;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
