test: square.jpg mercator.jpg sinusoidal.jpg

test%.map:
	for lat in $$(seq -90 $* 90); do for lon in $$(seq -180 $* 180); do echo $$lat $$lon \"$$lat $$lon\"; done; done > $@

square.jpg: test15.map ../ircmarkers ../IrcMarkers/*.pm
	perl -I .. ../ircmarkers test15.map 1920px-Equirectangular-projection.jpg $@

mercator.jpg: test10.map mercator.map ../ircmarkers ../IrcMarkers/*.pm
	perl -I .. ../ircmarkers mercator.map Normal_Mercator_map_85deg.jpg $@

sinusoidal.jpg: test10.map sinusoidal.map ../ircmarkers ../IrcMarkers/*.pm
	perl -I .. ../ircmarkers sinusoidal.map 1920px-Sinusoidal_Projection_11-5-30.jpg $@

clean:
	rm -f square.jpg mercator.jpg sinusoidal.jpg test*.map
