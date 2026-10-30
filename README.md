# SAPI-Term

Terminál pro internetové BBS (telnet) pro počítač Tesla SAPI-1 v sestavě z Liborových desek V (JPR-1V, RAM-1V,
AND-1V, CGA-1V, ZRD-1V, MPH-1V) s kartou DPI-1L pro síť. Program pro CP/M `SAPITERM.COM`, umí výstup na barevnou
grafiku CGA-1V (80×25 znaků) i na alfanumerický displej AND-1V (64×20) a vrací se do CP/M.

Terminal emulator (telnet BBS client) for the vintage Czech TESLA SAPI-1 computer.

**Stav:** ve vývoji. Hotové:
- terminál ANSI (ANSI-BBS, VT100) s vlastním písmem 4×8;
- telnet přes DPI-1L;
- adresář BBS a nastavení v `SAPITERM.CFG` vedle programu;
- znakové sady BBS (UTF-8, Latin-2, CP1250, CP852, Kamenický, KOI-8čs) a psaní česky z EKL-1;
- prohlížeč souborů `.ANS`;
- rychlost linky pro ANSI animace, blikání a režim 40×25;
- záznam relace, historie odrolovaných řádků, stahování XMODEM a YMODEM;
- PETSCII, ATASCII a Viewdata (terminály C64, Atari a Prestel s jejich písmy a barvami); ANSI ve 40 sloupcích
  s písmem Sharp MZ-700.

Další na řadě je zkouška na skutečném SAPI-1. Plán a stav jsou v [docs/stav.md](docs/stav.md).

## Překlad

`build.cmd` (pasmo 0.5.3 a Python 3), výsledek `build\sapiterm.com` a RAM disk `build\ramdisk.bin`. Podrobnosti
v [docs/vyvoj.md](docs/vyvoj.md).

## Licence

GPLv3, viz [LICENSE](LICENSE). Autor: Martin Lukášek.

Výjimka: písma 8×8 v `fonts/c64.txt`, `fonts/atari.txt` a `fonts/mz700.txt` jsou převzatá ze znakových ROM
Commodore 64, Atari 400/800 a Sharp MZ-700 a patří jejich vlastníkům (`docs/rozhodnuti.md`).
