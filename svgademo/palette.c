/***********************************************************************

palette.c - stellt einige Funktionen zur Manipulation der Farbpalette
            von VGA-Karten zur VerfÅgung.
            Entwickelt fÅr den SVGA-Treiber von Ullrich von Bassewitz,
            sollte aber auch auf jeder IBM 8514-Karte in Verbindung mit
            dem entsprechenden BGI-Treiber laufen.

            Friedlieb Jung-Merkelbach
            Burbachstra·e 41
            W-5270 Gummersbach 31

            Der Code hat mich zwar einige Arbeit gekostet, ist aber
            andererseits sicher nicht geeignet, die Welt zu retten.
            Daher habe ich nichts gegen eine Nutzung, auch innerhalb
            kommerzieller Programme.
            Nett wÑre aber bei Verbesserungen/Korrekturen oder interessanten
            neuen Paletten mitsamt Anwendungsbeispiel die öbersendung einer
            entsprechenden Diskette an meine obenstehende Adresse.  :-)

***********************************************************************/

# include <dos.h>
# include <graphics.h>

# include "palette.h"

typedef unsigned char Byte;

typedef struct   /* 1 Eintrag in der VGA-Palette */
{
    Byte red;
    Byte green;
    Byte blue;
} RGB_Entry;


/*
 *  Die folgende Tabelle sollte fÅr jede VGA-Karte brauchbare Ergebnisse
 *  bringen. Eventuell werden aber auch Korrekturen erforderlich; die
 *  entsprechenden Werte mÅ·ten ausprobiert oder (wem das lieber ist)
 *  "empirisch ermittelt" werden.
 */
static RGB_Entry EGAPalette[16] =
{  /*  Rot  GrÅn  Blau */
    { 0x00, 0x00, 0x00 } ,     /*  0  Schwarz     */
    { 0x00, 0x00, 0xAA } ,     /*  1  Blau        */
    { 0x00, 0xAA, 0x00 } ,     /*  2  GrÅn        */
    { 0x00, 0xAA, 0xAA } ,     /*  3  Zyan        */
    { 0xAA, 0x00, 0x00 } ,     /*  4  Rot         */
    { 0xAA, 0x00, 0xAA } ,     /*  5  Magenta     */
    { 0xAA, 0x55, 0x00 } ,     /*  6  Braun       */
    { 0xAA, 0xAA, 0xAA } ,     /*  7  Hellgrau    */
    { 0x57, 0x57, 0x57 } ,     /*  8  Dunkelgrau  */
    { 0x55, 0x55, 0xFF } ,     /*  9  Hellblau    */
    { 0x00, 0xFF, 0x00 } ,     /* 10  HellgrÅn    */
    { 0x00, 0xFF, 0xFF } ,     /* 11  Hellzyan    */
    { 0xFF, 0x55, 0x55 } ,     /* 12  Hellrot     */
    { 0xFF, 0x55, 0xFF } ,     /* 13  Hellmagenta */
    { 0xFF, 0xFF, 0x00 } ,     /* 14  Gelb        */
    { 0xFF, 0xFF, 0xFF }       /* 15  Wei·        */
} ;

/************************************************************************

         int fade(enum fade_mode modus, int steps, int milli)

blendet die 16 ersten Farben auf oder ab. Eine Erweiterung auf mehr
Farben ist in der derzeitigen Form nicht sinnvoll, da nur die ersten
16 Farben (nÑmlich Åber die obige Tabelle) bekannt sind.

return 0 bei Erfolg, -1 bei ungÅltigem Modus
GÅltige Modi (siehe palette.h):
    FADE_UP         blendet auf: von Schwarz zur vollen Helligkeit
    FADE_DOWN       blendet ab: von 'Total Normal' bis 'Stockdunkel'
    FADE_BLACKOUT   schaltet mit einem Schlag alle Lichter aus
    FADE_RESTORE    wieder an: Herstellung der Original-Farben

steps gibt die Anzahl der Schritte an, die fÅr das 'faden' verwendet
      werden.
millt gibt eine Zeit in Millisekunden an, die nach jedem Step
      gewartet wird.

Diese beiden Parameter werden nur bei FADE_UP und FADE_DOWN ausgewertet.

************************************************************************/

int fade(enum fade_mode modus, int steps, int milli)
{
    int i,
        loop;

    switch (modus)
    {
        case FADE_UP:
            for (loop = 0; loop < steps; ++loop)
            {
                for (i = 0; i < 16; i++)
                    setrgbpalette(i,
                        EGAPalette[i].red   * (loop / ((double) steps + 0.5)),
                        EGAPalette[i].green * (loop / ((double) steps + 0.5)),
                        EGAPalette[i].blue  * (loop / ((double) steps + 0.5)));
                delay(milli);
            }
            fade(FADE_RESTORE, 0 ,0);
            break;

        case FADE_DOWN:
            for (loop = steps; loop >= 0; --loop)
            {
                for (i = 0; i < 16; i++)
                    setrgbpalette(i,
                        EGAPalette[i].red   * (loop / ((double) steps + 0.5)),
                        EGAPalette[i].green * (loop / ((double) steps + 0.5)),
                        EGAPalette[i].blue  * (loop / ((double) steps + 0.5)));
                delay(milli);
            }
            fade(FADE_BLACKOUT, 0 ,0);
            break;

        case FADE_BLACKOUT:
            for (i = 0; i < 16; i++)
               setrgbpalette(i, 0, 0, 0);     /* Alles Schwarz */
            break;

        case FADE_RESTORE:
            for (i = 0; i < 16; i++)
                setrgbpalette(i,      /* Original EGA-Farben restaurieren */
                    EGAPalette[i].red,
                    EGAPalette[i].green,
                    EGAPalette[i].blue);
            break;

        default:
            return -1;
            /* break; */
    }
    return 0;
}


void plane(void)  /* Anregung aus c't 12/89, S. 168 */
{
    int r,
        g,
        b,
        i;

    for (i = 1; i >= 0; --i)
    {
        for (g = 0; g < 16; ++g)
            for (b = 0; b < 16; ++b)
                setrgbpalette(g + 16 * b, (i * 63) << 4, g << 4, b << 4);
        delay(2000);
        for (r = 0; r < 16; ++r)
            for (g = 0; g < 16; ++g)
                setrgbpalette(r + 16 * g, r << 4, g << 4, (i * 63) << 4);
        delay(2000);
        for (r = 0; r < 16; ++r)
            for (b = 0; b < 16; ++b)
                setrgbpalette(r + 16 * b, r << 4, (i * 63) << 4, b << 4);
        delay(2000);
    }
    return;

}


void setuniformpalette(void)  /* siehe c't 12/89, S. 168 */
{
    int r,
        g,
        b,
        i = 0;

    for (r = 0; r < 64; r += 9)
        for (g = 0; g < 64; g += 9)
            for (b = 0; b < 64; b += 21)
                setrgbpalette(i++, r << 2, g << 2, b << 2);
    return;
}


/************************************************************************

                   void set32palette(void)

setzt eine Palette aus folgenden Komponenten:
  16 Standardfarben
  16 dazu komplementÑre Farben
   7 Helligkeitsskalen zu je 32 Abstufungen mit den Farben
     Rot, GrÅn, Blau, Gelb, Cyan, Magenta und Grau

************************************************************************/

void set32palette(void)
{
    int i;

    for (i = 0; i < 16; i++)
    {
       setrgbpalette(i,                 /* Original EGA Farben */
           EGAPalette[i].red,
           EGAPalette[i].green,
           EGAPalette[i].blue);
       setrgbpalette(i + 16,            /* KomplementÑrfarben */
           0xFF - EGAPalette[i].red,
           0xFF - EGAPalette[i].green,
           0xFF - EGAPalette[i].blue);
    }
    for (i = 0; i < 32; i++)
    {                     /*     Rot    GrÅn    Blau  */
       setrgbpalette(i +  32, i << 3,      0,      0);    /* Rot     */
       setrgbpalette(i +  64,      0, i << 3,      0);    /* GrÅn    */
       setrgbpalette(i +  96,      0,      0, i << 3);    /* Blau    */
       setrgbpalette(i + 128, i << 3, i << 3,      0);    /* Gelb    */
       setrgbpalette(i + 160,      0, i << 3, i << 3);    /* Cyan    */
       setrgbpalette(i + 192, i << 3,      0, i << 3);    /* Magenta */
       setrgbpalette(i + 224, i << 3, i << 3, i << 3);    /* Grau    */
    }
    return;
}


/************************************************************************

                   void set32Hpalette(void)

setzt eine Palette aus folgenden Komponenten:
  16 Standardfarben
  16 dazu komplementÑre Farben
   7 Helligkeitsskalen zu je 32 Abstufungen mit den Farben
     Rot, GrÅn, Blau, Gelb, Cyan, Magenta und Grau
     genau wie set32palette(), jedoch beginnend in der zweiten
     HÑlfte der mîglichen Werte

************************************************************************/

void set32Hpalette(void)
{
    int i;

    for (i = 0; i < 16; i++)
    {
       setrgbpalette(i,                 /* Original EGA Farben */
           EGAPalette[i].red,
           EGAPalette[i].green,
           EGAPalette[i].blue);
       setrgbpalette(i + 16,            /* KomplementÑrfarben */
           0xFF - EGAPalette[i].red,
           0xFF - EGAPalette[i].green,
           0xFF - EGAPalette[i].blue);
    }
    for (i = 32; i < 64; i++)
    {                     /*     Rot    GrÅn    Blau  */
       setrgbpalette(i,       i << 2,      0,      0);    /* Rot     */
       setrgbpalette(i +  32,      0, i << 2,      0);    /* GrÅn    */
       setrgbpalette(i +  64,      0,      0, i << 2);    /* Blau    */
       setrgbpalette(i +  96, i << 2, i << 2,      0);    /* Gelb    */
       setrgbpalette(i + 128,      0, i << 2, i << 2);    /* Cyan    */
       setrgbpalette(i + 160, i << 2,      0, i << 2);    /* Magenta */
       setrgbpalette(i + 192, i << 2, i << 2, i << 2);    /* Grau    */
    }
    return;
}


/************************************************************************

                   void set64palette(void)

setzt eine Palette mit 4 Helligkeitsskalen zu je 64 Werten, mit den drei
Grundfarben Rot, GrÅn und Blau sowie Grau als "reine Mischfarbe"

************************************************************************/

void set64palette(void)
{
    int i;

    for (i = 0; i < 64; i++)
    {                   /*       Rot    GrÅn    Blau  */
       setrgbpalette(      i, i << 2,      0,      0);    /* Rotskala  */
       setrgbpalette(i +  64,      0, i << 2,      0);    /* GrÅnskala */
       setrgbpalette(i + 128,      0,      0, i << 2);    /* Blauskala */
       setrgbpalette(i + 192, i << 2, i << 2, i << 2);    /* Grauskala */
    }
    return;
}


void setflowpalette(void) /* ein Beispiel fÅr flie·ende FarbÅbergÑnge */
{
    int i;

    for (i = 0; i < 64; i++)
    {                        /*         Rot           GrÅn           Blau  */
       setrgbpalette(      i,        i << 2, (63 - i) << 2,             0);
       setrgbpalette( i + 64, (63 - i) << 2,             0,        i << 2);
       setrgbpalette(i + 128,             0,        i << 2, (63 - i) << 2);
    }
    for (i = 0; i < 32; i++)
    {
       setrgbpalette(i + 192,        i << 3, (31 - i) << 3,       i << 3);
       setrgbpalette(i + 224, (31 - i) << 3, (31 - i) << 3,       i << 3);
    }
    return;
}

