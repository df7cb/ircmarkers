VERSION="ircmarkers"
INSTALL_PROGRAMM=install

all: overlap ircmarkers.1

overlap:
	gcc -O2 -Wall -o overlap overlap.c

ircmarkers.1: ircmarkers Makefile
	pod2man --release="$(VERSION)" --center="User Documentation" $< > $@

install: overlap ircmarkers.1
	$(INSTALL_PROGRAMM) -D ircmarkers $(DESTDIR)/usr/bin/ircmarkers
	for pm in IrcMarkers/{File,Map,Marker}.pm ; do \
		$(INSTALL_PROGRAMM) -D $$pm $(DESTDIR)/usr/share/perl5/$$pm ; \
	done
	$(INSTALL_PROGRAMM) -D -s overlap $(DESTDIR)/usr/lib/ircmarkers/overlap
	$(INSTALL_PROGRAMM) -D fixed_01.ttf $(DESTDIR)/usr/share/ircmarkers/fixed_01.ttf

clean:
	rm -f overlap ircmarkers.1 examples/dl_out.jpg
