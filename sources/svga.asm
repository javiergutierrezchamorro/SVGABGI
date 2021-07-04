; ******************************************************************************
; *                                                                            *
; * BGI-Treiber fÅr Super-VGAs im 256-Farben Modus.                            *
; *                                                                            *
; * Ullrich von Bassewitz am 29.04.1991                                        *
; *                                                                            *
; ******************************************************************************


IDEAL                   ; Ideal-Modus
JUMPS                   ; Automatische Sprunganpassung
LOCALS                  ; Lokale Symbole zulassen
SMART


;---------------------------------------------------
;
; Verwendete Macros einbinden
;

INCLUDE "macros.asi"


IFNDEF Ver3
Ver3  = 0
ENDIF


; ==================================================
; Mit den folgenden Symbolen kann die Codeerzeugung gesteuert werden.
; Die Symbole werden normalerweise Åber's Makefile bzw. den TASM Aufruf
; gesetzt.
;
; P80286          = 1
; P80386          = 1

IFNDEF P80386
P80386  = 0
IFNDEF P80286
P80286  = 0
ENDIF
ENDIF


; Bei 80386 auch 80286-Instructions verwenden
IF P80386
IFNDEF P80286
P80286  = 1
ENDIF
ENDIF

; Prozessor setzen
RESETCPU

; ----------------------------------------
; Verwendete Konstanten einbinden

INCLUDE "const.asi"



; ==================================================

SEGMENT CODE PARA PUBLIC 'CODE'

IF Ver3
ASSUME  CS:CODE, DS:DATA
ELSE
ASSUME  CS:CODE, DS:CODE
ENDIF

Start:

;---------------------------------------------------
; Definition der verwendeten structs einbinden
;

INCLUDE "structs.asi"


;---------------------------------------------------
; Der Dispatcher liegt auf Adresse 0
; Er ist FAR codiert, sein RET dient gleichzeitig als NOP-Vektor

PROC    Dispatch Far

        push    ds
        SetToDS ds
        cld
        push    bp
        call    [Vector_Table + si]

        pop     bp
        pop     ds
FAR_NOP_Vector:
        ret

ENDP    Dispatch

;---------------------------------------------------
; FÅllbytes auf 10h

IF Ver3
        db      0
ELSE
        db      "Anna"
ENDIF

;---------------------------------------------------
; Datensegment

IF      Ver3
DSeg    dw      ?
ENDIF

;---------------------------------------------------
; Der Emulate-Vektor
; Das abschlie·ende ret wird auch als NOP-Vektor verwendet

PROC    Emulate NEAR

        ret                             ; Diese beiden Zeilen werden mit
        db      00h, 00h, 00h, 00h      ; call FAR GRAPH:XXXX Åberschrieben
NOP_Vector:
        ret                             ; Danach gehts zurÅck

ENDP    Emulate

; ----------------------------------------------------------------
; Allgemeine Unterprogramme


PROC    Int10 Near

        push    bp
        ;cld
        int     10h
        pop     bp
        ret

ENDP    Int10

;---------------------------------------------------------------------
; Unterprogramme einbinden

INCLUDE "dpmi.asi"                      ; DPMI-Stuff

INCLUDE "svgaopts.asi"                  ; Environment-Optionen

INCLUDE "detect.asi"                    ; Autodetect

INCLUDE "cards.asi"                     ; kartenspezifische Routinen

INCLUDE "s3.asi"                        ; S3 spezifische Routinen


; =========================================================================
;
; Install-Routine
;


PROC    Install NEAR

        cmp     al,01h                          ; Mode Query ?
        jnz     @@L1                            ; Nein
        mov     cx, ModeCount                   ; Ja: Number of modes supported
        ret

@@L1:   push    ds
        pop     es
        cmp     al, 02h                         ; Mode Name ?
        jnz     InstallDevice                   ; Nein
        jcxz    @@L3                            ; Modus 0
        cmp     cx, MaxAutoMode
        ja      @@L2
        mov     bx, cx                          ; Auto-Modus-Nummer in bx
        shl     bx, 1                           ; * 2 fÅr Wortzugriff
        mov     bx, [WORD AutoName-2+bx]        ; Zeiger auf Namen holen
        ret                                     ; fertig

; Es ist kein Autodetect-Modus

@@L2:   sub     cx, MaxAutoMode
@@L3:   ;fastimul ax, cx, SIZE TMode
		mov     ax, SIZE TMode                  ; LÑnge eines Tabelleneintrages
        mul     cx                              ; * Eintragsnummer
        mov     bx, ax
        mov     bx, [(TMode ModeTable + bx).ModeName]   ; Zeiger auf Namen
        ret

; Installieren

InstallDevice:
        push    cx                              ; Modus retten
        call    GetOpts                         ; Environment-Optionen holen
        pop     cx
        xor     ch, ch
        cmp     cl, ModeCount                   ; Modus zulÑssig ?
        jae     IllegalMode                     ; NEIN !
        jcxz    @@L5                            ; Modus 0
        cmp     cx, MaxAutoMode                 ; Ist es ein Autodetect-Modus
        ja      @@L4                            ; Nein

; Es ist ein Autodetect-Modus. Die Modus-Maske aus der Tabelle holen und
; die Autodetect-Routine aufrufen. RÅckgabe ist ein Eintrag der Mode-Tabelle
; in di

        mov     di, cx                          ; Modus-Nummer in di
        mov     al, [BYTE AutoMode-1+di]        ; Modus-BitSet holen
        push    es                              ; es wird zerstîrt
        call    AutoDetectMode                  ; Modus suchen
        pop     es
        jmp     short @@L6

; Es ist kein Autodetect-Modus der eingestellt werden soll

@@L4:   sub     cx, MaxAutoMode
@@L5:   mov     ax, SIZE TMode                  ; Grî·e eines Tabelleneintrags
        mul     cx
        mov     di, ax                          ; Offset nach di
        lea     di, [ModeTable + di]            ; Adresse nach di
@@L6:   mov     [ModePtr], di                   ; Adresse merken

; Aus den Daten des Modus-Eintrags in di die Daten fÅr die DST berechnen
; und setzen

        mov     ax, [(TMode di).XRes]           ; X-Auflîsung setzen
        dec     ax
        mov     [DST.XRes], ax
        mov     [DST.XEfRes], ax
        mov     ax, [(TMode di).YRes]           ; Y-Auflîsung setzen
        dec     ax
        mov     [DST.YRes], ax
        mov     [DST.YEfRes], ax

; Aspect-Ratio nach der Formel
;
;       Y * 10000     XInch
;      ----------- *  -----
;           X         YInch
;
; berechnen

        mov     ax, 10000
        mul     [(TMode di).YRes]
        div     [(TMode di).XRes]
        mul     [DST.XInch]
        div     [DST.YInch]
        mov     [DST.Aspec], ax

; Zeiger auf DST in es:bx zurÅckliefern, es stimmt schon

        mov     bx, OFFSET DST                  ; als aktuelle DST vermerken
        ret

IllegalMode:
        mov     di, OFFSET ModeTable            ; VGA256 rÅckliefern
        mov     [DST.Stat], grInvalidMode       ; UngÅltiger Modus
        jmp     @@L6                            ; und installieren

ENDP    Install

; =======================================================================
;
;      DW   offset   INIT         ; Initialize device for output
;
;   Input:
;      es:bx  --> Device Information Table
;
;   Return:
;      Nothing
;
; This vector is used to change an already INSTALLed device from text mode to
; graphics mode. This vector should also initialize any default palettes and
; drawing mode information as required. The input to this vector is a
; device information table (DIT). The format of the DIT is shown below and
; contains the background color and an initialization flag. If the device
; requires additional information at INIT time, these values can be appended
; to the DIT. There in no return value for this function. If an
; error occurs during device initialization, the STAT field of the Device
; Status Table should be loaded with the appropriate error value.
;
; ; ************** Device Information Table Definition **************
;
; struct  DIT
;         DB      0               ; Background color for initializing screen
;         DB      0               ; Init flag; 0A5h = don't init; anything
;                                 ;   else = init
;         DB      64 dup 0        ; Reserved for Borland's future use
;                                 ; additional user information here
; DIT     ends
;
;

PROC    Init NEAR

        mov     al, [es:bx]             ; Hintergrundfarbe
        and     al, 0fh                 ; BIOS nimmt nur 0-15
        mov     [BkColor], al           ; merken

; Ist im Status-Feld der DST ein Fehler eingetragen, dann direkt Ende
; (GRAPH nimmt's anscheinend nicht so genau mit der FehlerprÅfung, so da·
; ein Aufruf mit gesetztem Fehler durchaus mîglich ist. In diesem Fall ist
; Modus 0 eingeschaltet, es sieht aber trotzdem etwas bled aus, wenn in
; einen ungewollten Grafik-Modus geschaltet wird).

        cmp     [DST.Stat], grOk
        jne     InitEnd

; Das Grafik-Kernel beschummeln: Wie bereits im Kommentar zur Vektor-Tabelle
; ausgefÅhrt, prÅft das Grafik-Kernel ab Version 7.0 den FillPoly-Vektor.
; Wenn dieser nicht auf Emulate steht setzt sich das Kernel ein Flag, das
; zur Folge hat, dass Arc und PieSlice mit kleinen Radien nicht mehr korrekt
; arbeiten. Also steht in der Tabelle ein Zeiger auf Emulate, der hier
; korrigiert wird.

        mov     [Vector_Table + FuncFillPoly], OFFSET FillPoly

; X- und Y-Auflîsung und das Clip-Fenster rÅcksetzen

        xor     ax, ax
        mov     [Clip_X1], ax
        mov     [Clip_Y1], ax

        mov     ax, [DST.XEfRes]                ; Effektive X-Res
        mov     [Clip_X2], ax
        inc     ax
        mov     [MaxX], ax
        mov     [BytesPerLine], ax
        mov     ax, [DST.YEfRes]                ; Effektive Y-Res
        mov     [Clip_Y2], ax
        inc     ax
        mov     [MaxY], ax

; Die fÅr den Modus passende Segment-Umschaltroutine setzen

        mov     di, [ModePtr]
        mov     bl, [(TMode di).CardType]
        xor     bh, bh
        shl     bx, 1
        mov     ax, [SegSwitchTable+bx]
        mov     [SegSelect], ax

; Den Zeiger auf die VESA-Umschaltroutine zurÅcksetzen

IF P80386
        xor     eax, eax
        mov     [VESA_WinFunc], eax
ELSE
        xor     ax, ax
        mov     [WORD LOW VESA_WinFunc], ax
        mov     [WORD HIGH VESA_WinFunc], ax
ENDIF

; Modus einstellen. Hier mÅssen bei gesetzter Option M die VESA-Funktions-
; nummern verwendet werden

        test    [Options], OpUseVesaModes
        jnz     @@L2

; Normale Umschaltung

@@L1:   mov     ax, [(TMode di).BIOSax]
        mov     bx, [(TMode di).BIOSbx]
        jmp     @@L4

; Umschaltung mit VESA-Modusnummern

@@L2:   cmp     [(TMode di).Capabilities], M320x200
        mov     ax, 0013h
        jz      @@L4
        mov     al, [(TMode di).Capabilities]
        mov     bx, 100h
        cmp     al, M640x400
        jz      @@L3
        mov     bl, 01h
        cmp     al, M640x480
        jz      @@L3
        mov     bl, 03h
        cmp     al, M800x600
        jz      @@L3
        mov     bl, 05h
        cmp     al, M1024x768
        jz      @@L3
        mov     bl, 07h
        cmp     al, M1280x1024
        jnz     @@L1
@@L3:   mov     ax, 4F02h
@@L4:   push    di                              ; Zeiger retten
        call    Int10
        pop     di                              ; Zeiger auf Modus-Eintrag

; Jetzt noch eine evtl. vorhandene spezielle Routinen aufrufen

        call    [(TMode di).GraphOn]

; Screen-Paragraphs rechnen und setzen. Das darf erst jetzt geschehen, weil
; die kartenspezifische Routine evtl. BytesPerLine umsetzt.

        mov     ax, [MaxY]
        mul     [BytesPerLine]
        mov     [Word Low ScreenBytes], ax
        mov     [Word High ScreenBytes], dx

; Hintergrundfarbe als Paletteneintrag 0 setzen

		IF P80386        
			movzx     bx, [BkColor]
		ELSE
	        mov     bl, [BkColor]
	        xor     bh, bh
		ENDIF
        mov     ax, 0C000h              ; Code fÅr: Setze Hintergrund
        call    Palette                 ; "Palette"

; das war's bereits

InitEnd:
        ret

ENDP    Init

; ======================================================================
;
; CLEAR: Lîscht den Grafik-Bildschirm
;

PROC    Clear   NEAR

        call    [GE_Ready]              ; Auf die GE warten
        mov     es, [VideoSeg]
        mov     ax, [PageOfs]
        mul     [MaxX]                  ; Startadresse des Bildschirms rechnen
        mov     di, ax                  ; Offset in di
        mov     [Seg64], dl             ; Segment setzen
        call    [SegSelect]             ; Segment einstellen
        cld

IF      P80386
        xor     eax, eax
ELSE
        xor     ax, ax
ENDIF
        mov     cx, [WORD LOW ScreenBytes]
        mov     dx, [WORD HIGH ScreenBytes]
        jcxz    @@L5
        mov     bx, di
        add     bx, cx                  ; SegmentÅberlauf?
        jnc     @@L4                    ; Springe wenn Nein
        jmp     @@L1                    ; Springe wenn SegmentÅberlauf

IF      P80386

@@L0:   mov     bx, di                  ; Rest nach SegmentÅberlauf
@@L1:   mov     cx, di
        neg     cx                      ; Rest bis SegmentÅberlauf
        jnz     @@L2
        mov     ecx, 4000h
        rep     stosd
        jmp     @@L3

@@L2:   movzx   ecx, cx
        shr     cx, 2
        rep     stosd
        adc     cx, cx
        rep     stosw
@@L3:   inc     [Seg64]
        call    [SegSelect]
        movzx   ecx, bx
@@L4:   shr     cx, 2
        rep     stosd
        adc     cx, cx
        rep     stosw
@@L5:   dec     dx
        jns     @@L0

ELSE

@@L0:   mov     bx, di                  ; Rest nach SegmentÅberlauf
@@L1:   mov     cx, di
        neg     cx                      ; Rest bis SegmentÅberlauf
        jnz     @@L2
        mov     cx, 8000h
        jmp     @@L3

@@L2:   shr     cx, 1                   ; Anzahl ist immer gerade
@@L3:   rep     stosw
        inc     [Seg64]
        call    [SegSelect]
        mov     cx, bx
@@L4:   shr     cx, 1                   ; Anzahl ist immer gerade
        rep     stosw
@@L5:   dec     dx
        jns     @@L0

ENDIF

        ret

ENDP    Clear

; =========================================================================
;
; Post-Routine
;

PROC    Post    NEAR

; Wenn der Treiber im Protected-Mode lÑuft und die VESA-Segmentumschaltung
; auch im Protected-Mode aufgerufen wurde, dann ist ein Deskriptor dafÅr
; alloziert worden. Diesen freigeben.

        mov     bx, [WORD HIGH VESA_WinFunc]
        test    bx, bx                          ; Belegt ?
        jz      @@L1                            ; Springe wenn Nein

        call    DPMI_FreeDesc                   ; Deskriptor freigeben

; Den Emulate-Vektor wieder rÅcksetzen: Wie bereits im Kommentar zur
; Vektor-Tabelle ausgefÅhrt, prÅft das Grafik-Kernel ab Version 7.0 den
; FillPoly-Vektor.
; Wenn dieser nicht auf Emulate steht setzt sich das Kernel ein Flag, das
; zur Folge hat, dass Arc und PieSlice mit kleinen Radien nicht mehr korrekt
; arbeiten. Der Vektor in der Tabelle wird also zur Laufzeit (bei Init) erst
; richtig gesetzt. Damit dies auch bei als OBJ-File eingebundenen Treibern
; korrekt tut, muss er hier wieder rÅckgesetzt werden.

@@L1:   mov     [Vector_Table + FuncFillPoly], OFFSET Emulate

; Und Ende...

        ret

ENDP    Post



; =======================================================================
; Farbe setzen, al = Zeichenfarbe, ah = FÅllfarbe
;

PROC    Color Near

        mov     [DrawingColor], al
        mov     [FillColor], ah
        ret

ENDP    Color

; ======================================================================
; Pixel-Cursor bewegen
;

PROC    Move    Near

        mov     [CursorX], ax
        mov     [CursorY], bx
        ret

ENDP    Move

; ======================================================================
;
; Routinen Vect und Draw einbinden
;

INCLUDE "line.asi"


; ======================================================================
;
;       FillPoly
;
; Wird aufgerufen mit:
;       es:bx   Zeiger auf Punkteliste, wobei Teilpolygone mit Punktepaaren
;               $8001/$8001 abgeschlossen werden und das gesamte Polygon
;               nochmals mit $8000/$8000
;               es:bx ist gleichzeitig der Zeiger auf den von GRAPH
;               reservierten Speicherbereich (GraphBuf oder so), der auch fÅr
;               FloodFill benutzt wird. Am Ende der Liste ist daher Platz fÅr
;               eigene Variablen wenn auch nicht klar ist wieviel (im Normal-
;               fall aber 4KB, was bei dem verwendeten Verfahren mehr als genug
;               ist).
;       ax      Anzahl der Punkte, wobei die Trenn- und Abschlu·punkte
;               mitgezÑhlt werden.
;
; Die Åbergebene Liste ist geschlossen, d.h. erster und letzter Punkt eines
; Teilpolygons sind gleich.
;


PROC    FillPoly        NEAR
LOCAL   Y: WORD, YMax: WORD, Count: WORD, VertexList: DWORD, \
        LineList: DWORD, LineCount: WORD = LocalSize

        EnterProc       LocalSize

; Variablen speichern bzw. initialisieren

        and     ax, 7FFFh               ; BP 7.0 (High Bit ist Flag fÅr was ?)
        mov     [Count], ax             ; Anzahl Punkte merken
        mov     [Seg64], -1             ; Kein Segment eingestellt

; Den maximalen und den minimalen Y-Wert aus der Liste raussuchen.
; Die von Graph eingefÅgten Trenn- und Abschlu·punkte werden nicht benîtigt,
; sie werden beim Durchsuchen der Liste gelîscht.
; Die Liste wird ohne diese Punkte hinter die vorige Liste kopiert. Der
; Zeiger VertexList zeigt auf diese neue Liste. Am Ende dieser neuen Liste
; wird die Linien-Liste angelegt.


        push    es
        pop     ds
        mov     si, bx                  ; ds:si = VertexList
        mov     di, bx                  ; es:di = VertexList
        mov     cx, ax                  ; cx = Anzahl Punkte
IF P80286
        shl     ax, 2
ELSE
        shl     ax, 1
        shl     ax, 1                   ; Anzahl * 4
ENDIF
        add     di, ax                  ; es:di zeigt hinter VertexList
        mov     [WORD LOW VertexList], di
        mov     [WORD HIGH VertexList], es
        cld

        mov     bx, [WORD ds:si+2]      ; ersten Y-Wert als YMax...
        mov     dx, bx                  ; ...und als YMin nehmen

Even
@@L0:   lodsw                           ; X-Wert holen
        cmp     ah, 080h                ; Trenn- oder Abschlu·punkt ?
        jz      @@L3                    ; Springe wenn Ja

; Der Punkt ist gÅltig, prÅfen ob er als Maximum oder Minimum in Frage kommt.

        stosw                           ; X-Wert speichern
        ;movsw							; Y-Wert holen / Y-Wert speichern
        lodsw                           ; Y-Wert holen
        stosw                           ; Y-Wert speichern
        cmp     ax, bx                  ; Y-Wert > YMax ?
        jl      @@L1                    ; Springe wenn Nein
        xchg    ax, bx                  ; öbernehme wenn ja
        LOOPCX  @@L0                    ; Wert > Max kann nicht < Min sein
        jmp     @@C1

@@L1:   cmp     ax, dx                  ; Y-Wert < YMin ?
        jg      @@L2                    ; Springe wenn Nein
        xchg    ax, dx                  ; öbernehme wenn ja
@@L2:   LOOPCX  @@L0                    ; NÑchster Punkt
        jmp     @@C1

; Der Punkt ist ungÅltig und wird beim Kopieren Åbersprungen

@@L3:   
		add2    si						; Y-Wert ignorieren
        dec     [Count]                 ; Ein Punkt weniger
        jmp     @@L0                    ; und nÑchster Punkt

; Alle Trenn- und Abschlu·punkte sind jetzt gelîscht, in bx befindet sich
; der grî·te und in dx der kleinste Y-Wert des Polygons. Die Anzahl der
; Punkte in Count entspricht der wirklichen Anzahl.
; Maximum und Minimum werden gespeichert und es wird ein Zeiger auf das
; Ende der Polygon-Liste berechnet, der Platz dahinter dient spÑter zur
; Speicherung der Linienliste.

@@C1:   mov     [WORD LOW LineList], di
        mov     [WORD HIGH LineList], es

        SetToDS ds                      ; Datensegment neu laden
        mov     ax, [Clip_Y2]
        cmp     bx, ax                  ; YMax clippen
        jle     @@C2
        xchg    ax, bx
@@C2:   mov     [YMax], bx

        mov     ax, [Clip_Y1]
        cmp     dx, ax                  ; YMin clippen
        jge     @@C3
        xchg    ax, dx
@@C3:

; FÅr alle Y-Werte des Polygons werden jetzt die Start- und Endpunkte
; horizontaler Linien festgelegt, mit denen spÑter das Polygon gefÅllt wird.
; Die X-Werte werden dabei vorerst unsortiert in der Linienliste abgelegt
; und erst spÑter aufsteigend sortiert.

        mov     [Y], dx                 ; Y mit minimalem Wert initialisieren

; Schleifenbeginn

Even
@@L4:   mov     ax, [Y]
        cmp     ax, [YMax]
        jg      @@L30                   ; Ende erreicht

        mov     [LineCount], 0          ; Keine X-Linienpunkte vorhanden
        les     di, [LineList]          ; Zeiger auf Liste laden
        lds     si, [VertexList]        ; Zeiger auf Polygonliste
        mov     cx, [Count]             ; Anzahl Polygonpunkte
        dec     cx                      ; Eine Linie weniger als Punkte

; Feststellen ob die adressierte Linie den aktuellen Y-Wert schneidet

Even
@@L5:   mov     ax, [Y]                 ; Aktueller Y-Wert
        mov     bx, [WORD ds:si+2]      ; Y-Wert 1
        mov     dx, [WORD ds:si+6]      ; Y-Wert 2
        cmp     bx, dx                  ; bx < dx ?
        jle     @@L6                    ; Springe wenn ja

        cmp     ax, dx                  ; ax >= dx ?
        jl      @@L9                    ; Nein, kein Schnittpunkt
        cmp     ax, bx                  ; ax < bx ?
        jge     @@L9                    ; Nein, kein Schnittpunkt
        jmp     @@C10

@@L6:   cmp     ax, bx                  ; ax >= bx ?
        jl      @@L9                    ; Nein, kein Schnittpunkt
        cmp     ax, dx                  ; ax < dx ?
        jge     @@L9                    ; Nein, kein Schnittpunkt

; Die Linie besitzt geht durch die momentane Y-Koordinate. Den X-Wert
; berechnen, an dem dies stattfindet.

Even
@@C10:  sub     bx, dx                  ; Y-Wert1 - Y-Wert2
        jnz     @@L7

; Die Steigung der Begrenzungslinie des Polygons ist 0 ! FÅr die spÑtere
; Linie mÅssen also beide X-Koordinaten gespeichert werden. Es gibt also
; hier keinen einfachen Schnittpunkt, sondern eine ganze Linie. Deren
; Endkoordinaten werden festgehalten.

        mov     ax, [WORD ds:si]        ; X-Wert 1
        stosw                           ; in Linienliste merken
        inc     [LineCount]             ; Anzahl der Punkte erhîhen
        mov     ax, [WORD ds:si+4]      ; X-Wert 2
        jmp     @@L8                    ; speichern und nÑchste Linie

; Die Linie hat eine echte Steigung, den X-Wert des Schnittpunktes berechnen.

@@L7:   mov     ax, [WORD ds:si]        ; X-Wert 1
        sub     ax, [WORD ds:si+4]      ; - X-Wert 2
        mov     dx, [Y]                 ; Aktuelles Y
        sub     dx, [WORD ds:si+2]      ; - Start-Y
        imul    dx                      ;
        idiv    bx                      ;
        add     ax, [WORD ds:si]        ; X-Wert in ax

; Errechneten X-Wert speichern und Anzahl der Werte erhîhen

@@L8:   stosw                           ; X-Wert speichern
        inc     [LineCount]

; NÑchste Linie adressieren

@@L9:   add     si, 4                   ; NÑchster Polygonpunkt
        LOOPCX  @@L5

; In der Linienliste befindet sich jetzt eine ungeordnete Folge von
; X-Werten. Diese mÅssen aufsteigend sortiert werden.
; es und ds zeigen noch auf dasselbe Segment, das von VertexList bzw.
; LineList und mÅssen deshalb nicht neu geladen werden.
; Ausserdem kann die Tatsache ausgenutzt werden, da· es=ds.

        mov     si, [WORD LOW LineList] ; Offset von LineList laden
        mov     cx, [LineCount]         ; ZÑhler
        jcxz    @@L20                   ; Es gibt keine Punkte !
        dec     cx                      ;

Even
@@L10:  lodsw                           ; Ersten Wert holen
        mov     dx, cx                  ; Anzahl restliche Werte
        mov     di, si

Even
@@L11:  scasw                           ; ax > aktueller Wert ?
        jle     @@L12                   ; Springe wenn Nein
        xchg    ax, [WORD di-2]         ; Tauschen
@@L12:  dec     dx
        jnz     @@L11

        mov     [WORD ds:si-2], ax      ; Kleinsten Wert rÅckspeichern
        LOOPCX  @@L10                   ; NÑchster X-Wert

; Die Linienliste ist jetzt aufsteigend sortiert. FÅr jeweils zwei
; Punkte daraus wird ein horizontale Linie ausgegeben. Dazu mu·
; zuerst das ds-Register wieder restauriert werden, da ein Zugriff
; auf das Datensegment ab hier notwendig ist.
; Zum Zeichnen der Linien wird der HorLine-Vektor verwendet.
; Die Linie mu· noch in X-Richtung geclippt werden.


        SetToDS ds                      ; Datensegment laden
        mov     es, [VideoSeg]          ; und Videosegment nach es ...
        call    [GE_Ready]              ; Warten bis GE fertig
        call    [HorLineInit]           ; Initialisierung fÅr HorLine durchfÅhren
        mov     si, [WORD LOW LineList]
@@L15:  mov     ds, [WORD HIGH LineList]
        lodsw                           ; Erster X-Wert
        xchg    ax, bx
        lodsw                           ; Zweiter X-Wert
        xchg    ax, cx

        SetToDS ds                      ; Datensegment neu laden

        mov     ax, [Clip_X1]
        mov     dx, [Clip_X2]
        cmp     bx, dx                  ; Linie rechts au·erhalb ?
        jg      @@L18                   ; Keine Linie wenn ja
        cmp     bx, ax                  ; X1 clippen
        jg      @@L16
        mov     bx, ax
@@L16:  cmp     cx, ax                  ; Linie links au·erhalb ?
        jl      @@L18                   ; Keine Linie wenn ja
        cmp     cx, dx                  ; X2 clippen
        jl      @@L17
        mov     cx, dx
@@L17:
        mov     ax, [Y]
        push    si
        call    [HorLine]
        pop     si
@@L18:  sub     [LineCount], 2          ; Zwei Punkte verwendet
        ja      @@L15                   ; Weiter wenn noch welche da

; Weiter mit dem nÑchsten Y-Wert

@@L20:  inc     [Y]
        jmp     @@L4                    ; NÑchster Y-Wert

; Ende. Datensegment mu· nicht restauriert werden.

@@L30:  LeaveProc
        ret

ENDP    FillPoly

; ======================================================================
;
;         DW      FILLSTYLE       ; Set the filling pattern
;
;   Input:
;      al         Primary fill pattern number
;      es:bx      If the pattern number is 0FFh, this points to user define
;                 pattern mask.
;
;   Return:
;      Nothing
;
;

PROC    FillStyle Near

        cmp     al,0FFh                 ; User defined ?
        jnz     @@L2                    ; Nein

; Das User-Pattern wird an den letzten Tabellenplatz kopiert und kriegt
; dann die Nummer 12

        mov     cx, 8                   ; 8 Bytes
        mov     di, OFFSET UserPattern  ; usw...
@@L1:   mov     al, [es:bx]
        mov     [di],al
        inc     di
        inc     bx
        loop    @@L1
        mov     al, 12                  ; User-defined

; Hier geht's bei allen Patterns weiter

@@L2:   mov     [FillPatternNum], al

; Jetzt das Pattern zum schnelleren Zugriff noch kopieren
; cld wurde bereits vom Dispatcher gesetzt

        cbw                             ; ah = 0
IF P80286
        shl     ax, 3
ELSE
		shl     ax, 1
		shl     ax, 1
        shl     ax, 1                  ; * 8
ENDIF
        xchg    si, ax                  ; xchg statt mov
        add     si, OFFSET FillPatternTable
        mov     di, OFFSET FillPattern
        push    ds
        pop     es
IF P80386
        movsd
        movsd
ELSE
        movsw
        movsw
        movsw
        movsw
ENDIF
; Und Ende

        ret

ENDP    FillStyle

; ==========================================================================
; Textausgabe
;
;         DW      TEXT            ; Hardware text output at (CP)
;
;   Input:
;      es:bx      --> ASCII text of the string
;      cx         The length (in characters) of the string.
;
; This function is used to send hardware text to the output device. The text
; is output to the device beginning at the (CP). The (CP) is assumed to be
; at the upper left of the string.
;
;

;---------------------------------------------------
; Unterprogramm fÅr Text-Ausgabe
; Input
;  di = Zeichen
; RETURN
;   Pixel-Darstellung im Puffer CharShape
;

PROC    GetCharShape    Near

        push    bp
        cld

IF P80286
        shl     di, 3
ELSE
        shl     di, 1
        shl     di, 1
        shl     di, 1                   ; * 8 fÅr Index bei 8x8 Zeichensatz
ENDIF
        cmp     di, 128 * 8             ; Code >= 128 ?
        jb      ROMCh                   ; Nein

; Zeiger es:di von 0000h:0007Ch holen (RAM-Zeichensatz fÅr Zeichen ab 80h)

IF      Ver3
        les     bx, [Int1F]             ; Vektor 1F holen
ELSE
        xor     bx, bx
        mov     es, bx
        les     bx, [DWORD es:07Ch]
ENDIF
        mov     ax, es
        or      ax, bx                  ; Vektor = NIL ?
        jz      NoChar                  ; JA: Zeichensatz existiert nicht
        lea     di, [es:di+bx-400h]     ; Offset des Zeichens nach di
        jmp     CharOK                  ; es:di --> Zeichen

; Hier Einsprung wenn Zeichen >= 128 aber kein RAM-Zeichensatz geladen

NoChar: mov     di, ' ' * 8             ; Leerzeichen aus ROM nehmen

; es ist nur ein Zeichen < 128 oder es existiert kein RAM-Zeichensatz
; Der ROM-Zeichensatz liegt bei 0F000h:0FA6Eh

ROMCh:  lea     di, [di+ 0FA6Eh]
        mov     es, [SegF000]           ; es:di = 0F000h:0FA6Eh + Zeichenoffset

; Falls der Font um 90¯ gedreht werden mu· --> ab dafÅr
; Beim Einsprung zeigt es:di auf die Pixel-Darstellung des Zeichens
; Zuerst das Zeichen nach ax-dx holen

CharOK: mov     ax,[es:di+00h]                  ; Byte 1 und 2
        mov     bx,[es:di+02h]                  ; etc.
        mov     cx,[es:di+04h]
        mov     dx,[es:di+06h]
        SetToDS es                              ; es = Datensegment
        mov     di, Offset CharShape            ; Dahin soll das Zeichen
        cmp     [TextOrient], 00                ; waagrechter Text ?
        jnz     Rotate                          ; Nein, mu· gedreht werden

; Wir mÅssen das Zeichen nur noch speichern

        stosw                                   ; 1. + 2. Byte
        mov     ax, bx
        stosw                                   ; 2. + 3. ...
        mov     ax, cx
        stosw
        mov     ax, dx
        stosw
        jmp     GetCharEnd

; Das Zeichen mu· gedreht werden

Rotate: mov     bp,0008h
RotLp:  shr     al,1
        rcl     si,1
        shr     ah,1
        rcl     si,1
        shr     bl,1
        rcl     si,1
        shr     bh,1
        rcl     si,1
        shr     cl,1
        rcl     si,1
        shr     ch,1
        rcl     si,1
        shr     dl,1
        rcl     si,1
        shr     dh,1
        rcl     si,1
        xchg    ax,si
        stosb
        xchg    ax,si
        dec     bp
        jnz     RotLp

; Ende, das Zeichen befindet sich im Puffer CharShape

GetCharEnd:
        pop     bp
        ret

ENDP    GetCharShape

;---------------------------------------------------
; Zeichenausgabe Hardware-Text
;
; Zeichen ist in al, bx = X, cx = Y
;

PROC    OutChar Near

Local   YMult: Word, Diff: Word = LocalSize

        EnterProc  LocalSize

; Zuerst Zeichenposition gegen Clip-Fenster prÅfen

        cmp     bx, [Clip_X1]
        jb      OutCharEnd
        mov     di, [Clip_X2]
        sub     di, [TextSizeX]
        inc     di
        cmp     bx, di
        ja      OutCharEnd

        cmp     cx, [Clip_Y1]
        jb      OutCharEnd
        mov     di, [Clip_Y2]
        sub     di, [TextSizeY]
        inc     di
        cmp     cx, di
        ja      OutCharEnd

; Adresse des ersten Punktes rechnen

        xor     ah, ah
        mov     di, ax                  ; Zeichen in di
        mov     ax, cx                  ; ax = Y
        add     ax, [PageOfs]           ; Korrektur fÅr aktuelle Bildschirmseite
        mul     [MaxX]
        add     ax, bx                  ; + X
        adc     dl, 0
        mov     [Seg64], dl             ; Segment merken
        call    [SegSelect]             ; Segment einstellen
        push    ax                      ; Offset merken

; Berechnen, wieviel am Ende einer Zeile (X2) dazugezÑhlt werden mu· um bei
; (X1/Y+1) zu landen

        mov     ax, [MaxX]              ; ZeilenlÑnge in Pixeln
        sub     ax, [TextSizeX]         ; - Zeichengrî·e in Pixeln
        mov     [Diff], ax              ; und speichern

; Die Pixel-Darstellung des Zeichens in den Puffer laden (di = Zeichen)

        call    GetCharShape            ; Pixel-Darstellung --> CharShape

; Variable laden

        mov     si, Offset CharShape    ; Dort steht das Zeichen
        mov     al, [DrawingColor]
        mov     es, [VideoSeg]
        mov     bx, [TextMultX]         ; Ins Register fÅr Speed
        pop     di                      ; Offset

; Y-Schleife

@@OC2:  mov     ah, [si]                ; Pixel in ah
        mov     dx, [TextMultY]
        mov     [YMult], dx

; X-Schleife

@@OC3:  mov     dx, 8                   ; 8 Pixel in bh
@@OC4:  mov     cx, bx                  ; X-Grî·e des Pixels
        rol     ah, 1                   ; Pixel setzen ?
        jc      @@OC5                   ; Ja

; Pixel nicht setzen, trotzdem di erhîhen

        add     di, cx
        jnc     @@OC7                   ; Kein Segment-öbertrag
        inc     [Seg64]                 ; öbertrag
        call    [SegSelect]             ; einstellen
        jmp     @@OC7                   ; NÑchstes Zeichen-Pixel

; Ende hier wegen Sprungoptimierung

OutCharEnd:
        LeaveProc
        ret

; Segment-öberlauf behandeln

@@OC9:  inc     [Seg64]                 ; NÑchstes Segment
        call    [SegSelect]             ; ... einstellen
        jmp     @@OC6

@@OC10: inc     [Seg64]                 ; NÑchstes Segment
        call    [SegSelect]
        jmp     @@OC8

; Pixel XMult mal setzen

@@OC5:  mov     [es:di], al             ; Pixel setzen
        inc     di                      ; NÑchstes Pixel
        jz      @@OC9                   ; Segment-öberlauf behandeln
@@OC6:  LOOPCX  @@OC5

; NÑchstes Zeichen-Pixel

@@OC7:  dec     dx
        jnz     @@OC4

; NÑchste gleiche Zeile

        add     di, [Diff]              ; NÑchste Bildschirmzeile
        jc      @@OC10                  ; öberlauf
@@OC8:  dec     [YMult]
        jnz     @@OC3

; NÑchste Y-Zeile

        inc     si
        cmp     si, Offset CharShape + 8
        jne     @@OC2
        jmp     OutCharEnd

ENDP    OutChar

; ------------------------------------------------------------
; Ausgabe eines Text-Strings (Pixel-Font). Wird vom Dispatcher aufgerufen.

PROC    Text    Near

        call    [GE_Ready]              ; Warten bis die GE fertig ist
        cmp     [TextOrient], 01h       ; 90¯ gedreht ?
        jne     CharLoop
        add     bx, cx
        dec     bx

CharLoop:
        mov     al, [es:bx]             ; Zeichen vom String
        and     al, al                  ; 0 ?
        jz      TextEnd                 ; dann Ende
        push    es
        push    bx
        push    cx
        mov     bx, [CursorX]
        mov     cx, [CursorY]
        call    OutChar                 ; Zeichen ausgeben
        pop     cx
        pop     bx
        pop     es

; GefÑhrlich ! Hier wird die X-Grî·e des Fonts wahlweise auf die X- oder Y-
; Koordinate draufgerechnet. Das tut nur bei einem Hardware-Font, der
; X/Y = 1/1 besitzt.

        mov     dx, [TextSizeX]
        cmp     [TextOrient], 01h       ; 90¯ gedreht ?
        jnz     @@L1
        add     [CursorY], dx
        dec     bx
        jmp     Short @@L2

@@L1:   add     [CursorX], dx
        inc     bx
@@L2:   LOOPCX  CharLoop

; Fertig

TextEnd:
        ret

ENDP    Text

; ========================================================================
; TextStyle
;
;         DW      TEXTSTYLE       ; Hardware text style control
;
;   Input:
;      al         Hardware font number
;      ah         Hardware font orientation
;                 0 = Normal,   1 = 90 Degree,   2 = Down
;      bx         Desired X Character (size in graphics units)
;      cx         Desired Y Character (size in graphics units)
;
;   Return:
;      bx         Closest X Character size available (in graphics units)
;      cx         Closest Y Character size available (in graphics units)
;

PROC    TextStyle Near

        mov     [TextNum], al
        mov     [TextOrient], ah

; X und Y auf je 8 Pixel abrunden und dafÅr sorgen, da· die Grî·e mindestens
; 1 betrÑgt

        and     bx, 00F8h
        jnz     @@L1
        mov     bx, 8
@@L1:   mov     [TextSizeX], bx
        and     cx, 00F8h
        jnz     @@L2
        mov     cx, 8
@@L2:   mov     [TextSizeY], cx

; Die entsprechenden Multiplikatoren setzen

IF P80286
        shr     bl, 3
ELSE
        shr     bl, 1
        shr     bl, 1
        shr     bl, 1                   ; / 8
ENDIF
        mov     [Byte low TextMultX], bl

IF P80286
        shr     cl, 3
ELSE
        shr     cl, 1
        shr     cl, 1
        shr     cl, 1                    ; / 8
ENDIF
        mov     [Byte low TextMultY], cl

; Jetzt die tatsÑchliche Grî·e rÅckliefern

        mov     bx, [TextSizeX]
        mov     cx, [TextSizeY]
        ret

ENDP    TextStyle

; ==========================================================================
;
;         DW      LINESTYLE       ; Set the line drawing pattern
;
;   Input:
;      al         Line pattern number
;      bx         User-defined line drawing pattern
;      cx         Line width for drawing
;
;   Return:
;      Nothing
;
; Sets the current line-drawing style and the width of the line. The line
; width is either one pixel or three pixels in width.
;

PROC    LineStyle Near

        cmp     al, 04h                 ; User-defined ?
        jz      @@L1                    ; ja
        xor     ah, ah
        shl     ax, 1                   ; Nummer * 2 wegen Word
        mov     bx, ax
        mov     bx, [LineStyles+bx]     ; Bitmuster holen
@@L1:   mov     [LinePattern], bx       ; Bitmuster merken
        mov     [LineWidth], cx         ; Linienbreite merken
        ret

ENDP    LineStyle

; ============================================================================
; Clip-Fenster setzen
;
;         DW      SETCLIP         ; Define a clipping rectangle
;
;   Input:
;      ax         Upper Left X coordinate of clipping rectangle
;      bx         Upper Left Y coordinate of clipping rectangle
;      cx         Lower Right X coordinate of clipping rectangle
;      dx         Lower Right Y coordinate of clipping rectangle
;
;   Return:
;      Nothing
;
; The SETCLIP vector defines a rectangular clipping region on the screen. The
; registers (ax,bx) - (cx,dx) define the clipping region.
;
;

PROC    SetClip Near

        mov     [Clip_X1], ax
        mov     [Clip_Y1], bx
        mov     [Clip_X2], cx
        mov     [Clip_Y2], dx
        ret

ENDP    SetClip

; ============================================================================
;
;         DW      SAVEBITMAP      ; Write from screen memory to system memory
;
;   Input:
;      es:bx      Points to the buffer in system memory
;                 to be written. es:[bx] contains the width of the
;                 rectangle -1. es:[bx+2] contains the heigth of
;                 the rectangle -1.
;
;      cx         The upper left X coordinate of the rectangle.
;      dx         The upper left Y coordinate of the rectangle.
;
;   Return:
;      Nothing
;
; The SAVEBITMAP routine is a block copy routine that copies screen pixels
; from a defined rectangle as specified by (si,di) - (cx,dx) to the system
; memory.
;
;

PROC    SaveBitmap      Near

Local SX1:Word, SDiff:Word, SWidth: Word = L

; Stackframe erzeugen

        mov     bp, sp
        sub     sp, L

; Warten bis die GE bereit ist

        call    [GE_Ready]

; X1 speichern. Breite holen und speichern

        mov     [SX1], cx
        mov     ax, [Word es:bx]        ; Breite - 1
        inc     ax
        push    ax                      ; retten

; Errechnen wieviel bei Erreichen des Punktes X2+1 dazugezÑhlt werden mu· um
; X1 in der nÑchsten Linie zu erreichen

        mov     cx, [MaxX]
        sub     cx, ax
        push    cx                      ; Differenz retten

; es:di auf es:bx+4 stellen (Puffer)

        lea     di, [bx+4]

; Nach bx die Anzahl der Zeilen holen

        mov     bx, [es:bx+2]           ; Hîhe - 1
        inc     bx

; Die Adresse des Pixels bei X1/Y1 berechnen. Danach enthÑlt ax:si die aktuelle
; Adresse, ds zeigt auf's Videosegment (keine Variablen mehr !!!)

        mov     ax, dx                  ; Y1
        add     ax, [PageOfs]
        mul     [MaxX]                  ; dx ist futsch
        add     ax, [SX1]
        adc     dl, 0                   ; öberlauf
        xchg    si, ax                  ; Offset nach si
        mov     [Seg64], dl             ; Segment
        call    [SegSelect]             ; Segment einstellen

        mov     ds, [VideoSeg]
        pop     dx                      ; Differenz (X2/Y) zu (X1/Y+1)
        pop     bp                      ; Breite des Rechtecks nach bp

; Y-Schleife

Save1:  mov     cx, bp                  ; Breite des Rechtecks = Anzahl Punkte

; Testen, ob in der Zeile ein Segment-öberlauf auftreten kann

        mov     ax, si                  ; Bildschirm-Offset
        add     ax, cx                  ; + zu holende Pixel
        jc      Save4                   ; Ja, öberlauf

; Zeile hat keinen öberlauf
		RepMovS
; Neue Zeile

Save2:  add     si, dx
        jc      Save7                   ; öbertrag
Save3:  dec     bx                      ; Noch Zeilen ?
        jnz     Save1                   ; Ja

; Ende

        add     sp, L
        ret

; X-Schleife wenn öberlauf

Even
Save4:  movsb                           ; Byte Åbertragen
        test    si, si
        jz      Save6                   ; öbertrag
Save5:  LOOPCX  Save4
        jmp     Save2

; Segment-öberlauf in der X-Schleife korrigieren

Save6:  SetToDS ds
        inc     [Seg64]                 ; öberlauf
        call    [SegSelect]             ; Neues Segment einstellen
        mov     ds, [VideoSeg]
        jmp     Save5

; Segment-öberlauf in der Y-Schleife korrigieren

Save7:  SetToDS ds
        inc     [Seg64]                 ; öberlauf
        call    [SegSelect]             ; Neues Segment einstellen
        mov     ds, [VideoSeg]
        jmp     Save3

ENDP    SaveBitmap


; ============================================================================
;
;         DW      RESTOREBITMAP   ; Write screen memory to the screen.
;
;   Input:
;      es:bx      Points to the buffer in system memory
;                 to be read. es:[bx] contains the width of the
;                 rectangle -1. es:[bx+2] contains the heigth of
;                 the rectangle -1.
;
;      cx         The upper left X coordinate of the rectangle.
;      dx         The upper left Y coordinate of the rectangle.
;
;      al         The pixel operation to use when transferring
;                 the image into graphics memory. Write mode for
;                 block writing.
;                   0: Overwrite mode
;                   1: xor mode
;                   2: OR mode
;                   3: and mode
;                   4: Complement mode
;
;   Return:
;      Nothing
;
; The RESTOREBITMAP vector is used to load screen pixels from the system
; memory. The routine reads a stream of bytes from the system memory into the
; rectangle defined by (si,di) - (cx,dx). The value in the al register
; defines the mode that is used for the write. The following table defines
; the values of the available write modes:
;
;         Pixel Operation                 Code
;          Overwrite mode                  0
;          Logical xor                     1
;          Logical OR                      2
;          Logical and                     3
;          Complement                      4
;
;


;---------------------------------------------------
; Zuerst eine Reihe Unterprogramm, die jeweils eine Zeile im entsprechenden
; Mode kopieren. Registerbelegung siehe RestoreBitmap
;
; Folgende Register dÅrfen von den Unterprogrammen verÑndert werden:
; AX, DI
;
; Die Unterprogramme, die eine VerÑnderung vornehmen sind hier als
; Macro codiert (OPC ist der zustÑndige Operand):
;

MACRO   RestoreOP OP

; Testen, ob in der Zeile ein öberlauf auftreten kann

        mov     ax, di                  ;; Offset
        add     ax, cx                  ;; + zu setzende Pixel
        jc      @@L4                    ;; öberlauf mîglich

; Zeile kann ohne öberlauf kopiert werden

        shr     cx, 1                   ;; Ungerade Anzahl ?
        jnc     @@L1                    ;; Nein
        lodsb                           ;; Ja: Byte verarbeiten
        OP      [BYTE es:di], al
        inc     di
@@L1:   jcxz    @@L7                    ;; Nix mehr zu tun

IF P80386
        shr     cx, 1                   ;; Ungerade Wort-Anzahl ?
        jnc     @@L2                    ;; Nein
        lodsw                           ;; Ja: Wort verarbeiten
        OP      [WORD es:di], ax
        Add2	di
@@L2:   jcxz    @@L7

ALIGN 4
@@L3:   lodsd
        OP      [DWORD es:di], eax      ;; XORen
        add     di, 4
        loop	@@L3
        ret
ELSE

ALIGN 4
@@L2:   lodsw                           ;; Wort holen
        OP      [WORD es:di], ax        ;; XORen
        Add2	di						; nÑchstes Wort adressieren
        loop	@@L2
        ret
ENDIF

; Zeile kopieren wenn Segment-öberlauf

EVEN
@@L4:   lodsb                           ;; Byte holen
        OP      [BYTE es:di], al        ;; XORen
        inc     di
        jz      @@L6                    ;; Kein öbertrag
@@L5:   
		loop	@@L4
@@L7:   ret

@@L6:   mov     ax, ds                  ;; ds retten
        SetToDS ds                      ;; und neu laden
        inc     [Seg64]                 ;; öbertrag
        call    [SegSelect]             ;; Neues Segment setzen
        mov     ds, ax                  ;; altes ds wiederherstellen
        jmp     @@L5

ENDM    RestoreOP






PROC    RestoreOver     Near

; Testen, ob in der Zeile ein öberlauf auftreten kann

        mov     ax, di                  ; Offset
        add     ax, cx                  ; + zu setzende Pixel
        jc      ROver1                  ; öberlauf mîglich

; Kein öberlauf mîglich
		RepMovS
        ret                             ; und Ende

; Zeile kopieren wenn Segment-öberlauf in der Zeile

Even
ROver1: movsb                           ; Byte Åbertragen
        test    di, di
        jz      ROver3                  ; Kein öbertrag
ROver2: LOOPCX  ROver1
        ret

ROver3: mov     ax, ds                  ; ds retten
        SetToDS ds                      ; und neu laden
        inc     [Seg64]                 ; öbertrag
        call    [SegSelect]             ; Neues Segment setzen
        mov     ds, ax                  ; altes ds wiederherstellen
        jmp     ROver2

ENDP    RestoreOver



PROC    RestoreXOR      NEAR

        RestoreOP XOR

ENDP    RestoreXOR



PROC    RestoreOR       NEAR

        RestoreOP OR

ENDP    RestoreOR


PROC    RestoreAND      NEAR

        RestoreOP AND

ENDP    RestoreAND


PROC    RestoreNOT      NEAR

RNOT1:  lodsb                           ; Byte holen
        not     al                      ; Complement
        mov     [Byte es:di], al        ; NOTen
        inc     di
        jz      RNOT3                   ; öbertrag
RNOT2:  LOOPCX  RNOT1
        ret

RNOT3:  mov     ax, ds                  ; ds retten
        SetToDS ds                      ; und neu laden
        inc     [Seg64]                 ; öbertrag
        call    [SegSelect]             ; Neues Segment setzen
        mov     ds, ax                  ; altes ds wiederherstellen
        jmp     RNOT2

ENDP    RestoreNOT





PROC    RestoreTrans    NEAR

@@L1:   mov     al, [si]                ; Byte holen
        inc     si
        test    al, al                   ; = 0
        jz      @@L3                    ; Dann nicht schreiben
        mov     [es:di], al             ; Byte schreiben
        inc     di
        test    di, di                  ; öberlauf ?
        jz      @@L2                    ; Springe wenn ja
        loop	@@L1
        jmp     @@L4                    ; Springe ans Ende

; Segment-öberlauf behandeln
; ACHTUNG: Dies mu· immer geschehen, auch dann wenn der ZÑhler in cx abgelaufen
; ist. Die Abfrage auf cx=0 kommt am Ende der Segmentkorrektur !!!

@@L2:   mov     ax, ds                  ; ds retten
        SetToDS ds                      ; und mit Datensegment laden
        inc     [Seg64]
        call    [SegSelect]
        mov     ds, ax                  ; altes ds
        jcxz    @@L4                    ; Nur fÅr den Fall des Falles
        jmp     @@L1

; Byte nicht schreiben

EVEN
@@L3:   inc     di                      ; Byte Åberspringen
        loopne  @@L1                    ; Schleife wenn kein Seg-öberlauf
        je      @@L2                    ; Springe wenn öberlauf

; Ende

@@L4:   ret

ENDP    RestoreTrans


;---------------------------------------------------
; Eine Tabelle mit den Adressen der Funktionen

RestProcTable   dw      RestoreOver
                dw      RestoreXOR
                dw      RestoreOR
                dw      RestoreAND
                dw      RestoreNOT
                dw      RestoreTrans

;---------------------------------------------------

PROC    RestoreBitmap      NEAR

Local RX1:Word, RWidth: Word, RestProc: Word = LocalSize

; Stackframe erzeugen

        EnterProc       LocalSize
        push    ds                      ; Das brauchen wir
        cld                             ; das auch...

; Warten bis die GE bereit ist

        call    [GE_Ready]

; X1 speichern. RCopy mit einem Vektor belegen, der die Mode entsprechende
; Operation ausfÅhrt. Breite holen und speichern

        mov     [RX1], cx

        cbw                             ; al --> ax
        mov     di, ax                  ; ax --> di
        shl     di, 1                   ; * 2 fÅr Wort
        mov     di, [RestProcTable+di]  ; Adresse
        mov     [RestProc], di          ; speichern

        mov     ax, [WORD es:bx]        ; Breite - 1
        inc     ax
        mov     [RWidth], ax

; Errechnen wieviel bei Erreichen des Punktes X2+1 dazugezÑhlt werden mu· um
; X1 in der nÑchsten Linie zu erreichen

        mov     cx, [MaxX]
        sub     cx, ax
        push    cx                      ; Wert retten

; si auf bx+4 stellen (Puffer)

        lea     si, [bx+4]

; Nach bx die Anzahl der Zeilen holen

        mov     bx, [es:bx+2]           ; Hîhe - 1
        inc     bx

; Die Adresse des Pixels bei X1/Y1 berechnen. Danach enthÑlt ax:di die aktuelle
; Adresse, es zeigt auf's Videosegment, ds auf den Puffer

        mov     ax, dx                  ; Y1
        add     ax, [PageOfs]           ; Bildschirmseiten-Korrektur
        mul     [MaxX]                  ; dx ist futsch
        add     ax, [RX1]
        adc     dl, 0                   ; öberlauf
        xchg    di, ax                  ; Offset nach di
        mov     [Seg64], dl             ; Segment merken
        call    [SegSelect]             ; Segment einstellen

        mov     cx, es
        mov     es, [VideoSeg]          ; VideoSeg in es:di
        mov     ds, cx                  ; Puffer in ds:si

        pop     dx                      ; RDiff ((Y/X2) --> (Y+1/X1) in dx)


; Y-Schleife

@@L1:   mov     cx, [RWidth]            ; Breite des Rechtecks = Anzahl Punkte

; X-Schleife

        call    [RestProc]              ; Doit yeah !

; Neue Zeile

        add     di, dx
        jc      @@L3                    ; öbertrag
@@L2:   dec     bx                      ; Noch Zeilen ?
        jnz     @@L1                    ; Ja

; Ende

        pop     ds
        LeaveProc
        ret

; Segment-öberlauf korrigieren

@@L3:   mov     ax, ds
        SetToDS ds                      ; Datensegment laden
        inc     [Seg64]                 ; öberlauf
        call    [SegSelect]             ; Neues Segment setzen
        mov     ds, ax
        jmp     @@L2

ENDP    RestoreBitMap


; ==========================================================================
;
;         DW      PALETTE         ; Load a color entry into the Palette
;
;   Input:
;      ax         The index number and function code for load
;      bx         The color value to load into the palette
;
;   Return:
;      Nothing
;
; The PALETTE vector is used to load single entries into the palette. The
; register ax contains the function code for the load action and the index
; of the color table entry to be loaded. The upper two bits of ax determine
; the action to be taken. The table below tabulates the actions. If the
; control bits are 00, the color table index in (ax and 03FFFh) is loaded
; with the value in bx. If the control bits are 10, the color table index in
; (ax and 03FFFh) is loaded with the RGB value in (Red=bx, Green=cx, and
; Blue=dx). If the control bits are 11, the color table entry for the
; background is loaded with the value in bx.
;
;  Control Bits           Color Value and Index
;
;       00                Register bx contains color, ax is index
;       01                not used
;       10                Red=bx  Green=cx  Blue=dx, ax is index
;       11                Register bx contains color for background
;

PROC    Palette   Near

        test    ah, 0c0h        ; Code = 00 ?
        jnz     @@L1

; Bits 00, bx = Farbe, ax = Index

        mov     bh, bl
        mov     bl, al           ; bl = Index, bh = Color
        jmp     @@L2

; Bits 10 oder 11

@@L1:   test    ah, 40h
        jz      RGBPalette

; Bits 11, bx ist Hintergrundfarbe

        mov     bh, bl                  ; Farbe in bh
        xor     bl, bl                  ; Index fÅr Hintergrund ist 0
        mov     [BkColor], bh           ; Hintergrundfarbe merken
@@L2:   mov     ax, 1000h               ; Setze Palettenregister
        int     10h
        ret

; Bits 10 --> RGB-Palette
; Zur Anpassung an das Handbuch mÅssen die Farbwerte noch jeweils um 2 Bit nach
; rechts geschoben werden, die untersten 2 Bit sind laut Handbuch nicht belegt,
; der DAC benîtigt aber einen Bereich von 0..3Fh

; énderung am 21.08.1991 laut c't 9/91 S. 162. Vor dem Setzen des Blau-Anteils
; wird auf den horizontalen StrahlrÅcklauf gewartet um Zugriffskonflikte
; ("Schnee") zu verhindern. Interrupts werden nicht mehr gesperrt.

RGBPalette:
IF P80286
        shr     bx, 2
        shr     cx, 2
        shr     dx, 2
ELSE
        shr     bx, 1
        shr     bx, 1
        shr     cx, 1
        shr     cx, 1
        shr     dx, 1
        shr     dx, 1
ENDIF

        mov     si, dx
        mov     dx, 3C8h

        out     dx, al                  ; Nummer des Eintrags
        inc     dx
        mov     ax, bx
        out     dx, al                  ; Red
        mov     ax, cx
        out     dx, al                  ; Green

; Warten auf den horizontalen StrahlrÅcklauf

        mov     dx, 03DAh
@@L3:   in      al, dx
        test    al, 1
        jnz     @@L3                    ; Auf das Ende des H-Syncs warten
@@L4:   in      al, dx
        test    al, 1
        jz      @@L4                    ; Auf den Beginn des H-Syncs warten

; Blau-Anteil jetzt setzen

        mov     dx, 03C9h
        xchg    ax, si
        out     dx, al                  ; Blue

; Ende

        ret

ENDP    Palette


; ======================================================================
;
;         DW      ALLPALETTE      ; Load the full palette
;
;   Input:
;      es:bx --> array of palette entries
;
;   Return:
;      Nothing
;
; The ALLPALETTE routine loads the entire palette in one driver
; call. The register pair es:bx points to the table of values to be loaded
; into the palette. The number of entries is determined by the color entries
; in the Driver Status Table. The background color is not explicitly loaded
; with this command.
;
;

PROC    AllPalette      Near

        mov     al, 02h
        mov     dx, bx
        mov     ah, 16                  ; 16 StÅck hier nur wegen KompatibilitÑt
        int     10h                     ; Setze Palette
        ret

ENDP    AllPalette

; =========================================================================
;
;         DW      TEXTSIZ         ; Determine the height and width of text
;                                 ; strings in graphics units.
;
;   Input:
;      es:bx      --> ASCII text of the string
;      cx         The length (in characters) of the string.
;
;   Return:
;      bx         The width of the string in graphics units.
;      cx         The height of the string in graphics units.
;
; This function is used to determine the actual physical length and width of
; a text string. The current text attributes (set by TEXTSTYLE) are used to
; determine the actual dimensions of a string without displaying it. The
; application can thereby determine how a specific string will fit and reduce
; or increase the font size as required. There is NO graphics output for
; this vector. If an error occurs during length calculation, the STAT field
; of the Device Status Record should be marked with the device error code.
;
;

; Hier wird immer von einem horizontalen String ausgegangen !

PROC    TextSize        Near

        xchg    ax, cx                  ; LÑnge nach ax
        mul     [TextSizeX]             ; * Breite eines Zeichens
        xchg    bx, ax                  ; Resultat nach bx
        mov     cx, [TextSizeY]         ; cx ist Hîhe eines Zeichens
        ret

ENDP    TextSize


; =========================================================================
;
; FloodFill-Routine einbinden
;

INCLUDE "fill.asi"


; =========================================================================
;
; Routine zum Holen eines Pixels. Erwartet X/Y in ax/bx.
; Resultat: Farbe in dl.
; Wartet aus Performance-GrÅnden nicht auf die GE
;

PROC    GetPixel Near

        add     bx, [PageOfs]                   ; Bildschirmseiten-Korrektur
        xchg    ax, bx                          ; Y in ax, X in bx
        mul     [MaxX]                          ; * ZeilenlÑnge
        add     bx, ax                          ; + Offset
        adc     dl, 0                           ; Segment-öberlauf
        mov     [Seg64], dl                     ; Segment merken
        call    [SegSelect]                     ; und einstellen
        mov     ds, [VideoSeg]                  ; Videosegment laden
        mov     dl, [bx]                        ; Byte holen
        ret

ENDP    GetPixel



; =========================================================================
;
; Routine zum Setzen eines Pixels. Erwartet X/Y in ax/bx, Farbe in dl.
;
; Wartet aus Performance-GrÅnden nicht auf die GE
;


PROC    PutPixel

        add     bx, [PageOfs]                   ; Bildschirmseiten-Korrektur
        mov     cl, dl                          ; Farbe retten
        xchg    ax, bx                          ; Y in ax, X in bx
        mul     [MaxX]                          ; * ZeilenlÑnge
        add     bx, ax                          ; + Offset
        adc     dl, 0                           ; Segment-öberlauf
        mov     [Seg64], dl                     ; Segment merken
        call    [SegSelect]                     ; Segment einstellen
        mov     ds, [VideoSeg]                  ; Videosegment holen
        mov     [bx], cl                        ; Byte schreiben
        ret

ENDP    PutPixel


; =====================================================================
;
;         DW      BITMAPUTIL      ; Bitmap Utilities Function Table
;
;   Input:
;      Nothing
;
;   Return:
;      es:bx      --> BitMap Utility Table.
;
;
; The BITMAPUTIL vector loads a pointer into es:bx, which is the base of a
; table defining special case-entry points used for pixel manipulation.
; These functions are currently only called by the ellipse emulation routines
; that are in the BGI Kernel. If the device driver does not use emulation
; for ellipses, this entry does not need to be implemented. This entry was
; provided because some hardware requires additional commands to enter and
; exit pixel mode, thus adding overhead to the GETPIXEL and SETPIXEL vectors.
; This overhead affected the drawing speed of the ellipse emulation routines.
; These entry points are provided so that the ellipse emulation routines can
; enter pixel mode, and remain in pixel mode for the duration of the ellipse-
; rendering process.
;
; The format of the BITMAPUTIL table is as follows:
;
;   DW    offset  GOTOGRAPHIC     ; Enter pixel mode on the graphics hardware
;   DW    offset  EXITGRAPHIC     ; Leave pixel mode on the graphics hardware
;   DW    offset  PUTPIXEL        ; Write a pixel to the graphics hardware
;   DW    offset  GETPIXEL        ; Read a pixel from the graphics hardware
;   DW    offset  GETPIXBYTE      ; Return a word containing the pixel depth
;   DW    offset  SET_DRAW_PAGE   ; Select page in which to draw primitives
;   DW    offset  SET_VISUAL_PAGE ; Set the page to be displayed
;   DW    offset  SET_WRITE_MODE  ; xor Line Drawing Control
;
; The parameters of these functions are as follows:
;
;         GOTOGRAPHIC     ; Enter pixel mode on the graphics hardware
;         This function is used to enter the special Pixel Graphics mode.
;
;         EXITGRAPHIC     ; Leave pixel mode on the graphics hardware
;         This function is used to leave the special Pixel Graphics mode.
;
;         PUTPIXEL        ; Write a pixel to the graphics hardware
;         This function has the same format as the PUTPIXEL entry described
;         above.
;
;         GETPIXEL        ; Read a pixel from the graphics hardware
;         This function has the same format as the GETPIXEL entry described
;         above.
;
;         GETPIXBYTE      ; Return a word containing the pixel depth
;         This function returns the number of bits per pixel (color depth) of
;         the graphics hardware in the ax register.
;
;         SET_DRAW_PAGE   ; Select alternate output graphics pages (if any)
;         This function take the desired page number in the al register and
;         selects alternate graphics pages for output of graphics primitives.
;
;         SET_VISUAL_PAGE ; Select the visible alternate graphics pages (if any)
;         This function take the desired page number in the al register and
;         selects alternate graphics for displaying on the screen.
;
;         SET_WRITE_MODE  ; xor Line drawing mode control. xor Mode is selected
;         if the value in ax is one, and disabled if the value in ax is zero.
;
;
;

;--------------------------------

PROC    BitMapUtil Near

        push    ds
        pop     es
        mov     bx, OFFSET BitMapUtilTable
        ret

ENDP    BitMapUtil

;---------------------------------------------------
; Die diversen Funktionen der BitMapUtil-Tabelle beginnen hier

PROC    GetPixByte      FAR

        mov     ax, 8
        ret

ENDP    GetPixByte



PROC    SetWriteMode    FAR

        push    ds
        SetToDS ds
        and     al, 01h
        mov     [WriteMode], al
        pop     ds
        ret

ENDP    SetWriteMode


PROC    SetDrawPage FAR

        push    ds
        SetToDS ds                              ; Datensegment korrekt laden

; Kartenspezifische Routine aufrufen

        mov     bx, [ModePtr]                   ; Zeiger auf Modus-Deskriptor
        
		IF P80386        
			movzx     bl, [(TMode bx).CardType]       ; Kartentyp holen
		ELSE
	        mov     bl, [(TMode bx).CardType]       ; Kartentyp holen
    	    xor     bh, bh                           ; ... nach bx
		ENDIF
      
        shl     bx, 1                           ; * 2 fÅr Wortzugriff
        call    [SetDrawPageTable+bx]           ; kartenspezifischer Aufruf

        pop     ds
        ret

ENDP    SetDrawPage


PROC    SetVisualPage FAR

        push    ds
        SetToDS ds                              ; Datensegment laden

; Kartenspezifische Routine aufrufen

        mov     bx, [ModePtr]                   ; Zeiger auf Modus-Deskriptor
        
		IF P80386        
			movzx   bx, [(TMode bx).CardType]
		ELSE
	        mov     bl, [(TMode bx).CardType]       ; Kartentyp holen
	        xor     bh, bh                           ; ... nach bx
		ENDIF

        
        shl     bx, 1                           ; * 2 fÅr Wortzugriff
        call    [SetVisualPageTable+bx]         ; kartenspezifischer Aufruf

        pop     ds
        ret

ENDP    SetVisualPage


; ========================================================================
;
;         DW      offset COLOR_QUERY      ; Device Color Information Query
;
; This vector is used to inquire about the color capabilities of a given
; piece of hardware. A function code is passed into the driver in al. The
; following function codes are defined:
;
; >>> Color Table Size    al = 000h
;   Input:
;      None:
;
;   Return:
;      bx    The size of the color lookup table.
;      cx    The maximum color number allowed.
;
; The COLOR TABLE SIZE query is used to determine the maximum number of
; colors supported by the hardware. The value returned in the bx register is
; the number of color entries in the color lookup table. The value returned
; in the cx register is the highest number for a color value. This value is
; usually the value in bx minus one; however, there can be exceptions.
;
;
; >>> Default Color Table    al = 001h
;   Input:
;      Nothing
;
;   Return:
;      es:bx   --> default color table for the device
;
; The DEFAULT COLOR TABLE function is used to determine the color table
; values for the default (power-up) color table. The format of this table is
; a byte containing the number of valid entries, followed by the given number
; of bytes of color information.
;
;

PROC    ColorQuery NEAR

        cmp     al,01h
        jz      @@L1
        mov     bx, AvailColors         ; 16 Farben belegt
        mov     cx, MaxColors-1         ; aber 256 zulÑssig
        ret

@@L1:   push    ds
        pop     es
        mov     bx, OFFSET ColorTable
        ret

ENDP    ColorQuery

;   ================================================================
;
;         DW      PATBAR          ; fill rectangle (X1,Y1), (X2,Y2)
;
;   Input:
;      ax         X1--the rectangle's left coordinate
;      bx         Y1--the rectangle's top coordinate
;      cx         X2--the rectangle's right coordinate
;      dx         Y2--the rectangle's bottom coordinate
;
;   Return:
;      Nothing
;
; Fill (but don't outline) the indicated rectangle with the current fill
; pattern and fill color.
;

PROC    PatBar NEAR

Local BX1:Word, BY1:Word, Diff:Word, BHe:Word, BW:Word, Lines:Word, Lines8:Word = L

; Stackframe erzeugen (bp mu· nicht gerettet werden)

        mov     bp, sp
        sub     sp, L

; Warten bis die GE bereit ist

        call    [GE_Ready]

; Y-Werte um den Offset fÅr die eingestellte Bildschirmseite korrigieren

        mov     si, [PageOfs]
        add     bx, si
        add     dx, si

; X1/Y1 und X2/Y2 so umnudeln das X1<=X2 und Y1<=Y2.
; X2 und Y2 werden nur benîtigt um Breite und Hîhe zu rechnen und werden nicht
; gespeichert
; Die Umtauscherei am Anfang ist leider notwendig, wenn auch nicht
; dokumentiert...

        cmp     ax, cx
        jb      @@L1
        xchg    ax, cx
@@L1:   cmp     bx, dx
        jb      @@L2
        xchg    bx, dx
@@L2:   mov     [BX1], ax
        mov     [BY1], bx

; Errechnen wieviel bei Erreichen des Punktes X2+1 dazugezÑhlt werden mu· um
; X1 in der nÑchsten Linie zu erreichen
; Breite und Hîhe in Pixeln rechnen

        sub     dx, bx                  ; Y2 - Y1
        inc     dx                      ; + 1
        mov     [BHe], dx               ; = Hîhe
        sub     cx, ax                  ; X2 - X1
        inc     cx                      ; + 1
        mov     [BW], cx                ; = Breite
        mov     ax, [MaxX]
        sub     ax, cx
        mov     [Diff], ax              ; X2+1+Diff = X1 + MaxX

; Das achtfache der ZeilenlÑnge in Bytes zwischenspeichern. Alle 8 Zeilen
; wiederholt sich nÑmlich das Muster, und (wenn zwischen den 8 Zeilen kein
; öberlauf auftritt) kann einfach mit rep movsb kopiert werden.
; Au·erdem mu· ein ZÑhler fÅr die Zeilen mitgefÅhrt werden, da das nur geht,
; wenn mindestens 7 Zeilen geschrieben worden sind (sieht zwar auch sonst gut
; aus, erfÅllt aber andere Kriterien ).

        mov     ax, [MaxX]              ; ZeilenlÑnge in Bytes
IF P80286
        shl     ax, 3
ELSE
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1                   ; * 8
ENDIF
        mov     [Lines8], ax            ; Bytes fÅr 8 Zeilen
        mov     [Lines], 0000           ; ZeilenzÑhler

; Adresse des gerade bearbeiteten Punktes ist in al:di.

        mov     ax, [MaxX]
        mul     [BY1]                   ; BY1 * MaxX, dx ist futsch
        add     ax, [BX1]
        adc     dx, 0                   ; öberlauf
        mov     di, ax                  ; Offset
        mov     [Seg64], dl             ; Segment
        call    [SegSelect]             ; Segment setzen

; es aufs Videosegment setzen

        mov     es, [VideoSeg]

; BX1 := BX1 mod 8

        and     [BX1], 7                ; BX1 mod 8

; Zwei SpezialfÑlle abprÅfen: EmptyFill und SolidFill.

		IF P80386        
			movzx     ax, [FillColor]
		ELSE
	        xor     ah, ah                  ; Farbe = Hintergrundfarbe
	        mov     al, [FillColor]
		ENDIF

        cmp     [FillPatternNum], SolidFill
        je      PatBar1                 ; al = SolidFill-Farbe
        xchg    ah, al                  ; al=0, ah=FillColor, Flags=Const
        jb      PatBar1                 ; Springe wenn EmptyFill

; Farbe nach bx laden

        mov     bx, ax                  ; bh=FillColor, bl=0 (Hintergrund)

; Y-Schleife
; Passendes Muster fÅr den Y-Wert holen

Even
Bar1:   mov     cx, [BW]                ; Breite des Rechtecks = Anzahl Punkte

; PrÅfen, ob innerhalb der Zeile ein Segment-öberlauf auftreten kann. Wenn
; ja, dann FÅllen mit AbprÅfen des Overflows und Muster per Hand.

        mov     dx, di                  ; Adress Offset
        add     dx, cx                  ; + zu setzende Pixel
        jc      Bar2

; In dieser Zeile tritt kein öberlauf auf.
; Als nÑchstes prÅfen, ob bereits 7 Zeilen auf dem Bildschirm stehen. Wenn
; nicht --> FÅllen zu Fu·

        cmp     [Lines], 7
        jbe     Bar2                    ; war nix

; Wir haben mehr als 7 Zeilen, d.h. wenn die Zeile von 8 Zeilen vorher im
; selben Segment liegt kînnen wir einfach kopieren.

        mov     si, di                  ;
        sub     si, [Lines8]            ; - Bytes fÅr 8 Zeilen
        jc      Bar2                    ; öberlauf, war nix

; Sodele: FÅllen durch Kopieren

        mov     dx, ds                  ; ds retten
        mov     ds, [VideoSeg]          ; ... und auch auf's Videosegment
        test    di, 1                   ; Adresse ungerade ?
        jz      Bar02                   ; Nein
        movsb                           ; 1 Byte kopieren (--> Adresse gerade)
        loopz   Bar03                   ; ein Byte weniger Fertig !
Bar02:
		RepMovS
Bar03:  mov     ds, dx

; NÑchste Linie

Bar4:   inc     [BY1]                   ; NÑchste Zeile
        add     di, [Diff]              ; Adresse weitersetzen
        jc      Bar04                   ; öbertrag auf Segment
Bar0:   inc     [Lines]                 ; Wir haben eine Zeile mehr
        dec     [BHe]                   ; Hîhe - 1
        jnz     Bar1

; Und hier ist das Ende. ds wird nicht rÅckgesetzt, weil der Dispatcher es
; sowieso nochmals popt

PatBarEnd:
        add     sp, L
        ret

; Segment-öberlauf in der Y-Schleife behandeln

Bar04:  inc     [Seg64]                 ; öbertrag
        call    [SegSelect]             ; Segment einstellen
        jmp     Bar0                    ; Und weiter

; ----------------------------------------------------
; Zeile mit öberlauf oder zu wenig Zeilen zum Kopieren
; Passendes Muster fÅr den Y-Wert holen

Bar2:   mov     si, [BY1]
        and     si, 7
        mov     ah, [FillPattern + si]  ; Soll-Pattern in ah, si = Y mod 8
        mov     cx, [BX1]               ; = BX1 mod 8
        rol     ah, cl                  ; Ersten Punkt korrekt einstellen

; Anzahl Punkte holen (neu weil cx zerstîrt worden ist)

        mov     cx, [BW]                ; Breite des Rechtecks = Anzahl Punkte

; Los geht's
; Muster testen (Even fÅr Optimierung)

Even
Bar5:   rol     ah, 1                   ; Punkt setzen ?
        jc      Bar3                    ; Ja
        mov     [Byte es:di], bl        ; BkColor
        inc     di                      ; NÑchste Adresse
        jz      Bar6                    ; öberlauf korrigieren
Bar7:   LOOPCX  Bar5                    ; NÑchster Punkt
        jmp     Bar4                    ; NÑchste Linie

; Hierher wenn Punkt gesetzt wird

Even
Bar3:   mov     [es:di], bh             ; Punkt in FÅllfarbe setzen
        inc     di                      ; NÑchsten Punkt adressieren
        jz      Bar8                    ; öberlauf korigieren
Bar9:   LOOPCX  Bar5                    ; NÑchster Punkt
        jmp     Bar4                    ; NÑchste Linie

; Hier Einsprung bei Segment-öberlÑufen

Bar6:   inc     [Seg64]
        call    [SegSelect]
        jmp     Bar7

Bar8:   inc     [Seg64]
        call    [SegSelect]
        jmp     Bar9

; -------------------------------------------------------------
; Spezialfall fÅr schnelles FÅllen: Kein Muster vorhanden.
; Registerbelegung:
;   AL  = Farbe
;   DI  = Offset im Videosegment
;   ES  = Videosegment

PatBar1:
        mov     si, [BHe]               ; Hîhe des Rechtecks
        mov     bx, [Diff]              ; Wert fÅr öberlauf von X2+1 --> X1
        mov     ah, al                  ; Farbe auch in ah
        mov     bp, [BW]                ; Ab hier keine lokalen Variablen mehr

PB1:    mov     cx, bp                  ; Breite des Rechtecks

; Testen ob innerhalb der Zeile ein Segment-öberlauf auftreten kann

        mov     dx, di                  ; Adress-Offset
        add     dx, cx                  ; + zu setzende Pixel
        jc      PB2                     ; öberlauf in der Zeile

; Zeile ist ohne öberlauf

        test    di, 1                   ; Adresse ungerade ?
        jz      PB4                     ; Nein
        stosb                           ; Punkt setzen
        loopz	PB5						; Breite war 1

PB4:    RepStoS		                    ; / 2
										; Worte setzen bis cx = 0
										; War noch ein Carry ?
										; öbriges Byte falls cx <> 0

; Neue Zeile

PB5:    dec     si                      ; Noch eine Zeile ?
        jz      PatBarEnd               ; Nein, Ende
        add     di, bx                  ; bx = [Diff]
        jnc     PB1
        inc     [Seg64]                 ; öberlauf
        call    [SegSelect]             ; Neues Segment einstellen
        jmp     PB1

; Innerhalb der Zeile ist ein Segment-öberlauf

PB2:    mov     [es:di], al             ; Pixel setzen
        inc     di
        jnz     PB3                     ; kein Segment-öberlauf
        inc     [Seg64]                 ; öberlauf
        call    [SegSelect]             ; und Segment einstellen
PB3:    LOOPCX  PB2
        jmp     PB5

ENDP    PatBar

; ======================================================================
;
;         DW      ARC             ; Draw an elliptical arc
;
;   Input:
;      AX         The starting angle of the arc in degrees (0-360)
;      BX         The ending angle of the arc in degrees (0-360)
;      CX         X radius of the elliptical arc
;      DX         Y radius of the elliptical arc
;
;   Return:
;      Nothing
;
; ARC draws an elliptical arc using the (CP) as the center point of the
; arc, from the given start angle to the given end angle. To get circular
; arcs the application (not the driver) must adjust the Y radius as follows:
;
;      YRAD := XRAD * (ASPEC / 10000)
;
; where ASPEC is the aspect value stored in the DST.
;
;


; ---------------------------------------------------------------------------
;
; Plotten der Punkte (Y/X0-X) und (Y/X0+X). Der Y-Wert liegt definitiv im
; Fenster und befindet sich in ax. Aufgrund des Tricks in der aufrufenden
; Routine ist X1 (di) immer positiv, die Adress-Berechnung verlÑuft also ganz
; normal.
;
; Registerbelegung:
;    ax  = Y
;    di  = X1
;    si  = DeltaX   (X2 - X1)
;    cl  = Flags, Bit0 = X1 setzen, Bit1 = X2 setzen
;

PROC    Plot2   Near

        add     ax, [PageOfs]           ; Korrektur fÅr Bildschirmseite
        mul     [MaxX]
        add     di, ax                  ; Offset im Videosegment
        adc     dl, 0                   ; öberlauf
        cmp     dl, [Seg64]             ; stimmt das Segment schon ?
        jz      @@L1                    ; Ja
        mov     [Seg64], dl             ; Nein: Merken...
        call    [SegSelect]             ; ...und Setzen
@@L1:   mov     al, [DrawingColor]      ; Farbe holen
        test    cl, 01h                 ; Diesen Punkt plotten ?
        jz      @@L2                    ; Nein
        mov     [es:di], al             ; Ja: Punkt setzen
@@L2:   test    cl, 02h                 ; Den zweiten Punkt plotten ?
        jz      @@L4                    ; Nein

; Den zweiten Punkt plotten

        add     di, si                  ; + DeltaX
        jc      @@L3                    ; Segment-öberlauf
        stosb                           ; Punkt setzen
        ret

; Segment-öberlauf korrigieren

@@L3:   inc     [Seg64]                 ; Segment-öberlauf berÅcksichtigen
        call    [SegSelect]             ; Segment setzen
        stosb                           ; Punkt setzen

; Und Ende

@@L4:   ret

ENDP    Plot2

; -------------------------------------------------------------------
; Unterprogramm fÅr Ellipse zum Setzen des 4-fach gespiegelten Punktes mit
; 1 Pixel Durchmesser.
; cx = x, bx = y, ds = DSeg, es = VideoSeg
; ds, es und bp mÅssen bleiben alles andere darf zerstîrt werden.
; In [Seg64] wird das momentan eingestellte Segment erwartet - die Variable ist
; vor Start auf 0ffh zu initialisieren.
;

PROC    EPlot4Thin   Near
Local   X1: WORD = LocalSize

        EnterProc       LocalSize

; X-Werte berechnen und gegen die Clipping-Fenstergrenzen prÅfen

        mov     di, [CursorX]
        sub     di, cx                  ; X1
        mov     [X1], di
        shl     cx, 1                   ; DeltaX
        mov     si, cx                  ; si = DeltaX
        mov     ax, di
        add     ax, cx                  ; X2

        xor     cx, cx                  ; Flags = 0
        cmp     di, [Clip_X1]           ; Linker Punkt links innerhalb ?
        jl      @@L1                    ; Nein
        cmp     di, [Clip_X2]           ; Linker Punkt rechts innerhalb ?
        jg      @@L1                    ; Nein
        or      cl, 1                   ; Bit fÅr linken Punkt setzen
@@L1:   cmp     ax, [Clip_X1]           ; Rechter Punkt links innerhalb ?
        jl      @@L2                    ; Nein
        cmp     ax, [Clip_X2]           ; Rechter Punkt rechts innerhalb ?
        jg      @@L2                    ; Nein
        or      cl, 02h                 ; Bit fÅr rechten Punkt setzen
@@L2:   jcxz    @@L5                    ; Beide Bits 0 --> keine Punkte

; Hier kommt ein etwas "ausgefuchster" Trick: bei negativen X1 wird der linke
; Punkt nicht gezeichnet, da die Plot-Routine aber X1 als vorzeichenlosen
; (und daher dann sehr gro·en) Wert betrachtet und dann durcheinanderkommt,
; wird hier folgender Weg beschritten: X1 wird auf 0 gesetzt und DeltaX wird
; um den Betrag den X1 damit vergrî·ert wurde, vermindert. Damit wird X2
; korrekt geplottet und die Adress-Berechnung stimmt ohne 10-zeilige
; Assembler KlimmzÅge in der innersten Schleife.

        test    di, di                  ; Ist di negativ ?
        jns     @@L3                    ; Nein
        add     si, di                  ; si = DeltaX vermindern
        xor     di, di                  ; X1 = 0
        mov     [X1], di                ; und speichern

; Y-Wert der oberen beiden Punkte berechnen, prÅfen, ob diese Punkte im Fenster
; liegen

@@L3:   mov     ax, [CursorY]           ; Y0
        sub     ax, bx                  ; -Y
        cmp     ax, [Clip_Y2]           ; Y1 unterhalb des Fensters ?
        jg      @@L5                    ; --> Keiner der Punkte wird geplottet
        cmp     ax, [Clip_Y1]           ; Y1 oberhalb des Fensters ?
        jl      @@L4                    ; --> Punkt wird nicht geplottet

; Aufruf der Plot-Funktion. ax = Y, cl = Flags, di = X1, si = DeltaX
; Zerstîrt ax, di

        call    Plot2

; NÑchsten Punkt rechnen

@@L4:   mov     ax, [CursorY]
        add     ax, bx                  ; Y
        cmp     ax, [Clip_Y2]           ; Unterhalb ?
        jg      @@L5                    ; Ja --> Fertig
        cmp     ax, [Clip_Y1]           ; Oberhalb ?
        jl      @@L5                    ; Ja --> Fertig

; Aufruf der Plot-Funktion. ax = Y, cl = Flags, di = X1, si = DeltaX
; Zerstîrt ax, di

        mov     di, [X1]
        call    Plot2

; Fertig !

@@L5:
        LeaveProc
        ret

ENDP    EPlot4Thin


; -------------------------------------------------------------------
; Unterprogramm fÅr Ellipse zum Setzen des 4-fach gespiegelten Punktes mit
; 3 Pixel Durchmesser.
; cx = x, bx = y, ds = DSeg, es = VideoSeg
; ds, es und bp mÅssen bleiben alles andere darf zerstîrt werden.
; In [Seg64] wird das momentan eingestellte Segment erwartet - die Variable ist
; vor Start auf 0ffh zu initialisieren.
;

PROC    EPlot4Thick Near
Local   X: WORD, Y: WORD = LocalSize

        EnterProc       LocalSize

        mov     [X], cx
        mov     [Y], bx

; 5 mal EPlot4Thin aufrufen

        dec     bx
        js      @@L1
        call    EPlot4Thin              ; X/Y-1
@@L1:   mov     bx, [Y]
        mov     cx, [X]
        dec     cx
        js      @@L2
        call    EPlot4Thin              ; X-1/Y
@@L2:   mov     bx, [Y]
        mov     cx, [X]
        call    EPlot4Thin              ; X/Y
        mov     bx, [Y]
        mov     cx, [X]
        inc     cx
        call    EPlot4Thin              ; X+1/Y
        mov     bx, [Y]
        mov     cx, [X]
        inc     bx
        call    EPlot4Thin              ; X/Y+1

; Ende

        LeaveProc
        ret

ENDP    EPlot4Thick

; ----------------------------------------------------------------
; Zeichnen einer (vollen) Ellipse. Verwendet wird der Midpoint-Algorithmus
; aus "Computer Graphics" S. 90  (88ff) aber mit second order differences und
; Zusammenfassung von Faktoren etc.
;
; PROCEDURE Ellipse (X0, Y0, A, B);
;
; VAR
;   X, Y   : INTEGER;
;   Diff   : LONGINT;
;   QA, QB : LONGINT;
;   QA2    : LONGINT;
;   QB2    : LONGINT;
;   DeltaX : LONGINT;
;   DeltaY : LONGINT;
;   R1     : LONGINT;
;
;
; BEGIN
;   X := 0;
;   Y := B;
;   QA := LONGINT (A) * LONGINT (A);
;   QB := LONGINT (B) * LONGINT (B);
;   QA2 := 2 * QA;
;   QB2 := 2 * QB;
;
;   EPixels;
;
;   Diff := QB - (QA * LONGINT (B)) + (QA DIV 4);
;   R1 := QA * LONGINT (Y) - (QA DIV 2) - QB;
;   DeltaX := QB2 + QB;
;   DeltaY := QA2 * LONGINT (-Y + 1);
;
;   WHILE (R1 > 0) DO BEGIN
;     IF (Diff >= 0) THEN BEGIN
;       Inc (Diff, DeltaY);
;       Inc (DeltaY, QA2);
;       Dec (Y);
;       Dec (R1, QA);
;     END;
;     Inc (Diff, DeltaX);
;     Inc (DeltaX, QB2);
;     Inc (X);
;     Dec (R1, QB);
;     EPixels;
;   END;
;
;   Diff := (QB * (LONGINT (X + 1) * LONGINT (X) - QA) + (QB DIV 4)) +
;           (SQR (LONGINT (Y - 1)) * QA);
;   DeltaX := QB2 * LONGINT (X + 1);
;   DeltaY := QA * LONGINT (-2 * Y + 3);
;
;   WHILE (Y > 0) DO BEGIN
;     IF (Diff < 0) THEN BEGIN
;       Inc (Diff, DeltaX);
;       Inc (DeltaX, QB2);
;       Inc (X);
;     END;
;     Inc (Diff, DeltaY);
;     Inc (DeltaY, QA2);
;     Dec (Y);
;     EPixels;
;   END;
; END;
;

; Eintritt mit: cx = X-Radius (A), dx = Y-Radius (B)


PROC    Ellipse   Near

Local X: WORD, Y: WORD, Diff: DWORD, QA: DWORD, QB: DWORD, QA2: DWORD, \
      QB2: DWORD, DeltaX: DWORD, DeltaY: DWORD, R1: DWORD = LocalBytes

; PrÅfen, ob einer der beiden Radien <= 0 ist. Wenn ja, direkt Ende

        test    cx, cx
        jle     @@N1
        test    dx, dx
        jg      @@N2
@@N1:   ret

; Stackframe aufbauen

@@N2:   mov     bp, sp
        sub     sp, LocalBytes

; Variable initialisieren

        mov     [X], 0
        mov     [Y], dx                 ; dx = B
        mov     ax, dx                  ; ax = dx = B
        mul     dx
        mov     [WORD low QB], ax
        mov     [WORD high QB], dx      ; QB := B * B;

        shl     ax, 1
        rcl     dx, 1
        mov     [WORD low QB2], ax
        mov     [WORD high QB2], dx     ; QB2 := QB * 2;

        add     ax, [WORD low QB]
        adc     dx, [WORD high QB]
        mov     [WORD low DeltaX], ax
        mov     [WORD high DeltaX], dx  ; DeltaX := QB2 + QB

        mov     ax, cx                  ; ax = A
        mul     cx                      ;
        mov     [WORD low QA], ax
        mov     [WORD high QA], dx      ; QA := A * A;

        shl     ax, 1
        rcl     dx, 1
        mov     [WORD low QA2], ax
        mov     [WORD high QA2], dx     ; QA2 := QA * 2;

;   DeltaY := QA2 * LONGINT (-Y + 1);

        mov     bx, [Y]
        dec     bx                      ; bx = Y - 1
        mov     cx, dx                  ; high word von QA2 retten
        mul     bx
        mov     di, ax                  ; low word bereits fertig
        mov     si, dx                  ; high word retten
        mov     ax, cx                  ; high word von QA2
        mul     bx
        add     ax, si
        not     di
        not     ax
        sub     di, 1
        sbb     ax, 0
        mov     [WORD low DeltaY], di
        mov     [WORD high DeltaY], ax

;   Diff := QB - (QA * LONGINT (B)) + (QA DIV 4);

        mov     ax, [WORD low QA]
        mov     bx, [WORD high QA]
        mov     di, ax
        mov     si, bx
        shr     si, 1
        rcr     di, 1
        shr     si, 1
        rcr     di, 1
        add     di, [WORD low QB]
        adc     si, [WORD high QB]      ; QB + (QA div 4)

        mul     [Y]                     ; Y = B
        xchg    ax, bx                  ; low word in bx
        mov     cx, dx                  ; high word in cx
        mul     [Y]
        add     ax, cx
        sub     di, bx
        sbb     si, ax                  ; - (QA * B)

        mov     [WORD low Diff], di
        mov     [WORD high Diff], si

;   R1 := QA * LONGINT (Y) - (QA DIV 2) - QB;

        mov     ax, [WORD low QA]
        mov     bx, [WORD high QA]      ; QA = ax:bx
        mov     di, ax
        mov     si, bx
        shr     si, 1
        rcr     di, 1

        mul     [Y]
        xchg    ax, bx
        mov     cx, dx
        mul     [Y]
        add     ax, cx
        sub     bx, di
        sbb     ax, si                  ; QA * Y - (QA div 2)

        sub     bx, [WORD low QB]
        sbb     ax, [WORD high QB]
        mov     [WORD low R1], bx
        mov     [WORD high R1], ax

; Sonstiger Kleinkruscht

        mov     es, [VideoSeg]
        mov     [Seg64], 0FFh           ; Flag fÅr "kein Segment gesetzt"
        mov     cx, [X]
        mov     bx, [Y]
        call    [PlotVector]

; Pfuizz ! Initialisierung fertig, es kommt die Schleife
; WHILE (R1 > 0) DO BEGIN

@@L1:   xor     ax, ax                  ; ax = 0
        cmp     [WORD high R1], ax
        jl      @@L5
        jg      @@L2
        cmp     [WORD low R1], ax
        jbe     @@L5
@@L2:

; IF (Diff >= 0) THEN BEGIN

        cmp     [WORD high Diff], ax
        jl      @@L4
        jg      @@L3
        cmp     [WORD low Diff], ax
        jb      @@L4

; Diff ist >= 0

@@L3:   mov     ax, [WORD low DeltaY]
        mov     dx, [WORD high DeltaY]
        add     [WORD low Diff], ax
        adc     [WORD high Diff], dx    ; Inc (Diff, DeltaY)

        add     ax, [WORD low QA2]
        adc     dx, [WORD high QA2]
        mov     [WORD low DeltaY], ax
        mov     [WORD high DeltaY], dx  ; Inc (DeltaY, QA2)

        dec     [Y]                     ; Dec (Y);

        mov     ax, [WORD low QA]
        mov     dx, [WORD high QA]
        sub     [WORD low R1], ax
        sbb     [WORD high R1], dx      ; Dec (R1, QA);

; Was sonst noch in der ersten Region ausgefÅhrt werden mu·

@@L4:   mov     ax, [WORD low DeltaX]
        mov     dx, [WORD high DeltaX]
        add     [WORD low Diff], ax
        adc     [WORD high Diff], dx    ; Inc (Diff, DeltaY);

        add     ax, [WORD low QB2]
        adc     dx, [WORD high QB2]
        mov     [WORD low DeltaX], ax
        mov     [WORD high DeltaX], dx  ; Inc (DeltaX, QB2);

        inc     [X]                     ; Inc (X);

        mov     ax, [WORD low QB]
        mov     dx, [WORD high QB]
        sub     [WORD low R1], ax
        sbb     [WORD high R1], dx      ; Dec (R1, QB);

; Punkt setzen und neu

        mov     cx, [X]
        mov     bx, [Y]
        call    [PlotVector]
        jmp     @@L1

; Zweite Region: Initialisierungen
;   Diff := (QB * (LONGINT (X + 1) * LONGINT (X) - QA) + (QB DIV 4)) +
;           (SQR (LONGINT (Y - 1)) * QA);
;

@@L5:   mov     ax, [X]
        inc     ax
        mul     [X]                     ; X ist immer positiv, QB auch
        sub     ax, [WORD low QA]
        sbb     dx, [WORD high QA]      ; - QA
        mov     di, ax
        mov     si, dx                  ; X * (X+1) - QA in di:si
        mul     [WORD high QB]
        mov     cx, ax                  ; Zwischenergebnis in bx:cx
        mov     ax, di
        mul     [WORD low QB]
        mov     bx, ax
        add     cx, dx
        mov     ax, si
        mul     [WORD low QB]
        add     cx, ax                  ; bx:cx = ((X+1) * X - QA) * QB

        mov     ax, [WORD low QB]
        mov     dx, [WORD high QB]
        shr     dx, 1
        rcr     ax, 1
        shr     dx, 1
        rcr     ax, 1
        add     bx, ax
        adc     cx, dx                  ; + (QB DIV 4)

        mov     ax, [Y]
        dec     ax                      ; Y-1 (ist immer positiv)
        mul     ax                      ; ax * ax
        mov     di, ax
        mov     si, dx
        mul     [WORD high QA]
        add     cx, ax                  ; Zwischenergebnis in bx:cx
        mov     ax, di
        mul     [WORD low QA]
        add     bx, ax
        adc     cx, dx
        mov     ax, si
        mul     [WORD low QA]
        add     cx, ax                  ; Diff in bx:cx

        mov     [WORD low Diff], bx
        mov     [WORD high Diff], cx

;   DeltaX := QB2 * LONGINT (X + 1);

        mov     bx, [X]
        inc     bx                      ; X+1 ist immer positiv
        mov     ax, [WORD low QB2]
        mul     bx
        mov     [WORD low DeltaX], ax
        mov     cx, dx
        mov     ax, [WORD high QB2]
        mul     bx
        add     ax, cx
        mov     [WORD high DeltaX], ax

;   DeltaY := QA * LONGINT (-2 * Y + 3);

        mov     bx, [Y]
        shl     bx, 1
        sub     bx, 3                   ; bx = 2*Y - 3
        mov     ax, [WORD low QA]
        mul     bx
        xchg    ax, bx
        mov     cx, dx
        mul     [WORD high QA]
        add     ax, cx
        not     bx
        not     ax
        add     bx, 1
        adc     ax, 0
        mov     [WORD low DeltaY], bx
        mov     [WORD high DeltaY], ax

; Gargl ! Aber jetzt geht's los ...

@@L6:   xor     ax, ax
        cmp     [Y], ax
        jle     @@L9

; IF (Diff < 0) THEN BEGIN

        cmp     [WORD high Diff], ax
        jg      @@L8
        jl      @@L7
        cmp     [WORD low Diff], ax
        jnb     @@L8
@@L7:

; Diff ist < 0

        mov     ax, [WORD low DeltaX]
        mov     dx, [WORD high DeltaX]
        add     [WORD low Diff], ax
        adc     [WORD high Diff], dx            ; Inc (Diff, DeltaX);

        add     ax, [WORD low QB2]
        adc     dx, [WORD high QB2]
        mov     [WORD low DeltaX], ax
        mov     [WORD high DeltaX], dx          ; Inc (DeltaX, QB2);

        inc     [X]

; Und der Rest der Schleife

@@L8:   mov     ax, [WORD low DeltaY]
        mov     dx, [WORD high DeltaY]
        add     [WORD low Diff], ax
        adc     [WORD high Diff], dx            ; Inc (Diff, DeltaY)

        add     ax, [WORD low QA2]
        adc     dx, [WORD high QA2]
        mov     [WORD low DeltaY], ax
        mov     [WORD high DeltaY], dx          ; Inc (DeltaY, QA2);

        dec     [Y]

; Punkt setzen und neu

        mov     cx, [X]
        mov     bx, [Y]
        call    [PlotVector]
        jmp     @@L6

; Ende

@@L9:   mov     sp, bp
        ret

ENDP    Ellipse

; ---------------------------------------------------------------------------
; Hauptprogramm fÅr Ellipse. Wird Åber den Dispatcher aufgerufen.

PROC    Arc     NEAR

; Warten bis die GE bereit ist

        call    [GE_Ready]              ; Warten bis GE bereit

; PrÅfen ob es sich um eine 360¯ Ellipse handelt

        test    ax, ax                  ; Startwinkel = 0 ?
        jnz     @@L2                    ; Nein
        cmp     bx, 360                 ; Endwinkel = 360 ?
        jnz     @@L2                    ; Nein

; Es handelt sich um eine 360 Grad-Ellipse.  Liniendicke prÅfen und
; entsprechenden Zeichenvektor zuweisen

        mov     [PlotVector], OFFSET EPlot4Thin
        cmp     [LineWidth], 3          ; Dicke Linien ?
        jnz     @@L1                    ; Nein, dÅnne
        mov     [PlotVector], OFFSET EPlot4Thick

@@L1:   jmp     Ellipse                 ; Nein --> Ellipse

; Es handelt sich um keine 360¯-Ellipse. Emulate aufrufen

@@L2:   call    Emulate                 ; Ellipse emulieren
        ret

ENDP    Arc


;     ==================================================================
;
;         DW      PIESLICE        ; Draw an elliptical pie slice
;
;   Input:
;      AX         The starting angle of the slice in degrees (0-360)
;      BX         The ending angle of the slice in degrees (0-360)
;      CX         X radius of the elliptical slice
;      DX         Y radius of the elliptical slice
;
;   Return:
;      Nothing
;
; PIESLICE draws a filled elliptical pie slice (or wedge) using CP as the
; center of the slice, from the given start angle to the given end angle.
; The current FILLPATTERN and FILLCOLOR is used to fill the slice and it is
; outlined in the current COLOR. To get circular pie slices, the application
; (not the driver) must adjust the Y radius as follows:
;
;     YRAD := XRAD * ASPEC / 10000
;
; where ASPEC is the aspect value stored in the driver's DST.
;
;

PROC    PieSlice Near

; Warten bis die GE bereit ist

        call    [GE_Ready]              ; Warten bis GE bereit

; PrÅfen ob es sich um eine 360¯ Ellipse handelt

        test    ax, ax                  ; Startwinkel = 0 ?
        jnz     @@L2                    ; Nein
        cmp     bx, 360                 ; Endwinkel = 360 ?
        jnz     @@L2                    ; Nein

; Der Plot-Routine von Ellipse einen passenden Wert zuweisen

        mov     [PlotVector], OFFSET FullEllipsePlot

; Ellipse-Prozedur aufrufen

        jmp     Ellipse

; Es handelt sich um keine 360¯-Ellipse. Emulate aufrufen

@@L2:   call    Emulate                 ; Ellipse emulieren
        ret

ENDP    PieSlice

;     ==================================================================
;
;         DW      FILLED_ELLIPSE  ; Draw a filled ellipse at (CP)
;
;   Input:
;      AX         X Radius of the ellipse
;      BX         Y Radius of the ellipse
;
;   Return:
;      Nothing
;
; This vector is used to draw a filled ellipse. The center point of the
; ellipse is assumed to be at the current pointer (CP). The AX Register
; contains the X Radius of the ellipse, and the BX Register contains the Y
; Radius of the ellipse.
;
;

; -------------------------------------------------------------------------
; Ziehen einer horizontalen Linie im aktuellen FÅllmuster ohne Clipping
;
; Unterprogramm fÅr FullEllipsePlot und FillPoly. Wird aufgerufen mit ax = Y,
; bx = X1, cx = X2, es = VideoSegment.
;
; Frei verwendet werden dÅrfen ax, bx, cx, dx, si, di
; Ihre Werte behalten mÅssen es, ds, bp, ss, cs

PROC    Generic_HorLine Near

        cld
        mov     si, ax                  ; Y-Wert fÅr Muster
        and     si, 7                   ; mod 8

; Adresse berechnen

        CalcAdr                         ; Adresse berechnen
        xchg    di, ax                  ; Offset nach di

; Farbe holen

        mov     al, [FillColor]

; Das passende Pattern nach ah holen

        mov     ah, [FillPattern + si]

; Testen, ob das Muster 0FFh (alles farbig) oder 00h (alles Hintergrund) ist.
; Falls ja --> Sonderbehandlung mit rep stosb

        cmp     ah, 0FFh                ; Alles farbig ?
        jz      EPL_Solid
        test    ah, ah                   ; Alles Hintergrund ?
        jnz     EPL_Pattern             ; Nein, Muster
        xor     al, al                   ; Hintergrundfarbe holen

; Die Linie wird in einer Farbe gezogen. Hier geht's mit rep stosb erheblich
; schneller.
; Anzahl nach cx und prÅfen, ob innerhalb der Linie ein Segment-öberlauf
; stattfindet.

EPL_Solid:
        mov     ah, al                  ; Farbe in ah und al
        sub     cx, bx
        inc     cx
        jz      @@L9                    ; LÑnge ist 0
        mov     bx, di
        add     bx, cx
        jnc     @@L2                    ; Kein öberlauf

; Es findet ein öberlauf statt. Die Linie in zwei Teilen zeichnen

        mov     bx, di
        neg     bx                      ; Anzahl bis öberlauf
        sub     cx, bx                  ; In cx der Rest danach
        xchg    bx, cx

; Ersten Teil zeichnen

		RepStoS

; NÑchstes Segment setzen

        inc     [Seg64]                 ; NÑchstes Segment...
        call    [SegSelect]             ; ...setzen
        mov     cx, bx                  ; Restliche Anzahl

; Falls die restliche Anzahl 0 ist passiert hier nix, weil rep dann 0 mal
; ausgefÅhrt wird (ganz im Gegensatz zu weiter unten, loop wird nÑmlich dann
; 65536 mal ausgefÅhrt ... wie wir sie lieben, die Welt der Kompatiblen).

; Den zweiten (bzw. einzigen) Teil der Linie zeichnen

@@L2:   RepStoS

; Fertig !

        ret

; Es wird mit einem Muster gefÅllt. Das Muster befindet sich in ah und mu·
; fÅr die Startkoordinate passend gemacht werden.

EPL_Pattern:
        xchg    bx, cx                  ; cx = X1, bx = X2
        rol     ah, cl                  ; Anfangswert (rol ist immer mod xx)
        xchg    bx, cx                  ; cx = X2, bx = X1

; Anzahl nach cx und prÅfen, ob innerhalb der Linie ein Segment-öberlauf
; stattfindet.

        sub     cx, bx
        inc     cx
        mov     bx, di
        add     bx, cx
        jnc     @@L6                    ; Kein öberlauf

; Es findet ein öberlauf statt. Die Linie in zwei Teilen zeichnen

        mov     bx, di
        neg     bx                      ; Anzahl bis öberlauf
        sub     cx, bx                  ; In cx der Rest danach
        xchg    bx, cx

EVEN
@@L3:   rol     ah, 1
        jnc     @@L4
        stosb                           ; Pixel in Farbe setzen
        LOOPCX  @@L3
        jmp     short @@L5

EVEN
@@L4:   mov     [Byte es:di], 0         ; Pixel in Hintergrundfarbe fÅllen
        inc     di
        LOOPCX  @@L3
@@L5:

        inc     [Seg64]                 ; NÑchstes Segment...
        call    [SegSelect]             ; ...setzen
        mov     cx, bx                  ; Restliche Anzahl

; Den zweiten (einzigen) Teil der Linie zeichnen.

@@L6:   jcxz    @@L9                    ; Nichts zu zeichnen

EVEN
@@L7:   rol     ah, 1
        jnc     @@L8
        stosb                           ; Pixel in Farbe setzen
        LOOPCX  @@L7
        jmp     short @@L9

EVEN
@@L8:   mov     [Byte es:di], 0         ; Pixel in Hintergrundfarbe fÅllen
        inc     di
        LOOPCX  @@L7

; Das war's

@@L9:   ret

ENDP    Generic_HorLine

; -------------------------------------------------------------------
; Unterprogramm fÅr FilledEllipse zum Zeichnen der Ellipse.
;
; cx = x, bx = y, ds = cs, es = VideoSeg
; ds, es und bp mÅssen bleiben alles andere darf zerstîrt werden.
; In [Seg64] wird das momentan eingestellte Segment erwartet - die Variable ist
; vor Start auf 0ffh zu initialisieren.
;

PROC    FullEllipsePlot NEAR
Local   Y:WORD, X1: WORD, X2: WORD = LocalSize

        EnterProc       LocalSize

; Horizontale Linie initialisieren

        call    [HorLineInit]

; öbergebenen Y-Wert merken

        mov     [Y], bx

; X1 und X2 rechnen und entsprechend korrigieren

        mov     ax, cx
        neg     cx
        add     cx, [CursorX]           ; cx = X1
        add     ax, [CursorX]           ; ax = X2

        mov     dx, [Clip_X1]           ; Ecke links ins Register
        cmp     ax, dx                  ; Rechte Ecke links au·erhalb ?
        jl      @@L9                    ; Ja --> Garnichts zeichnen
        cmp     cx, dx                  ; Linke Ecke links au·erhalb ?
        jge     @@L1                    ; Nein
        mov     cx, dx                  ; Ja --> X1 auf linke Ecke korrigieren
@@L1:   mov     dx, [Clip_X2]           ; Ecke rechts ins Register
        cmp     cx, dx                  ; linke Ecke rechts au·erhalb ?
        jg      @@L9                    ; Ja --> Garnichts zu zeichnen
        cmp     ax, dx                  ; Rechte Ecke rechts au·erhalb ?
        jle     @@L2                    ; Nein
        mov     ax, dx                  ; Ja --> X2 auf rechte Ecke korrigieren
@@L2:

; Werte merken

        mov     [X1], cx
        mov     [X2], ax

; Y-Wert der oberen Linie rechnen und sehen, ob er im Fenster liegt.

        neg     bx
        add     bx, [CursorY]           ; bx = Y0 - Y
        cmp     bx, [Clip_Y2]           ; Unterhalb des Fensters ?
        jg      @@L9                    ; Ja --> Garnichts zu zeichnen
        cmp     bx, [Clip_Y1]           ; Im Fenster ?
        jl      @@L5                    ; Nein --> Keine Linie

; Die obere der beiden Linien liegt im Fenster, zeichnen

        xchg    bx, ax                  ; ax = Y, bx = X2
        xchg    bx, cx                  ; bx = X1, cx = X2
        call    [HorLine]

; Y-Wert der unteren Linie rechnen und sehen, ob er im Fenster liegt

@@L5:   mov     ax, [Y]
        add     ax, [CursorY]
        cmp     ax, [Clip_Y2]           ; Unterhalb des Fensters ?
        jg      @@L9                    ; Ja --> keine Linie
        cmp     ax, [Clip_Y1]           ; Oberhalb des Fensters ?
        jl      @@L9                    ; Ja --> keine Linie

; Die untere Linie Zeichnen

        mov     bx, [X1]
        mov     cx, [X2]
        call    [HorLine]

; Fertig !

@@L9:   LeaveProc
        ret

ENDP    FullEllipsePlot


; ----------------------------------------------------------------------
;
; Unterprogramm zum Zeichnen einer gefÅllten Ellipse. Es wird Ellipse mit
; einem entsprechenden Plot-Vektor verwendet.
;

PROC    FilledEllipse  NEAR

; Warten bis die GE bereit ist

        call    [GE_Ready]

; Umspeichern nach cx:dx, da DoEllipse die Radien dort erwartet

        xchg    cx, ax
        xchg    dx, bx

; Der Plot-Routine von Ellipse einen passenden Wert zuweisen

        mov     [PlotVector], OFFSET FullEllipsePlot

; Ellipse-Prozedur aufrufen

        jmp     Ellipse

ENDP    FilledEllipse


; -----------------------------------------------------------------

IF      Ver3
ENDS   Code

; -----------------------------------------------------------------

SEGMENT DATA PARA PUBLIC 'DATA'
ENDIF

;---------------------------------------------------
; Protected-Mode Variable

IF Ver3
; Die folgende Struktur _mu·_ zuallererst im Datensegment liegen !

                db      4               ; Anzahl Segmente
                dw      OFFSET Segs
                db      1               ; Ein Int-Vektor wird benîtigt
                dw      OFFSET Ints
                db      1               ; Low-Mem Segmente
                dw      LowSegs
                db      0               ; Data nicht ins Low-Mem
                dw      0
ENDIF
ProtMode        db      0               ; Protected Mode wenn != 0


LABEL           Segs
SegB800         dw      0B800h
VideoSeg        dw      0A000h
SegC000         dw      0C000h
SegF000         dw      0F000h

IF Ver3
LABEL           Ints
Int1F           dd      1Fh

LABEL           LowSegs
                dw      16              ; Grî·e: 16 Paras (256 Bytes)
LowBufSeg       dw      0               ; Real-Mode Segment
LowBufSel       dw      0               ; Protected Mode Selector
ELSE

; Statischer Puffer im Low Memory fÅr Versionen vor 3.0
LowBuf          db      256 dup (?)

ENDIF

;---------------------------------------------------
; Statische Struct zum Aufruf eines simulierten Real-Mode INTs

IF Ver3
RMRegs          RealModeRegs <>
ENDIF

;---------------------------------------------------
; Vektor-Tabelle
; Bemerkung zur Tabelle: Nach c't 11/89, 9/90 und 2/91 enthÑlt der Vektor
; 14 (0Eh) einen Einsprung fÅr den Scan-Konverter von FillPoly. Dieser Vektor
; wird jedoch nicht eingetragen, da das Grafik-Kernel von BP 7.0 diesen
; Vektor prÅft und wenn dieser nicht mehr auf Emulate zeigt, ein Flag setzt,
; was zur Folge hat, das Arc und PieSlice mit kleinen Radien nicht mehr
; korrekt arbeiten. Also steht der Vektor hier auf Emulate und wird spÑter
; (bei Init) auf den Offset von FillPoly gesetzt.
;

LABEL   Vector_Table  WORD

        dw      Install
        dw      Init
        dw      Clear
        dw      Post
        dw      Move
        dw      Draw
        dw      Vect
        dw      Emulate                 ; FillPoly, s.o.
        dw      Emulate                 ; Bar = Emulate
        dw      PatBar
        dw      Arc
        dw      Emulate                 ; Pieslice = Emulate
        dw      FilledEllipse
        dw      Palette
        dw      AllPalette
        dw      Color
        dw      FillStyle
        dw      LineStyle
        dw      TextStyle
        dw      Text
        dw      TextSize
        dw      NOP_Vector              ; Reserved
        dw      FloodFill
        dw      GetPixel
        dw      PutPixel
        dw      BitMapUtil
        dw      SaveBitMap
        dw      RestoreBitMap
        dw      SetClip
        dw      ColorQuery

        dw      35 dup (NOP_Vector)      ; Reserved for Borland use

; -------------------------------------------------------
; Hier kommen Vektoren, die intern verwendet werden.

SegSelect       dw      NOP_Vector      ; Vektor fÅr Segment-Umschaltung
PlotVector      dw      EPlot4Thin      ; Zeichenvektor fÅr DoEllipse
HorLine         dw      Generic_HorLine ; Horizontale Linie im aktuellen FÅllmuster
HorLineInit     dw      NOP_Vector      ; Init fÅr HorLine
GE_Ready        dw      NOP_Vector      ; Wartet bis die Hardware Engine fertig ist

; ------------------------------------------------------------
; BitMap-Utility Tabelle

BitMapUtilTable:
        dw      FAR_NOP_Vector          ; GotoGraphic nicht implementiert
        dw      FAR_NOP_Vector          ; ExitGraphic nicht implementiert
        dw      FAR_NOP_Vector          ; PutPixel nicht implementiert
        dw      FAR_NOP_Vector          ; GetPixel nicht implementiert
        dw      GetPixByte
        dw      SetDrawPage             ; SetDrawPage
        dw      SetVisualPage           ; SetVisualPage
        dw      SetWriteMode

;---------------------------------------------------
; Flags fÅr Optionen. Siehe die entsprechenden Konstanten in const.asi

Options         dw      0
OptText         db      9, "SVGAOPTS="

;---------------------------------------------------
; Grî·e des Bildschirms in Bytes als LongInt (fÅrs Lîschen)

ScreenBytes     dd      0

;---------------------------------------------------
; X- und Y-Auflîsung des gerade aktiven Modus und Y-Offset der aktuelle
; Seite.
; BytesPerLine sind die Anzahl Bytes pro Scanzeile. Sie entsprechen
; normalerweise MaxX (BytesPerLine ist neu mit Version 3.51, vorher
; wurde mit MaxX gerechnet), kînnen bei VESA-Treibern aber auch unter-
; schiedlich (grî·er) sein.

MaxX            dw      0
MaxY            dw      0
BytesPerLine    dw      0
PageOfs         dw      0

;---------------------------------------------------
; Clip-Fenster

Clip_X1         dw      0
Clip_Y1         dw      0
Clip_X2         dw      0
Clip_Y2         dw      0

;---------------------------------------------------
; Hier stehen die Farben: Hintergrundfarbe, Zeichen- und FÅllfarbe
;

BkColor         db      00h             ; Kommt nach Palettenregister 0
DrawingColor    db      0Fh             ; Zeichenfarbe
FillColor       db      0Fh             ; FÅllfarbe

;---------------------------------------------------
; Variable fÅr FloodFill.

BorderColor     db      ?               ; Begrenzungsfarbe
EVEN
StackBot        =       512             ; Unterer Teil des Stacks
StackTop        dw      ?               ; Oberes Ende
StackPtr        dw      ?               ; Zeiger in Stack
PrevXR          dw      ?
CurrXR          dw      ?
FillDir         dw      ?

;---------------------------------------------------
; Byte in dem das Segment reingeschrieben wird. Die SegSelect-Routinen
; verwenden dieses Byte.

Seg64           db      0FFh            ; -1 = Nicht gesetzt

;---------------------------------------------------
; Die Default-Farbtabelle enthÑlt 16 EintrÑge:

ColorTable      db      10h     ; 16 EintrÑge folgen
                db      00h, 01h, 02h, 03h, 04h, 05h, 06h, 07h
                db      08h, 09h, 0Ah, 0Bh, 0Ch, 0Dh, 0Eh, 0Fh

;---------------------------------------------------
; WriteMode zum Linien-Zeichnen, 01 = XORMode, 00 = Normal

WriteMode       db      0

;---------------------------------------------------
; X und Y Koordinate des "Current Drawing Pointers"

EVEN

CursorX         dw      0
CursorY         dw      0

;---------------------------------------------------
; Diverse Informationen fÅr den Hardware-Font

TextSizeX       dw      8               ; Pixels
TextSizeY       dw      8               ; Pixels
TextNum         db      00h             ; Nummer ist immer 0
TextOrient      db      00h             ; 0 = horiz., 1 = vert.
TextMultX       dw      01h             ; Text X-Multiplikator
TextMultY       dw      01h             ; Text Y-Multiplikator

;---------------------------------------------------
; LinePattern (Pattern fÅr gesetzten LineStyle) und Linienbreite

LinePattern     dw      0FFFFh          ; SolidLn
LineWidth       dw      1

;---------------------------------------------------
; Tabelle der Bitmuster fÅr die Linestyles.

LineStyles      dw      0FFFFh          ; SolidLn
                dw      0CCCCh          ; DottedLn
                dw      0FC78h          ; CenterLn
                dw      0F8F8h          ; DashedLn

;---------------------------------------------------
; Hier steht die Nummer des gerade aktiven Fill-Patterns (0-12), wobei
; 2-11 in der Tabelle Fillpatterns stehen, das User-Pattern mit 12 codiert
; ist statt 0FFh) und hinter die Tabelle kopiert wird.

FillPatternNum  db      SolidFill

; Hierher wird das aktuelle Fill-Pattern zum schnelleren Zugriff kopiert

FillPattern     db      8 dup (?)

;---------------------------------------------------
; FillPatterns kommen hier

LABEL   FillPatternTable        BYTE
        db      000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h  ;Empty Fill
        db      0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh  ;Solid Fill
        db      0FFh, 0FFh, 000h, 000h, 0FFh, 0FFh, 000h, 000h  ;Line Fill
        db      001h, 002h, 004h, 008h, 010h, 020h, 040h, 080h  ;Lt Slash Fill
        db      0E0h, 0C1h, 083h, 007h, 00Eh, 01Ch, 038h, 070h  ;Slash Fill
        db      0F0h, 078h, 03Ch, 01Eh, 00Fh, 087h, 0C3h, 0E1h  ;Backslash Fill
        db      0A5h, 0D2h, 069h, 0B4h, 05Ah, 02Dh, 096h, 04Bh  ;Lt Bkslash Fill
        db      0FFh, 088h, 088h, 088h, 0FFh, 088h, 088h, 088h  ;Hatch Fill
        db      081h, 042h, 024h, 018h, 018h, 024h, 042h, 081h  ;XHatch Fill
        db      0CCh, 033h, 0CCh, 033h, 0CCh, 033h, 0CCh, 033h  ;Interleave Fill
        db      080h, 000h, 008h, 000h, 080h, 000h, 008h, 000h  ;Wide Dot Fill
        db      088h, 000h, 022h, 000h, 088h, 000h, 022h, 000h  ;Close Dot Fill

; Der letzte Eintrag ist fÅr das User-Pattern freigehalten, das hierher
; kopiert wird.

UserPattern     db      8 dup (0)

;---------------------------------------------------
; Die Pixel-Darstellung des auszugebenden Zeichens (Hardware-Text)

CharShape       db      8 dup (0)

;---------------------------------------------------
; Variablen fÅr ATI Wonder (XL):
; ATI Identifikationsstring, der sich bei C000:0031 findet,
; eine Tabelle der ATI-Modusnummern mit den entsprechenden Bitmasken
; fÅr den Autodetect und die Adresse des Extended-Registers der ATI-Wonder
;

ATI_Ident       db      "761295520"
ATI_Modes       db      61h, M640x400
                db      62h, M640x480
                db      63h, M800x600
                db      64h, M1024x768
                db      00h                     ; Endekennung
Extended_Reg    dw      1CEh

;---------------------------------------------------
; Identifikationsstring von Paradise VGA's

Paradise_Ident  db      "VGA="

;---------------------------------------------------
; Variablen zum Ansprechen der VESA-Funktionen
;

VESA_Granularity        db      1       ; GranularitÑt des Fensters
EVEN
VESA_Window             dw      0       ; Verwendetes Fenster
VESA_WinFunc            dd      0       ; Zeiger auf Segmentumschalt-Routine


;---------------------------------------------------
; Die Namen der verschiedenen Modi. Auf die Namen wird Åber eine Tabelle
; mit Zeigern auf die Strings zugegriffen, wobei zwischen den normalen
; und den Autodetect-Modi unterschieden wird.

VGA256Name      db      15, "320x200x256 VGA", 0
VGA350Name      db      16, "640x350x256 SVGA", 0
VGA400Name      db      16, "640x400x256 SVGA", 0
VGA480Name      db      16, "640x480x256 SVGA", 0
VGA540Name      db      16, "720x540x256 SVGA", 0
VGA600Name      db      16, "800x600x256 SVGA", 0
VGA768Name      db      17, "1024x768x256 SVGA", 0
VGA1024Name     db      18, "1280x1024x256 SVGA", 0
VGAXXXName      db      15, "Autodetect SVGA", 00


; -------------------------------------------------------------
; Tabellen fÅr Autodetect
; Eine Tabelle mit Zeigern auf die Namen

LABEL   AutoName WORD
        dw      VGAXXXName      ; Modus 1
        dw      VGA400Name      ; Modus 2
        dw      VGA480Name      ; Modus 3
        dw      VGA600Name      ; Modus 4
        dw      VGA768Name      ; Modus 5
        dw      VGA1024Name     ; Modus 6

; Tabelle mit den Mode-Bits fÅr die Autodetect-Modi

LABEL   AutoMode BYTE
        db      MAll            ; Modus 1
        db      M640x400        ; Modus 2
        db      M640x480        ; Modus 3
        db      M800x600        ; Modus 4
        db      M1024x768       ; Modus 5
        db      M1280x1024      ; Modus 6

; --------------------------------------------------------------
; Die Segment-Select-Routinen fÅr die verschiedenen Karten.
; Die Tabelle wird direkt mit der Karten-Nummer indiziert.

LABEL SegSwitchTable    WORD
        dw      Nop_Vector              ; stinknormale VGA
        dw      ET3000_SegSwitch        ; ET3000 Chipsatz
        dw      ET4000_SegSwitch        ; ET4000 Chipsatz
        dw      Trident_SegSwitch       ; Trident 8900 Chipsatz
        dw      V7_SegSwitch            ; Video7 1024i oder VEGA VGA
        dw      Par_SegSwitch           ; Paradise VGA
        dw      ATI_SegSwitch           ; ATI VGAWonder
        dw      Evx_SegSwitch           ; Everex
        dw      Oak_SegSwitch           ; Oak
        dw      S3_SegSwitch            ; S3 Chipsatz
        dw      VESA_SegSwitch2         ; VGA unterstÅtzt VESA-Standard

; --------------------------------------------------------------
; SetDrawPage fÅr die verschiedenen Karten.
; Die Tabelle wird direkt mit der Karten-Nummer indiziert.

LABEL   SetDrawPageTable        WORD
        dw      Nop_Vector              ; stinknormale VGA
        dw      Generic_DrawPage        ; ET3000 Chipsatz
        dw      Generic_DrawPage        ; ET4000 Chipsatz
        dw      Generic_DrawPage        ; Trident 8900 Chipsatz
        dw      Generic_DrawPage        ; Video7 1024i oder VEGA VGA
        dw      Generic_DrawPage        ; Paradise VGA
        dw      Nop_Vector              ; ATI VGAWonder
        dw      Nop_Vector              ; Everex
        dw      Nop_Vector              ; Oak
        dw      S3_DrawPage             ; S3 Chipsatz
        dw      Generic_DrawPage        ; VGA unterstÅtzt VESA-Standard

; --------------------------------------------------------------
; SetVisualPage fÅr die verschiedenen Karten.
; Die Tabelle wird direkt mit der Karten-Nummer indiziert.

LABEL   SetVisualPageTable      WORD
        dw      Nop_Vector              ; stinknormale VGA
        dw      ET3000_VisualPage       ; ET3000 Chipsatz
        dw      ET4000_VisualPage       ; ET4000 Chipsatz
        dw      Trident_VisualPage      ; Trident 8900 Chipsatz
        dw      V7_VisualPage           ; Video7 1024i oder VEGA VGA
        dw      Par_VisualPage          ; Paradise VGA
        dw      Nop_Vector              ; ATI VGAWonder
        dw      Nop_Vector              ; Everex
        dw      Nop_Vector              ; Oak
        dw      S3_VisualPage           ; S3 Chipsatz
        dw      VESA_VisualPage         ; VGA unterstÅtzt VESA-Standard

; ------------------------------------------------------------
;
; Tabellen mit den Werten der Betriebsarten. Aus PlatzgrÅnden und weil es
; Vorteile hat, genau *eine* DST zu haben, sind die Werte nicht wie frÅher
; in erweiterten DST's gespeichert.
;

LABEL   ModeTable       TMode

; VGA 320x200x256
TMode   <320, 200, VGA256Name, 13h, 0,          \
         GenericVGA, M320x200, NOP_Vector>

; Tseng ET3000, 640x350x256
TMode  <640, 350, VGA350Name, 2Dh, 0,           \
        ET3000VGA, M640x350, NOP_Vector>

; Tseng ET3000, 640x480x256
TMode  <640, 480, VGA480Name, 2Eh, 0,           \
        ET3000VGA, M640x480, NOP_Vector>

; Tseng ET3000, 800x600x256
TMode  <800, 600, VGA600Name, 30h, 0,           \
        ET3000VGA, M800x600, NOP_Vector>

; Tseng ET4000, 640x350x256
TMode  <640, 350, VGA350Name, 2Dh, 0,           \
        ET4000VGA, M640x350, ET4000_GraphOn>

; TSeng ET4000 640x400x256
TMode  <640, 400, VGA400Name, 2Fh, 0,           \
        ET4000VGA, M640x400, ET4000_GraphOn>

; Tseng ET4000, 640x480x256
TMode  <640, 480, VGA480Name, 2Eh, 0,           \
        ET4000VGA, M640x480, ET4000_GraphOn>

; Tseng ET4000, 800x600x256
TMode  <800, 600, VGA600Name, 30h, 0,           \
        ET4000VGA, M800x600, ET4000_GraphOn>

; Tseng ET4000, 1024x768x256
TMode  <1024, 768, VGA768Name, 38h,0,           \
        ET4000VGA, M1024x768, ET4000_GraphOn>

; Trident 640x400x256
TMode  <640, 400, VGA400Name, 5Ch, 0,           \
        TridentVGA, M640x400, NOP_Vector>

; Trident 640x480x256
TMode  <640, 480, VGA480Name, 5Dh, 0,           \
        TridentVGA, M640x480, NOP_Vector>

; Trident 800x600x256
TMode  <800, 600, VGA600Name, 5Eh, 0,           \
        TridentVGA, M800x600, NOP_Vector>

; Trident 1024x768x256
TMode  <1024, 768, VGA768Name, 62h, 0,          \
        TridentVGA, M1024x768, NOP_Vector>

; Video7 640x400x256
TMode  <640, 400, VGA400Name, 6F05h, 66h,       \
        Video7VGA, M640x400, NOP_Vector>

; Video7 640x480x256
TMode  <640, 480, VGA480Name, 6F05h, 67h,       \
        Video7VGA, M640x480, NOP_Vector>

; Video7 800x600x256
TMode  <800, 600, VGA600Name, 6F05h, 69h,       \
        Video7VGA, M800x600, NOP_Vector>

; ATI VGA-Wonder 640x400x256
TMode  <640, 400, VGA400Name, 61h, 0,           \
        ATIVGA, M640x400, ATI_GraphOn>

; ATI VGA-Wonder 640x480x256
TMode  <640, 480, VGA480Name, 62h, 0,           \
        ATIVGA, M640x480, ATI_GraphOn>

; ATI VGA-Wonder 800x600x256
TMode  <800, 600, VGA600Name, 63h, 0,           \
        ATIVGA, M800x600, ATI_GraphOn>

; ATI VGA-Wonder 1024x768x256
TMode  <1024, 768, VGA1024Name, 64h, 0,          \
        ATIVGA, M1024x768, ATI_GraphOn>

; Paradise 640x400x256
TMode  <640, 400, VGA400Name, 5Eh, 0,           \
        ParadiseVGA, M640x400, NOP_Vector>

; Paradise 640x480x256
TMode  <640, 480, VGA480Name, 5Fh, 0,           \
        ParadiseVGA, M640x480, NOP_Vector>

; Paradise 800x600x256
TMode  <800, 600, VGA600Name, 5Ch, 0,           \
        ParadiseVGA, M800x600, NOP_Vector>

; Everex 640x350x256
TMode  <640, 350, VGA350Name, 70h, 13h,         \
        EverexVGA, M640x350, NOP_Vector>

; Everex 640x400x256
TMode  <640, 400, VGA400Name, 70h, 14h,         \
        EverexVGA, M640x400, NOP_Vector>

; Everex 640x480x256
TMode  <640, 480, VGA480Name, 70h, 30h,         \
        EverexVGA, M640x480, NOP_Vector>

; Everex 800x600x256
TMode  <800, 600, VGA600Name, 70h, 31h,         \
        EverexVGA, M800x600, NOP_Vector>

; Oak 640x400x256
TMode  <640, 400, VGA400Name, 53h, 00h,         \
        OakVGA, M640x400, NOP_Vector>

; Oak 800x600x256
TMode  <800, 600, VGA600Name, 54h, 00h,         \
        OakVGA, M800x600, NOP_Vector>

; S3 640x480x256
TMode  <640, 480, VGA480Name, 69h, 0,           \
        S3VGA, M640x480, S3_GraphOn>

; S3 800x600x256
TMode  <800, 600, VGA600Name, 6Bh, 0,           \
        S3VGA, M800x600, S3_GraphOn>

; S3 1024x768x256
TMode  <1024, 768, VGA768Name, 6Dh, 0h,         \
        S3VGA, M1024x768, S3_GraphOn>

; S3 1280x1024x256
TMode  <1280, 1024, VGA1024Name, 72h, 0h,       \
        S3VGA, M1280x1024, S3_GraphOn>

; VESA 640x400x256
TMode  <640, 400, VGA400Name, 4F02h, 100h,      \
        VESAVGA, M640x400, VESA_GraphOn>

; VESA 640x480x256
TMode  <640, 480, VGA480Name, 4F02h, 101h,      \
        VESAVGA, M640x480, VESA_GraphOn>

; VESA 800x600x256
TMode  <800, 600, VGA600Name, 4F02h, 103h,      \
        VESAVGA, M800x600, VESA_GraphOn>

; VESA 1024x768x256
TMode  <1024, 768, VGA768Name, 4F02h, 105h,     \
        VESAVGA, M1024x768, VESA_GraphOn>

; VESA 1280x1024x256
TMode  <1280, 1024, VGA1024Name, 4F02h, 107h,   \
        VESAVGA, M1280x1024, VESA_GraphOn>

Label   ModeTableEnd    TMode

; Noch ein Zeiger auf den aktuellen Eintrag

ModePtr         dw      ModeTable               ; VGA 320x200

; -----------------------------------------------
; Der Status-Record, der an TP Åbergeben wird.

DST     Status <>

IF      Ver3
ENDS    Data
ELSE
ENDS    Code
ENDIF

END Start



; ------------------------------------------------------------------------------



