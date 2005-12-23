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

sub despace {
	my $s = shift;
	$s =~ s/\s+/ /g;
	return $s;
}

sub new {
	my $config = { # default values
		projection => 'mercator',
		west => -180,
		north => 90,
		east => 180,
		south => -90,
		#center_lon => 0,
		dot_color => [255, 255, 255],
		dot_border => [0, 0, 0],
		dot_size => 2,
		dot_shape => 'dot',
		label_color => [255, 255, 0],
		label_border => [0, 0, 0],
		link_outside => 0,
		link_color => [255, 128, 0],
		#sign1_color => [100, 100, 100],
		link_style => 'solid',
		font => '/usr/share/ircmarkers/fixed_01.ttf',
		ptsize => 6,
		quiet => 0,
		overlap => '/usr/lib/ircmarkers/overlap',
		overlap_correction => 1,
		help_convert_crop => 0,
	};
	bless $config;
}

sub default_options { # this will be obsolete if all items are deOOified
	my $config = shift;
	my $item = shift;
	$item->{dot_color} ||= $config->{dot_color};
	$item->{dot_border} ||= $config->{dot_border};
	$item->{dot_size} ||= $config->{dot_size};
	$item->{dot_shape} ||= $config->{dot_shape};
	$item->{label_color} ||= $config->{label_color};
	$item->{label_border} ||= $config->{label_border};
	$item->{font} ||= $config->{font};
	$item->{ptsize} ||= $config->{ptsize};
	$item->{link_color} ||= $config->{link_color}; # only for links
}

sub parser_warn {
	my $config = shift;
	my $text = shift;
	my $loc = $config->{file} ? "$config->{file}:$." : "-o";
	warn "$loc: $text\n";
}

sub parse_options {
	my $config = shift;
	my $item = shift;
	die "huh?" unless ref $item;
	my $markernr = shift; # defined for markers, undef for yxlabels/links
	my $opt = shift;
	while($opt ne '') { # loop over options
		$opt =~ s/^\s+|#.*//g;
		last unless $opt ne '';
		if(defined $markernr and $opt =~ s/^gpg[ :](?:0x)?([0-9a-f]{16})//i) { # ':' is deprecated old syntax
			my $k = uc $1;
			if($config->{gpg}->{$k} and $config->{gpg}->{$k} ne $markernr) {
				warn "$config->{file}.$.: key $k already associated with $config->{gpg}->{$k}, overwriting with $markernr\n";
			}
			$config->{gpg}->{$k} = $markernr;
			$config->{gpg_not_found}->{$k} = $markernr;
		# local options
		} elsif($opt =~ s/^dot_colou?r (\d+) (\d+) (\d+)//) {
			$item->{dot_color} = [$1, $2, $3];
		} elsif($opt =~ s/^dot_border (no(ne)?|off)//) {
			$item->{dot_border} = -1;
		} elsif($opt =~ s/^dot_border (\d+) (\d+) (\d+)//) {
			$item->{dot_border} = [$1, $2, $3];
		} elsif($opt =~ s/^dot_size (\d+)//) {
			$item->{dot_size} = $1;
		} elsif($opt =~ s/^dot_shape (dot|circle)//) {
			$item->{dot_shape} = $1;
		} elsif($opt =~ s/^label_colou?r (\d+) (\d+) (\d+)//) {
			$item->{label_color} = [$1, $2, $3];
		} elsif($opt =~ s/^label_border (no(ne)?|off)//) {
			$item->{label_border} = -1;
		} elsif($opt =~ s/^label_border (\d+) (\d+) (\d+)//) {
			$item->{label_border} = [$1, $2, $3];
		} elsif($opt =~ s/^font (\S+)//) {
			die "font file not found: $1" unless -f $1;
			$item->{font} = $1;
			$item->{font} =~ s!^~/!$ENV{HOME}/!;
		} elsif($opt =~ s/^(?:font|pt)size (\d+)//) {
			$item->{ptsize} = $1;
		} elsif($opt =~ s/^href (\S+)//) {
			$item->{href} = $1;
		} elsif($opt =~ s/^(?:link|sign2)_colou?r (\d+) (\d+) (\d+)//) {
			$item->{link_color} = [$1, $2, $3];
		} elsif($opt =~ s/^(?:link|sign2)_colou?r (no(ne?)|off)//) {
			delete $item->{link_color};
		# error
		} else {
			$config->parser_warn("unknown option: $opt");
			last;
		}
	}
}

my $markernr = 0;
my $labelnr = 0;
my $linknr = 0;
sub parse {
	my $config = shift;
	$_ = shift;

	return if /^\s*$/;
	if(/^#include [<"](.+)[">]/) { # include next config file
		$config->read($1);
		return;
	}
	return if /^\s*#/;

	s/^([^"]+)/despace($1)/e; # compress space outside of quotes
	s/([^"]+)$/despace($1)/e;

	# global options
	if(/^read (.+)/) {
		$config->{read} = $1;
		$config->{read} =~ s!^~/!$ENV{HOME}/!;
	} elsif(/^write (.+)/) {
		$config->{write} = $1;
		$config->{write} =~ s!^~/!$ENV{HOME}/!;
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
	} elsif(/^sign1_colou?r (no(ne)?|off)$/) {
		delete $config->{sign1_color};
	} elsif(/^sign1_colou?r (\d+) (\d+) (\d+)$/) {
		$config->{sign1_color} = [$1, $2, $3];
	} elsif(/^imagemap (\S+)/) {
		$config->{imagemap} = $1;
	} elsif(/^overlap (.+)/) {
		$config->{overlap} = $1;
	} elsif(/^overlap_correction (on|yes)/) {
		$config->{overlap_correction} = 1;
	} elsif(/^overlap_correction (off|no)/) {
		$config->{overlap_correction} = 0;
	} elsif(/^recv(?:-keys)/) {
		$config->{recv} = 1;
	} elsif(/^quiet (on|yes)/) {
		$config->{quiet} = 1;
	} elsif(/^quiet (off|no)/) {
		$config->{quiet} = 0;
	# link
	} elsif(/"([^"]*)"\s+<?->\s+"([^"]+)"(.*)/) { # -> is old syntax
		my ($src, $dst, $opt) = ($1, $2, $3);
		my $srcnr = $config->{markerindex}->{$src};
		my $dstnr = $config->{markerindex}->{$dst};
		unless(defined $srcnr and defined $dstnr) {
			$config->parser_warn("both link endpoints must be defined");
			next;
		}
		$config->{links}->[$linknr] = { src => $srcnr, dst => $dstnr, arrow => '<->' };
		$config->default_options($config->{links}->[$linknr]);
		$config->parse_options($config->{links}->[$linknr], undef, $opt);
		$linknr++;
	# marker definitions
	} elsif(/^([\d.,-]+) ([\d.,-]+) "([^"]*)"(.*)/) { # xplanet marker file format
		my ($lat, $lon, $text, $opt) = ($1, $2, $3, $4);
		$lat =~ s/,/./;
		$lon =~ s/,/./;
		$config->{markers}->[$markernr]->{text} = $text;
		$config->{markers}->[$markernr]->{lat} = $lat;
		$config->{markers}->[$markernr]->{lon} = $lon;
		$config->{markerindex}->{$text} = $markernr;
		$config->default_options($config->{markers}->[$markernr]);
		$config->parse_options($config->{markers}->[$markernr], $markernr, $opt);
		$markernr++;
	} elsif(/^"([^"]*)"(.*)/) { # marker with options
		my ($text, $opt, $i) = ($1, $2);
		unless(defined ($i = $config->{markerindex}->{$text})) {
			$config->parser_warn("marker $text not defined yet");
			return;
		}
		$config->{markers}->[$i] ||= {};
		$config->parse_options($config->{markers}->[$i], $config->{markerindex}->{$text}, $opt);
	} elsif(/^label ([+-]?\d+) ([+-]?\d+) "([^"]+)"(.*)/) {
		$config->{yxlabels}->[$labelnr] = { labely => $1, labelx => $2, text => $3 };
		my $opt = $4;
		$config->default_options($config->{yxlabels}->[$labelnr]);
		$config->parse_options($config->{yxlabels}->[$labelnr], undef, $opt);
		$labelnr++;
	} elsif(/^polygon ([+-]?\d+) ([+-]?\d+) "([^"]+)"(.*)/) {
		# TODO
	# everything else is a globally applied local option or a syntax error
	} else {
		$config->parse_options($config, undef, $_);
	}
}

sub read {
	my $config = shift;
	my $file = shift || die "read: no filename";
	$file =~ s!^~/!$ENV{HOME}/!;
	$config->{file} = $file;

	my $fh = IO::File->new($file) or die "$file: $!";
	while (<$fh>) {
		chomp;
		$config->parse($_);
	}
	close $fh;

	return $config;
}

sub get_gpg_links {
	my $config = shift;

	my $keys = join ' ', keys %{$config->{gpg}};
	if ($config->{recv}) {
		system "gpg --recv-keys $keys";
	}

	open GPG, "gpg --list-sigs --with-colon --fixed-list-mode --fast-list-mode $keys |" or die "gpg: $!";
	my ($key, $src);
	while(<GPG>) {
		chomp;
		next if /^(rev|sub|tru|uat):/;
		if(/^pub::\d+:\d+:([0-9A-F]+):/) {
			$key = $1;
			warn "$key not related to any marker - did you use the long (16 char) keyid?\n" unless defined $config->{gpg}->{$key};
			$src = $config->{gpg}->{$key};
			delete $config->{gpg_not_found}->{$key};
		} elsif(/^sig:::\d+:([0-9A-F]+):/) {
			next unless defined $config->{gpg}->{$1}; # target not on map
			next if $key eq $1; # self-sig
			$config->{gpg_links}->{$config->{gpg}->{$1}}->{$src} = 1;
		} else {
			warn "unknown gpg output: $_";
		}
	}

	foreach my $key (keys %{$config->{gpg_not_found}}) {
		warn "$config->{gpg_not_found}->{$key}: key $key was not found in gpg's keyring\n";
	}

	foreach my $source (keys %{$config->{gpg_links}}) {
		next unless $config->{link_outside} or $config->{markers}->[$source]->{visible};
		foreach my $target (keys %{$config->{gpg_links}->{$source}}) {
			next unless $config->{link_outside} or $config->{markers}->[$target]->{visible};
			my ($arrow, $color);
			if($config->{gpg_links}->{$target}->{$source}) { # bidirectional link
				next if $target gt $source; # process only once
				$color = $config->{link_color};
				$arrow = "<->";
			} else {
				$color = $config->{sign1_color} or next; # don't draw unidirectional links
				$arrow = "-->";
			}
			next if not defined $config->{markers}->[$source]->{lat};
			next if not defined $config->{markers}->[$target]->{lat};
			push @{ $config->{links} },
				{ src => $source, dst => $target, link_color => $color, arrow => $arrow };
		}
	}
}

1;
