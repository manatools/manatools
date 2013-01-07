# the domain name for gettext
PGOAL = rpmdrake

# perl files to search translatable strings in
PL_FILES = ../rpmdrake ../edit-urpm-sources.pl ../rpmdrake.pm ../gurpmi.addmedia ../Rpmdrake/*.pm ../MageiaUpdate

POFILES = $(wildcard *.po)
MOFILES = $(POFILES:%.po=%.mo)
LANGS = $(POFILES:%.po=%)

top_srcdir=..
PREFIX = $(RPM_BUILD_ROOT)/usr
DATADIR = $(PREFIX)/share
LOCALEDIR=$(DATADIR)/locale

all: $(MOFILES)

%.mo: %.po
	msgfmt -o $@ $<

update_n_merge: $(PGOAL).pot merge

merge:
	@for n in $(POFILES); do \
		echo "Merging $$n"; \
		msgmerge "$$n" $(PGOAL).pot > "$$n"t; \
		mv -f "$$n"t "$$n"; \
	done

$(PGOAL).pot: $(PL_FILES)
	intltool-update --gettext-package desktopstuff --pot
	perl_checker -q --generate-pot $(PGOAL)_tmp.pot $(PL_FILES)
	msgcat --use-first $(PGOAL)_tmp.pot desktopstuff.pot > $@
	rm -f desktopstuff.pot $(PGOAL)_tmp.pot 

install:
	for l in $(LANGS); do \
		install -d $(LOCALEDIR)/$$l/LC_MESSAGES; \
		install -m 644 $$l.mo $(LOCALEDIR)/$$l/LC_MESSAGES/$(PGOAL).mo; \
	done

clean:
	@rm -rf *.mo *.pof *.pog $(POFILES:%=%t) $(PL_CFILES) desktopstuff.pot $(PGOAL)_tmp.pot

check:
	for i in *.po; do msgfmt -c $$i -o /dev/null; done 

