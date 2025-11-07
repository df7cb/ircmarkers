NAME = ircmarkers
CFLAGS ?= -Wall -g -O2
INSTALL ?= install

all: overlap ircmarkers.1

overlap: overlap.c

ircmarkers.1: ircmarkers
	pod2man --release="$(NAME)" --center="User Documentation" $< > $@

ircmarkers.man: ircmarkers.1
	nroff -man $< > $@

ircmarkers.html: ircmarkers
	pod2html --title="$<" $< > $@

install: overlap ircmarkers.1
	$(INSTALL) -D ircmarkers $(DESTDIR)/usr/bin/ircmarkers
	$(INSTALL) -D -m 664 IrcMarkers/File.pm $(DESTDIR)/usr/share/perl5/IrcMarkers/File.pm
	$(INSTALL) -D -m 664 IrcMarkers/Map.pm  $(DESTDIR)/usr/share/perl5/IrcMarkers/Map.pm
	$(INSTALL) -D overlap $(DESTDIR)/usr/lib/ircmarkers/overlap
	$(INSTALL) -D -m 664 fixed_01.ttf $(DESTDIR)/usr/share/ircmarkers/fixed_01.ttf
	$(INSTALL) -D -m 664 ircmarkers.1 $(DESTDIR)/usr/share/man/man1/ircmarkers.1

tags:
	ctags ircmarkers IrcMarkers/*.pm overlap.c

clean:
	rm -f overlap ircmarkers.1 ircmarkers.man ircmarkers.html tags pod2htm* example.jpg

.PHONY: all install tags clean
