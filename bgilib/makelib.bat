@rem    Diese Batch-Datei erzeugt die zwei Library-Dateien BGI.LIB fr
@rem    near-Speichermodelle und BGIFAR.LIB fr far-Speichermodelle
@rem    mit allen BGI-Treibern und Fonts einschlieálich der Custom-Driver
@rem    PRINTER.BGI und SVGA.BGI.
@rem
@rem    MAKELIB.BAT muá in's BGI-Verzeichnis kopiert werden und
@rem    auch von dort aus gestartet werden. Bitte darauf achten!
@rem
@rem    Anschlieáend k”nnen die erzeugten Libraries in das LIB-
@rem    Verzeichnis kopiert werden.
@rem
@rem    Von mir erweitert um HPDJ500C-Treiber am 24.10.92, Uz
@echo.
@cd
@echo.
@echo Wenn Sie sich NICHT im BGI-Verzeichnis befinden, drcken Sie bitte Strg-BREAK
@pause
md NEAR
md FAR
bgiobj    att          NEAR\att      _ATT_driver           > makelib.log
bgiobj    cga          NEAR\cga      _CGA_driver          >> makelib.log
bgiobj    egavga       NEAR\agavga   _EGAVGA_driver       >> makelib.log
bgiobj    herc         NEAR\herc     _Herc_driver         >> makelib.log
bgiobj    ibm8514      NEAR\ibm8514  _IBM8514_driver      >> makelib.log
bgiobj    pc3270       NEAR\pc3270   _PC3270_driver       >> makelib.log
bgiobj    euro.chr     NEAR\euro     _euro_font           >> makelib.log
bgiobj    goth.chr     NEAR\goth     _gothic_font         >> makelib.log
bgiobj    lcom.chr     NEAR\lcom     _lcom_font           >> makelib.log
bgiobj    litt.chr     NEAR\litt     _small_font          >> makelib.log
bgiobj    sans.chr     NEAR\sans     _sansserif_font      >> makelib.log
bgiobj    scri.chr     NEAR\scri     _scri_font           >> makelib.log
bgiobj    simp.chr     NEAR\simp     _simp_font           >> makelib.log
bgiobj    trip.chr     NEAR\trip     _triplex_font        >> makelib.log
bgiobj    tscr.chr     NEAR\tscr     _tscr_font           >> makelib.log
bgiobj    svga.bgi     NEAR\svga     _SVGA_driver         >> makelib.log
bgiobj    printer.bgi  NEAR\printer  _PRINTER_driver      >> makelib.log
bgiobj    hpdj500c.bgi NEAR\hpdj500c _HPDJ500C_driver     >> makelib.log

del bgi.lib
for %%i in (NEAR\*.obj) do tlib bgi +%%i , bgi.lst

bgiobj /F att          FAR\attf      _ATT_driver_far      >> makelib.log
bgiobj /F cga          FAR\cgaf      _CGA_driver_far      >> makelib.log
bgiobj /F egavga       FAR\egavgaf   _EGAVGA_driver_far   >> makelib.log
bgiobj /F herc         FAR\hercf     _Herc_driver_far     >> makelib.log
bgiobj /F ibm8514      FAR\ibm8514f  _IBM8514_driver_far  >> makelib.log
bgiobj /F pc3270       FAR\pc3270f   _PC3270_driver_far   >> makelib.log
bgiobj /F euro.chr     FAR\eurof     _euro_font_far       >> makelib.log
bgiobj /F goth.chr     FAR\gothf     _gothic_font_far     >> makelib.log
bgiobj /F lcom.chr     FAR\lcomf     _lcom_font_far       >> makelib.log
bgiobj /F litt.chr     FAR\littf     _small_font_far      >> makelib.log
bgiobj /F sans.chr     FAR\sansf     _sansserif_font_far  >> makelib.log
bgiobj /F scri.chr     FAR\scrif     _scri_font_far       >> makelib.log
bgiobj /F simp.chr     FAR\simpf     _simp_font_far       >> makelib.log
bgiobj /F trip.chr     FAR\tripf     _triplex_font_far    >> makelib.log
bgiobj /F tscr.chr     FAR\tscrf     _tscr_font_far       >> makelib.log
bgiobj /F printer.bgi  FAR\printerf  _PRINTER_driver_far  >> makelib.log
bgiobj /F svga.bgi     FAR\svgaf     _SVGA_driver_far     >> makelib.log
bgiobj /F hpdj500c.bgi FAR\hpdj500c  _HPDJ500C_driver     >> makelib.log

del bgifar.lib
for %%i in (FAR\*.obj) do tlib bgifar +%%i , bgifar.lst
