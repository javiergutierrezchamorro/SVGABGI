UNIT PixFont;


{
        Modul PixFont, V 1.10   (C) 1992 Ullrich von Bassewitz



  Erlaubt die Ausgabe von Text-Strings mit beliebigen Pixelfonts. Die
  verwendeten Pixel-Fonts mÅssen folgenderma·en aufgebaut sein:

  Ein Zeichen besteht aus XSize Spalten und YSize Zeilen.
  Die Daten fÅr die Pixel werden so angeordnet

    1. Zeichen:
      1. Zeile
      2. Zeile
      3. Zeile
      ...

    2. Zeichen
      1. Zeile
      2. Zeile
      3. Zeile
      ...

    ...

  Die Daten einer Zeile werden jeweils auf volle Bytes aufgerundet, so da·
  ein 8 Pixel breiter Font ein Byte pro Zeile, ein 9 Pixel breiter 2 Bytes
  pro Zeile besitzt etc.
  Das oberste Bit (Bit 7) eines Bytes wird links ausgegeben, jedes folgende
  Bit eine Position weiter rechts.
  Die erste Zeile wird zuoberst ausgegeben, jede folgende darunter.

  "Verpackt" wird der Font in ein Objekt, das Åber alle Eigenschaften zum
  Setzen der Grî·e etc. verfÅgt. Der Grund dafÅr ist eine der geplanten
  Erweiterungen des Bildschirmtreibers - die nÑchste Version soll beliebige
  Pixel-Fonts auf Treiber-Ebene ausgeben kînnen, wozu dann nur die WriteXY-
  Methode Åberladen werden mu·.

}




{ (C) Ullrich von Bassewitz am 22.01.1992 }

{ Diverse Compiler-Switches: }

{$F-     Force Far Calls Off  }
{$O-     No Overlays Allowed  }
{$A+     Align Data at Word Boundary }
{$B-     Short Circuit Boolean Evaluation }
{$I+     I/O Checking On     }
{$D+     Debug Information On }
{$L+     Local Symbols On     }
{$G-     No 286-Code }

{$IFDEF Debug }
  {$R+	 Range Checking On    }
  {$S+	 Stack Checking On    }
{$ELSE}
  {$R-	 Range Checking Off   }
  {$S-	 Stack Checking Off   }
{$ENDIF}




{ énderungsliste:

22.01.92  Uz            Erstellt.

26.03.92  Uz    M       Horizontale Zeichen-Ausgabe in Assembler umgeschrieben.
                        Bringt ca. 30% bei SVGA.BGI.

}


INTERFACE


USES
  DOS,               { wg. PathStr }
  Graph;



TYPE

  { Objekt zur Verwaltung eines Pixelfonts }
  PPixFont   = ^TPixFont;
  TPixFont   = OBJECT

    FontPtr      : POINTER;      { Zeiger auf die Font-Daten }
    FontXSize    : WORD;         { Grî·e des Fonts in X und Y (Pixels) }
    FontYSize    : WORD;
    FontXMult    : BYTE;         { Vergrî·erung des Fonts in X und Y }
    FontYMult    : BYTE;
    FontColor    : WORD;         { Farbe der Ausgabe }
    FontHoriz    : BYTE;         { Ausrichtung des Textes in horizontaler .. }
    FontVert     : BYTE;         { ... und vertikaler Richtung }
    FontDir      : WORD;         { Schreibrichtung }

    FontMem      : WORD;         { Speicher den das Objekt selber belegt hat }



    CONSTRUCTOR Init (FontData: POINTER; XSize, YSize: WORD);
    { Initialisiert das Font-Objekt. Als Farbe wird die aktuelle Zeichenfarbe
      Åbernommen, die Grî·e erhÑlt den Wert (1/1) und die Ausrichtung ist
      LeftText, TopText. FÅr FontData kann auch NIL Åbergeben werden wenn
      die Daten spÑter via LoadFont geladen oder Åber SetFont gesetzt
      werden sollen.
    }

    DESTRUCTOR Done; VIRTUAL;
    { Lîscht das Objekt. Gibt die Daten auf die FontPtr zeigt nur dann frei,
      wenn sie Åber LoadFont geladen wurden.
    }

    FUNCTION LoadFont (Name: PathStr; XSize, YSize: WORD): INTEGER;
    { LÑdt den Font mit dem Åbergebenen Namen. FÅr den Font wird Speicher
      reserviert in den der Font dann geladen wird. Gleichzeitig wird
      vermerkt, da· das Objekt selber Speicher belegt hat. Dieser Speicher
      wird beim Done freigegeben.
      Ist bereits ein Font geladen, so wird der belegte Speicherbereich vor
      der Verwendung freigegeben.
      Der Ergebniscode entspricht IOResult, d.h. wenn das Ergebnis 0 ist,
      wurde der Font erfolgreich geladen. Als Sonderfall kommt -1 zurÅck wenn
      zu wenig Speicher zum Laden des Fonts vorhanden war.
    }

    PROCEDURE SetFont (FontData: POINTER; XSize, YSize: WORD);
    { Setzt den Font neu. Ist bereits Speicher fÅr einen anderen Font belegt,
      so wird dieser zuvor freigegeben.
      Der Speicher den FontData^ belegt wird beim Done *nicht* freigegeben.
    }

    PROCEDURE SetFontSize (XMult, YMult: BYTE);
    { Setzt die Vergrî·erung fÅr den Font. Wird fÅr einen der Werte 0
      Åbergeben, so die Grî·e nicht akzeptiert.
    }

    PROCEDURE SetFontDirection (Dir: WORD);
    { Bekommt die neue Schreibrichtung (HorizDir/VertDir) Åbergeben. }

    PROCEDURE SetColor (Color: WORD);
    { Setzt die Farbe fÅr die folgenden Ausgaben. Der Wert wird auf die
      hîchste verfÅgbare Farbe begrenzt.
    }

    PROCEDURE SetFontJustify (Horiz, Vert: WORD);
    { Legt die Ausrichtung des Textes fÅr spÑtere Ausgaben fest. }

    PROCEDURE WriteXY (X, Y: INTEGER; S: STRING); VIRTUAL;
    { Soll einen String an der Åbergebenen Position auf dem Bildschirm
      ausgeben. Benutzt dazu GetPixel/PutPixel und ist deshalb mit allen
      Treibern kompatibel.
    }

  PRIVATE

    PROCEDURE OutChar0 (X0, Y0: INTEGER; C: CHAR);
    { Gibt ein Zeichen horizontal aus }

    PROCEDURE OutChar1 (X0, Y0: INTEGER; C: CHAR);
    { Gibt ein Zeichen vertikal aus }

  END;


{ -------------------------------------------------------------------------- }
{ Au·erhalb der Objekte }


FUNCTION Get8x14FontPtr: POINTER;
{ Holt (auf EGA's und VGA's) den Zeiger auf den 8x14 ROM-Font. Es erfolgt
  keine öberprÅfung ob eine EGA oder VGA vorhanden ist.
}


FUNCTION Get8x16FontPtr: POINTER;
{ Holt (auf VGA's) den Zeiger auf den 8x16 ROM-Font. Es erfolgt keine
  öberprÅfung ob eine VGA vorhanden ist.
}


{ -------------------------------------------------------------------------- }

IMPLEMENTATION



TYPE
  PByteArray = ^TByteArray;
  TByteArray = ARRAY [0..65519] OF BYTE;




{ -------------------------------------------------------------------------- }
{ --- Methoden von TPixFont --- }



CONSTRUCTOR TPixFont.Init (FontData: POINTER; XSize, YSize: WORD);
{ Initialisiert das Font-Objekt. Als Farbe wird die aktuelle Zeichenfarbe
  Åbernommen, die Grî·e erhÑlt den Wert (1/1) und die Ausrichtung ist
  LeftText, TopText. FÅr FontData kann auch NIL Åbergeben werden wenn
  die Daten spÑter via LoadFont geladen oder Åber SetFont gesetzt
  werden sollen.
}

BEGIN
  { Variable Åbernehmen }
  FontPtr    := FontData;
  FontXSize  := XSize;
  FontYSize  := YSize;

  { Rest sinnvoll setzen }
  FontXMult  := 1;
  FontYMult  := 1;
  FontColor  := GetColor;
  FontHoriz  := LeftText;
  FontVert   := TopText;
  FontDir    := HorizDir;
  FontMem    := 0;            { Kein Speicher selber belegt }
END;




DESTRUCTOR TPixFont.Done;
{ Lîscht das Objekt. Gibt die Daten auf die FontPtr zeigt nur dann frei,
  wenn sie Åber LoadFont geladen wurden.
}
BEGIN
  { Falls Speicher belegt, diesen freigeben }
  IF (FontMem <> 0) THEN FreeMem (FontPtr, FontMem);
END;





FUNCTION TPixFont.LoadFont (Name: PathStr; XSize, YSize: WORD): INTEGER;
{ LÑdt den Font mit dem Åbergebenen Namen. FÅr den Font wird Speicher
  reserviert in den der Font dann geladen wird. Gleichzeitig wird
  vermerkt, da· das Objekt selber Speicher belegt hat. Dieser Speicher
  wird beim Done freigegeben.
  Ist bereits ein Font geladen, so wird der belegte Speicherbereich vor
  der Verwendung freigegeben.
  Der Ergebniscode entspricht IOResult, d.h. wenn das Ergebnis 0 ist,
  wurde der Font erfolgreich geladen. Als Sonderfall kommt -1 zurÅck wenn
  zu wenig Speicher zum Laden des Fonts vorhanden war.
}
VAR
  F      : FILE;
  Result : INTEGER;   { IOResult }
  Size   : LONGINT;   { Dateigrî·e }
  P      : POINTER;   { Font-Zeiger }
  Bytes  : WORD;      { Gelesene Bytes }

LABEL
  ExitPoint;

BEGIN
  {$I-      I/O-Checking machen wird }

  { Annehmen, da· alles Ok lÑuft }
  LoadFont := 0;

  { Datei îffnen }
  Assign (F, Name);
  Reset (F, 1);
  Result := IOResult;
  IF (Result <> 0) THEN BEGIN
    LoadFont := Result;
    GOTO ExitPoint;
  END;

  { Grî·e feststellen }
  Size := FileSize (F);
  IF (Size = -1) OR (Size > 65520) THEN BEGIN
    { Datei zu gro· oder Zugriffsfehler }
    LoadFont := -1;
    GOTO ExitPoint;
  END;

  { Speicher belegen }
  GetMem (P, Size);
  IF (P = NIL) THEN BEGIN
    { Zu wenig Speicher }
    LoadFont := -1;
    GOTO ExitPoint;
  END;

  { Datei in den Speicher laden }
  BlockRead (F, P^, Size, Bytes);
  IF (Bytes <> Size) THEN Result := -1 ELSE Result := IOResult;
  IF (Result <> 0) THEN BEGIN
    LoadFont := Result;
    GOTO ExitPoint;
  END;

  { Werte Åbernehmen }
  FontPtr   := P;
  FontMem   := WORD (Size);
  FontXSize := XSize;
  FontYSize := YSize;

ExitPoint:
  { Datei wieder schliessen }
  Close (F);

  {$I+    I/O-Checking wieder einschalten }
END;







PROCEDURE TPixFont.SetFont (FontData: POINTER; XSize, YSize: WORD);
{ Setzt den Font neu. Ist bereits Speicher fÅr einen anderen Font belegt,
  so wird dieser zuvor freigegeben.
  Der Speicher den FontData^ belegt wird beim Done *nicht* freigegeben.
}
BEGIN
  { Falls Speicher belegt, diesen freigeben }
  IF (FontMem <> 0) THEN BEGIN
    FreeMem (FontPtr, FontMem);
    FontMem := 0;
  END;

  { Neuen Font eintragen }
  IF (XSize = 0) THEN XSize := 8;      { Was vernÅnftiges }
  IF (YSize = 0) THEN YSize := 8;      { dito }
  FontXSize := XSize;
  FontYSize := YSize;
  FontPtr   := FontData;
END;






PROCEDURE TPixFont.SetFontSize (XMult, YMult: BYTE);
{ Setzt die Vergrî·erung fÅr den Font. Wird fÅr einen der Werte 0
  Åbergeben, so die Grî·e nicht akzeptiert.
}
BEGIN
  { Wert 0 ist unzulÑssig }
  IF (XMult = 0) OR (YMult = 0) THEN Exit;

  { öbernehmen der Werte }
  FontXMult := XMult;
  FontYMult := YMult;
END;




PROCEDURE TPixFont.SetFontDirection (Dir: WORD);
{ Bekommt die neue Schreibrichtung (HorizDir/VertDir) Åbergeben. }

BEGIN
  { Nur gÅltige Werte akzeptieren }
  IF (Dir = HorizDir) OR (Dir = VertDir) THEN BEGIN
    FontDir := Dir;
  END;
END;





PROCEDURE TPixFont.SetColor (Color: WORD);
{ Setzt die Farbe fÅr die folgenden Ausgaben. Der Wert wird auf die
  hîchste verfÅgbare Farbe begrenzt.
}
VAR
  MaxColor : WORD;      { Hîchste verfÅgbare Farbe }

BEGIN
  { Obere Grenze testen }
  MaxColor := GetMaxColor;
  IF (Color > MaxColor) THEN Color := MaxColor;

  { öbernehmen }
  FontColor := Color;
END;




PROCEDURE TPixFont.SetFontJustify (Horiz, Vert: WORD);
{ Legt die Ausrichtung des Textes fÅr spÑtere Ausgaben fest. }

BEGIN
  { Werte Åbernehmen }
  FontHoriz := Horiz;
  FontVert  := Vert;
END;




PROCEDURE TPixFont.OutChar0 (X0, Y0: INTEGER; C: CHAR);
{ Ausgabe eines Zeichens in horizontaler Richtung }

VAR
  X, Y      : INTEGER;
  XM, YM    : WORD;
  GO        : WORD;
  GO1       : WORD;
  B         : BYTE;
  Mask      : BYTE;
  FX, FY    : WORD;
  YAdd      : WORD;

  { Einige Variable auf den Stack zum schnelleren Zugriff }
  FPtr      : POINTER;                  { enthÑlt FontPtr }
  FColor    : WORD;                     { enthÑlt FontColor }
  FXMult    : BYTE;                     { enthÑlt FontXMult }


BEGIN
  { Einige Variable umladen }
  ASM
    les     di, [Self]
    mov     ax, WORD PTR [(TPixFont PTR es:di).FontPtr]
    mov     WORD PTR [FPtr], ax
    mov     ax, WORD PTR [(TPixFont PTR es:di).FontPtr+2]
    mov     WORD PTR [FPtr+2], ax
    mov     ax, [(TPixFont PTR es:di).FontColor]
    mov     [FColor], ax
    mov     al, [(TPixFont PTR es:di).FontXMult]
    mov     [FXMult], al
  END;

  YAdd := (FontXSize + 7) SHR 3;

  GO := YAdd * FontYSize * WORD (C);

  Y := Y0;

  FOR FY := 0 TO Pred (FontYSize) DO BEGIN

    FOR YM := 1 TO FontYMult DO BEGIN

      X := X0;
      GO1 := GO;

      ASM
        les     di, [Self]                 { High BYTE von FontXSize ignorieren }
        mov     bh, BYTE PTR [(TPixFont PTR es:di).FontXSize]
        mov     bl, 01h                    { Maske ins Register fÅr Speed }
        mov     ch, [B]                    { Byte ins Register fÅr Speed }

      { X-Schleife }

      @@L0:
        ror     bl, 1                      { Neues Byte nîtig ? }
        jnc     @@L1                       { Springe wenn Nein }

      { Neues Byte laden }

        les     di, [FPtr]                 { Zeiger auf Puffer }
        add     di, [GO1]                  { + Offset }
        mov     ch, BYTE PTR [es:di]       { Neues Byte holen }
        mov     [B], ch                    { und auch merken }
        inc     [GO1]                      { Offset weitersetzen }

      @@L1:
        mov     cl, [FXMult]               { Vergrî·erung }
        test    bl, ch                     { Maske testen }
        jz      @@L3                       { Springe wenn nein }

      { Pixel MultX mal setzen }

        mov     ax, [X]
        push    bx                         { Maske und Byte FontXSize }

      @@L2:
        push    cx
        push    ax                         { X }
        push    ax
        push    [Y]
        push    [FColor]
        call    PutPixel
        pop     ax                         { X }
        pop     cx
        inc     ax                         { Inc X }
        dec     cl
        jnz     @@L2

        pop     bx                         { Maske und Byte FontXSize }
        mov     cl, [FXMult]

      { Pixel MultX mal nicht setzen }

      @@L3:
        mov     al, cl
        mov     ah, 0
        add     [X], ax

      { NÑchstes Pixel }

        dec     bh
        jnz     @@L0
      END;

      Inc (Y);
    END;

    Inc (GO, YAdd);
  END;

END;





PROCEDURE TPixFont.OutChar1 (X0, Y0: INTEGER; C: CHAR);
{ Ausgabe eines Zeichens in vertikaler Richtung }

VAR
  X, Y      : INTEGER;
  XM, YM    : WORD;
  GO        : WORD;
  GO1       : WORD;
  B         : BYTE;
  Mask      : BYTE;
  FX, FY    : WORD;
  YAdd      : WORD;

BEGIN
  YAdd := (FontXSize + 7) SHR 3;

  GO := YAdd * FontYSize * WORD (C);

  X := X0;

  FOR FY := 0 TO Pred (FontYSize) DO BEGIN

    FOR YM := 1 TO FontYMult DO BEGIN

      Mask := $80;
      Y := Y0;
      GO1 := GO;

      FOR FX := 0 TO Pred (FontXSize) DO BEGIN
        IF (Mask = $80) THEN BEGIN
          B := PByteArray (FontPtr)^ [GO1];
          Inc (GO1);
        END;

        IF ((B AND Mask) <> 0) THEN BEGIN
          { Pixel MultX mal setzen }
          FOR XM := 1 TO FontXMult DO BEGIN
            PutPixel (X, Y, FontColor);
            Dec (Y);
          END;
        END ELSE BEGIN
          { Pixel MultX mal nicht setzen }
          Dec (Y, FontXMult);
        END;
        { NÑchstes Bit maskieren }
        ASM
          ror     [Mask], 1
        END;
      END;
      Inc (X);
    END;

    Inc (GO, YAdd);
  END;

END;






PROCEDURE TPixFont.WriteXY (X, Y: INTEGER; S: STRING);
{ Gibt einen String auf das GerÑt aus, benutzt dazu GetPixel/PutPixel
  und ist deshalb mit allen Treibern kompatibel.
}

VAR
  XSize : WORD;    { X-Grî·e eines Zeichens mit den aktuellen Einstellungen }
  YSize : WORD;    { Y-Grî·e eines Zeichens mit den aktuellen Einstellungen }
  I     : WORD;    { Laufvariable }

BEGIN
  { Grî·e eines Zeichens mit den momentanen Einstellungen rechnen }
  XSize := FontXSize * WORD (FontXMult);
  YSize := FontYSize * WORD (FontYMult);

  { Ja nach Ausgaberichtung unterscheiden }
  CASE FontDir OF

    { Text ist horizontal }
    HorizDir:
      BEGIN
        { Anfangsposition je nach Alignment korrigieren }
        CASE FontHoriz OF
          LeftText  : ;           { Alles bereits Ok }
          CenterText: Dec (X, (WORD (Length (S)) * XSize) DIV 2);
          RightText : Dec (X, WORD (Length (S)) * XSize);
        END;
        CASE FontVert OF
          BottomText: Dec (Y, YSize);
          CenterText: Dec (Y, YSize DIV 2);
          TopText   : ;           { Alles Ok }
        END;

        { Text ausgeben }
        FOR I := 1 TO Length (S) DO BEGIN
          OutChar0 (X, Y, S [I]);
          Inc (X, XSize);
        END;
      END;


    { Text ist vertikal }
    VertDir:
      BEGIN
        { Anfangsposition je nach Alignment korrigieren }
        CASE FontHoriz OF
          LeftText  : Dec (X, YSize);
          CenterText: Dec (X, YSize DIV 2);
          RightText : ;           { Alles bereits Ok }
        END;
        CASE FontVert OF
          BottomText: Dec (Y, (WORD (Length (S)) * XSize));
          CenterText: Dec (Y, (WORD (Length (S)) * XSize) DIV 2);
          TopText   : ;           { Alles Ok }
        END;

        { Text von hinten her ausgeben }
        FOR I := Length (S) DOWNTO 1 DO BEGIN
          Inc (Y, XSize);
          OutChar1 (X, Y, S [I]);
        END;
      END;

  END;
END;


{ -------------------------------------------------------------------------- }
{ Au·erhalb der Objekte }


FUNCTION Get8x14FontPtr: POINTER; ASSEMBLER;
{ Holt (auf EGA's und VGA's) den Zeiger auf den 8x14 ROM-Font. Es erfolgt
  keine öberprÅfung ob eine EGA oder VGA vorhanden ist.
}
ASM
  mov     ax, 1130h
  mov     bh, 02h               { 8x14-Font }
  push    bp
  int     10h
  mov     ax, bp
  pop     bp
  mov     dx, es
END;






FUNCTION Get8x16FontPtr: POINTER; ASSEMBLER;
{ Holt (auf VGA's) den Zeiger auf den 8x16 ROM-Font. Es erfolgt keine
  öberprÅfung ob eine EGA oder VGA vorhanden ist.
}
ASM
  mov     ax, 1130h
  mov     bh, 06h               { 8x14-Font }
  push    bp
  int     10h
  mov     ax, bp
  pop     bp
  mov     dx, es
END;








{ -------------------------------------------------------------------------- }
{ Keine Initialisierung }

END.










