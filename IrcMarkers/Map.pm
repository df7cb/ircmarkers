# Copyright (C) 2004 Christoph Berg <cb@df7cb.de>
#
# This file originated from the mapmarkers distribution:
#
# MapMarkers, perl modules to create maps with markers.
# Copyright (C) 2002-2003 Guillaume Leclanche (Mo-Ize) <mo-ize@nul-en.info>
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

package IrcMarkers::Map;

use strict;
use warnings;
use GD;
use IPC::Open2;
use IrcMarkers::Marker;

# Some file-global vars
my $pi = 3.1415926535898;
my $degtorad = 0.017453292519943;
my $radtodeg = 57.295779513082;

# create 24bit images
GD::Image->trueColor(1);

# Class method, creates a new map
sub new {
	my($class, $config) = @_;

	# open input map
	my $file = $config->{read} || die "no file to read from";
	$file =~ /\.([^.]+)$/;
	my $type = lc $1;

	die "File not found: $file" unless -f $file;
	if ($type eq "gd" or $type eq "gd1") {
		$config->{IMAGE} = GD::Image->newFromGd($file);
	} elsif ($type eq "gd2") {
		$config->{IMAGE} = GD::Image->newFromGd2($file);
	} elsif ($type eq "gif") {
		$config->{IMAGE} = GD::Image->newFromGif($file);
	} elsif ($type eq "jpg" or $type eq "jpeg") {
		$config->{IMAGE} = GD::Image->newFromJpeg($file);
	} elsif ($type eq "png") {
		$config->{IMAGE} = GD::Image->newFromPng($file);
	} elsif ($type eq "xbm") {
		$config->{IMAGE} = GD::Image->newFromXbm($file);
	} elsif ($type eq "xpm") {
		$config->{IMAGE} = GD::Image->newFromXpm($file);
	} else {
		die "Unsupported input image format $type";
	}
	die "Error while reading $file: $!" unless $config->{IMAGE}; # we *should* have undef here on error, but apparently haven't?!

	# Let's get pixel width and height of the map
	($config->{w}, $config->{h}) = $config->{IMAGE}->getBounds();

	# check coordinates
	die "western latitude greater than eastern" if $config->{west} >= $config->{east};
	die "latitude range greater than 360 degrees" if $config->{east} - $config->{west} > 360;
	die "southern longitude greater than northern" if $config->{south} >= $config->{north};
	die "longitude range greater than 180 degrees" if $config->{north} - $config->{south} > 180;

	# handle view_*
	if ($config->{view_west} or $config->{view_south} or $config->{view_width} or $config->{view_height}) {
		$config->{view_west} = $config->{west} unless defined $config->{view_west};
		$config->{view_east} = $config->{east} unless defined $config->{view_east};
		$config->{view_north} = $config->{north} unless defined $config->{view_north};
		$config->{view_south} = $config->{south} unless defined $config->{view_south};

		die "view_west is outside of map" if $config->{view_west} < $config->{west};
		die "view_east is outside of map" if $config->{view_east} > $config->{east};
		die "view_south is outside of map" if $config->{view_south} < $config->{south};
		die "view_north is outside of map" if $config->{view_north} > $config->{north};

		my $w = $config->{w} * ($config->{view_east} - $config->{view_west}) / ($config->{east} - $config->{west});
		my $h = $config->{h} * ($config->{view_north} - $config->{view_south}) / ($config->{north} - $config->{south});
		if($config->{view_width}) { # scale image
			if($config->{view_height}) { # don't keep aspect ratio if user requests otherwise
				($w, $h) = ($config->{view_width}, $config->{view_height});
			} else {
				($w, $h) = ($config->{view_width}, $h * ($config->{view_width} / $w));
			}
		} else {
			if($config->{view_height}) {
				($w, $h) = ($w * ($config->{view_height} / $h), $config->{view_height});
			}
		}

		my $image = new GD::Image($w, $h);
		$image->copyResampled($config->{IMAGE}, 0, 0,
			($config->{view_west} - $config->{west}) / ($config->{east} - $config->{west}) * $config->{w},
			($config->{view_north} - $config->{north}) / ($config->{south} - $config->{north}) * $config->{h},
			$w, $h,
			$config->{w} * ($config->{view_east} - $config->{view_west}) / ($config->{east} - $config->{west}),
			$config->{h} * ($config->{view_north} - $config->{view_south}) / ($config->{north} - $config->{south})
		);
		($config->{west}, $config->{east}, $config->{south}, $config->{north}) =
			($config->{view_west}, $config->{view_east}, $config->{view_south}, $config->{view_north});
		undef $config->{IMAGE}; # free old image
		$config->{IMAGE} = $image;

		($config->{w}, $config->{h}) = $config->{IMAGE}->getBounds();
	}

	# handle projection system
	if ($config->{projection} eq 'mercator') {
		# degree per pixel RESolution
		$config->{xres} = ($config->{east} - $config->{west}) / $config->{w};
		$config->{yres} = ($config->{north} - $config->{south}) / $config->{h};
	} elsif ($config->{projection} eq 'sinusoidal') {
		#die "center_lon is not between lon coordinates" if $config->{center_lon} < $config->{west} or $config->{center_lon} > $config->{east};
		die "center_lon must be defined for sinusoidal maps" unless defined $config->{center_lon};
		# These 2 are not in pixels, but in absolute coordinates. To get pixels, they should be multiplied by $xres.
		$config->{Xleft} = ($config->{west} - $config->{center_lon}) * cos($config->{north} * $degtorad);
		$config->{Xright}  = ($config->{east} - $config->{center_lon}) * cos($config->{south} * $degtorad);

		# number of unitary graduation / pixel for x (RESolution)
		$config->{xres} = ($config->{Xright} - $config->{Xleft}) / $config->{w};
		# number of degrees / pixel for y
		$config->{yres} = ($config->{north} - $config->{south}) / $config->{h};
	} else {
		die("ERROR: $config->{projection}: This projection system is not supported yet.");
	}

	$config->{LABELS} = [];

	bless $config, $class;
}

sub add {
	my($config, $marker) = @_;

	my $dot = {
		shape => $config->{markers}->{$marker}->{dot_shape}, # can be either 'dot' or 'circle'
		colour => $config->{markers}->{$marker}->{dot_color}, # RGB data
		thickness => $config->{markers}->{$marker}->{dot_size}, # radius
		border => $config->{markers}->{$marker}->{dot_border}
	};
	my $label = {
		text => $marker, # The text displayed
		colour => $config->{markers}->{$marker}->{label_color}, # RGB data
		border => $config->{markers}->{$marker}->{label_border},
		fontpath => $config->{markers}->{$marker}->{font}, # Absolute path to the .ttf font file
		fontsize => $config->{markers}->{$marker}->{ptsize}, # Font size, unity is "points"
	};

	my($x, $y, $X0);
	if ($config->{projection} eq 'mercator') {
		# pixel values, sprintf rounds to nearest
		$x = sprintf("%u", ($config->{markers}->{$marker}->{lon} - $config->{west}) / $config->{xres});
		$y = sprintf("%u", ($config->{north} - $config->{markers}->{$marker}->{lat}) / $config->{yres});
	} elsif ($config->{projection} eq 'sinusoidal') {
		# absolute X
		$X0 = ($config->{markers}->{$marker}->{lon} - $config->{center_lon}) * cos($config->{markers}->{$marker}->{lat} * $degtorad);
		# pixel values
		$x = sprintf("%u", ($X0 - $config->{Xleft}) / $config->{xres});
		$y = sprintf("%u", ($config->{north} - $config->{markers}->{$marker}->{lat}) / $config->{yres});
	}

	$config->{markers}->{$marker}->{x} = $x;
	$config->{markers}->{$marker}->{y} = $y;

	if ($config->{projection} eq 'mercator') { # marker is out of bounds
		if(($config->{markers}->{$marker}->{lon} > $config->{east} or $config->{markers}->{$marker}->{lon} < $config->{west} or $config->{markers}->{$marker}->{lat} > $config->{north} or $config->{markers}->{$marker}->{lat} < $config->{south})) {
			return;
		}
	} elsif ($config->{projection} eq 'sinusoidal') {
		return if ($X0 < $config->{Xleft} or $X0 > $config->{Xright} or $config->{markers}->{$marker}->{lat} > $config->{north} or $config->{markers}->{$marker}->{lat} < $config->{south});
	}

	$config->{markers}->{$marker}->{visible} = 1;

	print "$label->{text} at $config->{markers}->{$marker}->{lon}, $config->{markers}->{$marker}->{lat} ($x, $y)\n" unless $config->{quiet};

	my $newlabel = new IrcMarkers::Marker ($x, $y, $dot, $label, $config->{IMAGE});
	push @{$config->{LABELS}}, $newlabel;
}

sub link {
	my ($config, $link, $target, $link_color) = @_;

	my $newlink = IrcMarkers::Marker->new_line($config->{markers}->{$link}->{x},
		$config->{markers}->{$link}->{y},
		$config->{markers}->{$target}->{x},
		$config->{markers}->{$target}->{y}, $link_color);
	if($link_color->[0] eq $config->{link_color}->[0]) {
		push @{$config->{LINKS}}, $newlink;
	} else {
		unshift @{$config->{LINKS}}, $newlink; # draw sign1 links before sign2
	}
}

sub compute_overlap {
	my($config) = @_;

	# We execute the program in order to be able to read its output
	# 3 is the offset: space between dot and text

	my $command = $config->{overlap} . " " . (scalar @{$config->{LABELS}}) . " " . $config->{w} . " " . $config->{h} . " 3";

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
	} @{$config->{LABELS}};
	close(W);

	# Analyse the output
	while (<R>) {
		/(\d+)\t([+-]\d+)\t([+-]\d+)/;
		$config->{LABELS}->[$1]->{LABELX} = $2;
		$config->{LABELS}->[$1]->{LABELY} = $3; #While imlib uses top, gd uses bottom
	}
	# Clean all this shit
	close(R);
}

sub draw {
	my $config = shift;
	my $image = $config->{IMAGE};
	map { $_->draw_line($image); } @{$config->{LINKS}};
	map { $_->draw_dot($image); } @{$config->{LABELS}};
	map { $_->draw_label($image) } @{$config->{LABELS}};
}

sub draw_label_new {
	my ($config, $item) = @_;
	my ($x, $y, $text) = (
		$item->{x},        # label upper left abscissa
		$item->{y},        # label upper ordinate
		$item->{text}
	);
	my $image = $config->{IMAGE};
	my $font = $item->{font} || $config->{font};
	my $fontsize = $item->{ptsize} || $config->{ptsize};

	my @bounds = GD::Image->stringFT($image->colorResolve(0, 0, 0), $font, $fontsize, 0, 0, 0, $text);
	$x = $x =~ /^-/ ? $config->{w} + $x - $bounds[2] : $x;
	$y = $y =~ /^-/ ? $config->{h} + $y : $y - $bounds[5];

	my $b = $item->{label_border} ? $item->{label_border} : $config->{label_border};
	if (ref $b) { # might be -1
		my $bordercolor = $image->colorResolve(@$b);
		$image->stringFT($bordercolor, $font, $fontsize, 0, $x+1, $y+1, $text);
		$image->stringFT($bordercolor, $font, $fontsize, 0, $x-1, $y-1, $text);
		$image->stringFT($bordercolor, $font, $fontsize, 0, $x+1, $y-1, $text);
		$image->stringFT($bordercolor, $font, $fontsize, 0, $x-1, $y+1, $text);
		$image->stringFT($bordercolor, $font, $fontsize, 0, $x+1, $y, $text);
		$image->stringFT($bordercolor, $font, $fontsize, 0, $x-1, $y, $text);
		$image->stringFT($bordercolor, $font, $fontsize, 0, $x, $y-1, $text);
		$image->stringFT($bordercolor, $font, $fontsize, 0, $x, $y+1, $text);
	}

	# And finally draw the text in the middle
	my $fontcolor = $image->colorResolve(@{$item->{label_color} || $config->{label_color}});
	$image->stringFT($fontcolor, $font, $fontsize, 0, $x, $y, $text);
}

sub set_line_style {
	my $config = shift;

	for(my $i = 25; $i >= 0; $i--) {
		push @{$config->{line_style}}, $config->{IMAGE}->colorResolve(10*$i, 10*$i, 10*$i);
	}
	$config->{IMAGE}->setStyle(@{$config->{line_style}});
}

sub draw_line_new {
	my ($config, $item) = @_;
	my $image = $config->{IMAGE};

	my $color = $image->colorResolve(@{$item->{link_color} || $config->{link_color}});
	$image->line($item->{x0}, $item->{y0}, $item->{x1}, $item->{y1}, $color);
	#$image->line($item->{x0}, $item->{y0}, $item->{x1}, $item->{y1}, gdStyled);
}

sub write {
	my($config, $file) = @_;
	my $image = $config->{IMAGE};

	$file =~ /\.([^.]+)$/;
	my $format = lc $1;
	my $data;
	if ($format eq "gd" or $format eq "gd1") {
		$data = $image->gd;
	} elsif ($format eq "gd2") {
		$data = $image->gd2;
	} elsif ($format eq "gif") {
		$data = $image->gif;
	} elsif ($format eq "jpg" or $format eq "jpeg") {
		$data = $image->jpeg;
	} elsif ($format eq "png") {
		$data = $image->png;
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

sub compute_boundingbox { # compute bounding box
	my $config = shift;
	my $item = shift;
	$config->{min_x} = $item->{x} if not defined $config->{min_x} or $item->{x} < $config->{min_x};
	$config->{max_x} = $item->{x} if not defined $config->{max_x} or $item->{x} > $config->{max_x};
	$config->{min_y} = $item->{y} if not defined $config->{min_y} or $item->{y} < $config->{min_y};
	$config->{max_y} = $item->{y} if not defined $config->{max_y} or $item->{y} > $config->{max_y};
}

# transitional stub
sub get_gpg_links {
	IrcMarkers::File::get_gpg_links(@_);
}

1;
