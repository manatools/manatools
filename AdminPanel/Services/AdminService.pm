# vim: set et ts=4 sw=4:
#*****************************************************************************
# 
#  Copyright (c) 2013 Angelo Naselli <anaselli@linux.it>
#  from drakx services
# 
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License version 2, as
#  published by the Free Software Foundation.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
# 
#*****************************************************************************

package AdminPanel::Services::AdminService;

#-######################################################################################
#- misc imports
#-######################################################################################

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
use AdminPanel::Services::Utility qw(
                                    services
                                    xinetd_services
                                    is_service_running
                                    restart_or_start
                                    stop
                                    set_service
                    );

use File::Basename;

extends qw( Module );

has '+icon' => (
    default => "/usr/share/mcc/themes/default/service-mdk.png",
);

has '+name' => (
    default => N("AdminService"), 
);

has 'services' => (
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

has 'xinetd_services' => (
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


sub description {
    my %services = (
acpid => N_("Listen and dispatch ACPI events from the kernel"),     
alsa => N_("Launch the ALSA (Advanced Linux Sound Architecture) sound system"),
anacron => N_("Anacron is a periodic command scheduler."),
apmd => N_("apmd is used for monitoring battery status and logging it via syslog.
It can also be used for shutting down the machine when the battery is low."),
atd => N_("Runs commands scheduled by the at command at the time specified when
at was run, and runs batch commands when the load average is low enough."),
'avahi-deamon' => N_("Avahi is a ZeroConf daemon which implements an mDNS stack"),
chronyd => N_("An NTP client/server"),
cpufreq => N_("Set CPU frequency settings"),
crond => N_("cron is a standard UNIX program that runs user-specified programs
at periodic scheduled times. vixie cron adds a number of features to the basic
UNIX cron, including better security and more powerful configuration options."),
cups => N_("Common UNIX Printing System (CUPS) is an advanced printer spooling system"),
dm => N_("Launches the graphical display manager"),
fam => N_("FAM is a file monitoring daemon. It is used to get reports when files change.
It is used by GNOME and KDE"),
g15daemon => N_("G15Daemon allows users access to all extra keys by decoding them and 
pushing them back into the kernel via the linux UINPUT driver. This driver must be loaded 
before g15daemon can be used for keyboard access. The G15 LCD is also supported. By default, 
with no other clients active, g15daemon will display a clock. Client applications and 
scripts can access the LCD via a simple API."),
gpm => N_("GPM adds mouse support to text-based Linux applications such the
Midnight Commander. It also allows mouse-based console cut-and-paste operations,
and includes support for pop-up menus on the console."),
haldaemon => N_("HAL is a daemon that collects and maintains information about hardware"),
harddrake => N_("HardDrake runs a hardware probe, and optionally configures
new/changed hardware."),
httpd => N_("Apache is a World Wide Web server. It is used to serve HTML files and CGI."),
inet => N_("The internet superserver daemon (commonly called inetd) starts a
variety of other internet services as needed. It is responsible for starting
many services, including telnet, ftp, rsh, and rlogin. Disabling inetd disables
all of the services it is responsible for."),
ip6tables => N_("Automates a packet filtering firewall with ip6tables"),
iptables => N_("Automates a packet filtering firewall with iptables"),
irqbalance => N_("Evenly distributes IRQ load across multiple CPUs for enhanced performance"),
keytable => N_("This package loads the selected keyboard map as set in
/etc/sysconfig/keyboard.  This can be selected using the kbdconfig utility.
You should leave this enabled for most machines."),
kheader => N_("Automatic regeneration of kernel header in /boot for
/usr/include/linux/{autoconf,version}.h"),
kudzu => N_("Automatic detection and configuration of hardware at boot."),
'laptop-mode' => N_("Tweaks system behavior to extend battery life"),
linuxconf => N_("Linuxconf will sometimes arrange to perform various tasks
at boot-time to maintain the system configuration."),
lpd => N_("lpd is the print daemon required for lpr to work properly. It is
basically a server that arbitrates print jobs to printer(s)."),
lvs => N_("Linux Virtual Server, used to build a high-performance and highly
available server."),
mandi => N_("Monitors the network (Interactive Firewall and wireless"),
mdadm => N_("Software RAID monitoring and management"),
messagebus => N_("DBUS is a daemon which broadcasts notifications of system events and other messages"),
msec => N_("Enables MSEC security policy on system startup"),
named => N_("named (BIND) is a Domain Name Server (DNS) that is used to resolve host names to IP addresses."),
netconsole => N_("Initializes network console logging"),
netfs => N_("Mounts and unmounts all Network File System (NFS), SMB (Lan
Manager/Windows), and NCP (NetWare) mount points."),
network => N_("Activates/Deactivates all network interfaces configured to start
at boot time."),
'network-auth' => N_("Requires network to be up if enabled"),
'network-up' => N_("Wait for the hotplugged network to be up"),
nfs => N_("NFS is a popular protocol for file sharing across TCP/IP networks.
This service provides NFS server functionality, which is configured via the
/etc/exports file."),
nfslock => N_("NFS is a popular protocol for file sharing across TCP/IP
networks. This service provides NFS file locking functionality."),
ntpd => N_("Synchronizes system time using the Network Time Protocol (NTP)"),
numlock => N_("Automatically switch on numlock key locker under console
and Xorg at boot."),
oki4daemon => N_("Support the OKI 4w and compatible winprinters."),
partmon => N_("Checks if a partition is close to full up"),
pcmcia => N_("PCMCIA support is usually to support things like ethernet and
modems in laptops.  It will not get started unless configured so it is safe to have
it installed on machines that do not need it."),
portmap => N_("The portmapper manages RPC connections, which are used by
protocols such as NFS and NIS. The portmap server must be running on machines
which act as servers for protocols which make use of the RPC mechanism."),
portreserve => N_("Reserves some TCP ports"),
postfix => N_("Postfix is a Mail Transport Agent, which is the program that moves mail from one machine to another."),
random => N_("Saves and restores system entropy pool for higher quality random
number generation."),
rawdevices => N_("Assign raw devices to block devices (such as hard disk drive
partitions), for the use of applications such as Oracle or DVD players"),
resolvconf => N_("Nameserver information manager"),
routed => N_("The routed daemon allows for automatic IP router table updated via
the RIP protocol. While RIP is widely used on small networks, more complex
routing protocols are needed for complex networks."),
rstatd => N_("The rstat protocol allows users on a network to retrieve
performance metrics for any machine on that network."),
rsyslog => N_("Syslog is the facility by which many daemons use to log messages to various system log files.  It is a good idea to always run rsyslog."),
rusersd => N_("The rusers protocol allows users on a network to identify who is
logged in on other responding machines."),
rwhod => N_("The rwho protocol lets remote users get a list of all of the users
logged into a machine running the rwho daemon (similar to finger)."),
saned => N_("SANE (Scanner Access Now Easy) enables to access scanners, video cameras, ..."),
shorewall => N_("Packet filtering firewall"),
smb => N_("The SMB/CIFS protocol enables to share access to files & printers and also integrates with a Windows Server domain"),
sound => N_("Launch the sound system on your machine"),
'speech-dispatcherd' => N_("layer for speech analysis"),
sshd => N_("Secure Shell is a network protocol that allows data to be exchanged over a secure channel between two computers"),
syslog => N_("Syslog is the facility by which many daemons use to log messages
to various system log files.  It is a good idea to always run syslog."),
'udev-post' => N_("Moves the generated persistent udev rules to /etc/udev/rules.d"),
usb => N_("Load the drivers for your usb devices."),
vnStat => N_("A lightweight network traffic monitor"),
xfs => N_("Starts the X Font Server."),
xinetd => N_("Starts other deamons on demand."),
    );
    my ($name) = @_;
    my $s = $services{$name};
    if ($s) {
        $s = translate($s);
    } else {
        my $file = "$::prefix/usr/lib/systemd/system/$name.service";
        if (-e $file) {
                $s = cat_($file);
                $s = $s =~ /^Description=(.*)/mg ? $1 : '';
        } else {
                $file = find { -e $_ } map { "$::prefix$_/$name" } '/etc/rc.d/init.d', '/etc/init.d', '/etc/xinetd.d';
                $s = cat_($file);
                $s =~ s/\\\s*\n#\s*//mg;
                $s =
                        $s =~ /^#\s+(?:Short-)?[dD]escription:\s+(.*?)^(?:[^#]|# {0,2}\S)/sm ? $1 :
                        $s =~ /^#\s*(.*?)^[^#]/sm ? $1 : '';

                $s =~ s/#\s*//mg;
        }
    }
    $s =~ s/\n/ /gm; $s =~ s/\s+$//;
    $s;
}

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

    $self->servicePanel();
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

    my ($l, $on_services) = AdminPanel::Services::Utility::services();
    my @xinetd_services = map { $_->[0] } AdminPanel::Services::Utility::xinetd_services();

    $self->xinetd_services();
    $self->xinetd_services(\@xinetd_services);
    $self->services(\@$l);
    $self->on_services(\@$on_services);

    $self->refreshRunningServices();
}

sub refreshRunningServices {
    my $self = shift;

    my @running;
    foreach ($self->all_services) {

        my $serviceName = $_;
        push @running, $serviceName if is_service_running($serviceName);
    }
    $self->running_services(\@running);
}

## serviceInfo sets widgets accordingly to selected service status 
## param
##   'service'     service name 
##   'infoPanel'   service information widget 
sub serviceInfo {
    my ($self, $service, $infoPanel) = @_;

    yui::YUI::ui()->blockEvents();
    ## infoPanel
    $infoPanel->setValue(formatAlaTeX(description($service)));
    yui::YUI::ui()->unblockEvents();
}

sub serviceStatus {
    my ($self, $tbl, $item) = @_;

    my $started;

    if (member($item->label(), $self->all_xinetd_services)) {
        $started = N("Start when requested");
    }
    else {
        $started = (member($item->label(), $self->all_running_services)? N("running") : N("stopped"));
    }
# TODO add icon green/red led  
    my $cell   = $tbl->toCBYTableItem($item)->cell(1);
    if ($cell) {
        $cell->setLabel($started);
        $tbl->cellChanged($cell);
    }
}

## draw service panel and manage it 
sub servicePanel {
    my $self = shift;

    my $appTitle = yui::YUI::app()->applicationTitle();

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->name);
    ## set icon if not already set by external launcher
    yui::YUI::app()->setApplicationIcon($self->icon);

#    my ($l, $on_services) = services();
#    my @xinetd_services = map { $_->[0] } xinetd_services();

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
    my $itemCollection = new yui::YItemCollection;
    foreach ($self->all_services) {

        my $serviceName = $_;
        
        my $item = new yui::YCBTableItem($serviceName);
        my $started;
        if (member($serviceName, $self->all_xinetd_services)) {
            $started = N("Start when requested");
        }
        else {
            $started = (member($serviceName, $self->all_running_services)? N("running") : N("stopped"));
        }

# TODO add icon green/red led  
        my $cell   = new yui::YTableCell($started);
        $item->addCell($cell);

        $item->check(member($serviceName, $self->all_on_services));
        $item->setLabel($serviceName);
        $itemCollection->push($item);
        $item->DISOWN();
    }
    $serviceTbl->addItems($itemCollection);
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
    my $closeButton = $factory->createPushButton($hbox, N("Close") );

    #first item status
    my $item = $serviceTbl->selectedItem();
    if ($item) {
        $self->serviceInfo($item->label(), $infoPanel);
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
                    $self->serviceInfo($item->label(), $infoPanel);
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
                        $self->refreshRunningServices();
                    }
                }
            }
            elsif ($widget == $startButton) {
                $item = $serviceTbl->selectedItem();
                if ($item) {
                    restart_or_start($item->label());
                    # we can push/pop service, but this (slower) should return real situation
                    $self->refreshRunningServices();
                    $self->serviceStatus($serviceTbl, $item);
                }
            }
            elsif ($widget == $stopButton) {
                $item = $serviceTbl->selectedItem();
                if ($item) {
                    stop($item->label());
                    # we can push/pop service, but this (slower) should return real situation
                    $self->refreshRunningServices();
                    $self->serviceStatus($serviceTbl, $item);
                }
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
