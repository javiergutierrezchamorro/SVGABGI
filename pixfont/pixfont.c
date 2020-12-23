/******************************************************************************/
/*                                                                            */
/*                                  PixFont                                   */
/*                                                                            */
/*                                                                            */
/*  (C) 1993 by Ullrich von Bassewitz                                         */
/*              ZwehrenbÅhlstra·e 33                                          */
/*              7400 TÅbingen                                                 */
/*                                                                            */
/*                                                                            */
/*                                                                            */
/*  Erlaubt die Ausgabe von Text-Strings mit beliebigen Pixelfonts. Die       */
/*  verwendeten Pixel-Fonts mÅssen folgenderma·en aufgebaut sein:             */
/*                                                                            */
/*  Ein Zeichen besteht aus XSize Spalten und YSize Zeilen.                   */
/*  Die Daten fÅr die Pixel werden so angeordnet                              */
/*                                                                            */
/*    1. Zeichen:                                                             */
/*      1. Zeile                                                              */
/*      2. Zeile                                                              */
/*      3. Zeile                                                              */
/*      ...                                                                   */
/*                                                                            */
/*    2. Zeichen                                                              */
/*      1. Zeile                                                              */
/*      2. Zeile                                                              */
/*      3. Zeile                                                              */
/*      ...                                                                   */
/*                                                                            */
/*    ...                                                                     */
/*                                                                            */
/*  Die Daten einer Zeile werden jeweils auf volle Bytes aufgerundet, so da·  */
/*  ein 8 Pixel breiter Font ein Byte pro Zeile, ein 9 Pixel breiter 2 Bytes  */
/*  pro Zeile besitzt etc.                                                    */
/*  Das oberste Bit (Bit 7) eines Bytes wird links ausgegeben, jedes folgende */
/*  Bit eine Position weiter rechts.                                          */
/*  Die erste Zeile wird zuoberst ausgegeben, jede folgende darunter.         */
/*                                                                            */
/*  Alle Routinen haben Namen die mit PixFont beginnen.                       */
/*                                                                            */
/*  énderungen:                                                               */
/*                                                                            */
/*  04.05.93    Uz      Pascal-Version nach C Åbersetzt.                      */
/*                                                                            */
/*  06.05.93    Uz      Namen geÑndert.                                       */
/*                                                                            */
/******************************************************************************/



#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <dos.h>
#include <graphics.h>
#include "pixfont.h"






/******************************************************************************/
/*                                                                            */
/* PixFontInit:                                                               */
/*                                                                            */
/* Erzeugt einen neues Kontroll-Objekt fÅr einen Font und liefert einen       */
/* Zeiger (das Handle) darauf zurÅck. FontData ist der Zeiger auf die         */
/* Font-Daten und kann auch NULL sein, wenn spÑter ein Font geladen werden    */
/* soll. XSize und YSize sind die Grundgrî·e des Fonts in Pixeln. Bei Fehlern */
/* kommt anstelle des Handles ein NULL-Zeiger zurÅck.                         */
/* Als Default wird die Vergrî·erung 1 und die aktuelle Zeichenfarbe als      */
/* Fontfarbe gewÑhlt.                                                         */
/*                                                                            */
/******************************************************************************/

HFONT PixFontInit (void *FontData, unsigned XSize, unsigned YSize)
{
    register HFONT Font;

    /* Speicher belegen */
    if ((Font = malloc (sizeof (PixFont))) == NULL) {
        /* Kein Speicher mehr da */
        return NULL;
    }

    /* Variable Åbernehmen */
    Font->FontPtr       = FontData;
    Font->FontXSize     = XSize;
    Font->FontYSize     = YSize;

    /* Rest sinnvoll setzen */
    Font->FontXMult     = 1;
    Font->FontYMult     = 1;
    Font->FontColor     = getcolor ();
    Font->FontHoriz     = LEFT_TEXT;
    Font->FontVert      = TOP_TEXT;
    Font->FontDir       = HORIZ_DIR;
    Font->FontMem       = 0U;

    /* struct als Ergebnis liefern */
    return Font;
}





/******************************************************************************/
/*                                                                            */
/* PixFontDone:                                                               */
/*                                                                            */
/* Lîscht einen Font und gibt evtl. belegten Speicher wieder frei. Das Handle */
/* ist danach ungÅltig und darf nicht mehr verwendet werden.                  */
/*                                                                            */
/******************************************************************************/

void PixFontDone (HFONT Font)
{
    /* Falls Speicher belegt, diesen wieder freigeben */
    if (Font->FontMem) {
        free (Font->FontPtr);
    }

    /* Und die struct lîschen */
    free (Font);

}





/******************************************************************************/
/*                                                                            */
/* PixFontLoad:                                                               */
/*                                                                            */
/* LÑdt die Fontdaten aus einer Datei. Falls zuvor bereits Speicher fÅr       */
/* andere Fontdaten belegt war wird dieser zuvor freigegeben. Der RÅckgabe-   */
/* code ist 0 wenn der Font erfolgreich geladen werden konnte, ansonsten      */
/* kommt ein Wert != 0 zurÅck (errno wenn grî·er 0, -1 bei allgemeinen        */
/* Fehlern).                                                                  */
/*                                                                            */
/******************************************************************************/

int PixFontLoad (HFONT Font, char *Name, unsigned XSize, unsigned YSize)
{

    FILE *F;
    long Size;


    /* Falls Speicher fÅr einen Font belegt wurde, diesen freigeben */
    if (Font->FontMem) {
        free (Font->FontPtr);
        Font->FontMem = 0;
    }


    /* Datei îffnen */
    if ((F = fopen (Name, "rb")) == NULL) {
        /* Fehler beim îffnen */
        return -1;
    }

    /* Dateizeiger ans Ende positionieren und LÑnge holen */
    (void) fseek (F, 0, SEEK_END);
    Size = ftell (F);
    rewind (F);

    if ((Size == -1L) || (Size > 0xFFF0L)) {
        /* Fehler oder falsche Grî·e */
        (void) fclose (F);
        return (Size > 0xFFF0L) ? -1 : errno;
    }

    /* Speicher belegen */
    Font->FontMem = (unsigned) Size;
    if ((Font->FontPtr = malloc (Font->FontMem)) == NULL) {
        /* Kein Speicher */
        (void) fclose (F);
        return -1;
    }

    /* Font in den Speicher lesen */
    (void) fread (Font->FontPtr, Font->FontMem, 1, F);

    /* Datei schlie·en */
    (void) fclose (F);

    /* Werte fÅr den Font setzen */
    Font->FontXSize = XSize;
    Font->FontYSize = YSize;

    /* Ok melden */
    return 0;

}





/******************************************************************************/
/*                                                                            */
/* PixFontSetFont:                                                            */
/*                                                                            */
/* Setzt die Fontdaten neu. Falls zuvor bereits Speicher fÅr andere Fontdaten */
/* belegt war wird dieser zuvor freigegeben. XSize und YSize sind die         */
/* Grundgrî·e des Fonts in Pixeln.                                            */
/*                                                                            */
/******************************************************************************/

void PixFontSetFont (HFONT Font, void *FontData, unsigned XSize, unsigned YSize)
{

    /* Falls Speicher fÅr einen Font belegt wurde, diesen freigeben */
    if (Font->FontMem) {
        free (Font->FontPtr);
        Font->FontMem = 0;
    }

    /* Font und dessen Werte Åbernehmen */
    Font->FontPtr     = FontData;
    Font->FontXSize   = XSize ? XSize : 8;
    Font->FontYSize   = YSize ? YSize : 8;

}





/******************************************************************************/
/*                                                                            */
/* PixFontSetScale:                                                           */
/*                                                                            */
/* Setzt die Vergrî·erung fÅr einen Font. XMult ist die Skalierung in X-,     */
/* YMult die Vergrî·erung in Y-Richtung.                                      */
/*                                                                            */
/******************************************************************************/

void PixFontSetScale (HFONT Font, unsigned char XMult, unsigned char YMult)
{
    /* PrÅfen ob die Parameter korrekt sind */
    if ((XMult == 0) || (YMult == 0)) {
        /* Fehler */
        return;
    }

    /* Neue Werte Åbernehmen */
    Font->FontXMult = XMult;
    Font->FontYMult = YMult;

}






/******************************************************************************/
/*                                                                            */
/* PixFontSetDirection:                                                       */
/*                                                                            */
/* Setzt die Ausgaberichtung fÅr den Font. ZulÑssige Werte sind HORIZ_DIR     */
/* (horizontale Ausgabe) und VERT_DIR (vertikale Ausgabe).                    */
/*                                                                            */
/******************************************************************************/

void PixFontSetDirection (HFONT Font, unsigned Dir)
{
    /* Parameter prÅfen */
    if ((Dir != HORIZ_DIR) && (Dir != VERT_DIR)) {
        /* Parameterfehler */
        return;
    }

    /* Wert Åbernehmen */
    Font->FontDir = Dir;
}





/******************************************************************************/
/*                                                                            */
/* PixFontSetColor:                                                           */
/*                                                                            */
/* Setzt die Farbe fÅr die Textausgabe. Der farbwert wird auf die maximal     */
/* unterstÅtzte Farbe des Adapters begrenzt.                                  */
/*                                                                            */
/******************************************************************************/

void PixFontSetColor (HFONT Font, unsigned Color)
{
    unsigned MaxColor = (unsigned) getmaxcolor ();

    if (Color > MaxColor) {
        Font->FontColor = MaxColor;
    } else {
        Font->FontColor = Color;
    }

}





/******************************************************************************/
/*                                                                            */
/* PixFontSetJustify:                                                         */
/*                                                                            */
/* Legt die Ausrichtung des Fonts bei der Ausgabe fest. Die Parameter         */
/* entsprechen denen der Funktion settextjustify.                             */
/*                                                                            */
/******************************************************************************/

void PixFontSetJustify (HFONT Font, unsigned Horiz, unsigned Vert)
{
    /* Werte Åbernehmen */
    Font->FontHoriz = Horiz;
    Font->FontVert  = Vert;
}






void PixFontWriteHChar (HFONT Font, unsigned X0, unsigned Y0, char C)
{

    int X, Y;
    unsigned XM, YM;
    char *CP1,*CP2;
    unsigned char B, Mask;
    unsigned FX, FY;

    unsigned FontColor = Font->FontColor;



    CP1 = (char *) Font->FontPtr + C * Font->FontYSize * ((Font->FontXSize + 7) / 8);
    Y = Y0;
    FY = Font->FontYSize;
    while (FY--) {

        /* Y-Mult Schleife */
        YM = Font->FontYMult;
        while (YM--) {

            FX = Font->FontXSize;
            Mask = 0x80;
            CP2 = CP1;
            X = X0;
            while (FX--) {

                /* Wenn notwendig neues Byte laden */
                if (Mask == 0x80) {
                    B = *CP2++;
                }

                /* Bit prÅfen, je nachdem Anzahl Punkte setzen */
                if (B & Mask) {
                    /* FontXMult Punkte setzen */
                    XM = Font->FontXMult;
                    while (XM--) {
                        putpixel (X++, Y, FontColor);
                    }
                } else {
                    /* FontXMult Punkte nicht setzen */
                    X += Font->FontXMult;
                }

                /* Maske rotieren */
                asm ror     [Mask], 1

            }

            /* NÑchster Y-Wert */
            Y++;

        }

        /* NÑchste Reihe im Font adressieren */
        CP1 += (Font->FontXSize + 7) / 8;

    }


}



void PixFontWriteVChar (HFONT Font, unsigned X0, unsigned Y0, char C)
{
    int X, Y;
    unsigned XM, YM;
    char *CP1,*CP2;
    unsigned char B, Mask;
    unsigned FX, FY;

    unsigned FontColor = Font->FontColor;



    CP1 = (char *) Font->FontPtr + C * Font->FontYSize * ((Font->FontXSize + 7) / 8);
    X = X0;
    FY = Font->FontYSize;
    while (FY--) {

        /* Y-Mult Schleife */
        YM = Font->FontYMult;
        while (YM--) {

            FX = Font->FontXSize;
            Mask = 0x80;
            CP2 = CP1;
            Y = Y0;
            while (FX--) {

                /* Wenn notwendig neues Byte laden */
                if (Mask == 0x80) {
                    B = *CP2++;
                }

                /* Bit prÅfen, je nachdem Anzahl Punkte setzen */
                if (B & Mask) {
                    /* FontXMult Punkte setzen */
                    XM = Font->FontXMult;
                    while (XM--) {
                        putpixel (X, Y--, FontColor);
                    }
                } else {
                    /* FontXMult Punkte nicht setzen */
                    Y -= Font->FontXMult;
                }

                /* Maske rotieren */
                asm ror     [Mask], 1

            }

            /* NÑchster Y-Wert */
            X++;

        }

        /* NÑchste Reihe im Font adressieren */
        CP1 += (Font->FontXSize + 7) / 8;

    }

}





void PixFontWriteXY (HFONT Font, int X, int Y, char *S)
{
    /* Grî·e des Fonts in der aktuellen Vergî·erung berechnen */
    unsigned XSize = Font->FontXSize * (unsigned) Font->FontXMult;
    unsigned YSize = Font->FontYSize * (unsigned) Font->FontYMult;

    /* Lange des Strings holen und merken */
    unsigned Len = strlen (S);


    /* Je nach Ausgaberichtung unterscheiden */
    switch (Font->FontDir) {


        case HORIZ_DIR:

            /* Anfangsposition je nach Alignment korrigieren */
            switch (Font->FontHoriz) {

                case LEFT_TEXT:
                    /* Stimmt bereits */
                    break;

                case CENTER_TEXT:
                    X -= (Len * XSize) / 2;
                    break;

                case RIGHT_TEXT:
                    X -= (Len * XSize);
                    break;

            }

            switch (Font->FontVert) {

                case BOTTOM_TEXT:
                    Y -= YSize;
                    break;

                case CENTER_TEXT:
                    Y -= (YSize / 2);
                    break;

                case TOP_TEXT:
                    /* Stimmt bereits */
                    break;

            }


            /* Und den Text ausgeben */
            while (Len--) {
                PixFontWriteHChar (Font, X, Y, *S);
                S++;
                X += XSize;
            }

            break;


        case VERT_DIR:

            /* Anfangsposition je nach Alignment korrigieren */
            switch (Font->FontHoriz) {

                case LEFT_TEXT:
                    X -= YSize;
                    break;

                case CENTER_TEXT:
                    X -= (YSize / 2);
                    break;

                case RIGHT_TEXT:
                    /* Stimmt bereits */
                    break;

            }

            switch (Font->FontVert) {

                case BOTTOM_TEXT:
                    Y -= Len * XSize;
                    break;

                case CENTER_TEXT:
                    Y -= (Len * XSize) / 2;
                    break;

                case TOP_TEXT:
                    /* Stimmt bereits */
                    break;

            }

            /* Text ausgeben */
            while (Len--) {
                Y += XSize;
                PixFontWriteVChar (Font, X, Y, *(S+Len));
            }

            break;

    }

    /* Ende */

}










void * Get8x14FontPtr (void)
{
    asm mov     ax, 1130h
    asm mov     bh, 02h         /* 8x14 Font */
    asm push    bp
    asm push    si
    asm push    di
    asm int     10h
    asm mov     ax, bp
    asm pop     di
    asm pop     si
    asm pop     bp
    return MK_FP (_ES, _AX);
}






void * Get8x16FontPtr (void)
{
    asm mov     ax, 1130h
    asm mov     bh, 06h         /* 8x16 Font */
    asm push    bp
    asm push    si
    asm push    di
    asm int     10h
    asm mov     ax, bp
    asm pop     di
    asm pop     si
    asm pop     bp
    return MK_FP (_ES, _AX);
}










