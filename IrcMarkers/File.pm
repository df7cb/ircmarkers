# Copyright (C) 2004 Christoph Berg <cb@df7cb.de>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# 2004-07-04 cb: added links and cleaned up code
# 2004-07-24 cb: added viewport

package IrcMarkers::File;

use strict;
use warnings;
use IO::File;

sub new {
	my $config = { # default values
		projection => 'mercator',
		west => -180,
		north => 90,
		east => 180,
		south => -90,
		center_lon => 0,
		dot_color => [255, 255, 255],
		dot_border => [0, 0, 0],
		label_color => [255, 255, 0],
		label_border => [0, 0, 0],
		link_outside => 0,
		link_color => [255, 128, 0],
		#sign1_color => [100, 100, 100],
		font => '/usr/share/ircmarkers/fixed_01.ttf',
		ptsize => 6,
		quiet => 0,
		overlap => '/usr/lib/ircmarkers/overlap',
		overlap_correction => 1,
	};
	bless $config;
}

sub parse_options {
	my $config = shift;
	my $marker = shift;
	my $opt = shift;
	while($opt) { # loop over options
		$opt =~ s/^\s+|#.*//g;
		last unless $opt;
		if($opt =~ s/gpg:([0-9a-fx]+)//i) {
			my $k = uc $1;
			if($config->{gpg}->{$k} and $config->{gpg}->{$k} ne $marker) {
				warn "$config->{file}.$.: key $k already associated with $config->{gpg}->{$k}, overwriting with $marker\n";
			}
			$config->{gpg}->{$k} = $marker;
			$config->{gpg_not_found}->{$k} = $marker;
		} else {
			warn "$config->{file}.$.: unknown option: $opt\n";
			last;
		}
	}
}

sub read {
	my $config = shift;
	my $file = shift || die "read: no filename";
	$config->{file} = $file;

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
		} elsif(/^view_(lon|west_east) (.+)\/(.+)/) {
			$config->{view_west} = $2;
			$config->{view_east} = $3;
		} elsif(/^view_(lat|south_north) (.+)\/(.+)/) {
			$config->{view_south} = $2;
			$config->{view_north} = $3;
		} elsif(/^view_width (.+)/) {
			$config->{view_width} = $1;
		} elsif(/^view_height (.+)/) {
			$config->{view_height} = $1;
		} elsif(/^projection (mercator|sinusoidal)/) {
			$config->{projection} = $1;
		} elsif(/^center_lon (.+)/) {
			$config->{center_lon} = $1;
		#} elsif(/^output_width (.+)/) {
		#	$config->{output_width} = $1;
		} elsif(/^dot_colou?r (\d+) (\d+) (\d+)$/) {
			$config->{dot_color} = [$1, $2, $3];
		} elsif(/^dot_border (\d+) (\d+) (\d+)$/) {
			$config->{dot_border} = [$1, $2, $3];
		} elsif(/^label_colou?r (\d+) (\d+) (\d+)$/) {
			$config->{label_color} = [$1, $2, $3];
		} elsif(/^label_border (no|off|none)$/) {
			delete $config->{label_border};
		} elsif(/^label_border (\d+) (\d+) (\d+)$/) {
			$config->{label_border} = [$1, $2, $3];
		} elsif(/^link_outside (on|yes)/) {
			$config->{link_outside} = 1;
		} elsif(/^link_outside (off|no)/) {
			$config->{link_outside} = 0;
		} elsif(/^(?:link|sign2)_colou?r (\d+) (\d+) (\d+)$/) {
			$config->{link_color} = [$1, $2, $3];
		} elsif(/^sign1_colou?r (no|off|none)$/) {
			delete $config->{sign1_color};
		} elsif(/^sign1_colou?r (\d+) (\d+) (\d+)$/) {
			$config->{sign1_color} = [$1, $2, $3];
		} elsif(/^font (.+)/) {
			$config->{font} = $1;
			die "font file not found: $config->{font}" unless -f $config->{font};
		} elsif(/^ptsize (.+)/) {
			$config->{ptsize} = $1;
		} elsif(/^overlap (.+)/) {
			$config->{overlap} = $1;
		} elsif(/^overlap_correction (on|yes)/) {
			$config->{overlap_correction} = 1;
		} elsif(/^overlap_correction (off|no)/) {
			$config->{overlap_correction} = 0;
		} elsif(/^quiet (on|yes)/) {
			$config->{quiet} = 1;
		} elsif(/^quiet (off|no)/) {
			$config->{quiet} = 0;
		} elsif(/^([\d.,-]+)\s+([\d.,-]+)\s+"([^"]+)"(.*)/) { # xplanet marker file format
			my ($lat, $lon, $marker, $opt) = ($1, $2, $3, $4);
			$lat =~ s/,/./;
			$lon =~ s/,/./;
			$config->{markers}->{$marker}->{lat} = $lat;
			$config->{markers}->{$marker}->{lon} = $lon;
			$config->parse_options($marker, $opt);
		} elsif(/^"([^"]*)"(.*)/) { # marker with options
			my ($marker, $opt) = ($1, $2);
			$config->parse_options($marker, $opt);
		} elsif(/"([^"]*)" -> "([^"]+)"/) {
			$config->{links}->{$1}->{$2} = 1;
		} else {
			warn "$file.$.: unknown format: $_\n";
		}
	}
	close $fh;

	return $config;
}

1;
