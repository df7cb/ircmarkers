#    Copyright (C) 2004 Christoph Berg <cb@df7cb.de>
#
#    This file originated from the mapmarkers distribution:
#
#    MapMarkers, perl modules to create maps with markers.
#    Copyright (C) 2002-2003 Guillaume Leclanche (Mo-Ize) <mo-ize@nul-en.info>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

#    2004-07-04 cb: added links and cleaned up code

package IrcMarkers::Map;

use strict;
use warnings;
use GD;
use IPC::Open2;
use IrcMarkers::Marker;
use vars qw($VERSION);
$VERSION = '2.0b1';

# Some file-global vars
my $pi = 3.1415926535898;
my $degtorad = 0.017453292519943;
my $radtodeg = 57.295779513082;
my $rearth = 6371030; # mean Earth radius

# create 24bit images
GD::Image->trueColor(1);

# Class method, creates a new map
sub new {
	my($class, $config) = @_;

	my $file = $config->{read} || die "no file to read from";
	$file =~ /\.([^.]+)$/;
	my $type = lc $1;

	$type = lc $type;
	if ($type eq "png") {
		$config->{IMAGE} = GD::Image->newFromPng($file);
	} elsif ($type eq "jpg" or $type eq "jpeg") {
		$config->{IMAGE} = GD::Image->newFromJpeg($file);
	} else {
		die "Unsupported input image format $type";
	}

	# Let's get pixel width and height of the map
	($config->{w}, $config->{h}) = $config->{IMAGE}->getBounds();

	if (lc $config->{projection} eq 'mercator') {
		# degree per pixel RESolution
		$config->{xres} = ($config->{east} - $config->{west}) / $config->{w};
		$config->{yres} = ($config->{north} - $config->{south}) / $config->{h};
	} elsif (lc $config->{projection} eq 'sinusoidal') {
		# These 2 are not in pixels, but in absolute coordinates. To get pixels, they should be multiplied by $Xres.
		$config->{Xright} = ($config->{west} - $config->{center_lon}) * cos($config->{north} * $degtorad);
		$config->{Xleft}  = ($config->{east} - $config->{center_lon}) * cos($config->{south} * $degtorad);

		# number of unitary graduation / pixel for x (RESolution)
		$config->{xres} = ($config->{Xright} - $config->{Xleft}) / $config->{w};
		# number of degrees / pixel for y
		$config->{yres} = ($config->{north} - $config->{south}) / $config->{h};
	} else {
		die("ERROR: ".$config->{projection}.": This projection system is not supported yet.");
	}

	$config->{LABELS} = [];

	die "font not found: $config->{font}" unless -f $config->{font};

	bless $config, $class;
}


sub add {
	my($config, $lon, $lat, $marker) = @_;

	my $dot = {
		shape => "circle", # can be either 'dot' or 'circle'
		colour => $config->{dot_color}, # RGB data
		thickness => 2, # radius
		border => $config->{dot_border}
	};
	my $label = {
		text => $marker, # The text displayed
		colour => $config->{label_color}, # RGB data
		border => $config->{label_border},
		fontpath => $config->{font}, # Absolute path to the .ttf font file
		fontsize => $config->{ptsize}, # Font size, unity is "points"
	};
	my($x, $y);

	if (lc $config->{projection} eq 'mercator') {
		# marker is out of bounds
		if(($lon > $config->{east} or $lon < $config->{west} or $lat > $config->{north} or $lat < $config->{south})) {
			#print "$label->{text} is out of bounds\n";
			return;
		}

		# pixel values
		$x = sprintf("%u", ($lon- $config->{west}) / $config->{xres});
		$y = sprintf("%u", ($config->{north} - $lat) / $config->{yres});
	} elsif (lc $config->{projection} eq 'sinusoidal') {
		# absolute X
		my $X0 = ($lon- $config->{center_lon}) * cos($lat* $degtorad);

		# marker is out of bounds
		return if ($X0 < $config->{Xleft} or $X0 > $config->{Xright} or $lat> $config->{north} or $lat< $config->{south});

		# pixel values
		$x = sprintf("%u", ($X0 - $config->{Xleft}) / $config->{xres});
		$y = sprintf("%u", ($config->{north} - $lat) / $config->{yres});
	}

	$config->{markers}->{$marker}->{x} = $x;
	$config->{markers}->{$marker}->{y} = $y;

	print "$label->{text} at $lon, $lat ($x, $y)\n" unless $config->{quiet};

	# Pixels are supposed to be unsigned integers, sprintf rounds to nearest.
	my $newlabel = new IrcMarkers::Marker ($x, $y, $dot, $label, $config->{IMAGE});
	push @{$config->{LABELS}}, $newlabel;
}

sub link {
	my ($config, $link, $target, $link_color) = @_;

	# Pixels are supposed to be unsigned integers, sprintf rounds to nearest.
	my $newlink = IrcMarkers::Marker->new_line($config->{markers}->{$link}->{x},
		$config->{markers}->{$link}->{y},
		$config->{markers}->{$target}->{x},
		$config->{markers}->{$target}->{y}, $link_color);
	push @{$config->{LINKS}}, $newlink;
}

sub draw {
	my($self, $file) = @_;

	# Handling overlaps
	if($self->{overlap_correction}) {
		# We execute the program in order to be able to read its output
		# 3 is the offset: space between dot and text

		my $command = $self->{overlap} . " " . (scalar @{$self->{LABELS}}) . " " . $self->{w} . " " . $self->{h} . " 3";

		my($rdrfh, $wtrfh);
		my $pid = open2(\*R, \*W, $command) or die "open2: $!";

		my $m = 0;
		map {
			my $ref = $_->{LABEL_BOUNDS};
			printf W ("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                        $m++,
                        $_->{X},
                        $_->{Y},
                        $_->{X} - $_->{DOT}->{thickness},
                        $_->{X} + $_->{DOT}->{thickness},
                        $_->{Y} - $_->{DOT}->{thickness},
                        $_->{Y} + $_->{DOT}->{thickness},
                        2 * $_->{DOT}->{thickness},
                        2 * $_->{DOT}->{thickness},
                        $ref->[0], # left x
                        $ref->[2], # right x
                        $ref->[5], # upper y
                        $ref->[1], # lower y
                        $ref->[2] - $ref->[0], # width
                        $ref->[1] - $ref->[5]  # height
            );
		} @{$self->{LABELS}};
		close(W);

		# Analyse the output
		while (<R>) {
			$_ =~ /(\d+)\t((\+|\-)\d+)\t((\+|\-)\d+)/;
			$self->{LABELS}->[$1]->{LABELX} = $2;
			$self->{LABELS}->[$1]->{LABELY} = $4; #While imlib uses top, gd uses bottom
		}
		# Clean all this shit
		close(R);
	}

	# In the end, drawing the file
	my $image = $self->{IMAGE};
	my $j = 0;
	map { $_->draw_line($image); } @{$self->{LINKS}};
	map { $_->draw_dot($image); } @{$self->{LABELS}};
	map { $_->draw_label($image) } @{$self->{LABELS}};

	$file =~ /\.([^.]+)$/;
	my $format = lc $1;
	my $data;
	if ($format eq "png") {
		$data = $image->png;
	} elsif ($format eq "jpg" or $format eq "jpeg") {
		$data = $image->jpeg;
	} elsif ($format eq "gd" or $format eq "gd1") {
		$data = $image->gd;
	} elsif ($format eq "gd2") {
		$data = $image->gd2;
	} elsif ($format eq "wbmp") {
		$data = $image->wbmp;
	} else {
		die "Unsupported output image format $format";
	}

	open (SVG, ">$file") or die "$file: $!";
	binmode SVG;
	print SVG $data;
	close SVG;
}

1;
