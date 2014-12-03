use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;
use File::ShareDir::Install;

install_share dist => 'share';


WriteMakefile(
    NAME             => 'AdminPanel',
    DISTNAME         => 'adminpanel',
    AUTHOR           => q{Angelo Naselli <anaselli@linux.it> - Matteo Pasotti <matteo.pasotti@gmail.com>},
    VERSION_FROM     => 'lib/AdminPanel/MainDisplay.pm',
    ABSTRACT         => 'AdminPanel is a generic launcher application that can run perl modules or external programs using Suse YUI abstarction.',
    LICENSE          => 'GPL_2',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
	'File::ShareDir::Install' => 0,
    },
    PREREQ_PM => {
        "Moose"              => 0,
        "Config::Auto"       => 0,
        "Config::Hosts"      => 0,
        "Config::Tiny"       => 0,
        # AdminPanel::Shared::Locales
        "Locale::gettext"    => 0,
        "Text::Iconv"        => 0,
        "Text::Diff"         => 0,
        "Date::Simple"       => 0,
        "DateTime::TimeZone" => 0,
        "Time::Piece"        => 0,
        "Time::HiRes"        => 0,
        "File::HomeDir"      => 0,
        "File::ShareDir"     => 0,
        "File::Copy"         => 0,
        "File::Remove"       => 0,
        "File::Basename"     => 0,
        "Sys::Syslog"        => 0,
        "Data::Password::Meter"    => 0,
        "Digest::MD5"        => 0,
        "IO::All"            => 0,
        "XML::Simple"        => 0,
        #Mandriva
        "MDK::Common"         => 0,
        "MDK::Common::File"   => 0,
        "MDK::Common::Func"   => 0,
        "MDK::Common::System" => 0,
        "MDK::Common::String" => 0,
        "Net::DBus"           => 0,
        "URPM"                => 0,
        "Glib"                => 0,
        "POSIX"               => 0,
        "utf8"               => 0,

        "English"             => 0,
        "Modern::Perl"        => 1.03,
        "autodie"             => 2.20,
    },
    EXE_FILES => [ qw( scripts/mpan.pl
                       scripts/mana
                       scripts/manaadduser
                       scripts/manaclock
                       scripts/manadm
                       scripts/manahost
                       scripts/manalog
                       scripts/manaproxy
                       scripts/manaservice
                       scripts/manauser
                       modules/contribfinder.py
                       modules/rpmdragora/dragora-urpm-addmedia
                       modules/rpmdragora/dragora-urpm-sources.pl
                       modules/rpmdragora/dragoraUpdate
                       modules/rpmdragora/rpmdragora
                       ) ],
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'AdminPanel-*' },
);

package MY;
use File::ShareDir::Install 'postamble';
