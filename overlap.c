/*
 * overlap.c is part of IrcMarkers
 *   Copyright (C) 2004 Christoph Berg <cb@df7cb.de>
 *
 *   2004-07-04: Modified to read from stdin
 *
 * Original copyright:
 *   MapMarkers, perl modules to create maps with markers.
 *   Copyright (C) 2002 Guillaume Leclanche (Mo-Ize) <mo-ize@nul-en.info>
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
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
#ifdef DEBUG /* FIXME: compiling without DEBUG breaks stuff */
    int orig_txt_x;
    int orig_txt_y;
#endif
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
    int alloc_markers = 2;

    /* invalid number of args */
    if (argc != 4)
    {
        fprintf(stderr, "invalid number of args\n");
        return(1);
    }

    nb_markers = 0;
    image_width = atoi(argv[1]);
    image_height = atoi(argv[2]);
    offset = atoi(argv[3]);
    markers = malloc( alloc_markers * sizeof(struct marker) );

    /* Read the data and store them into the struct table */
    for (nb_markers = 0; !feof(stdin); nb_markers++) {
        if(nb_markers > alloc_markers) {
            alloc_markers <<= 1;
            markers = realloc(markers, alloc_markers);
        }
        scanf("%u\t%u\t%u\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
                &(markers[nb_markers].id),
                &(markers[nb_markers].x),
                &(markers[nb_markers].y),
                &(markers[nb_markers].dot.left),
                &(markers[nb_markers].dot.right),
                &(markers[nb_markers].dot.top),
                &(markers[nb_markers].dot.bottom),
                &(markers[nb_markers].dot.width),
                &(markers[nb_markers].dot.height),
                &(markers[nb_markers].txt.left),
                &(markers[nb_markers].txt.right),
                &(markers[nb_markers].txt.top),
                &(markers[nb_markers].txt.bottom),
                &(markers[nb_markers].txt.width),
                &(markers[nb_markers].txt.height)
        );
#ifdef DEBUG
        markers[nb_markers].orig_txt_x = markers[nb_markers].txt.left;
        markers[nb_markers].orig_txt_y = markers[nb_markers].txt.bottom;
#endif
    }

    correctOverlap();

    /* Now write the resulting data to stdout */
    for (i = 0; i < nb_markers; i++) {
        printf("%u\t%c%d\t%c%d\n",
                    markers[i].id,
                    (markers[i].txt.left > 0 ? '+' : '-'),
                    abs(markers[i].txt.left),
                    (markers[i].txt.bottom > 0 ? '+' : '-'),
                    abs(markers[i].txt.bottom)
        );
#ifdef DEBUG
#if 0
        fprintf(stderr, "label %d moved %+d %+d\n", i,
                markers[i].orig_txt_x - markers[i].txt.left,
                markers[i].orig_txt_y - markers[i].txt.bottom);
#endif
#endif
    }

    return(0); /* give back control to perl */
}

static int
findOverlap(unsigned int id_current)
{
    int total_overlap = 0;
    register unsigned int i;
    for (i = 0; i < nb_markers; i++) {
        if (i != id_current) {
            total_overlap += calcOverlap(markers[id_current].txt, markers[i].txt);
            total_overlap += calcOverlap(markers[id_current].txt, markers[i].dot);
        }
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
        }

        align(markers+p, markers[p].alignment);
        p++;
    }
}

/* vim:sw=4:et
 */
