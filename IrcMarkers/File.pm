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

sub default_options {
	my $config = shift;
	my $item = shift;
	$item->{label_color} ||= $config->{label_color};
}

sub parse_options {
	my $config = shift;
	my $item = shift;
	die "huh?" unless ref $item;
	my $marker = shift; # defined for markers, undef for yxlabels
	my $opt = shift;
	while($opt) { # loop over options
		$opt =~ s/^\s+|#.*//g;
		last unless $opt;
		if($marker and $opt =~ s/^gpg[ :](?:0x)?([0-9a-fx]+)//i) { # ':' is deprecated old syntax
			my $k = uc $1;
			if($config->{gpg}->{$k} and $config->{gpg}->{$k} ne $marker) {
				warn "$config->{file}.$.: key $k already associated with $config->{gpg}->{$k}, overwriting with $marker\n";
			}
			$config->{gpg}->{$k} = $marker;
			$config->{gpg_not_found}->{$k} = $marker;
		# local options
		} elsif($opt =~ s/^dot_colou?r (\d+) (\d+) (\d+)//) {
			$item->{dot_color} = [$1, $2, $3];
		} elsif($opt =~ s/^dot_border (\d+) (\d+) (\d+)//) {
			$item->{dot_border} = [$1, $2, $3];
		} elsif($opt =~ s/^label_colou?r (\d+) (\d+) (\d+)//) {
			$item->{label_color} = [$1, $2, $3];
		} elsif($opt =~ s/^label_border (no(ne)?|off)//) {
			$item->{label_border} = -1;
		} elsif($opt =~ s/^label_border (\d+) (\d+) (\d+)//) {
			$item->{label_border} = [$1, $2, $3];
		} elsif($opt =~ s/^font (\S+)//) {
			die "font file not found: $1" unless -f $1;
			$item->{font} = $1;
		} elsif($opt =~ s/^ptsize (\d+)//) {
			$item->{ptsize} = $1;
		# error
		} else {
			warn "$config->{file}:$.: unknown option: $opt\n";
			last;
		}
	}
}

my $labelnr = 0;
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

		# global options
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
		# marker definitions
		} elsif(/^([\d.,-]+)\s+([\d.,-]+)\s+"([^"]+)"(.*)/) { # xplanet marker file format
			my ($lat, $lon, $marker, $opt) = ($1, $2, $3, $4);
			$lat =~ s/,/./;
			$lon =~ s/,/./;
			$config->{markers}->{$marker}->{lat} = $lat;
			$config->{markers}->{$marker}->{lon} = $lon;
			$config->default_options($config->{markers}->{$marker});
			$config->parse_options($config->{markers}->{$marker}, $marker, $opt);
		} elsif(/^"([^"]*)"(.*)/) { # marker with options
			my ($marker, $opt) = ($1, $2);
			$config->{markers}->{$marker} ||= {};
			$config->parse_options($config->{markers}->{$marker}, $marker, $opt);
		} elsif(/"([^"]*)" -> "([^"]+)"/) {
			$config->{links}->{$1}->{$2} = 1;
		} elsif(/^label (\d+) (\d+) "([^"]+)"(.*)/) {
			$config->{yxlabels}->[$labelnr] = { y => $1, x => $2, text => $3 };
			my $opt = $4;
			$config->default_options($config->{yxlabels}->[$labelnr]);
			$config->parse_options($config->{yxlabels}->[$labelnr], undef, $opt);
			$labelnr++;
		# everything else is a globally applied local option or a syntax error
		} else {
			$config->parse_options($config, undef, $_);
		}
	}
	close $fh;

	return $config;
}

sub get_gpg_links {
	my $config = shift;

	my $keys = join ' ', keys %{$config->{gpg}};
	#print "gpg --list-sigs --with-colon --fixed-list-mode --fast-list-mode $keys\n";
	open GPG, "gpg --list-sigs --with-colon --fixed-list-mode --fast-list-mode $keys |" or die "gpg: $!";
	my $key;
	while(<GPG>) {
		chomp;
		next if /^(rev|sub|tru|uat):/;
		#print "$_\n";
		if(/^pub::\d+:\d+:([0-9A-F]+):/) {
			$key = $1;
			warn "$key not related to any marker - did you use the long (16 char) keyid?\n" unless $config->{gpg}->{$key};
			delete $config->{gpg_not_found}->{$key};
		} elsif(/^sig:::\d+:([0-9A-F]+):/) {
			next unless $config->{gpg}->{$1}; # target not on map
			next if $key eq $1; # self-sig
			$config->{gpg_links}->{$1}->{$key} = 1;
		} else {
			warn "unknown gpg output: $_";
		}
	}

	foreach my $key (keys %{$config->{gpg_not_found}}) {
		warn "$config->{gpg_not_found}->{$key}: key $key was not found in gpg's keyring\n";
	}

	foreach $key (keys %{$config->{gpg}}) {
		my $marker = $config->{gpg}->{$key};
		unless($config->{markers}->{$marker}->{lat}) {
			warn "$marker was mentioned as key $key, but no coordinates defined\n";
		}
	}

	foreach my $key (keys %{$config->{gpg_links}}) {
		my $source = $config->{gpg}->{$key};
		next unless $config->{link_outside} or $config->{markers}->{$source}->{visible};
		foreach my $targetkey (keys %{$config->{gpg_links}->{$key}}) {
			my $target = $config->{gpg}->{$targetkey};
			next unless $config->{link_outside} or $config->{markers}->{$target}->{visible};
			my ($arrow, $color);
			# TODO: compute uni/bidi for markers instead of keys (for people with more than one key)
			if($config->{gpg_links}->{$targetkey}->{$key}) { # bidirectional link
				next if $targetkey gt $key; # process only once
				$color = $config->{link_color};
				$arrow = "<->";
			} else {
				$color = $config->{sign1_color} or next; # don't draw unidirectional links
				$arrow = "-->";
			}
			next unless $config->{markers}->{$source}->{lat};
			next unless $config->{markers}->{$target}->{lat};
			$config->link($source, $target, $color);
			print "$source $arrow $target\n" unless $config->{quiet};
		}
	}
}

1;
