/*
#    MapMarkers, perl modules to create maps with markers.
#    Copyright (C) 2002 Guillaume Leclanche (Mo-Ize) <mo-ize@nul-en.info>
#
#    2004-07-04: Christoph Berg <cb@df7cb.de>: Modified to read from stdin
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
*/

#include <stdio.h>
#include <stdlib.h>

#define min(x,y) (x < y ? x : y)
#define max(x,y) (x > y ? x : y)

#define RIGHT 0
#define LEFT 1
#define ABOVE 2
#define BELOW 3
#define CENTER 4

struct box {
    int left;
    int right;
    int top;
    int bottom;
    int width;
    int height;
};

struct marker {
    unsigned int id;
    unsigned int x;
    unsigned int y;
    int alignment;
    struct box dot;
    struct box txt;
};

static int nb_markers;
static unsigned int image_width;
static unsigned int image_height;
static int offset;
static struct marker *markers;


static void correctOverlap(void);
static int findOverlap(unsigned int id_current);
int calcOverlap(struct box label, struct box b);
static int align(struct marker *m, int i);


int
main(int argc, char* argv[])
{
    register int i = 0;

    /* invalid number of args */
    if (argc != 5)
    {
        fprintf(stderr, "invalid number of args\n");
        return(1);
    }

    nb_markers = atoi(argv[1]);
    image_width = atoi(argv[2]);
    image_height = atoi(argv[3]);
    offset = atoi(argv[4]);
    markers = malloc( atoi(argv[1]) * sizeof(struct marker) );

    /* Read the data and store them into the struct table */
    while (i < nb_markers) {
        scanf("%u\t%u\t%u\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
                    &(markers[i].id),
                    &(markers[i].x),
                    &(markers[i].y),
                    &(markers[i].dot.left),
                    &(markers[i].dot.right),
                    &(markers[i].dot.top),
                    &(markers[i].dot.bottom),
                    &(markers[i].dot.width),
                    &(markers[i].dot.height),
                    &(markers[i].txt.left),
                    &(markers[i].txt.right),
                    &(markers[i].txt.top),
                    &(markers[i].txt.bottom),
                    &(markers[i].txt.width),
                    &(markers[i].txt.height)
        );
        i++;
    }

    correctOverlap();

    /* Now write the resulting data to stdout */
    i = 0;
    while (i < nb_markers) {
        fprintf(stdout, "%u\t%c%d\t%c%d\n",
                    markers[i].id,
                    (markers[i].txt.left > 0 ? '+' : '-'),
                    abs(markers[i].txt.left),
                    (markers[i].txt.bottom > 0 ? '+' : '-'),
                    abs(markers[i].txt.bottom)
        );
        i++;
    }

    return(0); /* give back control to perl */
}

static int
findOverlap(unsigned int id_current)
{
    int total_overlap = 0;
    register unsigned int i = 0;
    while (i < nb_markers)
    {
        if (i == id_current)
        {
            i++;
            continue;
        }

        total_overlap += calcOverlap(markers[id_current].txt, markers[i].txt);
        total_overlap += calcOverlap(markers[id_current].txt, markers[i].dot);
        i++;
    }
    return(total_overlap);
}

int
calcOverlap(struct box label, struct box b)
{
    int width, height;

    if (label.left > b.right || label.right < b.left) return(0);

    if (label.top > b.bottom || label.bottom < b.top) return(0);

    if (label.left > b.left)
        width = min(b.right, label.right) - label.left;
    else
        width = min(b.right, label.right) - max(b.left, label.left);

    if (label.top > b.top)
        height = min(b.bottom, label.bottom) - label.top;
    else
        height = min(b.bottom, label.bottom) - max(b.top, label.top);

    return(width * height);
}

static int
align(struct marker *m, int i)
{
    int ordinate_overhang, abscissa_overhang;

    switch (i)
    {
    case RIGHT:
        m->txt.left = m->x + offset + m->dot.width/2;
        m->txt.top  = m->y - m->txt.height/2;
        break;
    case LEFT:
        m->txt.left = m->x - offset - m->txt.width - m->dot.width/2;
        m->txt.top  = m->y - m->txt.height/2;
        break;
    case ABOVE:
        m->txt.left = m->x - m->txt.width/2;
        m->txt.top  = m->y - offset - m->dot.height/2 - m->txt.height;
        break;
    case BELOW:
        m->txt.left = m->x - m->txt.width/2;
        m->txt.top  = m->y + offset + m->dot.height/2 ;
        break;
    case CENTER:
        m->txt.left = m->x - m->txt.width/2;
        m->txt.top  = m->y - m->txt.height/2;
    default:
        return(0);
    }

    m->txt.right = m->txt.left + m->txt.width;
    m->txt.bottom = m->txt.top + m->txt.height;

    ordinate_overhang = (image_width - m->txt.right < 0 ? image_width - m->txt.right : -min(0, m->txt.left));
    abscissa_overhang = (image_height - m->txt.bottom < 0 ? image_height - m->txt.bottom : -min(0, m->txt.top));

    return(abscissa_overhang * m->txt.height + ordinate_overhang * m->txt.width + ordinate_overhang * abscissa_overhang);
}

static void
correctOverlap(void)
{
    int alignments[5] = {RIGHT, LEFT, ABOVE, BELOW, CENTER};

    /* initialize each individual Marker's bounding box */
    register int p = 0;

    while (p < nb_markers)
    {
        int total_overlap = 0, max_overlap = 0, i = 0;
/* fprintf(stderr, "\tN°%d\n", p); */

        for (i = 0; i <= 4; i++)
        {
            if (i == 0 || total_overlap)
            {
                int overhang = align(markers+p, i);
                total_overlap = findOverlap(p) + overhang;
/* fprintf(stderr, "\t\tTry %d, Overlap = %d\n", i, total_overlap); */
                if (i == 0 || total_overlap < max_overlap)
                {
                    markers[p].alignment = alignments[i];
                    max_overlap = total_overlap;
                }
            }
            else
            {
                continue;
            }
        }

        align(markers+p, markers[p].alignment);
        p++;
    }
}
