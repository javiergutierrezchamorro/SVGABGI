

                  SVGA.BGI (C) 1990-95 Ullrich von Bassewitz
                           (C) 2020 by Javier Gutiérrez Chamorro

                                  README.TXT



Allgemeines
~~~~~~~~~~~
Die Neuerungen in Version 3.40 des Treibers betreffen vor allem S3 Karten. Als
Folge ergaben sich jedoch auch einige allgemeine nderungen, die im hier
aufgefhrt sind:

  * In Version 3.40 des Treibers wurde die Ansteuerung von S3 Karten komplett
    berarbeitet und erweitert. Deshalb mussten die Segmentumschalt-Routinen
    sowie die Routinen zur Verwendung mehrerer Bildschirmseiten fr _alle_
    Karten ge„ndert werden. Sollten bei Karten Probleme auftreten, die in alten
    Versionen des Treibers fehlerfrei liefen, bitte ich um Meldung unter Angabe
    von Kartenname/Chipsatz.
  * Fast alle Modusnummern haben sich ge„ndert, da ein neuer Modus "1280*1024
    Autodetect" dazugekommen ist.



S3-Karten
~~~~~~~~~

  * Bei S3-Karten werden jetzt die Beschleuniger-Funktionen der Hardware
    benutzt. Bei Problemen kann dies mit der Option "3" abgeschaltet werden
    (siehe SVGA.DOC).

  * Die Modus-Nummern fr die Umschaltung in die Grafik-Modi sind bei S3-Karten
    unterschiedlich. Ich habe mich bei den SVGA-Modi nach meiner SPEA Mirage
    gerichtet, die folgende Modi verwendet:

        S3 640x480x256          69h
        S3 800x600x256          6Bh
        S3 1024x768x256         6Dh
        S3 1280x1024x256        72h

    Diese Modusnummern sind offensichtlich nicht fr alle S3-Karten gltig,
    insbesondere existieren anscheinend S3 Karten mit VESA-Support bereits
    im Video-BIOS.
    Arbeitet die Umschaltung in den Grafikmodus nicht korrekt, dann k”nnen
    die Optionen 'V' und 'M' in Verbindung mit einem VESA-Treiber
    verwendet werden um eine korrekte Umschaltung zu gew„hrleisten. 'V'
    schaltet die VESA-Erkennung ab, d.h. die Karte wird nicht als VESA-Karte
    behandelt, 'M' erzwingt aber die Verwendung der VESA-Modus Nummern beim
    Umschalten. Durch dieses (zugegebenermassen relativ umst„ndliche) Verfahren
    wird der VESA-Treiber nur zur Modus-Umschaltung verwendet.
    Falls diese Probleme mit Ihrer Karte auftreten, k”nnen Sie mir gerne eine
    Liste der von Ihrer Karte untersttzten Modus-Nummern zusenden. Evtl. findet
    sich fr eine sp„tere Version des Treibers ein gnstigerer Weg.

  * In den DOS-Boxen von OS/2 sollte die Einstellung VIDEO_8514A_XGA_IOTRAP
    auf Off gesetzt werden. In der Standard-Einstellung (On) werden alle
    Zugriffe auf Register der S3-Karte abgefangen und berprft. Da die S3
    Beschleuniger-Funktionen ber solche Register gesteuert werden ergibt
    sich eine z.T. erhebliche Geschwindigkeit-Einbuáe.



Performance
~~~~~~~~~~~
Im Gegensatz zu den meisten anderen Treibern erlaubt SVGA.BGI eine sehr weite
Anpassung des Treibers an die Umgebung (80386-Version, S3-Hardware, schnelle
Bankswitching-Routinen fr VESA-Karten). Die vielf„ltigen Einstellungs-
m”glichkeiten des Treibers haben offenbar fr Verwirrung gesorgt und ich wurde
des ”fteren gefragt, was denn nun die "schnellsten" bzw. "besten" Einstellungen
seien.

Die Antwort darauf ist (natrlich): "Es kommt drauf an".

Um nur zwei Beispiele zu nennen:

  * Der 80386-Treiber ist auf 16-Bit ISA-Karten nur in einer Funktion meábar
    schneller als die "normale" Version (PutImage wenn Mode != CopyPut).
    Das „ndert sich aber, wenn es sich um eine VLB- oder PCI-Karte handelt.

  * Der Treiber verwendet bei S3-Karten die Linienfunktion der Karte um die
    Linien beim Fllen von Kreisen und Polygonen zu ziehen. Diese Funktionen
    arbeiten aber mit I/O-Befehlen, die je nach Prozessor und Modus mehr oder
    weniger schnell sein k”nnen. Zudem ist der Overhead pro Linie bei Verwendung
    der Grafik-Hardware h”her, als beim Ziehen der Linien per Software. Was von
    beidem schneller ist, h„ngt also nicht nur von der L„nge der Linien ab,
    sondern auch noch vom Modus, in dem der Prozessor l„uft und nicht zuletzt
    natrlich von der Geschwindigkeit der CPU selber.

Es lassen sich also keine allgemeinen Aussagen ber die "beste" oder
"schnellste" Einstellung machen. Wer tats„chlich auf h”chste Performance
angewiesen ist, sollte die beste Einstellung am Zielrechner selber ausprobieren.

