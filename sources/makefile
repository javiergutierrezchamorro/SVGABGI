#
# Makefile fÅr den SVGA BGI-Treiber
#
# Uz am 17.08.1994
#


#.SILENT
.AUTODEPEND


# ---------------------------------------------------------------
# Dummy-AbhÑngigkeit

all:            svgabgi svgabp7 svga286bgi svga286bp7 svga386bgi svga386bp7 obj dist

svgabgi:        svga.bgi

svgabp7:        svga.bp7

svga286bgi:     svga286.bgi

svga286bp7:     svga286.bp7

svga386bgi:     svga386.bgi

svga386bp7:     svga386.bp7


# ---------------------------------------------------------------
# Files

svga.bgi:       svga2.bin
                bh2 svga2 svga SVGA

svga.bp7:       svga3.bin
                bh3 svga3 svga3 svga3.map SVGA
		-del svga3.bp7
		-ren svga3.bgi svga.bp7

svga2.bin:      svga2.exe
                exetobin svga2

svga3.bin:      svga3.exe
                exetobin svga3

svga2.exe:      svga2.obj
                tlink /s /v svga2
                tdstrip -s svga2

svga3.exe:      svga3.obj
                tlink /s /v svga3
                tdstrip -s svga3

svga2.obj:      SVGA.ASM
                tasm /z /zn /m5 /DVer3=0 /DP80286=0 /DP80386=0 svga, svga2

svga3.obj:      SVGA.ASM
                tasm /z /zn /m5 /DVer3=1 /DP80286=0 /DP80386=0 svga, svga3

svga286.bgi:    svga2286.bin
                bh2 svga2286 svga286 SVGA

svga286.bp7:    svga3286.bin
                bh3 svga3286 svga3286 svga3286.map SVGA
		-del svga3286.bp7
		-ren svga3286.bgi svga286.bp7

svga2286.bin:   svga2286.exe
                exetobin svga2286

svga3286.bin:   svga3286.exe
                exetobin svga3286

svga2286.exe:   svga2286.obj
                tlink /s /v svga2286
                tdstrip -s svga2286

svga3286.exe:   svga3286.obj
                tlink /s /v svga3286
                tdstrip -s svga3286

svga2286.obj:   SVGA.ASM
                tasm /z /zn /m5 /DVer3=0 /DP80286=1 /DP80386=0 svga, svga2286

svga3286.obj:   SVGA.ASM
                tasm /z /zn /m5 /DVer3=1 /DP80286=1 /DP80386=0 svga, svga3286

svga386.bgi:    svga2386.bin
                bh2 svga2386 svga386 SVGA

svga386.bp7:    svga3386.bin
                bh3 svga3386 svga3386 svga3386.map SVGA386
		-del svga3386.bp7
		-ren svga3386.bgi svga386.bp7

svga2386.bin:   svga2386.exe
                exetobin svga2386

svga3386.bin:   svga3386.exe
                exetobin svga3386

svga2386.exe:   svga2386.obj
                tlink /s /v svga2386
                tdstrip -s svga2386

svga3386.exe:   svga3386.obj
                tlink /s /v svga3386
                tdstrip -s svga3386

svga2386.obj:   SVGA.ASM
                tasm /z /zn /m5 /DVer3=0 /DP80286=1 /DP80386=1 svga, svga2386

svga3386.obj:   SVGA.ASM
                tasm /z /zn /m5 /DVer3=1 /DP80286=1 /DP80386=1 svga, svga3386




# ---------------------------------------------------------------
# Dummy-Targets

obj:
                -del *.bak
		-del *.map
		-del *.prn
		-del *.$$$
		-del *.tds
		-del *.bin
		-del *.obj
		-del *.exe
		bgiobj svga.bgi svgan _SVGA_driver
		bgiobj svga286.bgi svga286n _SVGA_driver
		bgiobj svga386.bgi svga386n _SVGA_driver

		bgiobj /F svga.bgi svgaf _SVGA_driver_far
		bgiobj /F svga286.bgi svga286f _SVGA_driver_far
		bgiobj /F svga386.bgi svga386f _SVGA_driver_far


		del bgifar.lib
		for %%i in (FAR\*.obj) do tlib bgifar +%%i , bgifar.lst


dist:           
		-del ..\svga\*
		-copy *.bgi ..\svga
		-copy *.bp7 ..\svga
		-copy *.obj ..\svga
		-del *.bgi
		-del *.bp7


