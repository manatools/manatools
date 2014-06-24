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

=head2 get_timezone_prefix

=head3 OUTPUT

timezone_prefix: directory in which time zone files are

=head3 DESCRIPTION

Return the timezone directory (defualt: /usr/share/zoneinfo)

=cut

#=============================================================

sub get_timezone_prefix() {
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

no Moose;
__PACKAGE__->meta->make_immutable;


1;

########################

=comment




# TODO fix
our $ntp = "ntp";
my $servername_config_suffix = "";
# unless (-f $::prefix . "/etc/" . $ntp . ".conf") {
#     $ntp = "chrony";
#     $servername_config_suffix = " iburst";
# }

sub ntp_server() {
    find { $_ ne '127.127.1.0' } map { if_(/^\s*server\s+(\S*)/, $1) } cat_($::prefix . "/etc/" . $ntp . ".conf");
}

sub set_ntp_server {
    my ($server) = @_;
    my $f = $::prefix . "/etc/" . $ntp . ".conf";
    -f $f or return;

    my $pool_match = qr/\.pool\.ntp\.org$/;
    my @servers = $server =~ $pool_match  ? (map { "$_.$server" } 0 .. 2) : $server;

    my $added = 0;
    substInFile {
        if (/^#?\s*server\s+(\S*)/ && $1 ne '127.127.1.0') {
            $_ = $added ? $_ =~ $pool_match ? undef : "#server $1\n" : join('', map { "server $_$servername_config_suffix\n" } @servers);
            $added = 1;
        }
    } $f;
    if ($ntp eq "ntp") {
	output_p("$::prefix/etc/ntp/step-tickers", join('', map { "$_\n" } @servers));
    }

    require services;
    services::set_status($ntp . 'd', to_bool($server), $::isInstall);
}

sub write {
    my ($t) = @_;

    set_ntp_server($t->{ntp});

    my $tz_prefix = get_timezone_prefix();
    eval { cp_af($tz_prefix . '/' . $t->{timezone}, "$::prefix/etc/localtime") };
    $@ and log::l("installing /etc/localtime failed");
    setVarsInSh("$::prefix/etc/sysconfig/clock", {
	ZONE => $t->{timezone},
	UTC  => bool2text($t->{UTC}),
	ARC  => "false",
    });

    my $adjtime_file = $::prefix . '/etc/adjtime';
    my @adjtime = cat_($adjtime_file);
    @adjtime or @adjtime = ("0.0 0 0.0\n", "0\n");
    $adjtime[2] = $t->{UTC} ? "UTC\n" : "LOCAL\n";
    output_p($adjtime_file, @adjtime);
}

sub reload_sys_clock {
    my ($t) = @_;
    require run_program;
    any::disable_x_screensaver();
    run_program::run('hwclock', '--hctosys', ($t->{UTC} ? '--utc' : '--localtime'));
    any::enable_x_screensaver();
}

#- best guesses for a given country
my %c2t = (
'AM' => 'Asia/Yerevan',
'AR' => 'America/Buenos_Aires',
'AT' => 'Europe/Vienna',
'AU' => 'Australia/Sydney',
'BA' => 'Europe/Sarajevo',
'BE' => 'Europe/Brussels',
'BG' => 'Europe/Sofia',
'BR' => 'America/Sao_Paulo', #- most brazilians live on this time zone
'BY' => 'Europe/Minsk',
'CA' => 'Canada/Eastern',
'CH' => 'Europe/Zurich',
'CN' => 'Asia/Beijing',
'CZ' => 'Europe/Prague',
'DE' => 'Europe/Berlin',
'DK' => 'Europe/Copenhagen',
'EE' => 'Europe/Tallinn',
'ES' => 'Europe/Madrid',
'FI' => 'Europe/Helsinki',
'FR' => 'Europe/Paris',
'GB' => 'Europe/London',
'GE' => 'Asia/Yerevan',
'GL' => 'Arctic/Longyearbyen',
'GR' => 'Europe/Athens',
'HR' => 'Europe/Zagreb',
'HU' => 'Europe/Budapest',
'ID' => 'Asia/Jakarta',
'IE' => 'Europe/Dublin',
'IL' => 'Asia/Tel_Aviv',
'IN' => 'Asia/Kolkata',
'IR' => 'Asia/Tehran',
'IS' => 'Atlantic/Reykjavik',
'IT' => 'Europe/Rome',
'JP' => 'Asia/Tokyo',
'KR' => 'Asia/Seoul',
'LT' => 'Europe/Vilnius',
'LV' => 'Europe/Riga',
'MK' => 'Europe/Skopje',
'MT' => 'Europe/Malta',
'MX' => 'America/Mexico_City',
'MY' => 'Asia/Kuala_Lumpur',
'NL' => 'Europe/Amsterdam',
'NO' => 'Europe/Oslo',
'NZ' => 'Pacific/Auckland',
'PL' => 'Europe/Warsaw',
'PT' => 'Europe/Lisbon',
'RO' => 'Europe/Bucharest',
'RU' => 'Europe/Moscow',
'SE' => 'Europe/Stockholm',
'SI' => 'Europe/Ljubljana',
'SK' => 'Europe/Bratislava',
'TH' => 'Asia/Bangkok',
'TJ' => 'Asia/Dushanbe',
'TR' => 'Europe/Istanbul',
'TW' => 'Asia/Taipei',
'UA' => 'Europe/Kiev',
'US' => 'America/New_York',
'UZ' => 'Asia/Tashkent',
'VN' => 'Asia/Saigon',
'YU' => 'Europe/Belgrade',
'ZA' => 'Africa/Johannesburg',
);

sub fuzzyChoice { 
    my ($b, $count) = bestMatchSentence($_[0], keys %c2t);
    $count ? $b : '';
}
sub bestTimezone { $c2t{fuzzyChoice($_[0])} || 'GMT' }

our %ntp_servers;

sub get_ntp_server_tree {
    my ($zone) = @_;
    map {
        $ntp_servers{$zone}{$_} => (
            exists $ntp_servers{$_} ?
              $zone ?
                translate($_) . "|" . N("All servers") :
                N("All servers") :
              translate($zone) . "|" . translate($_)
        ),
        get_ntp_server_tree($_);
    } keys %{$ntp_servers{$zone}};
}

sub ntp_servers() {
    # FIXME: missing parameter:
    +{ get_ntp_server_tree() };
}

sub dump_ntp_zone {
    my ($zone) = @_;
    map { if_(/\[\d+\](.+) -- (.+\.ntp\.org)/, $1 => $2) } `lynx -dump http://www.pool.ntp.org/zone/$zone`;
}
sub print_ntp_zone {
    my ($zone, $name) = @_;
    # FIXME: missing parameter:
    my %servers = dump_ntp_zone($zone);
    print qq(\$ntp_servers{"$name"} = {\n);
    print join('', map { qq(    N_("$_") => "$servers{$_}",\n) } sort(keys %servers));
    print "};\n";
    \%servers;
}
sub print_ntp_servers() {
    print_ntp_zone();
    my $servers = print_ntp_zone('@', "Global");
    foreach my $name (sort(keys %$servers)) {
        my ($zone) = $servers->{$name} =~ /^(.*?)\./;
        print_ntp_zone($zone, $name);
    }
}

# perl -Mtimezone -e 'timezone::print_ntp_servers()'
$ntp_servers{""} = {
    N_("Global") => "pool.ntp.org",
};
$ntp_servers{Global} = {
    N_("Africa") => "africa.pool.ntp.org",
    N_("Asia") => "asia.pool.ntp.org",
    N_("Europe") => "europe.pool.ntp.org",
    N_("North America") => "north-america.pool.ntp.org",
    N_("Oceania") => "oceania.pool.ntp.org",
    N_("South America") => "south-america.pool.ntp.org",
};
$ntp_servers{Africa} = {
    N_("South Africa") => "za.pool.ntp.org",
    N_("Tanzania") => "tz.pool.ntp.org",
};
$ntp_servers{Asia} = {
    N_("Bangladesh") => "bd.pool.ntp.org",
    N_("China") => "cn.pool.ntp.org",
    N_("Hong Kong") => "hk.pool.ntp.org",
    N_("India") => "in.pool.ntp.org",
    N_("Indonesia") => "id.pool.ntp.org",
    N_("Iran") => "ir.pool.ntp.org",
    N_("Israel") => "il.pool.ntp.org",
    N_("Japan") => "jp.pool.ntp.org",
    N_("Korea") => "kr.pool.ntp.org",
    N_("Malaysia") => "my.pool.ntp.org",
    N_("Philippines") => "ph.pool.ntp.org",
    N_("Singapore") => "sg.pool.ntp.org",
    N_("Taiwan") => "tw.pool.ntp.org",
    N_("Thailand") => "th.pool.ntp.org",
    N_("Turkey") => "tr.pool.ntp.org",
    N_("United Arab Emirates") => "ae.pool.ntp.org",
};
$ntp_servers{Europe} = {
    N_("Austria") => "at.pool.ntp.org",
    N_("Belarus") => "by.pool.ntp.org",
    N_("Belgium") => "be.pool.ntp.org",
    N_("Bulgaria") => "bg.pool.ntp.org",
    N_("Czech Republic") => "cz.pool.ntp.org",
    N_("Denmark") => "dk.pool.ntp.org",
    N_("Estonia") => "ee.pool.ntp.org",
    N_("Finland") => "fi.pool.ntp.org",
    N_("France") => "fr.pool.ntp.org",
    N_("Germany") => "de.pool.ntp.org",
    N_("Greece") => "gr.pool.ntp.org",
    N_("Hungary") => "hu.pool.ntp.org",
    N_("Ireland") => "ie.pool.ntp.org",
    N_("Italy") => "it.pool.ntp.org",
    N_("Lithuania") => "lt.pool.ntp.org",
    N_("Luxembourg") => "lu.pool.ntp.org",
    N_("Netherlands") => "nl.pool.ntp.org",
    N_("Norway") => "no.pool.ntp.org",
    N_("Poland") => "pl.pool.ntp.org",
    N_("Portugal") => "pt.pool.ntp.org",
    N_("Romania") => "ro.pool.ntp.org",
    N_("Russian Federation") => "ru.pool.ntp.org",
    N_("Slovakia") => "sk.pool.ntp.org",
    N_("Slovenia") => "si.pool.ntp.org",
    N_("Spain") => "es.pool.ntp.org",
    N_("Sweden") => "se.pool.ntp.org",
    N_("Switzerland") => "ch.pool.ntp.org",
    N_("Ukraine") => "ua.pool.ntp.org",
    N_("United Kingdom") => "uk.pool.ntp.org",
    N_("Yugoslavia") => "yu.pool.ntp.org",
};
$ntp_servers{"North America"} = {
    N_("Canada") => "ca.pool.ntp.org",
    N_("Guatemala") => "gt.pool.ntp.org",
    N_("Mexico") => "mx.pool.ntp.org",
    N_("United States") => "us.pool.ntp.org",
};
$ntp_servers{Oceania} = {
    N_("Australia") => "au.pool.ntp.org",
    N_("New Zealand") => "nz.pool.ntp.org",
};
$ntp_servers{"South America"} = {
    N_("Argentina") => "ar.pool.ntp.org",
    N_("Brazil") => "br.pool.ntp.org",
    N_("Chile") => "cl.pool.ntp.org",
};

1;
=cut
