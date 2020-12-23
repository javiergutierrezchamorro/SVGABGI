/**********************************************************************

svgademo.c - Demo einiger Mîglichkeiten des SVGA.BGI-Treibers

In tiefer Dankbarkeit fÅr den tollen Treiber und zur StÑrkung der
C-Fraktion developed by

    Friedlieb Jung-Merkelbach
    Burbachstra·e 41
    W-5270 Gummersbach 31

Und nun der gleiche Spruch wie in palette.c, mittels cut&paste reinkopiert:
Der Code hat mich zwar einige Arbeit gekostet, ist aber andererseits sicher
nicht geeignet, die Welt zu retten. Daher habe ich nichts gegen eine Nutzung,
auch innerhalb kommerzieller Programme.
Nett wÑre aber bei Verbesserungen/Korrekturen oder interessanten neuen Paletten
mitsamt Anwendungsbeispiel die öbersendung einer entsprechenden Diskette an
meine obenstehende Adresse.  :-)

**********************************************************************/

# include <alloc.h>
# include <bios.h>
# include <graphics.h>
# include <dos.h>
# include <stdio.h>
# include <conio.h>
# include <stdlib.h>
# include <time.h>
# include <signal.h>

# include "palette.h"


int GraphDriver,
    GraphMode = 1,  /* Autodetect */
    MaxX,
    MaxY;


void quit(void)  /* Programmabbruch durch Ctrl-Break oder ESC */
{
    closegraph();
    printf("Bye...");
    exit(1);
}


void wait(int sek) /* wartet auf Tastendruck oder bis zu sek Sekunden */
{
    time_t ticks = clock();

    while (kbhit())  /* Tastaturpuffer leeren, ESC auswerten */
        if (getch() == 27) /* Escape */
            quit();

    while (!kbhit())
        if ((clock() - ticks) / CLK_TCK > sek)
            break;
}


/* zeigt (spalten * zeilen) Farben am Bildschirm an */
void displayColors(int spalten, int zeilen)
{
    int i,
        j,
        breite = (int) (MaxX / (double) (spalten) + 0.5),
        x = 0;

    if (spalten * zeilen != 256)
        return; /* étsch! */

    for (i = 0; i < spalten; i++)
    {
        for (j = 0; j < zeilen; ++j)
        {
            setfillstyle(SOLID_FILL, i + (j * spalten));
            bar(x, MaxY * j / (double) zeilen,
                x + breite, MaxY * (j + 1) / (double) zeilen);
        }
        x += breite;
    }
    return;
}





void far *msg_buf = NULL;      /* Imagebuffer fÅr msg_on() und msg_off() */
int      msg_x,                /*  - dessen linke obere Ecke, x */
         msg_y;                /*  - dessen linke obere Ecke, y */

void msg_on(char *msg)  /* gibt eine Meldung in der Bildschirmmitte aus */
{
    int w,
        h;
    int end_x,
        end_y;

    if (MaxX <= 320)  /* wg. negativen x-Koordinaten und */
        return;       /* vielleicht nicht korrektem Clipping */

    settextjustify(CENTER_TEXT, CENTER_TEXT);
    settextstyle(DEFAULT_FONT, HORIZ_DIR, 1);
    setfillstyle(SOLID_FILL, 30);
    setcolor(0);
    w = textwidth(msg);
    h = textheight(msg);

    if ((msg_buf = farmalloc( /* won 1st price in readable-programming contest */
        imagesize(msg_x = (MaxX - w) / 2 - 5, msg_y = (MaxY - h) / 2 - 2,
                  end_x = (MaxX + w) / 2 + 5, end_y = (MaxY + h) / 2 + 2))) == NULL)
            return;
    getimage(msg_x, msg_y, end_x, end_y, msg_buf);
    bar(msg_x, msg_y, end_x, end_y);
    outtextxy(MaxX / 2, MaxY / 2, msg);
    return;
}


void msg_off(void)   /* schaltet mit msg_on() erzeugte Meldung wieder aus */
{
    if (msg_buf == NULL)
        return;
    putimage(msg_x, msg_y, msg_buf, COPY_PUT);
    farfree(msg_buf);
    msg_buf = NULL;
    return;
}



void ShadowText(int x, int y, int tfarbe, int sfarbe, char *text)
{   /* gibt schattierten Text aus */
    int altefarbe = getcolor();

    setcolor(sfarbe);
    outtextxy(x + 1, y + 1, text);        /* dezent */
    /* outtextxy(x + 2, y + 2, text); */  /* weniger dezent */
    setcolor(tfarbe);
    outtextxy(x, y, text);
    setcolor(altefarbe);
    return;
}



void errex(char *text) /* Beendet das Programm mit einer Fehlermeldung */
{
    printf("%s.\nProgramm erfordert VGA-Karte.\n", text);
    exit(1);
}


typedef void (*VoidFunPtr) (void);

/* ruft showfunc auf, zeigt text an und wartet */
void show(VoidFunPtr showfunc, char *text)
{
    if (showfunc != NULL)
        showfunc();
    msg_on(text);
    wait(5);
    msg_off();
    wait(5);
    return;
}


void init(void)   /* initialisiert die Grafik */
{
    extern void _Cdecl SVGA_driver(void);

    if ((GraphDriver = installuserdriver("SVGA", NULL)) < 0)
        errex("Treiber kann nicht installiert werden");
    if (registerbgidriver(SVGA_driver) < 0)
        errex("Treiber kann nicht registriert werden");
    if (registerbgifont(sansserif_font) < 0)
        errex("Zeichensatz kann nicht registriert werden");
    initgraph(&GraphDriver, &GraphMode, "");
    if (graphresult() != grOk )
        errex("Grafik kann nicht initialisiert werden");

    /*
     *  Abfrage auf Modus 0. msg_on() wÅrde sonst Åber den Bildschirmrand
     *  schreiben, was Åbelste Folgen haben kann. Ausprobieren!
     */
    if ((MaxX = getmaxx()) <= 320)
    {
        int gm = getgraphmode();

        restorecrtmode();
        printf("Ihre VGA-Karte wird von SVGA leider nicht ausreichend unterstÅtzt.\n");
        printf("Sie kînnen die Demo anschauen, werden aber auf erklÑrende Texte\n");
        printf("verzichten mÅssen. Investieren Sie in Ihre Hardware. (Taste...) ");
        do
            if (getch() == 27) /* Escape */
                quit();
        while (kbhit());
        setgraphmode(gm);
    }
    MaxY = getmaxy();
    return;
}



void intro(void) /* Programmstart: BegrÅ·ung der GÑste, Agenda, ... */
{
    fade(FADE_BLACKOUT, 0, 0);
    settextjustify(CENTER_TEXT, CENTER_TEXT);
    settextstyle(SANS_SERIF_FONT, HORIZ_DIR, 6);
    ShadowText(MaxX / 2, MaxY / 4, LIGHTBLUE, LIGHTGRAY, "SVGA BGI-Treiber");
    settextstyle(SANS_SERIF_FONT, HORIZ_DIR, 4);
    ShadowText(MaxX / 2, MaxY / 2, LIGHTBLUE, LIGHTGRAY, "Demoprogramm");
    ShadowText(MaxX / 2, MaxY / 4 * 3, LIGHTBLUE, LIGHTGRAY, "Da wei· man, was man hat...");
    ShadowText(MaxX / 2, MaxY / 4 * 3 + 1.2 * textheight("X"),
        LIGHTBLUE, LIGHTGRAY, "(Bitte zurÅcklehnen)");
    fade(FADE_UP, 120, 1);
    wait(5);
    fade(FADE_DOWN, 120, 1);

    cleardevice();
    ShadowText(MaxX / 2, MaxY / 4, YELLOW, LIGHTBLUE, "Die Frage ist ja eigentlich, was man");
    ShadowText(MaxX / 2, MaxY / 4 + 1.2 * textheight("X"),
        YELLOW, LIGHTBLUE, "mit 256 Farben blo· machen soll.");
    ShadowText(MaxX / 2, MaxY / 2, YELLOW, LIGHTBLUE,
        "Einige Anregungen finden Sie hier.");
    fade(FADE_UP, 120, 1);
    wait(5);

    fade(FADE_DOWN, 50, 4);
    cleardevice();
    fade(FADE_RESTORE, 0, 0);

    return;
}


void balls(void)
{
    int x,
        y,
        size,               /* Grî·enfaktor */
        color,              /* verwendete Farbe */
        startcolor;         /* StartNr. der Farbskala */

    set32Hpalette();
    setlinestyle(SOLID_LINE, 0, THICK_WIDTH);
    randomize();

    while (kbhit())
        getch();

    while (!kbhit())
    {
        x = random(MaxX);
        y = random(MaxY);
        startcolor = random(7) * 32 + 32;
        size = random(3) == 2 ? 2 : 1;    /* mehr kleine BÑlle */

        if (bioskey(2) & 0x01)   /* linke Shift-Taste: andere Palette */
            set32palette();
        else if (bioskey(2) & 0x02) /* rechte Shift-Taste: wieder zurÅck */
            set32Hpalette();
        for (color = 0; color < 32; ++color)
        {
            setcolor(startcolor + 32 - color);
            circle(x, y, color * size);
        }
    }
    return;
}



void main(void)
{
    signal(SIGINT, quit);
    init();

    if (MaxX > 320)  /* Schrift ist nicht lesbar bei 320 * 200 */
        intro();

    displayColors(16, 16);
    msg_on(" Voreingestellte Palette nach initgraph() ");
    wait(5);
    msg_off();
    wait(5);

    displayColors(64, 4);
    msg_on(" Das Gleiche, nur etwas anders dargestellt ");
    wait(5);
    msg_off();
    wait(5);

    show(set64palette, " 4 Skalen zu je 64 Werten, Grundfarben + Grau ");
    show(set32palette, " Standardfarben + 7 Skalen zu je 32 Werten ");

    displayColors(16, 16);
    show(plane, " FarbflÑchen ");
    show(setuniformpalette, " \"Uniforme Quantisierung\" ");

    displayColors(64, 4);
    show(setflowpalette, " Ein Beispiel mit flie·enden öbergÑngen ");

    cleardevice();
    set32Hpalette();
    balls();

    do
        getch();
    while (kbhit());

    closegraph();
}

