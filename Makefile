VERSION=ircmarkers
INSTALL_PROGRAMM=install

all: overlap ircmarkers.1

overlap:
	gcc -O2 -Wall -o overlap overlap.c

ircmarkers.1: ircmarkers
	pod2man --release="$(VERSION)" --center="User Documentation" $< > $@

install: overlap ircmarkers.1
	$(INSTALL_PROGRAMM) -D ircmarkers $(DESTDIR)/usr/bin/ircmarkers
	for pm in IrcMarkers/{File,Map,Marker}.pm ; do \
		$(INSTALL_PROGRAMM) -D -m 664 $$pm $(DESTDIR)/usr/share/perl5/$$pm ; \
	done
	$(INSTALL_PROGRAMM) -D -s overlap $(DESTDIR)/usr/lib/ircmarkers/overlap
	$(INSTALL_PROGRAMM) -D -m 664 fixed_01.ttf $(DESTDIR)/usr/share/ircmarkers/fixed_01.ttf
	$(INSTALL_PROGRAMM) -D -m 664 ircmarkers.1 $(DESTDIR)/usr/share/man/man1/ircmarkers.1

clean:
	rm -f overlap ircmarkers.1 examples/dl_out.jpg
