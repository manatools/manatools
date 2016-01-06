use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;
use File::ShareDir::Install;

install_share dist => 'share';


WriteMakefile(
    NAME             => 'ManaTools',
    DISTNAME         => 'manatools',
    AUTHOR           => q{Angelo Naselli <anaselli@linux.it> - Matteo Pasotti <matteo.pasotti@gmail.com>},
    VERSION_FROM     => 'lib/ManaTools/Version.pm',
    ABSTRACT         => 'ManaTools is a generic launcher application that can run perl modules or external programs using Suse YUI abstarction.',
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
        "Moose::Autobox"     => 0,
        "MooseX::Getopt"     => 0,
        "MooseX::ClassAttribute" => 0,
        "Config::Auto"       => 0,
        "Config::Hosts"      => 0,
        "Config::Tiny"       => 0,
        # ManaTools::Shared::Locales
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
        "MDK::Common::Various" => 0,
        "MDK::Common::DataStructure" => 0,
        "Net::DBus"           => 0,
        "URPM"                => 0,
        "Glib"                => 0,
        "POSIX"               => 0,
        "utf8"               => 0,

        "English"             => 0,
        "Modern::Perl"        => 1.03,
        "autodie"             => 2.20,
    },
    EXE_FILES => [ qw( scripts/mpan
                       scripts/mana
                       scripts/manaadduser
                       scripts/manaclock
                       scripts/manadm
                       scripts/manahost
                       scripts/manalog
                       scripts/manaproxy
                       scripts/manaservice
                       scripts/manauser
                       scripts/manawall
                       modules/contribfinder.py
                       modules/rpmdragora/dragora-urpm-addmedia
                       modules/rpmdragora/dragora-urpm-sources.pl
                       modules/rpmdragora/dragoraUpdate
                       modules/rpmdragora/rpmdragora
                       ) ],
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'ManaTools-*' },
);

package MY;

sub postamble {
    my $inherited = File::ShareDir::Install::postamble(@_);

    my $newTargets = << 'MAKE_FRAG';

# Installation directories
localedir = $(PREFIX)/share/locale

PGOAL = manatools

# perl files to search translatable strings in
PL_FILES = $(shell find lib/ManaTools/ -type f -name "*.pm") \
	$(shell find scripts/ -type f -name "*") \
	modules/rpmdragora/dragoraUpdate \
	modules/rpmdragora/rpmdragora \
	modules/rpmdragora/dragora-urpm-addmedia \
	modules/rpmdragora/dragora-urpm-sources.pl

# its files (let's use them all at the moment)
ITS_FILES = -i extras/polkit/policy.its \
            -i extras/conf/mpan/categories.its \
            -i extras/conf/mpan/settings.its \
            -i extras/conf/manawall/manawall.its 

# polkit files
POL_IN_FILES = $(shell find extras/polkit/*.policy.in)
POL_FILES = $(POL_IN_FILES:%.policy.in=%.policy)

# manatools configuration files
CONF_IN_FILES =  $(shell find  extras/conf/mpan/ -type f -name "*.conf.in") \
	$(shell find  extras/conf/manawall/ -type f -name "*.conf.in")
CONF_FILES = $(CONF_IN_FILES:%.conf.in=%.conf)

# deskrop files
DESKTOP_IN_FILES = $(shell find extras/desktop/*.desktop.in)
DESKTOP_FILES = $(DESKTOP_IN_FILES:%.desktop.in=%.desktop)

POFILES = $(shell find po/ -name "*.po")
MOFILES = $(POFILES:%.po=%.mo)
LANGS = $(POFILES:po/%.po=%)
LINGUAS = $(LANGS)

GOALS = $(PGOAL).pot  $(MOFILES)

locales: $(GOALS)

install_locales: locales 
	# add translation in policy file
	for p in $(POL_IN_FILES); do \
		itstool -j $$p $(ITS_FILES) -o "$${p%.*}" `ls po/*.mo`; \
	done
	for p in $(CONF_IN_FILES); do \
		itstool -j $$p $(ITS_FILES) -o "$${p%.*}" `ls po/*.mo`; \
	done
	echo $(LINGUAS) > po/LINGUAS
	for p in $(DESKTOP_IN_FILES); do \
		msgfmt --desktop --template $$p -d po -o "$${p%.*}"; \
	done
	cd po && for l in $(LANGS); do \
		install -d $(localedir)/$$l/LC_MESSAGES; \
		install -m 644 $$l.mo $(localedir)/$$l/LC_MESSAGES/$(PGOAL).mo; \
	done

clean_locales:
	rm -f po/*~ po/*.[oas] po/*.mo po/manatools_perl.pot po/manapol.pot \
	po/manaconf.pot po/manadesktop.pot $(POL_FILES) $(CONF_FILES) $(DESKTOP_FILES)

%.mo: %.po
	msgfmt --check -o $@ $<

$(PGOAL).pot: manatools_perl.pot manapol.pot manaconf.pot manadesktop.pot
	msgcat po/manatools_perl.pot po/manapol.pot \
	po/manaconf.pot po/manadesktop.pot > po/$@

manatools_perl.pot: $(PL_FILES)  
	xgettext --from-code=UTF-8 --language=Perl -D ./ -o po/$@ \
		--msgid-bugs-address="https://bugs.mageia.org/" \
		--package-name=$(NAME) --package-version=$(VERSION) \
		--copyright-holder="Angelo Naselli - Matteo Pasotti" \
		--keyword=N --keyword=N_ --keyword=P \
		$(PL_FILES)

manapol.pot: $(POL_IN_FILES)
	itstool -o po/$@ $(ITS_FILES) $(POL_IN_FILES)

manaconf.pot: $(CONF_IN_FILES)
	itstool -o po/$@ $(ITS_FILES) $(CONF_IN_FILES)

manadesktop.pot: $(DESKTOP_IN_FILES)
	xgettext $(DESKTOP_IN_FILES) -o po/manadesktop.pot 
	
update_n_merge: $(PGOAL).pot merge

merge:
	@for n in $(POFILES); do \
		echo "Merging $$n"; \
		msgmerge "$$n" po/$(PGOAL).pot > "$$n"t; \
		mv -f "$$n"t "$$n"; \
	done

MAKE_FRAG

    return $inherited . $newTargets;
}
