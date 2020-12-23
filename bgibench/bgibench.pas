PROGRAM BGIBench;

{
                 BGIBench   (C) 1991 Ullrich von Bassewitz


  Neue Version ohne MTK zur Zeitmessung. Zeitmessung wird Åber eigene Int08-
  Routine erledigt.

  * Beliebig erweiterbar, da nur Standard-Module verwendet werden.

  * Nur compilerbar mit Version 6.0 des Pascal Compilers wegen Assembler-
    Routinen.

  * Programmiert den Timer 0 unter Verwendung direkter Zugriffe. Setzt also
    erstens eine kompatible Hardware voraus und zweitens, da· sich keine
    TSR's bedinden, die wÑhrend das Ablaufs von BGIBench auch den Timer
    manipulieren.

  * Achtung bei der VerÑnderung von TimeSlice: Die Me·genauigkeit steigt
    zwar mit einer Verkleinerung, die Chance, da· sich der Rechner aufhÑngt
    jedoch genauso....
    Vorsicht bei Zeiten < 1 ms.
    Eine bessere Mîglichkeit zur Erhîhung der Messgenauigkeit bietet die
    Erhîhung der Durchlaufzahl (Konstante Mult).

  * Bei Test im Modus 320x200 arbeiten manche Zeichenoperationen au·erhalb
    des Bildschirms. Hier sind die Koordinaten entsprechend zu korrigieren.
    (Aber wen interessiert schon 320x200 ?).
}



{ énderungen:

  28.11.1991  (Uz)   Anpassung an Version 3.0 des Treibers (hauptsÑchlich
                     Erweiterung der maximalen Modus-Anzahl).

  22.05.1992  (Uz)   Zeitnahme fÅr FillPoly (mit und ohne Muster) eingebaut.

}



{$M 16384, 0, 100000}
{$R-}
{$I-}
{$G-}
{$X-}
{$O-}
{$V-}
{$A+}
{$X-}



USES
  CRT,
  DOS,
  Graph;




VAR
  GraphDriver : INTEGER;
  GraphMode   : INTEGER;
  I           : WORD;
  P           : POINTER;
  MaxX        : INTEGER;
  MaxY        : INTEGER;
  DriverName  : PathStr;
  ModeStr     : STRING;
  ExitSave    : POINTER;    { Merker fÅr Exit-Prozedur }
  SaveInt08   : POINTER;    { Alter Interruptvektor 08h }
  SystemTicks : LONGINT;    { ZÑhlt die TimeSlice-Ticks }
  TotalTime   : LONGINT;    { ZÑhler fÅr Gesamzeit des Tests }


TYPE
  Suit        = RECORD
    Desc      : STRING[80];
    T         : LONGINT;
  END;

CONST
  {--- Timer-Ticker ---}
  TimerSource     = 1193182;                 { Grundfrequenz des Timers in Hz }
  TimeSlice       = 0.010;                   { Timer-Takt. Nie > 0.055 !! }
  { Increments pro Timer-Takt }
  TickIncs        = Round (TimerSource * TimeSlice);


  {--- Anzahl DurchgÑnge ---}
  Mult        = 200;


  TestSuit    : ARRAY [1..19] OF Suit = (
    (Desc : 'Diagonale durchgezogene Linie (kein XOR)        [ms]: '),
    (Desc : 'Waagrechte durchgezogene Linie (kein XOR)       [ms]: '),
    (Desc : 'Senkrechte durchgezogene Linie (kein XOR)       [ms]: '),
    (Desc : 'Waagrechter Text Grî·e 1                        [ms]: '),
    (Desc : 'Senkrechter Text Grî·e 1                        [ms]: '),
    (Desc : 'Waagrechter Text Grî·e 3                        [ms]: '),
    (Desc : 'Senkrechter Text Grî·e 3                        [ms]: '),
    (Desc : 'GefÅllte FlÑche 100x100 ohne Muster             [ms]: '),
    (Desc : 'GefÅllte FlÑche 100x100 mit Muster              [ms]: '),
    (Desc : 'Kreis mit Radius = 50, Breite 1 Pixel           [ms]: '),
    (Desc : 'Kreis mit Radius = 50, Breite 3 Pixel           [ms]: '),
    (Desc : 'Ellipse, a = 30, b = 50, Breite 1 Pixel         [ms]: '),
    (Desc : 'Ellipse, a = 30, b = 50, Breite 3 Pixel         [ms]: '),
    (Desc : 'Voll ausgefÅllte Ellipse, a = 20, b = 40        [ms]: '),
    (Desc : 'GetImage 100x100                                [ms]: '),
    (Desc : 'PutImage 100x100 (kein XOR)                     [ms]: '),
    (Desc : 'PutImage 100x100 (XOR)                          [ms]: '),
    (Desc : 'FillPoly ohne Muster                            [ms]: '),
    (Desc : 'FillPoly mit Muster                             [ms]: ')
  );

  { Turbo-Treiber }
  DriverTable : ARRAY [1..10] OF STRING [8] = (
    'CGA',
    'MCGA',
    'EGA',
    'EGA64',
    'EGAMONO',
    'IBM8514',
    'HERCMONO',
    'ATT400',
    'VGA',
    'PC3270'
  );


  Poly : ARRAY [1..6] OF PointType = (
    (X : 150; Y : 200),
    (X : 200; Y : 300),
    (X : 300; Y : 300),
    (X : 350; Y : 200),
    (X : 300; Y : 100),
    (X : 200; Y : 100)
  );




{ -------------------------------------------------------------------------- }

{ --- Inlines --- }

PROCEDURE SetTimer0 (TimerWert : WORD);       { Timer 0 einstellen }
  INLINE ($B0/$34/           { mov     al, 34h }
          $E6/$43/           { out     43h, al }
          $58/               { pop     ax      }
          $E6/$40/           { out     40h, al }
          $86/$C4/           { xchg    al, ah  }
          $E6/$40);          { out     40h, al }

PROCEDURE ResetTimer0;       { Timer 0 rÅcksetzen }
  INLINE ($B0/$34/           { mov     al, 34h }
          $E6/$43/           { out     43h, al }
          $B0/$00/           { mov     al, 00h }
          $E6/$40/           { out     40h, al }
          $E6/$40);          { out     40h, al }


{ -------------------------------------------------------------------------- }
{ Hilfsprozeduren zur Zeitmessung }


PROCEDURE BGIBenchExit; FAR;
{ Stellt bei Programmende den orginalen Int8-Vektor sowie die ursprÅngliche
  Timer-Frequenz wieder her. Wird auch nach Ablauf der Messung aufgerufen.
}
BEGIN
  ExitProc := ExitSave;
  ResetTimer0;
  SetIntVec ($08, SaveInt08);
END;




PROCEDURE Int8Handler; FAR; ASSEMBLER;
{ Bildet den orginalen Timer in Software nach, zÑhlt intern aber Ticks der
  Periode TimeSlice.
}
CONST
  Ticks : WORD = 0;

ASM
  { Benîtigte Register retten/setzen }
  push    ax
  push    ds
  mov     ax, Seg @Data
  mov     ds, ax

  { Den internen ZeitzÑhler hochzÑhlen }
  add     [WORD Ptr SystemTicks], 1
  adc     [WORD Ptr SystemTicks+2], 0 { öberlauf }

  { Den Software-Timer hochzÑhlen }
  mov     ax, TickIncs                { Ticks pro TimeSlice }
  add     [Ticks], ax                 { auf den Software-Timer addieren }
  jnc     @L1                         { Springe wenn kein öberlauf }

  { öberlauf des Software-Timers. Den alten Int08 aufrufen, dann Ende }
  pushf
  call    [SaveInt08]                 { Int 8 simulieren }
  jmp     @L2

  { Kein öberlauf, dem Interrupt-Controller ein EOI schicken, dann Ende }
@L1:
  mov     al, 20h
  out     20h, al

  { Ende }
@L2:
  pop     ds
  pop     ax
  iret
END;



PROCEDURE InstallInt8Handler;
{ Klinkt eine eigene Routine in den System-Ticker ein und beschleunigt
  den Ticker auf den Wert TimeSlice.
}
BEGIN
  { Interrupt-Vektor 8 holen }
  GetIntVec ($08, SaveInt08);
  { Exit-Prozedur einklinken }
  ExitSave := ExitProc;
  ExitProc := @BGIBenchExit;
  { Int 8 einklinken }
  SetIntVec ($08, @Int8Handler);
  { Ticker beschleunigen }
  SetTimer0 (TickIncs);
END;




FUNCTION SystemTime : LONGINT; ASSEMBLER;
{ Holt den Ticker-ZÑhler. Ein Direkt-Zugriff auf die Variable ist nicht
  mîglich, da diese nicht in einem Rutsch gelesen wird (keine atomare
  Operation). Deshalb Umweg Åber diese Routine, die wÑhrend des Zugriffs
  die Interrupts sperrt.
}
ASM
  pushf                                    { I-Flag retten }
  cli                                      { interrupts off }
  mov     ax, [WORD Ptr SystemTicks]       { Low Word holen }
  mov     dx, [WORD Ptr SystemTicks+2]     { High Word holen }
  popf                                     { Altes I-Flag restaurieren }
END;


{ -------------------------------------------------------------------------- }
{ Sonstige Hilfsprozeduren }



PROCEDURE ResetInOut;
{ Setzt die Variablen Input und Output wieder auf StdIn bzw. StdOut }
BEGIN
  Assign (Input, '');
  Reset (Input);
  Assign (Output, '');
  Rewrite (Output);
END;




PROCEDURE SetDefaultExtension (VAR Name : PathStr; Ext : ExtStr);
{ FÅgt an Name eine Datei-Erweiterung an wenn Name keine besitzt. }

VAR
  D : DirStr;
  N : NameStr;
  E : ExtStr;

BEGIN
  FSplit (Name, D, N, E);
  IF (E = '') THEN Name := D + N + Ext;
END;





FUNCTION FExists (Name : PathStr) : BOOLEAN;
{ öberprÅft die Existenz einer Datei via FindFirst. Findet keine Hidden oder
  Ñhnliche Dateien, findet jedoch Dateien mit Wildcards.
}
VAR
  SR : SearchRec;

BEGIN
  FindFirst (Name, Archive, SR);
  FExists := (DOSError = 0);
END;




PROCEDURE UpCaseLong (VAR S : STRING);
{ Wandelt den Åbergebenen String nach Gro·schrift }

VAR
  I : WORD;

BEGIN
  FOR I := 1 TO Length (S) DO S [I] := UpCase (S [I]);
END;



FUNCTION BorlandDriver (Name : NameStr) : INTEGER;
{ Liefert den Index in die Tabelle mit den Borland BGI-Treibern falls der
  Åbergebene Treiber sich darin findet, ansonsten 0.
}

VAR
  I : INTEGER;

BEGIN
  { Name in der Tabelle suchen }
  FOR I := 1 TO (SizeOf (DriverTable) DIV SizeOf (NameStr)) DO BEGIN
    IF (DriverTable [I] = Name) THEN BEGIN
      { Gefunden }
      BorlandDriver := I;
      Exit;
    END;
  END;

  { Nicht gefunden }
  BorlandDriver := 0;
END;




FUNCTION RegisterDriver (DriverName : NameStr) : INTEGER;
{ Registriert den Treiber }

VAR
  DriverNum : INTEGER;

BEGIN
  DriverNum := InstallUserDriver (DriverName, NIL);
  IF (DriverNum < 0) THEN BEGIN
    Writeln ('Fehler beim Registrieren von ', DriverName);
    Halt (1);
  END;
  RegisterDriver := DriverNum;
END;





PROCEDURE GraphOn (Driver, Mode : INTEGER);
{ Schaltet in den Grafik-Modus }

BEGIN
  InitGraph (Driver, Mode, '');
  IF (GraphResult <> grOK) THEN BEGIN
    Writeln ('Fehler bei InitGraph, Treiber = ', Driver, ', Modus = ', Mode);
    Halt (1);
  END;
END;





PROCEDURE GetMode (DriverName : STRING; VAR Driver, Mode : INTEGER);
{ Holt den zum Grafiktreiber passenden Modus. }

CONST
  MaxMode   = 40;       { Maximal zulÑssige Modi }


VAR
  D         : DirStr;
  N         : NameStr;
  E         : ExtStr;
  LoMode    : INTEGER;
  Modes     : ARRAY [0..Pred (MaxMode)] OF STRING [80];
  I         : WORD;
  ModeCount : WORD;
  Code      : INTEGER;
  ModeStr   : STRING [80];


BEGIN
  { Den Namen in seine Bestandteile zerlegen }
  FSplit (DriverName, D, N, E);
  IF (E = '') THEN E := '.BGI';

  { Nachsehen, ob N einer der normalen Treiber ist. }
  Driver := BorlandDriver (N);
  IF (Driver <> 0) THEN BEGIN
    { Ein ganz normaler Turbo-Treiber. Den hîchsten verfÅgbaren Modus nach
      Mode holen.
    }
    GetModeRange (Driver, LoMode, Mode);
  END ELSE BEGIN
    { Es ist ein fremder Treiber, nachsehen, ob der Treiber auch existiert }
    IF (NOT FExists (D + N + E)) THEN BEGIN
      WriteLn (DriverName, ' existiert nicht');
      Halt;
    END;

    { Treiber registrieren, Treibernummer gÅltig belegen }
    Driver := RegisterDriver (N);

    { Nachsehen, ob die Modus-Nummer in der Kommandozeile steht }
    IF (ParamCount >= 2) THEN BEGIN
      Val (ParamStr (2), Mode, Code);
      IF (Code <> 0) OR (Mode < 0) THEN BEGIN
        { Falscher Modus }
        Writeln ('UngÅltiger Wert fÅr Grafik-Modus');
        Halt (1);
      END;
    END ELSE BEGIN

      { Modus 0 einschalten und die Modi holen }
      GraphOn (Driver, 0);
      ModeCount := GetMaxMode;
      IF (ModeCount >= MaxMode) THEN ModeCount := Pred (MaxMode);
      FOR I := 0 TO ModeCount DO Modes [I] := GetModeName (I);

      { Grafik wieder ausschalten und Menue bauen }
      CloseGraph;
      FOR I := 0 TO ModeCount DO BEGIN
        Write (I:2, '  --  ', Modes [I], '': 29 - Length (Modes [I]));
        IF (Odd (I)) THEN Writeln;
      END;
      WriteLn;
      WriteLn;

      { Eingabe holen und prÅfen }
      REPEAT
        Write ('Nummer ? ');
        ReadLn (Mode);
      UNTIL (Mode >= 0) AND (Mode <= ModeCount);
    END;
  END;
END;


{ -------------------------------------------------------------------------- }

BEGIN
  { Ctrl-Break sperren wegen geÑndertem Int08 }
  CheckBreak := FALSE;

  { stdin und stdout verwenden }
  ResetInOut;

  { öberschrift ausgeben }
  Writeln ('BGIBench   (C) 1991 Ullrich von Bassewitz');

  { Nachsehen, ob ein Treibername in der Kommandozeile angegeben ist. Wenn
    nicht, nachfragen.
  }
  DriverName := ParamStr (1);
  IF (Drivername = '') THEN BEGIN
    { War nix, nachfragen }
    Write ('Name des Treibers: '); ReadLn (DriverName);
    IF (DriverName = '') THEN Halt;
  END;

  { Name nach Gro·schrift wandeln }
  UpcaseLong (DriverName);

  { Zum Namen die Treibernummer und den Modus holen }
  GetMode (DriverName, GraphDriver, GraphMode);

  { Grafik einschalten }
  GraphOn (GraphDriver, GraphMode);

  { Zum eingeschalteten Modus die passende Beschreibung holen und merken }
  ModeStr := GetModeName (GraphMode);

  { Wir sind so weit, den Interrupt-Handler fÅr den Int08 installieren }
  InstallInt8Handler;

  MaxX := GetMaxX;
  MaxY := GetMaxY;
  SetColor (LightBlue);
  SetLineStyle (SolidLn, 0, NormWidth);

  WITH TestSuit [1] DO BEGIN
    T := SystemTime;
    FOR I := 1 TO Mult DO Line (0, 0, MaxX, MaxY);
    T := SystemTime - T;
  END;

  WITH TestSuit [2] DO BEGIN
    T := SystemTime;
    FOR I := 1 TO Mult DO Line (0, 0, 0, MaxY);
    T := SystemTime - T;
  END;

  WITH TestSuit [3] DO BEGIN
    T := SystemTime;
    FOR I := 1 TO Mult DO Line (0, 0, MaxX, 0);
    T := SystemTime - T;
  END;

  WITH TestSuit [4] DO BEGIN
    SetTextStyle (DefaultFont, HorizDir, 1);
    T := SystemTime;
    FOR I := 1 TO Mult DO OutTextXY (130, 130, 'Aber hallo !');
    T := SystemTime - T;
  END;

  WITH TestSuit [5] DO BEGIN
    SetTextStyle (DefaultFont, VertDir, 1);
    T := SystemTime;
    FOR I := 1 TO Mult DO OutTextXY (130, 130, 'Aber hallo !');
    T := SystemTime - T;
  END;

  WITH TestSuit [6] DO BEGIN
    SetTextStyle (DefaultFont, HorizDir, 3);
    T := SystemTime;
    FOR I := 1 TO Mult DO OutTextXY (100, 100, 'Aber hallo !');
    T := SystemTime - T;
  END;

  WITH TestSuit [7] DO BEGIN
    SetTextStyle (DefaultFont, VertDir, 3);
    T := SystemTime;
    FOR I := 1 TO Mult DO OutTextXY (100, 100, 'Aber hallo !');
    T := SystemTime - T;
  END;

  WITH TestSuit [8] DO BEGIN
    SetFillStyle (SolidFill, LightBlue);
    T := SystemTime;
    FOR I := 1 TO Mult DO Bar (150, 150, 250, 250);
    T := SystemTime - T;
  END;

  WITH TestSuit [9] DO BEGIN
    SetFillStyle (SlashFill, LightBlue);
    T := SystemTime;
    FOR I := 1 TO Mult DO Bar (250, 150, 350, 250);
    T := SystemTime - T;
  END;

  WITH TestSuit [10] DO BEGIN
    SetLineStyle (SolidLn, 0, NormWidth);
    T := SystemTime;
    FOR I := 1 TO Mult DO Circle (400, 400, 50);
    T := SystemTime - T;
  END;

  WITH TestSuit [11] DO BEGIN
    SetLineStyle (SolidLn, 0, ThickWidth);
    T := SystemTime;
    FOR I := 1 TO Mult DO Circle (500, 400, 50);
    T := SystemTime - T;
  END;

  WITH TestSuit [12] DO BEGIN
    SetLineStyle (SolidLn, 0, NormWidth);
    T := SystemTime;
    FOR I := 1 TO Mult DO Ellipse (140, 400, 0, 360, 30, 50);
    T := SystemTime - T;
  END;

  WITH TestSuit [13] DO BEGIN
    SetLineStyle (SolidLn, 0, ThickWidth);
    T := SystemTime;
    FOR I := 1 TO Mult DO Ellipse (200, 400, 0, 360, 30, 50);
    T := SystemTime - T;
    SetLineStyle (SolidLn, 0, NormWidth);
  END;

  WITH TestSuit [14] DO BEGIN
    SetFillStyle (SolidFill, LightBlue);
    T := SystemTime;
    FOR I := 1 TO Mult DO FillEllipse (500, 200, 20, 40);
    T := SystemTime - T;
  END;

  WITH TestSuit [15] DO BEGIN
    GetMem (P, ImageSize (0, 0, 100, 100));
    IF (P = NIL) THEN BEGIN
      CloseGraph;
      WriteLn ('Sorry, nicht genug Speicher');
      Halt;
    END;
    T := SystemTime;
    FOR I := 1 TO Mult DO GetImage (250, 150, 350, 250, P^);
    T := SystemTime - T;
  END;

  WITH TestSuit [16] DO BEGIN
    T := SystemTime;
    FOR I := 1 TO Mult DO PutImage (150, 150, P^, NormalPut);
    T := SystemTime - T;
  END;

  WITH TestSuit [17] DO BEGIN
    T := SystemTime;
    FOR I := 1 TO Mult DO PutImage (250, 150, P^, XORPut);
    T := SystemTime - T;
  END;

  WITH TestSuit [18] DO BEGIN
    SetFillStyle (SolidFill, LightBlue);
    SetColor (LightBlue);
    T := SystemTime;
    FOR I := 1 TO Mult DO FillPoly (SizeOf (Poly) DIV SizeOf (PointType), Poly);
    T := SystemTime - T;
  END;

  WITH TestSuit [19] DO BEGIN
    SetFillStyle (SlashFill, LightBlue);
    SetColor (LightBlue);
    T := SystemTime;
    FOR I := 1 TO Mult DO FillPoly (SizeOf (Poly) DIV SizeOf (PointType), Poly);
    T := SystemTime - T;
  END;

  { RÅckschalten auf Text }
  CloseGraph;

  { Timer und Int08 wieder rÅcksetzen }
  BGIBenchExit;

  { Ausgeben der getesteten Karten und des Modus }
  Writeln ('Treiber: ', DriverName);
  Writeln ('Modus  : ', ModeStr);
  Writeln;

  { Ausgabe der Ergebnisse }
  TotalTime := 0;
  FOR I := 1 TO (SizeOf (TestSuit) DIV SizeOf (Suit)) DO BEGIN
    WITH TestSuit [I] DO BEGIN
      Inc (TotalTime, T);
      WriteLn (Desc, (TimeSlice * T) * 1000 / Mult : 6 : 2);
    END;
  END;
  Writeln ('------------------------------------------------------------');
  Writeln ('Gesamtzeit fÅr alle Tests zusammen              [ms]: ',
            (TimeSlice * TotalTime) * 1000 / Mult : 6 : 2);
END.
