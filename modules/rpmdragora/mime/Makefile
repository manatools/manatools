PREFIX = /usr/local
DATADIR = $(PREFIX)/share
MIMEDIR   = $(DATADIR)/mime/packages/
MIMELNKDIR= $(DATADIR)/mimelnk/application/
APPDIR    = $(DATADIR)/applications/

DESKTOP_IN := $(wildcard *.desktop.in)
DESKTOP = $(DESKTOP_IN:.desktop.in=.desktop)

all: $(DESKTOP)

clean:
	rm -f $(DESKTOP)

install: all
	install -d $(MIMEDIR) $(MIMELNKDIR) $(APPDIR)
	install -m644 gurpmi.addmedia.desktop $(APPDIR)/
	install -m644 x-urpmi-media.desktop $(MIMELNKDIR)/
	install -m644 urpmi-media.xml $(MIMEDIR)/

%.desktop:   %.desktop.in
	intltool-merge --utf8 ../po $< $@ -d -u -c intltool-merge-cache

