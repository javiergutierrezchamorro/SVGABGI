#
# Makefile fÅr den SVGA BGI-Treiber
#
# Uz am 17.08.1994
#


.SILENT
.AUTODEPEND


# ---------------------------------------------------------------
# Dummy-AbhÑngigkeit

all:            svga

svga:           svga.bgi

svga386:        svga386.bgi

# ---------------------------------------------------------------
# Files

svga.bgi:       svga.bin
                bh3 svga svga svga SVGA

svga.bin:       svga.exe
                exetobin svga.exe svga.bin

svga.exe:       svga.obj
                tlink /s /v svga
                tdstrip -s svga

svga.obj:       svga.asm
                tasm /zi /m5 /DVer3=1 /DP80286=0 /DP80386=0 svga

svga386.bgi:    svga386.bin
                bh3 svga386 svga386 svga386 SVGA386

svga386.bin:    svga386.exe
                exetobin svga386.exe svga386.bin

svga386.exe:    svga386.obj
                tlink /s /v svga386
                tdstrip -s svga386

svga386.obj:    svga.asm
                tasm /zi /m5 /DVer3=1 /DP80286=1 /DP80386=1 svga,svga386

# ---------------------------------------------------------------
# Dummy-Targets

clean:
                -del *.bak *.map *.prn *.$$$ svga*.bin

zap:            clean
                -del *.obj svga*.exe svga*.tds

zip:
                -del svga.zip
                pkzip svga.zip *.asm *.asi makefile makefile.old

