# vim: set et ts=4 sw=4:
package AdminPanel::Shared::TimeZone;

#============================================================= -*-perl-*-

=head1 NAME

AdminPanel::Shared::TimeZone - module to manage TimeZone settings

=head1 SYNOPSIS

    my $tz = AdminPanel::Shared::TimeZone->new();


=head1 DESCRIPTION

This module allows to manage time zone settings.

=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc AdminPanel::Shared::TimeZone


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
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=head1 METHODS

=cut


use diagnostics;
use strict;

use Moose;

use DateTime::TimeZone;
use Config::Auto;
use AdminPanel::Shared::Locales;
use AdminPanel::Shared::Services;

use MDK::Common::File;
use MDK::Common::Func;

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

=head3 clock_configuration_file

    optional parameter to set the clock system configuration file,
    default value is /etc/sysconfig/clock

=cut

#=============================================================

has 'clock_configuration_file' => (
    is => 'rw',
    isa => 'Str',
    default => "/etc/sysconfig/clock",
);

#=============================================================

=head2 new - optional parameters

=head3 ntp_configuration_file

    optional parameter to set the ntp server configuration file,
    default value is /etc/[chrony|ntp].conf

=cut

#=============================================================

has 'ntp_configuration_file' => (
    is  => 'rw',
    isa => 'Str',
    builder => '_ntp_configuration_file_init',
);

sub _ntp_configuration_file_init {
    my $self = shift;

    if (-f  "/etc/chrony.conf") {
        return "/etc/chrony.conf";
    }
    return "/etc/ntp.conf";
}

#=============================================================

=head2 new - optional parameters

=head3 ntp_program

    optional parameter to set the ntp program that runs into the
    system, default value is [chrony|ntp]

=cut

#=============================================================

has 'ntp_program' => (
    is  => 'rw',
    isa => 'Str',
    builder => '_ntp_program_init',
);

sub _ntp_program_init {
    my $self = shift;

    if (-f  "/etc/chrony.conf") {
        return "chrony";
    }
    return "ntp";
}

#=== globals ===

has 'servername_config_suffix' => (
    is  => 'ro',
    isa => 'Str',
    lazy     => 1,
    builder  => '_servername_config_suffix_init',
);

sub _servername_config_suffix_init {
    my $self = shift;

    return " iburst" if ($self->ntp_program eq "chrony");

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
    $self->loc(AdminPanel::Shared::Locales->new(domain_name => 'libDrakX') );
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

=head2 readConfiguration

=head3 OUTPUT

    hash containing:
        UTC  => HW clock is set as UTC
        ZONE => Time Zone set

=head3 DESCRIPTION

    This method returns the time zone system settings as hash
    reference

=cut

#=============================================================
sub readConfiguration {
    my $self = shift;

    my $prefs  = {};

    if (-e $self->clock_configuration_file) {
        $prefs  = Config::Auto::parse($self->clock_configuration_file);
    }

    return $prefs;
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
    } keys $ns;
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

=head2 isNTPRunning

=head3 DESCRIPTION

   This method just returns if the given ntp server is running

=cut

#=============================================================

sub isNTPRunning {
    my$self = shift;

    # TODO is that valid for any ntp program? adding ntp_service_name parameter
    my $ntpd = $self->ntp_program . 'd';

    return !AdminPanel::Shared::Services::is_service_running($ntpd);
}

no Moose;
__PACKAGE__->meta->make_immutable;


1;


