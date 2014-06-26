# vim: set et ts=4 sw=4:
package AdminPanel::Shared::Services;
#============================================================= -*-perl-*-

=head1 NAME

AdminPanel::Shared::Services - shares the API to manage services

=head1 SYNOPSIS

use AdminPanel::Shared::Services;
 
my ($l, $on_services) = AdminPanel::Shared::Services::services();

=head1 DESCRIPTION

  This module aims to share all the API to manage system services,
  to be used from GUI applications or console.
  
  From the original code drakx services.

=head1 EXPORT

  description
  services
  xinetd_services
  is_service_running
  restart_or_start
  stopService
  startService
  restart
  set_service
  service_exists
  start_not_running_service
  starts_on_boot
  start_service_on_boot
  do_not_start_service_on_boot
  enable
  disable
  set_status

=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc AdminPanel::Shared::Services

=head1 SEE ALSO

AdminPanel::Shared

=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2013-2014, Angelo Naselli.

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


#-######################################################################################
#- misc imports
#-######################################################################################

use strict;
use diagnostics;

use Sys::Syslog;
use File::Basename qw( basename );
use AdminPanel::Shared qw(member);
use AdminPanel::Shared::Locales;

use lib qw(/usr/lib/libDrakX);
use MDK::Common::Func qw(find);
use MDK::Common::File qw(cat_);
use run_program qw(rooted);

use base qw(Exporter);

our @EXPORT = qw(
                description
                services
                xinetd_services
                is_service_running
                restart_or_start
                stopService
                startService
                restart
                set_service
                service_exists
                start_not_running_service
                starts_on_boot
                start_service_on_boot
                do_not_start_service_on_boot
                enable
                disable
                set_status
                );


my $loc = AdminPanel::Shared::Locales->new(domain_name => 'libDrakX-standalone');

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
    my %services = (
acpid => $loc->N_("Listen and dispatch ACPI events from the kernel"),	    
alsa => $loc->N_("Launch the ALSA (Advanced Linux Sound Architecture) sound system"),
anacron => $loc->N_("Anacron is a periodic command scheduler."),
apmd => $loc->N_("apmd is used for monitoring battery status and logging it via syslog.
It can also be used for shutting down the machine when the battery is low."),
atd => $loc->N_("Runs commands scheduled by the at command at the time specified when
at was run, and runs batch commands when the load average is low enough."),
'avahi-deamon' => $loc->N_("Avahi is a ZeroConf daemon which implements an mDNS stack"),
chronyd => $loc->N_("An NTP client/server"),
cpufreq => $loc->N_("Set CPU frequency settings"),
crond => $loc->N_("cron is a standard UNIX program that runs user-specified programs
at periodic scheduled times. vixie cron adds a number of features to the basic
UNIX cron, including better security and more powerful configuration options."),
cups => $loc->N_("Common UNIX Printing System (CUPS) is an advanced printer spooling system"),
dm => $loc->N_("Launches the graphical display manager"),
fam => $loc->N_("FAM is a file monitoring daemon. It is used to get reports when files change.
It is used by GNOME and KDE"),
g15daemon => $loc->N_("G15Daemon allows users access to all extra keys by decoding them and 
pushing them back into the kernel via the linux UINPUT driver. This driver must be loaded 
before g15daemon can be used for keyboard access. The G15 LCD is also supported. By default, 
with no other clients active, g15daemon will display a clock. Client applications and 
scripts can access the LCD via a simple API."),
gpm => $loc->N_("GPM adds mouse support to text-based Linux applications such the
Midnight Commander. It also allows mouse-based console cut-and-paste operations,
and includes support for pop-up menus on the console."),
haldaemon => $loc->N_("HAL is a daemon that collects and maintains information about hardware"),
harddrake => $loc->N_("HardDrake runs a hardware probe, and optionally configures
new/changed hardware."),
httpd => $loc->N_("Apache is a World Wide Web server. It is used to serve HTML files and CGI."),
inet => $loc->N_("The internet superserver daemon (commonly called inetd) starts a
variety of other internet services as needed. It is responsible for starting
many services, including telnet, ftp, rsh, and rlogin. Disabling inetd disables
all of the services it is responsible for."),
ip6tables => $loc->N_("Automates a packet filtering firewall with ip6tables"),
iptables => $loc->N_("Automates a packet filtering firewall with iptables"),
irqbalance => $loc->N_("Evenly distributes IRQ load across multiple CPUs for enhanced performance"),
keytable => $loc->N_("This package loads the selected keyboard map as set in
/etc/sysconfig/keyboard.  This can be selected using the kbdconfig utility.
You should leave this enabled for most machines."),
kheader => $loc->N_("Automatic regeneration of kernel header in /boot for
/usr/include/linux/{autoconf,version}.h"),
kudzu => $loc->N_("Automatic detection and configuration of hardware at boot."),
'laptop-mode' => $loc->N_("Tweaks system behavior to extend battery life"),
linuxconf => $loc->N_("Linuxconf will sometimes arrange to perform various tasks
at boot-time to maintain the system configuration."),
lpd => $loc->N_("lpd is the print daemon required for lpr to work properly. It is
basically a server that arbitrates print jobs to printer(s)."),
lvs => $loc->N_("Linux Virtual Server, used to build a high-performance and highly
available server."),
mandi => $loc->N_("Monitors the network (Interactive Firewall and wireless"),
mdadm => $loc->N_("Software RAID monitoring and management"),
messagebus => $loc->N_("DBUS is a daemon which broadcasts notifications of system events and other messages"),
msec => $loc->N_("Enables MSEC security policy on system startup"),
named => $loc->N_("named (BIND) is a Domain Name Server (DNS) that is used to resolve host names to IP addresses."),
netconsole => $loc->N_("Initializes network console logging"),
netfs => $loc->N_("Mounts and unmounts all Network File System (NFS), SMB (Lan
Manager/Windows), and NCP (NetWare) mount points."),
network => $loc->N_("Activates/Deactivates all network interfaces configured to start
at boot time."),
'network-auth' => $loc->N_("Requires network to be up if enabled"),
'network-up' => $loc->N_("Wait for the hotplugged network to be up"),
nfs => $loc->N_("NFS is a popular protocol for file sharing across TCP/IP networks.
This service provides NFS server functionality, which is configured via the
/etc/exports file."),
nfslock => $loc->N_("NFS is a popular protocol for file sharing across TCP/IP
networks. This service provides NFS file locking functionality."),
ntpd => $loc->N_("Synchronizes system time using the Network Time Protocol (NTP)"),
numlock => $loc->N_("Automatically switch on numlock key locker under console
and Xorg at boot."),
oki4daemon => $loc->N_("Support the OKI 4w and compatible winprinters."),
partmon => $loc->N_("Checks if a partition is close to full up"),
pcmcia => $loc->N_("PCMCIA support is usually to support things like ethernet and
modems in laptops.  It will not get started unless configured so it is safe to have
it installed on machines that do not need it."),
portmap => $loc->N_("The portmapper manages RPC connections, which are used by
protocols such as NFS and NIS. The portmap server must be running on machines
which act as servers for protocols which make use of the RPC mechanism."),
portreserve => $loc->N_("Reserves some TCP ports"),
postfix => $loc->N_("Postfix is a Mail Transport Agent, which is the program that moves mail from one machine to another."),
random => $loc->N_("Saves and restores system entropy pool for higher quality random
number generation."),
rawdevices => $loc->N_("Assign raw devices to block devices (such as hard disk drive
partitions), for the use of applications such as Oracle or DVD players"),
resolvconf => $loc->N_("Nameserver information manager"),
routed => $loc->N_("The routed daemon allows for automatic IP router table updated via
the RIP protocol. While RIP is widely used on small networks, more complex
routing protocols are needed for complex networks."),
rstatd => $loc->N_("The rstat protocol allows users on a network to retrieve
performance metrics for any machine on that network."),
rsyslog => $loc->N_("Syslog is the facility by which many daemons use to log messages to various system log files.  It is a good idea to always run rsyslog."),
rusersd => $loc->N_("The rusers protocol allows users on a network to identify who is
logged in on other responding machines."),
rwhod => $loc->N_("The rwho protocol lets remote users get a list of all of the users
logged into a machine running the rwho daemon (similar to finger)."),
saned => $loc->N_("SANE (Scanner Access Now Easy) enables to access scanners, video cameras, ..."),
shorewall => $loc->N_("Packet filtering firewall"),
smb => $loc->N_("The SMB/CIFS protocol enables to share access to files & printers and also integrates with a Windows Server domain"),
sound => $loc->N_("Launch the sound system on your machine"),
'speech-dispatcherd' => $loc->N_("layer for speech analysis"),
sshd => $loc->N_("Secure Shell is a network protocol that allows data to be exchanged over a secure channel between two computers"),
syslog => $loc->N_("Syslog is the facility by which many daemons use to log messages
to various system log files.  It is a good idea to always run syslog."),
'udev-post' => $loc->N_("Moves the generated persistent udev rules to /etc/udev/rules.d"),
usb => $loc->N_("Load the drivers for your usb devices."),
vnStat => $loc->N_("A lightweight network traffic monitor"),
xfs => $loc->N_("Starts the X Font Server."),
xinetd => $loc->N_("Starts other deamons on demand."),
    );
    my ($name) = @_;
    my $s = $services{$name};
    if ($s) {
        $s = $loc->N($s);
    } else {
        my $file = "$::prefix/usr/lib/systemd/system/$name.service";
        if (-e $file) {
                $s = MDK::Common::File::cat_($file);
                $s = $s =~ /^Description=(.*)/mg ? $1 : '';
        } else {
                $file = MDK::Common::Func::find { -e $_ } map { "$::prefix$_/$name" } '/etc/rc.d/init.d', '/etc/init.d', '/etc/xinetd.d';
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
    my ($service, $enable) = @_;

    my @xinetd_services = map { $_->[0] } xinetd_services();

    if (AdminPanel::Shared::member($service, @xinetd_services)) {
        $ENV{PATH} = "/usr/bin:/usr/sbin";
        run_program::rooted($::prefix, "/usr/sbin/chkconfig", $enable ? "--add" : "--del", $service);
    } elsif (_running_systemd() || _has_systemd()) {
        # systemctl rejects any symlinked units. You have to enabled the real file
        if (-l "/lib/systemd/system/$service.service") {
            my $name = readlink("/lib/systemd/system/$service.service");
            $service = File::Basename::basename($name);
        } else {
            $service = $service . ".service";
        }
        $ENV{PATH} = "/usr/bin:/usr/sbin";
        run_program::rooted($::prefix, "/usr/bin/systemctl", $enable ? "enable" : "disable", $service);
    } else {
        my $script = "/etc/rc.d/init.d/$service";
        $ENV{PATH} = "/usr/bin:/usr/sbin";
        run_program::rooted($::prefix, "/usr/sbin/chkconfig", $enable ? "--add" : "--del", $service);
        #- FIXME: handle services with no chkconfig line and with no Default-Start levels in LSB header
        if ($enable && MDK::Common::File::cat_("$::prefix$script") =~ /^#\s+chkconfig:\s+-/m) {
            $ENV{PATH} = "/usr/bin:/usr/sbin";
            run_program::rooted($::prefix, "/usr/sbin/chkconfig", "--level", "35", $service, "on");
        }
    }
}

sub _run_action {
    my ($service, $action, $do_not_block) = @_;
    if (_running_systemd()) {
        if ($do_not_block) {
            $ENV{PATH} = "/usr/bin:/usr/sbin";
            run_program::rooted($::prefix, '/usr//bin/systemctl', '--no-block', $action, "$service.service");
        }
        else {
            $ENV{PATH} = "/usr/bin:/usr/sbin";
            run_program::rooted($::prefix, '/usr/bin/systemctl', $action, "$service.service");
        }
    } else {
        $ENV{PATH} = "/usr/bin:/usr/sbin:/etc/rc.d/init.d/";
        run_program::rooted($::prefix, "/etc/rc.d/init.d/$service", $action);
    }
}

sub _running_systemd() {
    $ENV{PATH} = "/usr/bin:/usr/sbin";
    run_program::rooted($::prefix, '/usr/bin/mountpoint', '-q', '/sys/fs/cgroup/systemd');
}

sub _has_systemd() {
    $ENV{PATH} = "/usr/bin:/usr/sbin";
    run_program::rooted($::prefix, '/usr/bin/rpm', '-q', 'systemd');
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
sub xinetd_services() {
    local $ENV{LANGUAGE} = 'C';
    my @xinetd_services;
    $ENV{PATH} = "/usr/bin:/usr/sbin";
    foreach (run_program::rooted_get_stdout($::prefix, '/usr/sbin/chkconfig', '--list', '--type', 'xinetd')) {
        if (my ($xinetd_name, $on_off) = m!^\t(\S+):\s*(on|off)!) {
            push @xinetd_services, [ $xinetd_name, $on_off eq 'on' ];
        }
    }
    @xinetd_services;
}

sub _systemd_services() {
    local $ENV{LANGUAGE} = 'C';
    my @services;
    my %loaded;
    # Running system using systemd
    Sys::Syslog::syslog('info|local1', "Detected systemd running. Using systemctl introspection.");
    foreach (run_program::rooted_get_stdout($::prefix, '/usr/bin/systemctl', '--full', '--all', 'list-units')) {
        if (my ($name) = m!^(\S+)\.service\s+loaded!) {
            # We only look at non-template, non-linked service files in /lib
            # We also check for any non-masked sysvinit files as these are
            # also handled by systemd
            if ($name !~ /.*\@$/g && (-e "$::prefix/lib/systemd/system/$name.service" or -e "$::prefix/etc/rc.d/init.d/$name") && ! -l "$::prefix/lib/systemd/system/$name.service") {
                push @services, [ $name, !!run_program::rooted($::prefix, '/usr/bin/systemctl', '--quiet', 'is-enabled', "$name.service") ];
                $loaded{$name} = 1;
            }
        }
    }
    # list-units will not list disabled units that can be enabled
    foreach (run_program::rooted_get_stdout($::prefix, '/usr/bin/systemctl', '--full', 'list-unit-files')) {
        if (my ($name) = m!^(\S+)\.service\s+disabled!) {
            # We only look at non-template, non-linked service files in /lib
            # We also check for any non-masked sysvinit files as these are
            # also handled by systemd
            if (!exists $loaded{$name} && $name !~ /.*\@$/g && (-e "$::prefix/lib/systemd/system/$name.service" or -e "$::prefix/etc/rc.d/init.d/$name") && ! -l "$::prefix/lib/systemd/system/$name.service") {
                # Limit ourselves to "standard" targets which can be enabled
                my $wantedby = MDK::Common::File::cat_("$::prefix/lib/systemd/system/$name.service") =~ /^WantedBy=(graphical|multi-user).target$/sm ? $1 : '';
                if ($wantedby) {
                    push @services, [ $name, 0 ];
                }
            }
        }
    }

    @services;
}

sub _legacy_services() {
    local $ENV{LANGUAGE} = 'C';
    my @services;
    my $has_systemd = _has_systemd();
    if ($has_systemd) {
        # The system not using systemd but will be at next boot. This is
        # is typically the case in the installer. In this mode we must read
        # as much as is practicable from the native systemd unit files and
        # combine that with information from chkconfig regarding legacy sysvinit
        # scripts (which systemd will parse and include when running)
        Sys::Syslog::syslog('info|local1', "Detected systemd installed. Using fake service+chkconfig introspection.");
        foreach (glob_("$::prefix/lib/systemd/system/*.service")) {
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
                    if (!-l "$::prefix/lib/systemd/system/$wantedby.target.wants/$name.service") {
                        push @services, [ $name, !!-l "$::prefix/etc/systemd/system/$wantedby.target.wants/$name.service" ];
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
    foreach (run_program::rooted_get_stdout($::prefix, '/sbin/chkconfig', '--list', '--type', 'sysv')) {
        if (my ($name, $l) = m!^(\S+)\s+(0:(on|off).*)!) {
            # If we expect to use systemd (i.e. installer) only show those
            # sysvinit scripts which are not masked by a native systemd unit.
            my $has_systemd_unit = _systemd_unit_exists($name);
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

=head3 OUTPUT

@l:           all the system services
@on_services: all the services that start at boot

=head3 DESCRIPTION

This function returns two lists, all the system service and
all the active ones.

=cut

#=============================================================


sub services() {
    my @Services;
    if (_running_systemd()) {
        @Services = _systemd_services();
    } else {
        @Services = _legacy_services();
    }

    my @l = xinetd_services();
    push @l, @Services;
    @l = sort { $a->[0] cmp $b->[0] } @l;
    [ map { $_->[0] } @l ], [ map { $_->[0] } grep { $_->[1] } @l ];
}



sub _systemd_unit_exists {
    my ($name) = @_;
    # we test with -l as symlinks are not valid when the system is chrooted:
    -e "$::prefix/lib/systemd/system/$name.service" or -l "$::prefix/lib/systemd/system/$name.service";
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
    my ($service) = @_;
    -x "$::prefix/etc/rc.d/init.d/$service" or _systemd_unit_exists($service);
}

#=============================================================

=head2 restart

=head3 INPUT

$service: Service to restart

=head3 DESCRIPTION

This function restarts a given service

=cut

#=============================================================


sub restart ($) {
    my ($service) = @_;
    # Exit silently if the service is not installed
    service_exists($service) or return 1;
    _run_action($service, "restart");
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

sub restart_or_start ($) {
    my ($service) = @_;
    # Exit silently if the service is not installed
    service_exists($service) or return 1;
    _run_action($service, is_service_running($service) ? "restart" : "start");
}


#=============================================================

=head2 startService

=head3 INPUT

$service: Service to start

=head3 DESCRIPTION

This function starts a given service

=cut

#=============================================================

sub startService ($) {
    my ($service) = @_;
    # Exit silently if the service is not installed
    service_exists($service) or return 1;
    _run_action($service, "start");
}

#=============================================================

=head2 start_not_running_service

=head3 INPUT

$service: Service to start

=head3 DESCRIPTION

This function starts a given service if not running

=cut

#=============================================================

sub start_not_running_service ($) {
    my ($service) = @_;
    # Exit silently if the service is not installed
    service_exists($service) or return 1;
    is_service_running($service) || _run_action($service, "start");
}

#=============================================================

=head2 stopService

=head3 INPUT

$service: Service to stop

=head3 DESCRIPTION

This function stops a given service

=cut

#=============================================================
sub stopService ($) {
    my ($service) = @_;
    # Exit silently if the service is not installed
    service_exists($service) or return 1;
    _run_action($service, "stop");
}

#=============================================================

=head2 is_service_running

=head3 INPUT

$service: Service to check

=head3 DESCRIPTION

This function returns if the given service is running

=cut

#=============================================================

sub is_service_running ($) {
    my ($service) = @_;
    # Exit silently if the service is not installed
    service_exists($service) or return 0;
    my $out;
    if (_running_systemd()) {
        $ENV{PATH} = "/usr/bin:/usr/sbin";
        $out = run_program::rooted($::prefix, '/usr/bin/systemctl', '--quiet', 'is-active', "$service.service");
    } else {
        $ENV{PATH} = "/usr/bin:/usr/sbin";
        $out = run_program::rooted($::prefix, '/usr/sbin/service', $service, 'status');
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
    my ($service) = @_;
    my (undef, $on_services) = services();
    AdminPanel::Shared::member($service, @$on_services);
}

#=============================================================

=head2 start_service_on_boot

=head3 INPUT

$service: Service name


=head3 DESCRIPTION

This function set the given service active at boot

=cut

#=============================================================
sub start_service_on_boot ($) {
    my ($service) = @_;
    set_service($service, 1);
}

#=============================================================

=head2 do_not_start_service_on_boot

=head3 INPUT

$service: Service name


=head3 DESCRIPTION

This function set the given service disabled at boot

=cut

#=============================================================
sub do_not_start_service_on_boot ($) {
    my ($service) = @_;
    set_service($service, 0);
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
    my ($service, $o_dont_apply) = @_;
    start_service_on_boot($service);
    restart_or_start($service) unless $o_dont_apply;
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
    my ($service, $o_dont_apply) = @_;
    do_not_start_service_on_boot($service);
    stopService($service) unless $o_dont_apply;
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
    my ($service, $enable, $o_dont_apply) = @_;
    if ($enable) {
        enable($service, $o_dont_apply);
    } else {
        disable($service, $o_dont_apply);
    }
}

1;
