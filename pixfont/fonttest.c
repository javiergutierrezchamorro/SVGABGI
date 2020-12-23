/******************************************************************************/
/*                                                                            */
/*                     FontTest, Testprogramm zum Modul PixFont               */
/*                                                                            */
/*                                                                            */
/*  (C) 1993 by Ullrich von Bassewitz                                         */
/*              ZwehrenbÅhlstra·e 33                                          */
/*              7400 TÅbingen                                                 */
/*                                                                            */
/*  E-Mail: uz@moppi.sunflower.sub.org                                        */
/*                                                                            */
/******************************************************************************/


#include <stdlib.h>
#include <stdio.h>
#include <graphics.h>
#include "pixfont.h"


/* SVGA-Treiber verwenden */
#define SVGA




void Error (char *Msg, char *I)
{
    closegraph ();
    if (I) {
        fprintf (stderr, Msg, I);
    } else {
        fprintf (stderr, Msg);
    }
    exit (1);
}





int main (void)
{

    int GD, GM, GE;
    HFONT Font8x14, Font8x16, Font16x16;

#ifdef SVGA
    GD = installuserdriver ("SVGA", NULL);
    if (GD < 0) {
        fprintf (stderr, "Fehler beim Installieren von SVGA.BGI\n");
        exit (1);
    }
    GM = 3;             /* 640 * 480 * 256 */
#else
    GD = DETECT;
#endif

    initgraph (&GD, &GM, NULL);
    if ((GE = graphresult ()) != 0) {
        fprintf (stderr, "Fehler bei initgraph: %s\n", grapherrormsg (GE));
        exit (1);
    }


    if ((Font8x14 = PixFontInit (Get8x14FontPtr (), 8, 14)) == NULL) {
        Error ("Fehler bei PixFontInit\n", NULL);
    }
    if ((Font8x16 = PixFontInit (Get8x16FontPtr (), 8, 16)) == NULL) {
        Error ("Fehler bei PixFontInit\n", NULL);
    }
    if ((Font16x16 = PixFontInit (NULL, 8, 16)) == NULL) {
        Error ("Fehler bei PixFontInit\n", NULL);
    }
    if (PixFontLoad (Font16x16, "16x16.fnt", 16, 16) != 0) {
        Error ("Fehler beim Laden von 16x16.fnt\n", NULL);
    }


    PixFontSetColor (Font8x14, LIGHTBLUE);
    PixFontWriteXY (Font8x14, 10, 100, "Aber hallo !");
    PixFontSetScale (Font8x14, 1, 2);
    PixFontWriteXY (Font8x14, 10, 130, "Aber hallo !");
    PixFontSetScale (Font8x14, 2, 1);
    PixFontWriteXY (Font8x14, 10, 160, "Aber hallo !");

    PixFontSetColor (Font8x16, LIGHTGREEN);
    PixFontWriteXY (Font8x16, 10, 200, "Aber hallo !");
    PixFontSetScale (Font8x16, 1, 2);
    PixFontWriteXY (Font8x16, 10, 230, "Aber hallo !");
    PixFontSetScale (Font8x16, 2, 1);
    PixFontWriteXY (Font8x16, 10, 260, "Aber hallo !");

    PixFontSetColor (Font16x16, LIGHTRED);
    PixFontWriteXY (Font16x16, 10, 300, "Aber hallo !");
    PixFontSetScale (Font16x16, 1, 2);
    PixFontWriteXY (Font16x16, 10, 330, "Aber hallo !");
    PixFontSetScale (Font16x16, 2, 1);
    PixFontWriteXY (Font16x16, 10, 360, "Aber hallo !");

    PixFontSetDirection (Font8x14, VERT_DIR);
    PixFontSetJustify (Font8x14, LEFT_TEXT, BOTTOM_TEXT);
    PixFontWriteXY (Font8x14, 300, 400, "Aber hallo !");
    PixFontSetScale (Font8x14, 1, 2);
    PixFontWriteXY (Font8x14, 330, 400, "Aber hallo !");
    PixFontSetScale (Font8x14, 2, 1);
    PixFontWriteXY (Font8x14, 360, 400, "Aber hallo !");

    PixFontSetDirection (Font8x16, VERT_DIR);
    PixFontSetJustify (Font8x16, LEFT_TEXT, BOTTOM_TEXT);
    PixFontWriteXY (Font8x16, 400, 400, "Aber hallo !");
    PixFontSetScale (Font8x16, 1, 2);
    PixFontWriteXY (Font8x16, 430, 400, "Aber hallo !");
    PixFontSetScale (Font8x16, 2, 1);
    PixFontWriteXY (Font8x16, 460, 400, "Aber hallo !");

    PixFontSetDirection (Font16x16, VERT_DIR);
    PixFontSetJustify (Font16x16, LEFT_TEXT, BOTTOM_TEXT);
    PixFontWriteXY (Font16x16, 500, 400, "Aber hallo !");
    PixFontSetScale (Font16x16, 1, 2);
    PixFontWriteXY (Font16x16, 530, 400, "Aber hallo !");
    PixFontSetScale (Font16x16, 2, 1);
    PixFontWriteXY (Font16x16, 560, 400, "Aber hallo !");

    (void) getchar ();

    PixFontDone (Font8x14);
    PixFontDone (Font8x16);
    PixFontDone (Font16x16);


    closegraph ();

    return 0;

}




