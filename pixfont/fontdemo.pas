PROGRAM FontDemo;


{            Beispielprogramm zur Anwendung des Moduls PixFont

                   Ullrich von Bassewitz am 12.05.1992

  ACHTUNG:

    * Das Programm erwartet die Fonts im aktuellen Verzeichnis.

    * Es wird der Bildschirm-Modus 640*480 Autodetect verwendet. Bei Karten,
      die diesen Modus nicht kennen erfolgt Abbruch mit einer Fehlermeldung
      --> die Konstante DriverMode weiter unten anpassen oder durch Aus-
      klammern des DEFINEs SVGA den EGAVGA-Treiber verwenden.

}


{ Letzte énderung: 12.05.1992 }

{ Diverse Compiler-Switches: }

{$F-     Force Far Calls Off  }
{$O-     No Overlays Allowed  }
{$A+     Align Data at Word Boundary }
{$B-     Short Circuit Boolean Evaluation }
{$I-     I/O Checking Off     }
{$D+     Debug Information On }
{$L+     Local Symbols On     }
{$G-     No 286-Code }
{$M      16384, 128000, 655360    Speicher festlegen }

{$IFDEF Debug }
  {$R+   Range Checking On    }
  {$S+   Stack Checking On    }
{$ELSE}
  {$R-   Range Checking Off   }
  {$S-   Stack Checking Off   }
{$ENDIF}




{ Folgendes DEFINE lîschen wenn der EGAVGA-Treiber verwendet werden soll }
{$DEFINE SVGA}



USES
  CRT,            { wegen ReadKey }
  DOS,            { DOS-Interface }
  Graph,          { Turbo Standard-Modul }
  PixFont;        { Pixelfonts }




CONST
  DriverMode = 2;   { verwende 640*480 Autodetect }




TYPE
  PSpecialPixFont = ^TSpecialPixFont;
  TSpecialPixFont = OBJECT (TPixFont)

    FontName : STRING [8];       { Name des Fonts }

    CONSTRUCTOR Load (Name: PathStr; XSize, YSize: WORD);
    { Neuer Konstruktor der den Font gleich lÑdt. Verwendet au·erdem
      RandomColor um die Farbe auf einen Zufallswert zu setzen.
      Aus dem Åbergebenen Namen wird au·erdem FontName belegt.
    }

    PROCEDURE RandomColor;
    { Belegt die Farbe mit einem (hellen) Zufallswert }

    PROCEDURE ShowDemo (Y: WORD);
    { Gibt an der Position Y den Demo-Text aus }

  END;




VAR
  { Diverse Font-Objekte }
  Font8x11          : TSpecialPixFont;
  Font8x12          : TSpecialPixFont;
  Font8x14          : TSpecialPixFont;
  Font8x16          : TSpecialPixFont;
  Font8x16ant       : TSpecialPixFont;
  Font8x16bro       : TSpecialPixFont;
  Font8x16cou       : TSpecialPixFont;
  Font8x16med       : TSpecialPixFont;
  Font8x16rom       : TSpecialPixFont;
  Font8x16san       : TSpecialPixFont;
  Font8x16scr       : TSpecialPixFont;
  Font16x16         : TSpecialPixFont;


CONST
  { Merker ob Grafik eingeschaltet ist }
  GraphicsOn : BOOLEAN = FALSE;

  { Test-Text den die Font-Objekte ausgeben }
  FoxText    = 'The quick brown fox jumps over the lazy dog 1234567890 times';

  { Anzahl obiger Fonts }
  FontCount = 11;

  { Ein Array mit Zeigern auf alle Font-Objekte }
  Font : ARRAY [1..FontCount] OF PSpecialPixFont = (
    @Font8x11,
    @Font8x12,
    @Font8x14,
    @Font8x16,
    @Font8x16ant,
    @Font8x16bro,
    @Font8x16cou,
    @Font8x16med,
    @Font8x16rom,
    @Font8x16san,
    @Font8x16scr
  );



{ -------------------------------------------------------------------------- }
{ Kleinkruscht }


PROCEDURE GraphOff;
{ Schaltet wenn nîtig die Grafik aus }

BEGIN
  IF (GraphicsOn) THEN BEGIN
    CloseGraph;
    GraphicsOn := FALSE;
  END;
END;



PROCEDURE Abort (Msg: STRING);

BEGIN
  GraphOff;
  Writeln (Msg);
  Halt (1);
END;


PROCEDURE GraphOn;

VAR
  GraphDriver, GraphMode : INTEGER;
  I                      : WORD;
  Result                 : INTEGER;

BEGIN
{$IFDEF SVGA}
  { SVGA.BGI verwenden }

  GraphDriver := InstallUserDriver ('SVGA', NIL);
  IF (GraphDriver < 0) THEN Abort ('Fehler beim Installieren von SVGA.BGI');

{$IFNDEF VER60}
  { Korrektur fÅr Versionen bis 5.5 }
  Inc (GraphDriver, 5);
{$ENDIF}

  GraphMode := DriverMode;

  { Grafik einschalten, Palette setzen }
  InitGraph (GraphDriver, GraphMode, '');
  Result := GraphResult;
  IF (Result < 0) THEN BEGIN
    Abort ('Fehler beim Einschalten der Grafik: ' + GraphErrorMsg (Result));
  END;

  { Vermerken das die Grafik an ist }
  GraphicsOn := TRUE;
{$ELSE}

  { EGAVGA verwenden (nur im VGA-Modus wegen Get8xYYFontPtr) }
  GraphDriver := Detect;
  InitGraph (GraphDriver, GraphMode, GetEnv ('BGIPATH'));
  IF (Result < 0) THEN BEGIN
    Abort ('Fehler beim Einschalten der Grafik: ' + GraphErrorMsg (Result));
  END;

  { Vermerken das die Grafik an ist }
  GraphicsOn := TRUE;

  { PrÅfen ob der VGA-Modus eingeschaltet ist }
  IF (GraphDriver <> VGA) OR (GraphMode <> VGAHi) THEN BEGIN
    Abort ('Programm lÑuft nur unter VGA''s');
  END;
{$ENDIF}
END;


{ -------------------------------------------------------------------------- }
{ Methoden von TSpecialPixFont }


CONSTRUCTOR TSpecialPixFont.Load (Name: PathStr; XSize, YSize: WORD);
{ Neuer Konstruktor der den Font gleich lÑdt }

VAR
  Result : INTEGER;
  NumStr : STRING [7];
  Dir    : DirStr;
  Ext    : ExtStr;


BEGIN
  { Zuerst den Init-Konstruktor verwenden }
  Init (NIL, XSize, YSize);

  { Dann den Font laden }
  Result := LoadFont (Name, XSize, YSize);
  IF (Result <> 0) THEN BEGIN
    Str (Result, NumStr);
    Abort ('Fehler ' + NumStr + ' beim Laden von ' + Name);
  END;

  { Name des Fonts aus dem Dateinamen bestimmen }
  FSplit (Name, Dir, FontName, Ext);

  { Farbe noch nett belegen }
  RandomColor;
END;






PROCEDURE TSpecialPixFont.RandomColor;
{ Belegt die Farbe mit einem (hellen) Zufallswert }
BEGIN
  IF (Random (2) = 0) THEN BEGIN
    SetColor (Random (7) + 1);
  END ELSE BEGIN
    SetColor (Random (7) + 9);
  END;
END;




PROCEDURE TSpecialPixFont.ShowDemo (Y: WORD);
{ Gibt an der Position Y den Demo-Text aus }

BEGIN
  { Zuerst den eigen Namen ausgeben }
  SetFontSize (1, 1);
  SetFontJustify (CenterText, TopText);
  WriteXY (GetmaxX DIV 2, Y, FontName + ' : ' + FoxText);
END;


{ -------------------------------------------------------------------------- }
{ Hauptprogramm }



PROCEDURE Demo;
{ Gibt die Texte in allen Fonts aus }

VAR
  Y        : WORD;
  I        : WORD;
  YInc     : WORD;


BEGIN
  { Erstmal Titel ausgeben }
  Font16x16.SetFontJustify (CenterText, TopText);
  Font16x16.WriteXY (GetMaxX DIV 2, 0, 'Pixelfont - Demo');

  { Startzeile festlegen }
  Y := 30;

  { Abstand zwischen den Zeilen ausrechnen }
  YInc := (GetMaxY - Y) DIV FontCount;

  { Dann der Reihe nach die Fonts was sagen lassen }
  FOR I := 1 TO FontCount DO BEGIN
    Font [I]^.ShowDemo (Y);
    Inc (Y, YInc);
  END;
END;





BEGIN
  { Zufallsgenerator initialisieren }
  Randomize;

  { Grafik einschalten }
  GraphOn;

  { Font-Objekte initialisieren }
  Font8x11.Load ('8x11.FNT', 8, 11);
  Font8x12.Load ('8x12.FNT', 8, 12);
  Font8x16ant.Load ('8x16ANT.FNT', 8, 16);
  Font8x16bro.Load ('8x16BRO.FNT', 8, 16);
  Font8x16cou.Load ('8x16COU.FNT', 8, 16);
  Font8x16med.Load ('8x16MED.FNT', 8, 16);
  Font8x16rom.Load ('8x16ROM.FNT', 8, 16);
  Font8x16san.Load ('8x16SAN.FNT', 8, 16);
  Font8x16scr.Load ('8x16SCR.FNT', 8, 16);
  Font16x16.Load ('16x16.FNT', 16, 16);

  { Sonderbehandlung: Die folgenden Fonts liegen im ROM }
  Font8x14.Init (Get8x14FontPtr, 8, 14);
  Font8x16.Init (Get8x16FontPtr, 8, 16);
  Font8x14.RandomColor;
  Font8x16.RandomColor;
  Font8x14.FontName := '8x14';
  Font8x16.FontName := '8x16';

  { Und jetzt Text ausgeben }
  Demo;

  { Auf Taste warten }
  REPEAT UNTIL (ReadKey <> #00);

  { Grafik ausschalten und Ende }
  GraphOff;
END.
