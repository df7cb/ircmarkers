INSTALL_PROGRAMM=install

overlap:
	gcc -O2 -Wall -o overlap overlap.c

install: overlap
	$(INSTALL_PROGRAMM) -D ircmarkers $(DESTDIR)/usr/bin/ircmarkers
	for pm in IrcMarkers/{File,Map,Marker}.pm ; do \
		$(INSTALL_PROGRAMM) -D $$pm $(DESTDIR)/usr/share/perl5/$$pm ; \
	done
	$(INSTALL_PROGRAMM) -D -s overlap $(DESTDIR)/usr/lib/ircmarkers/overlap
	$(INSTALL_PROGRAMM) -D fixed_01.ttf $(DESTDIR)/usr/share/ircmarkers/fixed_01.ttf

clean:
	rm -f overlap examples/dl_out.jpg
