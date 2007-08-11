NAME=ircmarkers
INSTALL_PROGRAMM=install
#DEBUG=-DDEBUG
VERSION=$(shell dpkg-parsechangelog 2>&1 | perl -ne 'print $$1 if /^Version: ([^-]*)/')
TGZ=$(NAME)_$(VERSION).orig.tar.gz
TGZ_DIR=$(NAME)-$(VERSION)

all: overlap ircmarkers.1

overlap: overlap.c
	gcc -g -O2 -Wall $(DEBUG) -o overlap overlap.c

ircmarkers.1: ircmarkers
	pod2man --release="$(NAME)" --center="User Documentation" $< > $@

ircmarkers.man: ircmarkers.1
	nroff -man $< > $@

ircmarkers.html: ircmarkers
	pod2html --title="$<" $< > $@

install: overlap ircmarkers.1
	$(INSTALL_PROGRAMM) -D ircmarkers $(DESTDIR)/usr/bin/ircmarkers
	$(INSTALL_PROGRAMM) -D -m 664 IrcMarkers/File.pm $(DESTDIR)/usr/share/perl5/IrcMarkers/File.pm
	$(INSTALL_PROGRAMM) -D -m 664 IrcMarkers/Map.pm  $(DESTDIR)/usr/share/perl5/IrcMarkers/Map.pm
	$(INSTALL_PROGRAMM) -D overlap $(DESTDIR)/usr/lib/ircmarkers/overlap
	$(INSTALL_PROGRAMM) -D -m 664 fixed_01.ttf $(DESTDIR)/usr/share/ircmarkers/fixed_01.ttf
	$(INSTALL_PROGRAMM) -D -m 664 ircmarkers.1 $(DESTDIR)/usr/share/man/man1/ircmarkers.1

tags:
	ctags ircmarkers IrcMarkers/*.pm overlap.c

clean:
	rm -f overlap ircmarkers.1 ircmarkers.man ircmarkers.html tags pod2htm* example.jpg

dist:
	[ ! -f ../$(TGZ) ]
	mkdir ../$(TGZ_DIR)
	cp -a . ../$(TGZ_DIR)
	rm -rf ../$(TGZ_DIR)/debian
	find ../$(TGZ_DIR) -name .svn | xargs rm -rf
	cd .. && tar cvz -f $(TGZ) $(TGZ_DIR)
	rm -rf ../$(TGZ_DIR)

.PHONY: all install tags clean dist
