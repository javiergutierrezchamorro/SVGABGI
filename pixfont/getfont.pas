PROGRAM GetFont;


{ Programm zur Extraktion der VGA-Fonts aus dem VGA-BIOS }



{ Ullrich von Bassewitz am 22.01.1992 }

{ Letzte Žnderung: 22.01.1992 }

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





USES
  DOS;



PROCEDURE SaveFont (Name: STRING; FontNum: BYTE; Size: WORD);

VAR
  F       : FILE;
  FontPtr : POINTER;

BEGIN
  { Zeiger auf den Font holen }
  ASM
    mov     ax, 1130h
    mov     bh, [FontNum]
    push    bp
    int     10h
    mov     ax, bp
    pop     bp
    mov     WORD PTR [FontPtr+2], es
    mov     WORD PTR [FontPtr], ax
  END;

  { Font speichern }
  Assign (F, Name);
  ReWrite (F, 1);
  BlockWrite (F, FontPtr^, Size);
  Close (F);
END;






BEGIN
  SaveFont ('8X16.FNT', 6, $1000);
  SaveFont ('8X14.FNT', 2, $E00);
END.

