/*
 * overlap.c is part of IrcMarkers
 *   Copyright (C) 2004, 2005, 2006 Christoph Berg <cb@df7cb.de>
 *
 *   2004-07-04: Modified to read from stdin
 *
 * Original copyright:
 *   MapMarkers, perl modules to create maps with markers.
 *   Copyright (C) 2002 Guillaume Leclanche (Mo-Ize) <mo-ize@nul-en.info>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
*/

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#define min(x,y) (x < y ? x : y)
#define max(x,y) (x > y ? x : y)

enum align_e {
    RIGHT = 0,
    LEFT,
    ABOVE,
    BELOW,
    CENTER,
};

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
#ifdef DEBUG
    int orig_txt_x;
    int orig_txt_y;
#endif
};

static int nb_markers;
static unsigned int image_width;
static unsigned int image_height;
static int offset;
static struct marker *markers;


static int
box_overlap(struct box *label, struct box *b)
{
    int width, height;

    if (label->left > b->right || label->right < b->left)
        return 0;
    if (label->top > b->bottom || label->bottom < b->top)
        return 0;

    if (label->left > b->left)
        width = min(b->right, label->right) - label->left;
    else
        width = min(b->right, label->right) - max(b->left, label->left);

    if (label->top > b->top)
        height = min(b->bottom, label->bottom) - label->top;
    else
        height = min(b->bottom, label->bottom) - max(b->top, label->top);

    return width * height;
}

static int
overlap(unsigned int id_current, struct box *b)
{
    int total_overlap = 0;
    int i;
    for (i = 0; i < nb_markers; i++) {
        if (i == id_current)
            continue;
        total_overlap += box_overlap(b, &(markers[i].txt));
        total_overlap += box_overlap(b, &(markers[i].dot));
    }
    return total_overlap;
}

static int
border_overlap(struct box *m)
{
    int ordinate_overhang, abscissa_overhang;

    ordinate_overhang = (image_width - m->right < 0 ? image_width - m->right : -min(0, m->left));
    abscissa_overhang = (image_height - m->bottom < 0 ? image_height - m->bottom : -min(0, m->top));
    return ordinate_overhang * m->width + abscissa_overhang * m->height
        + ordinate_overhang * abscissa_overhang;
}

void
align(struct box *b, struct marker *m, int a)
{
    switch (a) {
    case RIGHT:
        b->left = m->x + offset + m->dot.width/2;
        b->top  = m->y - m->txt.height/2;
        break;
    case LEFT:
        b->left = m->x - offset - m->txt.width - m->dot.width/2;
        b->top  = m->y - m->txt.height/2;
        break;
    case ABOVE:
        b->left = m->x - m->txt.width/2;
        b->top  = m->y - offset - m->txt.height - m->dot.height/2;
        break;
    case BELOW:
        b->left = m->x - m->txt.width/2;
        b->top  = m->y + offset + m->dot.height/2;
        break;
    case CENTER:
        b->left = m->x - m->txt.width/2;
        b->top  = m->y - m->txt.height/2;
        break;
    default:
        assert(0);
    }

    b->width = m->txt.width;
    b->height = m->txt.height;

    b->right = b->left + b->width;
    b->bottom = b->top + b->height;
}

static void
correctOverlap(void)
{
    /* initialize each individual Marker's bounding box */
    int i;
    for (i = 0; i < nb_markers; i++)
    {
        struct box b[5];
        int max_overlap = 0, a = 0;
#if DEBUG
        fprintf(stderr, "Marker %d: %d\n", i, markers[i].dot.height);
#endif

        for (a = 0; a <= 4; a++)
        {
            align(b+a, markers+i, a);
            int total_overlap = border_overlap(b+a) + overlap(i, b+a);
#if DEBUG
            fprintf(stderr, "\tTry alignment %d: Overlap = %d %d %d\n", a, total_overlap, b[a].left, b[a].bottom);
#endif
            if (a == 0 || total_overlap < max_overlap) {
                markers[i].alignment = a;
                max_overlap = total_overlap;
            }
            if (total_overlap == 0)
                break;
        }

        markers[i].txt = b[markers[i].alignment];
    }
}

int
main(int argc, char* argv[])
{
    int i = 0;
    int alloc_markers = 4;

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
    assert(markers);

    /* Read the data and store them into the struct table */
    for (nb_markers = 0; !feof(stdin); nb_markers++) {
        if(nb_markers >= alloc_markers) {
            void *nm;
            alloc_markers <<= 2;
            nm = realloc(markers, alloc_markers * sizeof(struct marker));
            assert(nm);
            markers = nm;
        }
        if (15 !=
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
                &(markers[nb_markers].txt.height)))
            assert(0);
#ifdef DEBUG
        markers[nb_markers].orig_txt_x = markers[nb_markers].txt.left;
        markers[nb_markers].orig_txt_y = markers[nb_markers].txt.bottom;
#endif
    }

    correctOverlap();

    /* Now write the resulting data to stdout */
    for (i = 0; i < nb_markers; i++) {
        printf("%u\t%+d\t%+d\n",
                    markers[i].id,
                    markers[i].txt.left,
                    markers[i].txt.bottom);
#if DEBUG
        fprintf(stderr, "label %d moved %+d %+d (alignment %d)\n", i,
                markers[i].orig_txt_x - markers[i].txt.left,
                markers[i].orig_txt_y - markers[i].txt.bottom,
                markers[i].alignment);
#endif
    }

    return 0; /* give back control to perl */
}

/* vim:sw=4:et
 */
