#    (c) 2004 Christoph Berg <cb@df7cb.de>
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

package IrcMarkers::Marker;

use strict;
use GD;
use Exporter;
use vars qw(@ISA @EXPORT_OK $TYPE $OFFSET);

@ISA = qw(Exporter);
@EXPORT_OK = qw(
                new
                text
                x
                y
                width
                height
                move
                draw
            );

$OFFSET = 3;

# Class method, creates a new label, given x, y and text
sub new {
	my($class, $x, $y, $dot, $label, $image) = @_;
	my $self = {};

	$self->{X} = $x;
	$self->{Y} = $y;
	$self->{LABELX} = $x + $dot->{thickness} + $OFFSET;
	$self->{LABELY} = $y + $dot->{thickness};
	$self->{TEXT} = $label; # HASH ref, keys are "text" "colour" "border" "fontpath" "fontsize"
	$self->{DOT} = $dot;

	# Calculate the label bounds needed later by the overlap corrector
    my @tmp = GD::Image->stringFT(  $image->colorResolve(0, 0, 0), 
                                    $label->{fontpath}, 
                                    $label->{fontsize}, 
                                    0,
                                    $self->{LABELX}, 
                                    $self->{LABELY}, 
                                    $label->{text});
	$self->{LABEL_BOUNDS} = \@tmp;

	bless $self, $class;
}

sub draw_label {
	my ($self, $image) = @_;
	my ($labelx, $labely, $text) = (
		$self->{LABELX},        # label upper left abscissa
		$self->{LABELY},        # label upper ordinate
		$self->{TEXT}           # label hash ref containing "text" "border" "colour" "fontpath" "fontsize"
	);
	my $font = $text->{fontpath};
	my $fontsize = $text->{fontsize};

	if (exists $text->{border}) {
		my $bordercolor = $image->colorResolve(@{$text->{border}});
		$image->stringFT($bordercolor, $font, $fontsize, 0, $labelx+1, $labely+1, $text->{text});
		$image->stringFT($bordercolor, $font, $fontsize, 0, $labelx-1, $labely-1, $text->{text});
		$image->stringFT($bordercolor, $font, $fontsize, 0, $labelx+1, $labely-1, $text->{text});
		$image->stringFT($bordercolor, $font, $fontsize, 0, $labelx-1, $labely+1, $text->{text});
		$image->stringFT($bordercolor, $font, $fontsize, 0, $labelx+1, $labely, $text->{text});
		$image->stringFT($bordercolor, $font, $fontsize, 0, $labelx-1, $labely, $text->{text});
		$image->stringFT($bordercolor, $font, $fontsize, 0, $labelx, $labely-1, $text->{text});
		$image->stringFT($bordercolor, $font, $fontsize, 0, $labelx, $labely+1, $text->{text});
	}

	# And finally draw the black text in the middle
	my $fontcolor = $image->colorResolve(@{$text->{colour}});
	$image->stringFT($fontcolor, $font, $fontsize, 0, $labelx, $labely, $text->{text});
}

sub draw_dot {
	my($self, $image) = @_;
	my($x, $y, $dot) = ($self->{X}, $self->{Y}, $self->{DOT});

	# Default values if there are undefined
	$dot->{colour}      = [255, 255, 255]   if (!defined $dot->{colour});
	$dot->{thickness}   = 2                 if (!defined $dot->{thickness});
	$dot->{shape}       = 'dot'             if (!defined $dot->{shape});

	my $dotcolour = $image->colorResolve(@{$dot->{colour}});
	my $dotborder = (defined $dot->{border} ? $image->colorResolve(@{$dot->{border}}) : undef);

	if ($dot->{shape} eq 'dot') {
		$image->arc($x,$y, $dot->{thickness}+1, $dot->{thickness}+1, 0, 360, $dotborder) if defined $dotborder;
		# core of the dot
		# draw concentric circles until the requested radius is reached
		for (my $rayon = 0; $rayon <= $dot->{thickness}; $rayon++) {
			$image->arc($x, $y, $rayon, $rayon, 0, 360, $dotcolour);
		}
	} else { # shape is supposed to be a circle
		$image->arc($x,$y, $dot->{thickness}+1, $dot->{thickness}+1, 0, 360, $dotborder) if defined $dotborder;
		$image->arc($x,$y, $dot->{thickness}, $dot->{thickness}, 0, 360, $dotcolour);
	}
}

sub new_line {
	my($class, $x0, $y0, $x1, $y1, $color) = @_;
	my $self = {};

	$self->{x0} = $x0;
	$self->{y0} = $y0;
	$self->{x1} = $x1;
	$self->{y1} = $y1;
	$self->{color} = $color;

	bless $self, $class;
}

sub draw_line {
	my($self, $image) = @_;
	my $color = $image->colorResolve(@{$self->{color}});
	$image->line($self->{x0}, $self->{y0}, $self->{x1}, $self->{y1}, $color);
}

1;
