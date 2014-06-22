use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;
use File::ShareDir::Install;

install_share dist => 'share'; 


WriteMakefile(
    NAME             => 'AdminPanel',
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
    },
    PREREQ_PM => {
        "Moose"              => 0,
        "Config::Auto"       => 0,
        "Config::Hosts"      => 0,
        # AdminPanel::Shared::Locales
        "Locale::gettext"    => 0,
        "Text::Iconv"        => 0,
        "Date::Simple"       => 0,
        "DateTime::TimeZone" => 0,
        "Time::Piece"        => 0,
        "File::HomeDir"      => 0,
        "File::ShareDir"     => 0,
        "File::Copy"         => 0,
        "File::Remove"       => 0,
        "File::Basename"     => 0,
        "Sys::Syslog"        => 0,
        "Data::Password::Meter"    => 0,
        "Digest::MD5"        => 0,
        "IO::All"            => 0,
        "Modern::Perl"       => 1.03,
        "autodie"            => 2.20,
    },
    EXE_FILES => [ qw( scripts/adminClock
                       scripts/adminService
                       scripts/adminUser
                       scripts/apanel.pl
                       scripts/hostmanager
                       scripts/logviewer
                       scripts/mgaAddUser
                       ) ],
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'AdminPanel-*' },
);

package MY;
use File::ShareDir::Install 'postamble';
