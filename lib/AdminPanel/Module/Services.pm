# vim: set et ts=4 sw=4:

package AdminPanel::Module::Services;

#============================================================= -*-perl-*-

=head1 NAME

AdminPanel::Module::Services - This module aims to manage service 
                               with GUI

=head1 SYNOPSIS

    my $serviceMan = AdminPanel::Module::Services->new();
    $serviceMan->start();

=head1 DESCRIPTION

    This module presents all the system service status and gives
    the availability to administrator to stop, start and active at boot 
    them.
    
    From the original code drakx services.

=head1 SUPPORT

    You can find documentation for this module with the perldoc command:

    perldoc AdminPanel::Module::Services::Module

=head1 SEE ALSO
   
   AdminPanel::Module

=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2014, Angelo Naselli.

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


use strict;

# TODO same translation atm
use lib qw(/usr/lib/libDrakX);
use common qw(N
              N_
              cat_ 
              formatAlaTeX 
              translate 
              find);
use run_program;

use Moose;

use yui;
use AdminPanel::Shared;
use AdminPanel::Shared::Services qw(
                                    description
                                    services
                                    xinetd_services
                                    is_service_running
                                    restart_or_start
                                    stop
                                    set_service
                                    );

use File::Basename;

extends qw( AdminPanel::Module );

has '+icon' => (
    default => "/usr/share/mcc/themes/default/service-mdk.png",
);

has '+name' => (
    default => N("AdminService"), 
);

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


has 'running_services' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    init_arg  => undef,
    handles => {
        all_running_services    => 'elements',
        add_running_service     => 'push',
        map_running_service     => 'map',
        running_service_count   => 'count',
        sorted_running_services => 'sort',
    },
);

=head1 VERSION

Version 1.0.0

=cut

our $VERSION = '1.0.0';


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

    my ($l, $on_services) = AdminPanel::Shared::Services::services();
    my @xinetd_services = map { $_->[0] } AdminPanel::Shared::Services::xinetd_services();

    $self->_xinetd_services();
    $self->_xinetd_services(\@xinetd_services);
    $self->_services(\@$l);
    $self->on_services(\@$on_services);

    $self->_refreshRunningServices();
}

sub _refreshRunningServices {
    my $self = shift;

    my @running;
    foreach ($self->all_services) {

        my $serviceName = $_;
        push @running, $serviceName if is_service_running($serviceName);
    }
    $self->running_services(\@running);
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
    $infoPanel->setValue(formatAlaTeX(description($service)));
    yui::YUI::ui()->unblockEvents();
}


sub _serviceStatusString {
    my ($self, $serviceName) = @_;
    
    my $started;

    if (member($serviceName, $self->all_xinetd_services)) {
        $started = N("Start when requested");
    }
    else {
        $started = (is_service_running($serviceName)? N("running") : N("stopped"));
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

    $tbl->deleteAllItems();
    my $itemCollection = new yui::YItemCollection;
    foreach ($self->all_services) {
        
        my $serviceName = $_;
        
        my $item = new yui::YCBTableItem($serviceName);
        my $started = $self->_serviceStatusString($serviceName);
        
        # TODO add icon green/red led  
        my $cell   = new yui::YTableCell($started);
        $item->addCell($cell);
        
        $item->check(member($serviceName, $self->all_on_services));
        $item->setLabel($serviceName);
        $itemCollection->push($item);
        $item->DISOWN();
    }
    $tbl->addItems($itemCollection);
}

## draw service panel and manage it (main dialog)
sub _servicePanel {
    my $self = shift;

    my $appTitle = yui::YUI::app()->applicationTitle();

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->name);
    ## set icon if not already set by external launcher
    yui::YUI::app()->setApplicationIcon($self->icon);

    my $mageiaPlugin = "mga";
    my $factory      = yui::YUI::widgetFactory;
    my $mgaFactory   = yui::YExternalWidgets::externalWidgetFactory($mageiaPlugin);
    $mgaFactory      = yui::YMGAWidgetFactory::getYMGAWidgetFactory($mgaFactory);
    
    my $dialog  = $factory->createMainDialog;
    my $vbox    = $factory->createVBox( $dialog );
    my $frame   = $factory->createFrame ($vbox, N("Services"));

    my $frmVbox = $factory->createVBox( $frame );
    my $hbox = $factory->createHBox( $frmVbox );

    my $yTableHeader = new yui::YTableHeader();
    $yTableHeader->addColumn(N("Service"), $yui::YAlignBegin);
    $yTableHeader->addColumn(N("Status"),  $yui::YAlignCenter);
    $yTableHeader->addColumn(N("On boot"), $yui::YAlignBegin);

    ## service list (serviceBox)
    my $serviceTbl = $mgaFactory->createCBTable($hbox, $yTableHeader, $yui::YCBTableCheckBoxOnLastColumn);
   
    $self->_fillServiceTable($serviceTbl);
    
    $serviceTbl->setImmediateMode(1);
    $serviceTbl->setWeight(0, 50);

    ## info panel (infoPanel)
    $frame   = $factory->createFrame ($hbox, N("Information"));
    $frame->setWeight(0, 30);
    $frmVbox = $factory->createVBox( $frame );
    my $infoPanel = $factory->createRichText($frmVbox, "--------------"); #, 0, 0);
    $infoPanel->setAutoScrollDown();

    ### Service Start button ($startButton)
    $hbox = $factory->createHBox( $frmVbox );
    my $startButton = $factory->createPushButton($hbox, N("Start"));
    
    ### Service Stop button ($stopButton)
    my $stopButton  = $factory->createPushButton($hbox, N("Stop"));

    # dialog buttons
    $factory->createVSpacing($vbox, 1.0);
    ## Window push buttons
    $hbox = $factory->createHBox( $vbox );
    my $align = $factory->createLeft($hbox);
    $hbox     = $factory->createHBox($align);
    my $aboutButton = $factory->createPushButton($hbox, N("About") );
    $align = $factory->createRight($hbox);
    $hbox     = $factory->createHBox($align);
    
    ### Service Refresh button ($refreshButton)
    my $refreshButton  = $factory->createPushButton($hbox, N("Refresh"));
    my $closeButton = $factory->createPushButton($hbox, N("Close") );

    #first item status
    my $item = $serviceTbl->selectedItem();
    if ($item) {
        $self->_serviceInfo($item->label(), $infoPanel);
        if (member($item->label(), $self->all_xinetd_services)) {
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
                my $license = translate($AdminPanel::Shared::License);
                # TODO fix version value
                AboutDialog({ name => N("AdminService"),
                    version => $self->VERSION, 
                    copyright => N("Copyright (C) %s Mageia community", '2013-2014'),
                    license => $license, 
                    comments => N("Service Manager is the Mageia service and daemon management tool \n(from the original idea of Mandriva draxservice)."),
                    website => 'http://www.mageia.org',
                    website_label => N("Mageia"),
                    authors => "Angelo Naselli <anaselli\@linux.it>\nMatteo Pasotti <matteo.pasotti\@gmail.com>",
                    translator_credits =>
                        #-PO: put here name(s) and email(s) of translator(s) (eg: "John Smith <jsmith@nowhere.com>")
                        N("_: Translator(s) name(s) & email(s)\n")}
                );
            }
            elsif ($widget == $serviceTbl) {
                
                # service selection changed
                $item = $serviceTbl->selectedItem();
                if ($item) {
                    $self->_serviceInfo($item->label(), $infoPanel);
                    if (member($item->label(), $self->all_xinetd_services)) {
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

                        set_service($item->label(), $item->checked());
                        # we can push/pop service, but this (slower) should return real situation
                        $self->_refreshRunningServices();
                    }
                }
            }
            elsif ($widget == $startButton) {
                $item = $serviceTbl->selectedItem();
                if ($item) {
                    yui::YUI::app()->busyCursor();
                    restart_or_start($item->label());
                    # we can push/pop service, but this (slower) should return real situation
                    $self->_refreshRunningServices();
                    $self->_serviceStatus($serviceTbl, $item);
                    yui::YUI::app()->normalCursor();
                }
            }
            elsif ($widget == $stopButton) {
                $item = $serviceTbl->selectedItem();
                if ($item) {
                    yui::YUI::app()->busyCursor();
                    stop($item->label());
                    # we can push/pop service, but this (slower) should return real situation
                    $self->_refreshRunningServices();
                    $self->_serviceStatus($serviceTbl, $item);
                    yui::YUI::app()->normalCursor();
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
