PREFIX = /usr/local
DATADIR = $(PREFIX)/share

DESKTOP_IN := $(wildcard *.desktop.in)
DESKTOP = $(DESKTOP_IN:.desktop.in=.desktop)

all: $(DESKTOP)

clean:
	rm -f $(DESKTOP)

install: all
	install -d $(DATADIR)/applications
	install -m644 $(DESKTOP) $(DATADIR)/applications


%.desktop:   %.desktop.in
	intltool-merge --utf8 ../po $< $@ -d -u -c intltool-merge-cache

