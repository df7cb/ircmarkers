# (c) 2004 Christoph Berg <cb@df7cb.de>

package IrcMarkers::File;

use strict;
use warnings;
use IO::File;

sub new {
	my $config = {
		projection => 'mercator',
		west => -180,
		north => 90,
		east => 180,
		south => -90,
		center_lon => 0,
		dot_color => [255, 255, 255],
		label_color => [255, 255, 0],
		link_color => [255, 128, 0],
		font => './fixed_01.ttf',
		ptsize => 6,
		overlap_correction => 1,
	};
	bless $config;
}

sub read {
	my $config = shift;
	my $file = shift || die "read: no filename";

	my $fh = IO::File->new($file) or die "$file: $!";
	while (<$fh>) {
		chomp;
		next if /^\s*$/;
		if(/^#include [<"](.+)[">]/) { # include next config file
			$config->read($1);
			next;
		}
		last if /^#eof/; # EOF marker
		next if /^#/;

		if(/^read (.+)/) {
			$config->{read} = $1;
		} elsif(/^write (.+)/) {
			$config->{write} = $1;
		} elsif(/^(lon|west_east) (.+)\/(.+)/) {
			$config->{west} = $2;
			$config->{east} = $3;
		} elsif(/^(lat|south_north) (.+)\/(.+)/) {
			$config->{south} = $2;
			$config->{north} = $3;
		} elsif(/^projection (.+)/) {
			$config->{projection} = $1;
		} elsif(/^center_lon (.+)/) {
			$config->{center_lon} = $1;
		} elsif(/^dot_colou?r (\d+) (\d+) (\d+)/) {
			$config->{dot_color} = [$1, $2, $3];
		} elsif(/^label_colou?r (\d+) (\d+) (\d+)/) {
			$config->{label_color} = [$1, $2, $3];
		} elsif(/^link_colou?r (\d+) (\d+) (\d+)/) {
			$config->{link_color} = [$1, $2, $3];
		} elsif(/^font (.+)/) {
			$config->{font} = $1;
		} elsif(/^ptsize (.+)/) {
			$config->{ptsize} = $1;
		} elsif(/^overlap_correction (.+)/) {
			$config->{overlap_correction} = $1;
		} elsif(/^([\d.,]+)\s+([\d.,]+)\s+"([^"]*)"/) { # xplanet marker file format
			my ($lat, $lon, $text) = ($1, $2, $3);
			$lat =~ s/,/./;
			$lon =~ s/,/./;
			$config->{markers}->{$text}->{lat} = $lat;
			$config->{markers}->{$text}->{lon} = $lon;
		} elsif(/"([^"]*)" -> "([^"]*)"/) {
			$config->{links}->{$1}->{$2} = 1;
		} else {
			warn "$file.$.: unknown format\n";
		}
	}
	close $fh;

	return $config;
}

1;
