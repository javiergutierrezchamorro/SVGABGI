PROGRAM PCXView;


{ Kleiner Viewer fÅr PCX-Dateien (ZSoft Paintbrush) als Demo fÅr die Benutzung
  des SVGA.BGI Treibers.

                      (C) 1991 Ullrich von Bassewitz

  énderungen:

  28.11.1991 (Uz)
  Anpassung an Version 3.0 des Treibers.

  03.05.1995 (Uz)
  HRes und VRes wurden falsch interpretiert.

}



{$M 16384, 16384, 16384}
{$R-}
{$I-}
{$G-}
{$X-}
{$O-}
{$V-}
{$A+}
{$X-}



USES
  DOS,
  CRT,
  Graph;




TYPE
  CharPtr   = ^Char;
  DWord     = RECORD
    LoWord  : WORD;
    HiWord  : WORD;
  END;

  TPaletteEntry = RECORD
    Red         : BYTE;
    Green       : BYTE;
    Blue        : BYTE;
  END;

  TPalette      = ARRAY [BYTE] OF TPaletteEntry;

  { Der Header eine PCX-Datei laut c't 8/91 }
  TPCXHeader      = RECORD
    Manufacturer  : BYTE;
    Version       : BYTE;
    Encoding      : (EncNone, EncRLE);
    PixelDepth    : BYTE;
    WX1           : WORD;
    WY1           : WORD;
    WX2           : WORD;
    WY2           : WORD;
    HRes          : WORD;               { Horizontale Auflîsung in DPI }
    VRes          : WORD;               { Vertikale Auflîsung in DPI }
    ColorMap      : ARRAY [0..15] OF TPaletteEntry;
    Reserved      : BYTE;
    PlaneCount    : BYTE;
    BytesPerLine  : WORD;
    PaletteInfo   : WORD;
    Filler        : ARRAY [1..58] OF BYTE;
  END;


VAR
  { Palette fÅr das Bild }
  Palette   : TPalette;

  { File-Header }
  Header    : TPCXHeader;

  { Datenpuffer }
  Buffer    : ARRAY [1..32768] OF BYTE;
  BufFill   : WORD;            { Anzahl Bytes im Puffer }
  BufIndex  : WORD;            { Index in den Puffer }

  { Die File-Variable fÅr das PCX-File }
  PCXFile   : File;

  { Anzahl Nutzbytes (Datenbytes) im File }
  DataBytes : LONGINT;



CONST
  { LÑnge des Fileheaders }
  HeaderSize    = 128;

  { Merker ob Grafikmodus aktiv }
  GraphicsOn : BOOLEAN = FALSE;


{ -------------------------------------------------------------------------- }





PROCEDURE GraphOff;
{ Schaltet wenn nîtig die Grafik aus }

BEGIN
  IF (GraphicsOn) THEN BEGIN
    CloseGraph;
    GraphicsOn := FALSE;
  END;
END;




FUNCTION FromASCIIZ (P : CharPtr) : STRING;
{ Wandelt einen ASCIIZ-String nach Pascal-String }

VAR
  S   : STRING;
  Len : BYTE ABSOLUTE S;              { Das LÑngenbyte }

BEGIN
  Len := 0;
  WHILE (P^ <> #00) DO BEGIN
    Inc (Len);
    S [Len] := P^;
    Inc (DWord (P).LoWord);           { Offset-Anteil erhîhen }
  END;

  { Ergebnis zuweisen }
  FromASCIIZ := S;
END;






PROCEDURE BlockRead (VAR F : File; VAR Data; Count : WORD);
{ Ersetzt die orginale Blockread-Routine durch eine mit Fehlercheck }

VAR
  BytesRead : WORD;

BEGIN
  System.BlockRead (F, Data, Count, BytesRead);
  IF (IOResult <> 0) OR (Count <> BytesRead) THEN BEGIN
    { Fehler beim Lesen }
    GraphOff;
    Writeln ('Fehler beim Lesen von ', FromASCIIZ (@FileRec (F).Name [0]));
    Close (F);
    InOutRes := 0;      { Ergebnis von Close ignorieren }
    Halt;
  END;
END;






PROCEDURE ReadControlData (VAR F : FILE);
{ Liest Header und Palette aus der Datei }

VAR
  I     : WORD;
  XRes  : WORD;
  YRes  : WORD;

BEGIN
  { Header lesen }
  BlockRead (F, Header, HeaderSize);

  { Header prÅfen }
  WITH Header DO BEGIN
    { X- und Y-Auflîsung rechnen }
    XRes := WX2 - WX1 + 1;
    YRes := WY2 - WY1 + 1;

    { Sicherheits-PrÅfung }
    IF (Manufacturer <> $0A) OR (Version <> 5) OR (Encoding <> EncRLE) OR
       (PixelDepth <> 8) OR (PlaneCount <> 1) OR (XRes > 1024) OR
       (YRes > 1280) THEN BEGIN
      { Falscher Header }
      GraphOff;
      Writeln ('Falscher Header !');
      Close (F);
      InOutRes := 0;      { Ergebnis von Close ignorieren }
      Halt;
    END;
  END;

  { Palette einlesen }
  Seek (F, FileSize (F) - SizeOf (Palette));
  BlockRead (F, Palette, SizeOf (Palette));

  { Anzahl Datenbytes errechnen (Dateigrî·e - Header - Palette) }
  DataBytes := FileSize (F) - SizeOf (Header) - SizeOf (Palette);
END;






PROCEDURE GraphOn;

VAR
  GraphDriver, GraphMode : INTEGER;
  I                      : WORD;
  Result                 : INTEGER;
  XRes  : WORD;
  YRes  : WORD;

BEGIN
  GraphDriver := InstallUserDriver ('SVGA', NIL);
  IF (GraphDriver < 0) THEN BEGIN
    Writeln ('Fehler beim installieren von SVGA.BGI');
    Halt;
  END;

  { Korrektur fÅr Versionen bis 5.5
  Inc (GraphDriver, 5);
  }

  { X- und Y-Auflîsung rechnen }
  XRes := Header.WX2 - Header.WX1 + 1;
  YRes := Header.WY2 - Header.WY1 + 1;

  { Jetzt den passenden Modus anhand der Auflîsung des PCX-Files festlegen }
  IF (YRes <= 200) AND (XRes <= 320) THEN BEGIN
    GraphMode := 0;      { 320x200x256 }
  END ELSE IF (YRes <= 400) AND (XRes <= 640) THEN  BEGIN
    GraphMode := 2;      { 640x400x256 }
  END ELSE IF (YRes <= 480) AND (XRes <= 640) THEN  BEGIN
    GraphMode := 3;      { 640x480x256 }
  END ELSE IF (YRes <= 600) AND (XRes <= 800) THEN  BEGIN
    GraphMode := 4;      { 800x600x256 }
  END ELSE IF (YRes <= 768) AND (XRes <= 1024) THEN  BEGIN
    GraphMode := 5;      { 1024x768x256 }
  END ELSE IF (YRes <= 1024) AND (XRes <= 1280) THEN  BEGIN
    GraphMode := 6;      { 1280x1024x256 }
  END ELSE BEGIN
    Writeln ('Grafik-Auflîsung wird nicht unterstÅtzt.');
    Halt;
  END;

  { Grafik einschalten, Palette setzen }
  InitGraph (GraphDriver, GraphMode, '');
  Result := GraphResult;
  IF (Result < 0) THEN BEGIN
    Writeln ('Fehler beim Einschalten der Grafik: ', GraphErrorMsg (Result));
    Halt;
  END;

  { Vermerken das die Grafik an ist }
  GraphicsOn := TRUE;

  { Die Palette aus dem Header setzen. }
  FOR I := 0 TO 255 DO WITH Palette [I] DO SetRGBPalette (I, Red, Green, Blue);
END;




PROCEDURE Paint (VAR F : File);
{ Malt das Bild }


VAR
  BytesLeft : LONGINT;
  X, Y      : INTEGER;
  Count     : WORD;
  B         : BYTE;



  PROCEDURE NextByte;
  BEGIN
    IF (BufIndex = BufFill) THEN BEGIN
      { Puffer ist leer, lesen }
      IF (BytesLeft > SizeOf (Buffer)) THEN BEGIN
        BlockRead (F, Buffer, SizeOf (Buffer));
        BufFill := SizeOf (Buffer);
      END ELSE BEGIN
        BlockRead (F, Buffer, BytesLeft);
        BufFill := BytesLeft;
      END;
      Dec (BytesLeft, BufFill);
      BufIndex := 0;
    END;
    Inc (BufIndex);
    B := Buffer [BufIndex];
  END;


BEGIN  { Paint }
  { Position nach dem Header anfahren }
  Seek (F, SizeOf (Header));

  BytesLeft := DataBytes;

  X := Header.WX1;
  Y := Header.WY1;

  { Puffer als gelîscht markieren }
  BufIndex := 0;
  BufFill  := 0;
  REPEAT
    NextByte;
    IF (B >= $C0) THEN BEGIN
      { Wiederholungsfaktor }
      Count := B AND $3F;            { Anzahl }
      NextByte;                      { Farbe }

    END ELSE BEGIN
      Count := 1;
    END;

    WHILE (Count > 0) DO BEGIN
      IF (X > Header.WX2) THEN BEGIN
        Inc (Y);
        X := Header.WX1;
      END;
      PutPixel (X, Y, B);
      Inc (X);
      Dec (Count);
    END;

  UNTIL (Y > Header.WY2);

  { Fertig }
END;





PROCEDURE SetDefaultExtension (VAR FileName : PathStr; Ext : ExtStr);
{ Setzt eine Erweiterung wenn keine existiert }

VAR
  D : DirStr;
  N : NameStr;
  E : ExtStr;

BEGIN
  FSplit (FileName, D, N, E);
  IF (E = '') THEN E := Ext;
  FileName := D + N + E;
END;




PROCEDURE OpenFile (VAR F : File);
{ Bearbeitet die Kommandozeile und îffnet die Datei }

VAR
  FileName : PathStr;
  I        : WORD;
  PCount   : WORD;
  Item     : STRING;


  PROCEDURE Usage;
  BEGIN
    Writeln ('Aufruf mit PCXVIEW Dateiname[.PCX]');
    Halt;
  END;


BEGIN
  PCount := ParamCount;
  IF (PCount = 0) OR (PCount > 1) THEN Usage;
  FileName := ParamStr (1);

  SetDefaultExtension (FileName, '.PCX');

  FileMode := 0;        { R/O vorgeben }
  Assign (F, FileName);
  Reset (F, 1);
  IF (IOResult <> 0) THEN BEGIN
    Writeln ('Fehler beim ôffnen von ', FileName);
    Halt;
  END;

END;






BEGIN
  { RÅckschalten auf stdin/stdout }
  Assign (Input, '');
  Reset (Input);
  Assign (Output, '');
  ReWrite (Output);

  OpenFile (PCXFile);           { Datei îffnen }
  ReadControlData (PCXFile);    { Header und Palette lesen }
  GraphOn;                      { Grafikmodus festlegen und Grafik einschalten }
  Paint (PCXFile);              { Bild lesen und darstellen }
  REPEAT UNTIL ReadKey <> #00;  { Warten bis Taste }
  GraphOff;                     { Grafik ausschalten }
  Close (PCXFile);              { Bild-Datei schlie·en }
END.
