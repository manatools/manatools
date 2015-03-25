# vim: set et ts=4 sw=4:
package ManaTools::Shared::TimeZone;

#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::TimeZone - module to manage TimeZone settings

=head1 SYNOPSIS

    my $tz = ManaTools::Shared::TimeZone->new();


=head1 DESCRIPTION

This module allows to manage time zone settings.

=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Shared::TimeZone


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
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=head1 METHODS

=cut


use diagnostics;
use strict;

use Moose;
use English;
use Sys::Syslog;

use DateTime::TimeZone;
use Net::DBus;

use ManaTools::Shared::Locales;
use ManaTools::Shared::Services;

use MDK::Common::File qw(cat_ output_p substInFile);
use MDK::Common::Func qw(find if_);


#=============================================================

=head2 new - optional parameters

=head3 timezone_prefix

    optional parameter to set the system timezone directory,
    default value is /usr/share/zoneinfo

=cut

#=============================================================

has 'timezone_prefix' => (
    is => 'rw',
    isa => 'Str',
    default => "/usr/share/zoneinfo",
);


#=============================================================

=head2 new - optional parameters

=head3 ntp_configuration_file

    optional parameter to set the ntp server configuration file,
    default value is evaluated in the following order
    /etc/chrony.conf if found
    /etc/ntp.conf if found and not found chrony
    /etc/systemd/timesyncd.conf default

=cut

#=============================================================

has 'ntp_configuration_file' => (
    is  => 'rw',
    isa => 'Str',
    builder => '_ntp_configuration_file_init',
);

sub _ntp_configuration_file_init {
    my $self = shift;

    return "/etc/chrony.conf" if (-f  "/etc/chrony.conf");

    return "/etc/ntp.conf" if (-f "/etc/ntp.conf");

    return "/etc/systemd/timesyncd.conf";
}

#=============================================================

=head2 new - optional parameters

=head3 ntp_conf_dir

    optional parameter to set ntp configuration directory,
    default value is /etc/ntp

=cut

#=============================================================

has 'ntp_conf_dir' => (
    is   => 'rw',
    isa  => 'Str',
    lazy => 1,
    default => "/etc/ntp",
);

#=============================================================

=head2 new - optional parameters

=head3 ntp_program

    optional parameter to set the ntp program that runs into the
    system, available value are chronyd, ntpd and systemd-timesyncd.

    Default value is evaluate by configuration file found in the
    system, fallback choice is systemd-timesyncd.

=cut

#=============================================================
has 'ntp_program' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    builder => '_ntp_program_init',
);

sub _ntp_program_init {
    my $self = shift;

    return "chronyd" if ($self->ntp_configuration_file() eq "/etc/chrony.conf");

    return "ntpd" if ($self->ntp_configuration_file() eq "/etc/ntp.conf");

    return "systemd-timesyncd" if ($self->ntp_configuration_file() eq "/etc/systemd/timesyncd.conf");
}

#=============================================================

=head2 attribute

=head3 ntpServiceConfig

    This RO attribute is a HashRef containing managed ntp
    service as key and related configuration file.

    Allowed actions:
        getNTPServiceConfig => retrieves config file from the
                               given ntp service
        ntpServiceConfigPairs => Key,Value pairs access

=cut

#=============================================================
has 'ntpServiceConfig' => (
    traits    => ['Hash'],
    default   => sub { {
        'chronyd'           => '/etc/chrony.conf',
        'ntpd'              => '/etc/ntp.conf',
        'systemd-timesyncd' => '/etc/systemd/timesyncd.conf'
    } },
    is        => 'ro',
    isa       => 'HashRef',
    handles   => {
        getNTPServiceConfig   => 'get',
        ntpServiceConfigPairs => 'kv',
    },
    init_arg  => undef,
);

# has 'dmlist' => (
#     is      => 'rw',
#     isa     => 'ArrayRef',
#     builder => '_build_dmlist',
# );

#=============================================================

=head2 new - optional parameters

=head3 installer_or_livecd

    To inform the back-end that is working during installer or
    livecd. Useful if Time zone setting and using fix_system
    to use the real time clock (see setLocalRTC and
    writeConfiguration).

=cut

#=============================================================
has 'installer_or_livecd' => (
    is  => 'rw',
    isa => 'Bool',
    default => 0,
);

#=== globals ===

has 'sh_services' => (
        is => 'rw',
        init_arg => undef,
        lazy     => 1,
        builder => '_SharedServicesInitialize'
);

sub _SharedServicesInitialize {
    my $self = shift();

    $self->sh_services(ManaTools::Shared::Services->new() );
}


has 'dbus_timedate1_service' => (
    is       => 'rw',
    init_arg => undef,
    lazy     => 1,
    builder  => '_dbusTimeDateInitialize'
);

sub _dbusTimeDateInitialize {
    my $self = shift();

    my $bus = Net::DBus->system;
    $self->dbus_timedate1_service($bus->get_service("org.freedesktop.timedate1"));
}


has 'dbus_timedate1_object' => (
    is       => 'rw',
    init_arg => undef,
    lazy     => 1,
    builder  => '_dbusObjectInitialize'
);

sub _dbusObjectInitialize {
    my $self = shift();

    $self->dbus_timedate1_object($self->dbus_timedate1_service->get_object("/org/freedesktop/timedate1"));
}


has 'servername_config_suffix' => (
    is  => 'ro',
    isa => 'Str',
    lazy     => 1,
    builder  => '_servername_config_suffix_init',
);

sub _servername_config_suffix_init {
    my $self = shift;

    return " iburst" if ($self->ntp_program eq "chronyd");

    return "";
}

has 'loc' => (
        is       => 'rw',
        lazy     => 1,
        init_arg => undef,
        builder  => '_localeInitialize'
);

sub _localeInitialize {
    my $self = shift;

    # TODO fix domain binding for translation
    $self->loc(ManaTools::Shared::Locales->new(domain_name => 'libDrakX') );
    # TODO if we want to give the opportunity to test locally add dir_name => 'path'
}


has 'ntp_servers' => (
    traits    => ['Hash'],
    is        => 'rw',
    isa       => 'HashRef',
    lazy      => 1,
    handles   => {
        get_ntp_server     => 'get',
        ntp_server_pairs   => 'kv',
    },
    init_arg  => undef,
    builder => '_buildNTPServers'
);

sub _buildNTPServers {
    my $self = shift;

    my %ntpServersHash;
    $ntpServersHash{"-"} = {
        $self->loc->N_("Global") => "pool.ntp.org",
    };
    $ntpServersHash{Global} = {
        $self->loc->N_("Africa") => "africa.pool.ntp.org",
        $self->loc->N_("Asia") => "asia.pool.ntp.org",
        $self->loc->N_("Europe") => "europe.pool.ntp.org",
        $self->loc->N_("North America") => "north-america.pool.ntp.org",
        $self->loc->N_("Oceania") => "oceania.pool.ntp.org",
        $self->loc->N_("South America") => "south-america.pool.ntp.org",
    };
    $ntpServersHash{Africa} = {
        $self->loc->N_("South Africa") => "za.pool.ntp.org",
        $self->loc->N_("Tanzania") => "tz.pool.ntp.org",
    };
    $ntpServersHash{Asia} = {
        $self->loc->N_("Bangladesh") => "bd.pool.ntp.org",
        $self->loc->N_("China") => "cn.pool.ntp.org",
        $self->loc->N_("Hong Kong") => "hk.pool.ntp.org",
        $self->loc->N_("India") => "in.pool.ntp.org",
        $self->loc->N_("Indonesia") => "id.pool.ntp.org",
        $self->loc->N_("Iran") => "ir.pool.ntp.org",
        $self->loc->N_("Israel") => "il.pool.ntp.org",
        $self->loc->N_("Japan") => "jp.pool.ntp.org",
        $self->loc->N_("Korea") => "kr.pool.ntp.org",
        $self->loc->N_("Malaysia") => "my.pool.ntp.org",
        $self->loc->N_("Philippines") => "ph.pool.ntp.org",
        $self->loc->N_("Singapore") => "sg.pool.ntp.org",
        $self->loc->N_("Taiwan") => "tw.pool.ntp.org",
        $self->loc->N_("Thailand") => "th.pool.ntp.org",
        $self->loc->N_("Turkey") => "tr.pool.ntp.org",
        $self->loc->N_("United Arab Emirates") => "ae.pool.ntp.org",
    };
    $ntpServersHash{Europe} = {
        $self->loc->N_("Austria") => "at.pool.ntp.org",
        $self->loc->N_("Belarus") => "by.pool.ntp.org",
        $self->loc->N_("Belgium") => "be.pool.ntp.org",
        $self->loc->N_("Bulgaria") => "bg.pool.ntp.org",
        $self->loc->N_("Czech Republic") => "cz.pool.ntp.org",
        $self->loc->N_("Denmark") => "dk.pool.ntp.org",
        $self->loc->N_("Estonia") => "ee.pool.ntp.org",
        $self->loc->N_("Finland") => "fi.pool.ntp.org",
        $self->loc->N_("France") => "fr.pool.ntp.org",
        $self->loc->N_("Germany") => "de.pool.ntp.org",
        $self->loc->N_("Greece") => "gr.pool.ntp.org",
        $self->loc->N_("Hungary") => "hu.pool.ntp.org",
        $self->loc->N_("Ireland") => "ie.pool.ntp.org",
        $self->loc->N_("Italy") => "it.pool.ntp.org",
        $self->loc->N_("Lithuania") => "lt.pool.ntp.org",
        $self->loc->N_("Luxembourg") => "lu.pool.ntp.org",
        $self->loc->N_("Netherlands") => "nl.pool.ntp.org",
        $self->loc->N_("Norway") => "no.pool.ntp.org",
        $self->loc->N_("Poland") => "pl.pool.ntp.org",
        $self->loc->N_("Portugal") => "pt.pool.ntp.org",
        $self->loc->N_("Romania") => "ro.pool.ntp.org",
        $self->loc->N_("Russian Federation") => "ru.pool.ntp.org",
        $self->loc->N_("Slovakia") => "sk.pool.ntp.org",
        $self->loc->N_("Slovenia") => "si.pool.ntp.org",
        $self->loc->N_("Spain") => "es.pool.ntp.org",
        $self->loc->N_("Sweden") => "se.pool.ntp.org",
        $self->loc->N_("Switzerland") => "ch.pool.ntp.org",
        $self->loc->N_("Ukraine") => "ua.pool.ntp.org",
        $self->loc->N_("United Kingdom") => "uk.pool.ntp.org",
        $self->loc->N_("Yugoslavia") => "yu.pool.ntp.org",
    };
    $ntpServersHash{"North America"} = {
        $self->loc->N_("Canada") => "ca.pool.ntp.org",
        $self->loc->N_("Guatemala") => "gt.pool.ntp.org",
        $self->loc->N_("Mexico") => "mx.pool.ntp.org",
        $self->loc->N_("United States") => "us.pool.ntp.org",
    };
    $ntpServersHash{Oceania} = {
        $self->loc->N_("Australia") => "au.pool.ntp.org",
        $self->loc->N_("New Zealand") => "nz.pool.ntp.org",
    };
    $ntpServersHash{"South America"} = {
        $self->loc->N_("Argentina") => "ar.pool.ntp.org",
        $self->loc->N_("Brazil") => "br.pool.ntp.org",
        $self->loc->N_("Chile") => "cl.pool.ntp.org",
    };

    return \%ntpServersHash;
}


#=============================================================

=head2 get_timezone_prefix

=head3 OUTPUT

timezone_prefix: directory in which time zone files are

=head3 DESCRIPTION

Return the timezone directory (defualt: /usr/share/zoneinfo)

=cut

#=============================================================
sub get_timezone_prefix {
    my $self = shift;

    return $self->timezone_prefix;
}

#=============================================================

=head2 getTimeZones

=head3 INPUT

    $from_system: if present and its value is not 0 checks into timezone_prefix
                directory and gets the list from there

=head3 OUTPUT

    @l: ARRAY containing sorted time zones

=head3 DESCRIPTION

    This method returns the available timezones

=cut

#=============================================================
sub getTimeZones {
    my ($self, $from_system) = @_;

    if ($from_system and $from_system != 0) {
        require MDK::Common::DataStructure;
        require MDK::Common::Various;
        my $tz_prefix = $self->get_timezone_prefix();
        open(my $F, "cd $tz_prefix && find [A-Z]* -noleaf -type f |");
        my @l = MDK::Common::DataStructure::difference2([ MDK::Common::Various::chomp_(<$F>) ], [ 'ROC', 'PRC' ]);
        close $F or die "cannot list the available zoneinfos";
        return sort @l;
    }

    return DateTime::TimeZone->all_names;
}

#=============================================================

=head2 setTimeZone

=head3 INPUT

    $new_time_zone: New time zone to be set

=head3 DESCRIPTION

    This method get the new time zone to set and performs
    the setting

=cut

#=============================================================
sub setTimeZone {
    my ($self, $new_time_zone) = @_;

    die "Time zone value required" if !defined($new_time_zone);

    my $object   = $self->dbus_timedate1_object;
    $object->SetTimezone($new_time_zone, 1);
}

#=============================================================

=head2 getTimeZone

=head3 OUTPUT

    $timezone: current time zone

=head3 DESCRIPTION

    This method returns the current timezone setting

=cut

#=============================================================
sub getTimeZone {
    my ($self) = @_;

    my $object       = $self->dbus_timedate1_object;

    return $object->Get("org.freedesktop.timedate1", 'Timezone') || "";
}


#=============================================================

=head2 setLocalRTC

=head3 INPUT

    $enable: bool value enable/disable real time clock as
             localtime
    $fix_system: bool read or not the real time clock

=head3 DESCRIPTION

    This method enables/disables the real time clock as
    localtime (e.g. disable means set the rtc to UTC).
    NOTE from dbus:
    Use SetLocalRTC() to control whether the RTC is in
    local time or UTC. It is strongly recommended to maintain
    the RTC in UTC. Some OSes (Windows) however maintain the
    RTC in local time which might make it necessary to enable
    this feature. However, this creates various problems as
    daylight changes might be missed. If fix_system is passed
    "true" the time from the RTC is read again and the system
    clock adjusted according to the new setting.
    If fix_system is passed "false" the system time is written
    to the RTC taking the new setting into account.
    Use fix_system=true in installers and livecds where the
    RTC is probably more reliable than the system time.
    Use fix_system=false in configuration UIs that are run during
    normal operation and where the system clock is probably more
    reliable than the RTC.

=cut

#=============================================================
sub setLocalRTC {
    my ($self, $enable, $fix_system) = @_;

    die "Localtime enable/disable value required" if !defined($enable);

    $fix_system = 0 if !defined($fix_system);
    my $object   = $self->dbus_timedate1_object;
    $object->SetLocalRTC($enable, $fix_system, 1) ;
}

#=============================================================

=head2 getLocalRTC

=head3 OUTPUT

    $localRTC: 1 if RTC is localtime 0 for UTC

=head3 DESCRIPTION

    This method returns the RTC localtime setting

=cut

#=============================================================
sub getLocalRTC {
    my $self = shift;

    my $object   = $self->dbus_timedate1_object;

    return $object->Get("org.freedesktop.timedate1", 'LocalRTC') ? 1 : 0;
}

#=============================================================

=head2 setEmbeddedNTP

=head3 INPUT

    $enable: enable/disable systemd NTP service

=head3 DESCRIPTION

    This method enables/disables and starts/stops systemd NTP service,

=cut

#=============================================================
sub setEmbeddedNTP {
    my ($self, $enable) = @_;

    my $object   = $self->dbus_timedate1_object;
    $object->SetNTP(($enable ? 1 : 0), 1);
}

#=============================================================

=head2 getEmbeddedNTP

=head3 OUTPUT

    $NTP: if systemd NTP is enabled

=head3 DESCRIPTION

    This method returns the systemd NTP service is running

=cut

#=============================================================
sub getEmbeddedNTP {
    my ($self) = @_;

    my $object       = $self->dbus_timedate1_object;

    return $object->Get("org.freedesktop.timedate1", 'NTP') || "";
}




#=============================================================

=head2 setTime

=head3 INPUT

    $sec_since_epoch: Time in seconds since 1/1/1970

=head3 DESCRIPTION

    This method set the system time and sets the RTC also

=cut

#=============================================================
sub setTime {
    my ($self, $sec_since_epoch) = @_;

    die "second since epoch required" if !defined($sec_since_epoch);

    my $object = $self->dbus_timedate1_object;
    my $usec   = $sec_since_epoch* 1000000;

    $object->SetTime($usec, 0, 1);
}

#=============================================================

=head2 readConfiguration

=head3 OUTPUT

    hash reference containing:
        UTC  => HW clock is set as UTC
        ZONE => Time Zone set

=head3 DESCRIPTION

    This method returns the time zone system settings as hash
    reference

=cut

#=============================================================
sub readConfiguration {
    my $self = shift;

    my $prefs        = {};
    $prefs->{'ZONE'} = $self->getTimeZone();
    $prefs->{'UTC'}  = $self->getLocalRTC() ? 0 : 1;

    return $prefs;
}


#=============================================================

=head2 writeConfiguration

=head3 INPUT

    $info: hash containing:
           UTC  => HW clock is set as UTC
           ZONE => Time Zone

=head3 DESCRIPTION

    This method sets the passed Time Zone configuration.
    If installer_or_livecd attribute is set fix_system is
    passed to setLocalRTC

=cut

#=============================================================
sub writeConfiguration {
    my ($self, $info) = @_;

    die "UTC  field required" if !defined($info->{UTC});
    die "ZONE field required" if !defined($info->{ZONE});

    my $localRTC = $info->{UTC} ? 0 : 1;
    $self->setLocalRTC(
        $localRTC,
        $self->installer_or_livecd
    );

    $self->setTimeZone(
        $info->{ZONE}
    );
}


#left for back compatibility
sub _get_ntp_server_tree {
    my ($self, $zone) = @_;
    $zone = "-" if ! $zone;
    my $ns = $self->get_ntp_server($zone);
    return if !$ns;

    map {
        $ns->{$_} => (
             $self->get_ntp_server($_) ?
              $zone ?
                $self->loc->N($_) . "|" . $self->loc->N("All servers") :
                $self->loc->N("All servers") :
              $self->loc->N($zone) . "|" . $self->loc->N($_)
        ),
        $self->_get_ntp_server_tree($_)
    } keys %{$ns};
}

#=============================================================

=head2 ntpServers

=head3 OUTPUT

 HASHREF containing ntp_server => zone info

=head3 DESCRIPTION

 This method returns an hash ref containing pairs ntp-server, zone

=cut

#=============================================================
sub ntpServers {
    my ($self) = @_;
    # FIXME: missing parameter:
   +{$self->_get_ntp_server_tree()};
}


#=============================================================

=head2 ntpCurrentServer

=head3 INPUT

Input_Parameter: in_par_description

=head3 DESCRIPTION

Returns the current ntp server address read from configuration file

=cut

#=============================================================
sub ntpCurrentServer {
    my $self = shift;

    MDK::Common::Func::find { $_ ne '127.127.1.0' } map { MDK::Common::Func::if_(/^\s*server\s+(\S*)/, $1) } MDK::Common::File::cat_($self->ntp_configuration_file);
}

#=============================================================

=head2 currentNTPService

=head3 DESCRIPTION

    Returns the current ntp service

=cut

#=============================================================
sub currentNTPService {
    my $self = shift;

    my $ntpd = $self->ntp_program;

    return $ntpd;
}

#=============================================================

=head2 isNTPRunning

=head3 DESCRIPTION

   This method just returns if the given ntp server is running

=cut

#=============================================================
sub isNTPRunning {
    my $self = shift;

    my $ntpd      = $self->ntp_program;
    my $isRunning = $self->sh_services->is_service_running($ntpd);

    if (!$isRunning) {
        my @ntp_service = ("chronyd", "ntpd");
        foreach ( @ntp_service ) {
            $ntpd = $_;
            $isRunning = $self->sh_services->is_service_running($ntpd);
            last if $isRunning;
        }
        if ($isRunning) {
            $self->ntp_program($ntpd);
            if ($ntpd eq "chronyd") {
                $self->ntp_configuration_file("/etc/chrony.conf");
            }
            elsif ($ntpd eq "ntpd") {
                $self->ntp_configuration_file("/etc/ntp.conf");
            }
        }
        else {
            # fallback systemd-timesyncd

            if ($self->getEmbeddedNTP()) {
                $ntpd = "systemd-timesyncd";
                $self->ntp_program($ntpd);
                $self->ntp_configuration_file("/etc/systemd/timesyncd.conf");
                $isRunning = $self->sh_services->is_service_running($ntpd);
                # if it is not started you cannot set time with NTP true
                if (!$isRunning) {
                     Sys::Syslog::syslog(
                        'info|local1',
                        $self->loc->N("%s enabled but stopped - disabling it",
                            $ntpd
                        )
                    );
                    $self->setEmbeddedNTP(0);
                }
            }
        }
    }

    return $isRunning;
}

#=============================================================

=head2 setNTPConfiguration

=head3 INPUT

    $server: server address to be configured as NTP server

=head3 DESCRIPTION

    This method writes into NTP configuration file new server address
    settings (note that root rights are required) or it rises an
    exception

=cut

#=============================================================
sub setNTPConfiguration {
    my ($self, $server) = @_;

    my $f = $self->ntp_configuration_file;
    -f $f or return;

    die  $self->loc->N("user does not have the rights to change configuration file, skipped")
        if ($EUID != 0);

    my $pool_match = qr/\.pool\.ntp\.org$/;
    my @servers = $server =~ $pool_match  ? (map { "$_.$server" } 0 .. 2) : $server;

    if ($self->ntp_program eq "systemd-timesyncd") {
        my $added = 0;
        MDK::Common::File::substInFile {
            if (/^#?\s*NTP=\s+(\S*)/ && $1 ne '127.127.1.0') {
                $_ = $added ? $_ =~ $pool_match ? undef : "#NTP=$1\n" : join('NTP= ', @servers, "\n");
                $added = 1;
            }
        } $f;
        if ($self->ntp_program eq "ntpd") {
            my $ntp_prefix = $self->ntp_conf_dir;
                MDK::Common::File::output_p("$ntp_prefix/step-tickers", join('', map { "$_\n" } @servers));
        }
    }
    else {
        my $added = 0;
        my $servername_config_suffix = $self->servername_config_suffix ? $self->servername_config_suffix : " ";
        MDK::Common::File::substInFile {
            if (/^#?\s*server\s+(\S*)/ && $1 ne '127.127.1.0') {
                $_ = $added ? $_ =~ $pool_match ? undef : "#server $1\n" : join('', map { "server $_$servername_config_suffix\n" } @servers);
                $added = 1;
            }
        } $f;
        if ($self->ntp_program eq "ntpd") {
            my $ntp_prefix = $self->ntp_conf_dir;
                MDK::Common::File::output_p("$ntp_prefix/step-tickers", join('', map { "$_\n" } @servers));
        }
    }

}

#=============================================================

=head2 enableAndStartNTP

=head3 INPUT

    $server: server address to be configured

=head3 DESCRIPTION

    This method writes into NTP configuration file new server address
    settings

=cut

#=============================================================
sub enableAndStartNTP {
    my ($self, $server) = @_;

    my $ntpd = $self->ntp_program;

    ManaTools::Shared::disable_x_screensaver();
    if ($ntpd eq "systemd-timesyncd") {
        $self->setEmbeddedNTP(1);
    }
    else {
        if ($self->isNTPRunning()) {
            $self->sh_services->stopService($ntpd);
        }

        #if systemd-timesyncd is running has to be stopped and disabled
        $self->setEmbeddedNTP(0) if ($self->getEmbeddedNTP());

        # enable but do not start the service
        $self->sh_services->set_status($ntpd, 1, 1);
        if ($ntpd eq "chronyd") {
            $self->sh_services->startService($ntpd);
            $ENV{PATH} = "/usr/bin:/usr/sbin";
            # Wait up to 30s for sync
            system('/usr/bin/chronyc', 'waitsync', '30', '0.1');
        } else {
            $ENV{PATH} = "/usr/bin:/usr/sbin";
            system('/usr/sbin/ntpdate', $server) if $server;
            $self->sh_services->startService($ntpd);
        }
    }
    ManaTools::Shared::enable_x_screensaver();
}

#=============================================================

=head2 disableAndStopNTP

=head3 DESCRIPTION

    Disable and stop the ntp server

=cut

#=============================================================
sub disableAndStopNTP {
    my $self = shift;

    my $ntpd = $self->ntp_program;

    if ($ntpd eq "systemd-timesyncd") {
        $self->setEmbeddedNTP(0);
    }
    else {
        # also stop the service without dont_apply parameter
        $self->sh_services->set_status($ntpd, 0);
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;


1;


