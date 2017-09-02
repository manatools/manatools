# vim: set et ts=4 sw=4:
package ManaTools::Shared::Services;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::Services - shares the API to manage services

=head1 SYNOPSIS

use ManaTools::Shared::Services;

my $serv = ManaTools::Shared::Services->new();

my ($l, $on_services) = $serv->services();

=head1 DESCRIPTION

  This module aims to share all the API to manage system services,
  to be used from GUI applications or console.

  From the original code drakx services.

=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Shared::Services

=head1 SEE ALSO

ManaTools::Shared

=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2013-2016, Angelo Naselli.

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

use Sys::Syslog;
use Net::DBus;
use Net::DBus::Annotation qw(:auth);
use File::Basename;

use ManaTools::Shared::Locales;
use MDK::Common::Func qw(find);
use MDK::Common::File;
use MDK::Common::DataStructure qw(member);
use ManaTools::Shared::RunProgram qw(rooted);

has 'loc' => (
        is => 'rw',
        isa => 'ManaTools::Shared::Locales',
        lazy => 1,
        builder => '_localeInitialize',
);


sub _localeInitialize {
    my $self = shift;

    $self->loc(
        ManaTools::Shared::Locales->new(
            domain_name => 'manatools',
        )
    );
}


has 'dbus_systemd1_service' => (
    is       => 'rw',
    init_arg => undef,
    lazy     => 1,
    builder  => '_dbusServiceInitialize'
);

sub _dbusServiceInitialize {
    my $self = shift();

    my $bus = Net::DBus->system;
    $self->dbus_systemd1_service($bus->get_service("org.freedesktop.systemd1"));
}


has 'dbus_systemd1_object' => (
    is       => 'rw',
    init_arg => undef,
    lazy     => 1,
    builder  => '_dbusObjectInitialize'
);

sub _dbusObjectInitialize {
    my $self = shift();

    $self->dbus_systemd1_object($self->dbus_systemd1_service->get_object("/org/freedesktop/systemd1"));
}

has 'include_static_services' => (
    is  => 'rw',
    isa => 'Bool',
    default => 0
);

#=============================================================

=head2 attributes

=head3 service_info

    A HashRef collecting all the service information.
    if include_static_services (default is false) is set also static
    services are included.

=cut

#=============================================================
has 'service_info' => (
    is  => 'rw',
    traits    => ['Hash'],
    isa       => 'HashRef',
    handles   => {
        set_service_info   => 'set',
        get_service_info   => 'get',
        service_info_pairs => 'kv',
    },
    init_arg  => undef,
    lazy     => 1,
    builder  => '_serviceInfoInitialization'
);

sub _serviceInfoInitialization {
    my $self = shift();

    my %services = ();
    if ($self->_running_systemd()) {
        my $object     = $self->dbus_systemd1_object;
        my $properties = $object->ListUnits();

        foreach my $s (@{$properties}) {
            my $name = $s->[0];
            if (index($name, ".service") != -1) {
                my $st = eval{$object->GetUnitFileState($name)} if $name !~ /.*\@.*$/g;
                $name =~ s|.service||;
                if (!$st) {
                    if ($name !~ /.*\@$/g &&
                        (-e "/usr/lib/systemd/system/$name.service" or -e "/etc/rc.d/init.d/$name") &&
                        ! -l "/usr/lib/systemd/system/$name.service") {
                            $st = 'enabled';
                        }
                }
                if ($st && ($self->include_static_services() || $st ne 'static')) {
                    $services{$name} = {
                        'name' => $s->[0],
                        'description' => $s->[1],
                        'load_state' => $s->[2],
                        'active_state' => $s->[3],
                        'sub_state' => $s->[4],
                        'unit_path' => $s->[6],
                        'enabled'   => $st eq 'enabled',
                    };
                }
            }
        }

        my $unit_files = $object->ListUnitFiles();
        foreach my $s (@{$unit_files}) {
            my $name = $s->[0];
            my $st = $s->[1];
            if (index($name, ".service") != -1) {
                $name = File::Basename::basename($name, ".service");
                if (!$services{$name} &&
                    $name !~ /.*\@$/g &&
                    (-e $s->[0] or -e "/etc/rc.d/init.d/$name") &&
                    ! -l $s->[0] && ($st eq "disabled" || $st eq "enabled")) {
                    my $wantedby = $self->_WantedBy($s->[0]);
                    if ($wantedby) {
                        my $descr = $self->getUnitProperty($name, 'Description');

                        $services{$name} = {
                            'name'        => $name,
                            'description' => $descr,
                            'enabled'     => $st eq "enabled",
                        };
                    }
                }
            }
        }
    }

    return \%services;
}

#=============================================================

=head2 description

=head3 INPUT

name: Service Name

=head3 OUTPUT

Description: Service description

=head3 DESCRIPTION

THis function return the description for the given service

=cut

#=============================================================
sub description {
    my ($self, $name) = @_;

    my %services = (
acpid => $self->loc->N_("Listen and dispatch ACPI events from the kernel"),
alsa => $self->loc->N_("Launch the ALSA (Advanced Linux Sound Architecture) sound system"),
anacron => $self->loc->N_("Anacron is a periodic command scheduler."),
apmd => $self->loc->N_("apmd is used for monitoring battery status and logging it via syslog.
It can also be used for shutting down the machine when the battery is low."),
atd => $self->loc->N_("Runs commands scheduled by the at command at the time specified when
at was run, and runs batch commands when the load average is low enough."),
'avahi-deamon' => $self->loc->N_("Avahi is a ZeroConf daemon which implements an mDNS stack"),
chronyd => $self->loc->N_("An NTP client/server"),
cpufreq => $self->loc->N_("Set CPU frequency settings"),
crond => $self->loc->N_("cron is a standard UNIX program that runs user-specified programs
at periodic scheduled times. vixie cron adds a number of features to the basic
UNIX cron, including better security and more powerful configuration options."),
cups => $self->loc->N_("Common UNIX Printing System (CUPS) is an advanced printer spooling system"),
dm => $self->loc->N_("Launches the graphical display manager"),
fam => $self->loc->N_("FAM is a file monitoring daemon. It is used to get reports when files change.
It is used by GNOME and KDE"),
g15daemon => $self->loc->N_("G15Daemon allows users access to all extra keys by decoding them and
pushing them back into the kernel via the linux UINPUT driver. This driver must be loaded
before g15daemon can be used for keyboard access. The G15 LCD is also supported. By default,
with no other clients active, g15daemon will display a clock. Client applications and
scripts can access the LCD via a simple API."),
gpm => $self->loc->N_("GPM adds mouse support to text-based Linux applications such the
Midnight Commander. It also allows mouse-based console cut-and-paste operations,
and includes support for pop-up menus on the console."),
haldaemon => $self->loc->N_("HAL is a daemon that collects and maintains information about hardware"),
harddrake => $self->loc->N_("HardDrake runs a hardware probe, and optionally configures
new/changed hardware."),
httpd => $self->loc->N_("Apache is a World Wide Web server. It is used to serve HTML files and CGI."),
inet => $self->loc->N_("The internet superserver daemon (commonly called inetd) starts a
variety of other internet services as needed. It is responsible for starting
many services, including telnet, ftp, rsh, and rlogin. Disabling inetd disables
all of the services it is responsible for."),
ip6tables => $self->loc->N_("Automates a packet filtering firewall with ip6tables"),
iptables => $self->loc->N_("Automates a packet filtering firewall with iptables"),
irqbalance => $self->loc->N_("Evenly distributes IRQ load across multiple CPUs for enhanced performance"),
keytable => $self->loc->N_("This package loads the selected keyboard map as set in
/etc/sysconfig/keyboard.  This can be selected using the kbdconfig utility.
You should leave this enabled for most machines."),
kheader => $self->loc->N_("Automatic regeneration of kernel header in /boot for
/usr/include/linux/{autoconf,version}.h"),
kudzu => $self->loc->N_("Automatic detection and configuration of hardware at boot."),
'laptop-mode' => $self->loc->N_("Tweaks system behavior to extend battery life"),
linuxconf => $self->loc->N_("Linuxconf will sometimes arrange to perform various tasks
at boot-time to maintain the system configuration."),
lpd => $self->loc->N_("lpd is the print daemon required for lpr to work properly. It is
basically a server that arbitrates print jobs to printer(s)."),
lvs => $self->loc->N_("Linux Virtual Server, used to build a high-performance and highly
available server."),
mandi => $self->loc->N_("Monitors the network (Interactive Firewall and wireless)"),
mdadm => $self->loc->N_("Software RAID monitoring and management"),
messagebus => $self->loc->N_("DBUS is a daemon which broadcasts notifications of system events and other messages"),
msec => $self->loc->N_("Enables MSEC security policy on system startup"),
named => $self->loc->N_("named (BIND) is a Domain Name Server (DNS) that is used to resolve host names to IP addresses."),
netconsole => $self->loc->N_("Initializes network console logging"),
netfs => $self->loc->N_("Mounts and unmounts all Network File System (NFS), SMB (Lan
Manager/Windows), and NCP (NetWare) mount points."),
network => $self->loc->N_("Activates/Deactivates all network interfaces configured to start
at boot time."),
'network-auth' => $self->loc->N_("Requires network to be up if enabled"),
'network-up' => $self->loc->N_("Wait for the hotplugged network to be up"),
nfs => $self->loc->N_("NFS is a popular protocol for file sharing across TCP/IP networks.
This service provides NFS server functionality, which is configured via the
/etc/exports file."),
nfslock => $self->loc->N_("NFS is a popular protocol for file sharing across TCP/IP
networks. This service provides NFS file locking functionality."),
ntpd => $self->loc->N_("Synchronizes system time using the Network Time Protocol (NTP)"),
numlock => $self->loc->N_("Automatically switch on numlock key locker under console
and Xorg at boot."),
oki4daemon => $self->loc->N_("Support the OKI 4w and compatible winprinters."),
partmon => $self->loc->N_("Checks if a partition is close to full up"),
pcmcia => $self->loc->N_("PCMCIA support is usually to support things like ethernet and
modems in laptops.  It will not get started unless configured so it is safe to have
it installed on machines that do not need it."),
portmap => $self->loc->N_("The portmapper manages RPC connections, which are used by
protocols such as NFS and NIS. The portmap server must be running on machines
which act as servers for protocols which make use of the RPC mechanism."),
portreserve => $self->loc->N_("Reserves some TCP ports"),
postfix => $self->loc->N_("Postfix is a Mail Transport Agent, which is the program that moves mail from one machine to another."),
random => $self->loc->N_("Saves and restores system entropy pool for higher quality random
number generation."),
rawdevices => $self->loc->N_("Assign raw devices to block devices (such as hard disk drive
partitions), for the use of applications such as Oracle or DVD players"),
resolvconf => $self->loc->N_("Nameserver information manager"),
routed => $self->loc->N_("The routed daemon allows for automatic IP router table updated via
the Routing Information Protocol. While RIP is widely used on small networks, more complex
routing protocols are needed for complex networks."),
rstatd => $self->loc->N_("The rstat protocol allows users on a network to retrieve
performance metrics for any machine on that network."),
rsyslog => $self->loc->N_("Syslog is the facility by which many daemons use to log messages to various system log files.  It is a good idea to always run rsyslog."),
rusersd => $self->loc->N_("The rusers protocol allows users on a network to identify who is
logged in on other responding machines."),
rwhod => $self->loc->N_("The rwho protocol lets remote users get a list of all of the users
logged into a machine running the rwho daemon (similar to finger)."),
saned => $self->loc->N_("SANE (Scanner Access Now Easy) enables to access scanners, video cameras, ..."),
shorewall => $self->loc->N_("Packet filtering firewall"),
smb => $self->loc->N_("The SMB/CIFS protocol enables to share access to files & printers and also integrates with a Windows Server domain"),
sound => $self->loc->N_("Launch the sound system on your machine"),
'speech-dispatcherd' => $self->loc->N_("layer for speech analysis"),
sshd => $self->loc->N_("Secure Shell is a network protocol that allows data to be exchanged over a secure channel between two computers"),
syslog => $self->loc->N_("Syslog is the facility by which many daemons use to log messages
to various system log files.  It is a good idea to always run syslog."),
'udev-post' => $self->loc->N_("Moves the generated persistent udev rules to /etc/udev/rules.d"),
usb => $self->loc->N_("Load the drivers for your usb devices."),
vnStat => $self->loc->N_("A lightweight network traffic monitor"),
xfs => $self->loc->N_("Starts the X Font Server."),
xinetd => $self->loc->N_("Starts other deamons on demand."),
    );

    my $s = $services{$name};
    if ($s) {
        $s = $self->loc->N($s);
    }
    elsif ($self->get_service_info($name)) {
        $s = $self->get_service_info($name)->{description};
    }
    else {
        my $file = "/usr/lib/systemd/system/$name.service";
        if (-e $file) {
                $s = MDK::Common::File::cat_($file);
                $s = $s =~ /^Description=(.*)/mg ? $1 : '';
        } else {
                $file = MDK::Common::Func::find { -e $_ } map { "$_/$name" } '/etc/rc.d/init.d', '/etc/init.d', '/etc/xinetd.d';
                $s = MDK::Common::File::cat_($file);
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


#=============================================================

=head2 set_service

=head3 INPUT

    $service: Service name
    $enable:  enable/disable service

=head3 DESCRIPTION

    This function enable/disable at boot the given service

=cut

#=============================================================
sub set_service {
    my ($self, $service, $enable) = @_;

    my @xinetd_services = map { $_->[0] } $self->xinetd_services();

    # NOTE EnableUnitFiles and DisableUnitFiles don't work with legacy services
    #      and return file not found
    my $legacy = -e "/etc/rc.d/init.d/$service";

    if (MDK::Common::DataStructure::member($service, @xinetd_services)) {
        $ENV{PATH} = "/usr/bin:/usr/sbin";
        ManaTools::Shared::RunProgram::rooted("", "/usr/sbin/chkconfig", $enable ? "--add" : "--del", $service);
    } elsif (!$legacy && ($self->_running_systemd() || $self->_has_systemd())) {
        $service = $service . ".service";
        my $dbus_object = $self->dbus_systemd1_object;
        if ($enable) {
            $dbus_object->EnableUnitFiles(dbus_auth_interactive, [$service], 0, 1);
        }
        else {
            $dbus_object->DisableUnitFiles(dbus_auth_interactive, [$service], 0);
        }
        # reload local cache
        $self->_systemd_services(1);
    } else {
        my $script = "/etc/rc.d/init.d/$service";
        $ENV{PATH} = "/usr/bin:/usr/sbin";
        ManaTools::Shared::RunProgram::rooted("", "/usr/sbin/chkconfig", $enable ? "--add" : "--del", $service);
        #- FIXME: handle services with no chkconfig line and with no Default-Start levels in LSB header
        if ($enable && MDK::Common::File::cat_("$script") =~ /^#\s+chkconfig:\s+-/m) {
            $ENV{PATH} = "/usr/bin:/usr/sbin";
            ManaTools::Shared::RunProgram::rooted("", "/usr/sbin/chkconfig", "--level", "35", $service, "on");
        }
    }
}

sub _run_action {
    my ($self, $service, $action) = @_;
    if ($self->_running_systemd()) {
        my $object     = $self->dbus_systemd1_object;
        if ($action eq 'start') {
            $object->StartUnit(dbus_auth_interactive, "$service.service", 'fail');
        }
        elsif ($action eq 'stop') {
            $object->StopUnit(dbus_auth_interactive, "$service.service", 'fail');
        }
        else {
            $object->RestartUnit(dbus_auth_interactive, "$service.service", 'fail');
        }
        # reload local cache
        $self->_systemd_services(1);
    } else {
        $ENV{PATH} = "/usr/bin:/usr/sbin:/etc/rc.d/init.d/";
        ManaTools::Shared::RunProgram::rooted("", "/etc/rc.d/init.d/$service", $action);
    }
}

sub _running_systemd {
    my $self = shift;

    $ENV{PATH} = "/usr/bin:/usr/sbin";
    ManaTools::Shared::RunProgram::rooted("", '/usr/bin/mountpoint', '-q', '/sys/fs/cgroup/systemd');
}

sub _has_systemd {
    my $self = shift;

    $ENV{PATH} = "/usr/bin:/usr/sbin";
    ManaTools::Shared::RunProgram::rooted("", '/usr/bin/rpm', '-q', 'systemd');
}

#=============================================================

=head2 xinetd_services

=head3 OUTPUT

    xinetd_services: All the xinetd services

=head3 DESCRIPTION

    This functions returns all the xinetd services in the system.
    NOTE that xinetd *must* be enable at boot to get this info

=cut

#=============================================================
sub xinetd_services {
    my $self = shift;

    my @xinetd_services = ();

    #avoid warning if xinetd is not installed and either enabled
    my $ser_info =  $self->get_service_info('xinetd');
    if ($ser_info && $ser_info->{enabled} eq "1") {
        local $ENV{LANGUAGE} = 'C';
        $ENV{PATH} = "/usr/bin:/usr/sbin";
        foreach (ManaTools::Shared::RunProgram::rooted_get_stdout("", '/usr/sbin/chkconfig', '--list', '--type', 'xinetd')) {
            if (my ($xinetd_name, $on_off) = m!^\t(\S+):\s*(on|off)!) {
                push @xinetd_services, [ $xinetd_name, $on_off eq 'on' ];
            }
        }
    }
    return @xinetd_services;
}

sub _systemd_services {
    my ($self, $reload) = @_;

    if ($reload) {
        $self->service_info($self->_serviceInfoInitialization());
    }

    my @services;
    for my $pair ( $self->service_info_pairs) {
        my $name = $pair->[0];
        my $info = $pair->[1];
        push @services, [$name, $info->{'enabled'}];
    }

    return @services;

}

sub _legacy_services {
    my $self = shift;

    local $ENV{LANGUAGE} = 'C';
    my @services;
    my $has_systemd = $self->_has_systemd();
    if ($has_systemd) {
        # The system not using systemd but will be at next boot. This is
        # is typically the case in the installer. In this mode we must read
        # as much as is practicable from the native systemd unit files and
        # combine that with information from chkconfig regarding legacy sysvinit
        # scripts (which systemd will parse and include when running)
        Sys::Syslog::syslog('info|local1', "Detected systemd installed. Using fake service+chkconfig introspection.");
        foreach (glob_("/usr/lib/systemd/system/*.service")) {
            my ($name) = m!([^/]*).service$!;

            # We only look at non-template, non-symlinked service files
            if (!(/.*\@\.service$/g) && ! -l $_) {
                # Limit ourselves to "standard" targets
                my $wantedby = MDK::Common::File::cat_($_) =~ /^WantedBy=(graphical|multi-user).target$/sm ? $1 : '';
                if ($wantedby) {
                    # Exclude if enabled statically
                    # Note DO NOT use -e when testing for files that could
                    # be symbolic links as this will fail under a chroot
                    # setup where -e will fail if the symlink target does
                    # exist which is typically the case when viewed outside
                    # of the chroot.
                    if (!-l "/usr/lib/systemd/system/$wantedby.target.wants/$name.service") {
                        push @services, [ $name, !!-l "/etc/systemd/system/$wantedby.target.wants/$name.service" ];
                    }
                }
            }
        }
    } else {
        Sys::Syslog::syslog('info|local1', "Could not detect systemd. Using chkconfig service introspection.");
    }

    # Regardless of whether we expect to use systemd on next boot, we still
    # need to instrospect information about non-systemd native services.
    my $runlevel;
    my $on_off;
    if (!$::isInstall) {
        $runlevel = (split " ", `/sbin/runlevel`)[1];
    }
    foreach (ManaTools::Shared::RunProgram::rooted_get_stdout("", '/sbin/chkconfig', '--list', '--type', 'sysv')) {
        if (my ($name, $l) = m!^(\S+)\s+(0:(on|off).*)!) {
            # If we expect to use systemd (i.e. installer) only show those
            # sysvinit scripts which are not masked by a native systemd unit.
            my $has_systemd_unit = $self->_systemd_unit_exists($name);
            if (!$has_systemd || !$has_systemd_unit) {
                if ($::isInstall) {
                    $on_off = $l =~ /\d+:on/g;
                } else {
                    $on_off = $l =~ /$runlevel:on/g;
                }
                push @services, [ $name, $on_off ];
            }
        }
    }
    @services;
}

#- returns:
#--- the listref of installed services
#--- the listref of "on" services
#=============================================================

=head2 services

=head3 INPUT

    $reload: load service again

=head3 OUTPUT

    @l:           all the system services
    @on_services: all the services that start at boot

=head3 DESCRIPTION

    This function returns two lists, all the system service and
    all the active ones.

=cut

#=============================================================


sub services {
    my ($self, $reload) = @_;

    my @Services;
    if ($self->_running_systemd()) {
        @Services = $self->_systemd_services($reload);
    } else {
        @Services = $self->_legacy_services();
    }

    my @l = $self->xinetd_services();
    push @l, @Services;
    @l = sort { $a->[0] cmp $b->[0] } @l;
    [ map { $_->[0] } @l ], [ map { $_->[0] } grep { $_->[1] } @l ];
}


# if we loaded service info, then exists
sub _systemd_unit_exists {
    my ($self, $name) = @_;

    return defined ($self->get_service_info($name));
}

#=============================================================

=head2 service_exists

=head3 INPUT

    $service: Service name

=head3 OUTPUT

    0/1: if the service exists

=head3 DESCRIPTION

    This function checks if a service is installed by looking for
    its unit or init.d service

=cut

#=============================================================

sub service_exists {
    my ($self, $service) = @_;
    $self->_systemd_unit_exists($service) or -x "/etc/rc.d/init.d/$service";
}

#=============================================================

=head2 restart

=head3 INPUT

    $service: Service to restart

=head3 DESCRIPTION

    This function restarts a given service

=cut

#=============================================================


sub restart  {
    my ($self, $service) = @_;
    # Exit silently if the service is not installed
    $self->service_exists($service) or return 1;
    $self->_run_action($service, "restart");
}

#=============================================================

=head2 restart_or_start

=head3 INPUT

    $service: Service to restart or start

=head3 DESCRIPTION

    This function starts a given service if it is not running,
    it restarts that otherwise

=cut

#=============================================================

sub restart_or_start {
    my ($self, $service) = @_;
    # Exit silently if the service is not installed
    $self->service_exists($service) or return 1;
    $self->_run_action($service, $self->is_service_running($service) ? "restart" : "start");
}


#=============================================================

=head2 startService

=head3 INPUT

    $service: Service to start

=head3 DESCRIPTION

    This function starts a given service

=cut

#=============================================================

sub startService {
    my ($self, $service) = @_;
    # Exit silently if the service is not installed
    $self->service_exists($service) or return 1;
    $self->_run_action($service, "start");
}

#=============================================================

=head2 start_not_running_service

=head3 INPUT

    $service: Service to start

=head3 DESCRIPTION

    This function starts a given service if not running

=cut

#=============================================================

sub start_not_running_service {
    my ($self, $service) = @_;
    # Exit silently if the service is not installed
    $self->service_exists($service) or return 1;
    $self->is_service_running($service) || $self->_run_action($service, "start");
}

#=============================================================

=head2 stopService

=head3 INPUT

    $service: Service to stop

=head3 DESCRIPTION

    This function stops a given service

=cut

#=============================================================
sub stopService {
    my ($self, $service) = @_;
    # Exit silently if the service is not installed
    $self->service_exists($service) or return 1;
    $self->_run_action($service, "stop");
}

#=============================================================

=head2 is_service_running

=head3 INPUT

    $service: Service to check

=head3 DESCRIPTION

    This function returns if the given service is running

=cut

#=============================================================

sub is_service_running {
    my ($self, $service) = @_;
    # Exit silently if the service is not installed
    $self->service_exists($service) or return 0;
    my $out;
    if ($self->_running_systemd()) {
        my $ser_info = $self->get_service_info($service);
        $out = $ser_info->{active_state} eq 'active' if $ser_info->{active_state};
    } else {
        $ENV{PATH} = "/usr/bin:/usr/sbin";
        $out = ManaTools::Shared::RunProgram::rooted("", '/usr/sbin/service', $service, 'status');
    }
    return $out;
}

#=============================================================

=head2 starts_on_boot

=head3 INPUT

    $service: Service name


=head3 DESCRIPTION

    This function returns if the given service starts at boot

=cut

#=============================================================
sub starts_on_boot {
    my ($self, $service) = @_;
    my (undef, $on_services) = $self->services();
    MDK::Common::DataStructure::member($service, @$on_services);
}

#=============================================================

=head2 start_service_on_boot

=head3 INPUT

    $service: Service name


=head3 DESCRIPTION

    This function set the given service active at boot

=cut

#=============================================================
sub start_service_on_boot {
    my ($self, $service) = @_;
    $self->set_service($service, 1);
}

#=============================================================

=head2 do_not_start_service_on_boot

=head3 INPUT

    $service: Service name


=head3 DESCRIPTION

    This function set the given service disabled at boot

=cut

#=============================================================
sub do_not_start_service_on_boot  {
    my ($self, $service) = @_;
    $self->set_service($service, 0);
}

#=============================================================

=head2 enable

=head3 INPUT

    $service:         Service name
    $o_dont_apply:    do not start it now

=head3 DESCRIPTION

    This function set the given service active at boot
    and restarts it if o_dont_apply is not given

=cut

#=============================================================
sub enable {
    my ($self, $service, $o_dont_apply) = @_;
    $self->start_service_on_boot($service);
    $self->restart_or_start($service) unless $o_dont_apply;
}

#=============================================================

=head2 disable

=head3 INPUT

    $service:         Service name
    $o_dont_apply:    do not stop it now

=head3 DESCRIPTION

    This function set the given service disabled at boot
    and stops it if o_dont_apply is not given

=cut

#=============================================================
sub disable {
    my ($self, $service, $o_dont_apply) = @_;
    $self->do_not_start_service_on_boot($service);
    $self->stopService($service) unless $o_dont_apply;
}

#=============================================================

=head2 set_status

=head3 INPUT

    $service:         Service name
    $enable:          Enable/disable
    $o_dont_apply:    do not start it now

=head3 DESCRIPTION

    This function set the given service to enable/disable at boot
    and restarts/stops it if o_dont_apply is not given

=cut

#=============================================================
sub set_status {
    my ($self, $service, $enable, $o_dont_apply) = @_;
    if ($enable) {
        $self->enable($service, $o_dont_apply);
    } else {
        $self->disable($service, $o_dont_apply);
    }
}

# NOTE $service->get_object("/org/freedesktop/systemd1/unit/$name_2eservice");
#    has empty WantedBy property if disabled
sub _WantedBy {
    my ($self, $path_service) = @_;

    my $wantedby = MDK::Common::File::cat_($path_service) =~ /^WantedBy=(graphical|multi-user).target$/sm ? $1 : '';

    return $wantedby;
}

#=============================================================

=head2 getUnitProperty

=head3 INPUT

    $unit: unit name
    $property: property name

=head3 OUTPUT

    $property_value: property value

=head3 DESCRIPTION

    This method returns the requested property value

=cut

#=============================================================
sub getUnitProperty {
    my ($self, $unit, $property) = @_;

    my $name = $unit . ".service";
    $name =~ s|-|_2d|g;
    $name =~ s|\.|_2e|g;
    my $service = $self->dbus_systemd1_service;
    my $unit_object = $service->get_object("/org/freedesktop/systemd1/unit/" . $name);
    my $property_value = eval {$unit_object->Get("org.freedesktop.systemd1.Unit", $property)} || "";

    return $property_value;
}

1;
