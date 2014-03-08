use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

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
        #'ABC'              => 1.6,
        #'Foo::Bar::Module' => 5.0401,
        "Moose"             => 0,
        "Config::Hosts"     => 0,        
        # AdminPanel::Shared::Locales
        "Locale::gettext"   => 0,
        "Text::Iconv"       => 0,
	"Date::Simple"      => 0,
	"File::HomeDir"     => 0,
    },
    EXE_FILES => [ qw( scripts/adminMouse  
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
