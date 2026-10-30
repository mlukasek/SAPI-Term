# SAPI-Term

Terminál pro internetové BBS (telnet) pro počítač Tesla SAPI-1 v sestavě z Liborových desek V (JPR-1V, RAM-1V,
AND-1V, CGA-1V, ZRD-1V, MPH-1V) s kartou DPI-1L pro síť. Program pro CP/M `SAPITERM.COM`, umí výstup na barevnou
grafiku CGA-1V (80×25 znaků) i na alfanumerický displej AND-1V (64×20) a vrací se do CP/M.

Terminal emulator (telnet BBS client) for the vintage Czech TESLA SAPI-1 computer.

**Stav:** ve vývoji. Hotový je terminál ANSI (ANSI-BBS, VT100) s vlastním písmem 4×8, telnet přes DPI-1L a prohlížeč souborů
`.ANS`. Další na řadě jsou skutečné BBS (seznam, adresář, čeština). Plán a stav jsou v
[docs/stav.md](docs/stav.md).

## Překlad

`build.cmd` (pasmo 0.5.3 a Python 3), výsledek `build\sapiterm.com` a RAM disk `build\ramdisk.bin`. Podrobnosti
v [docs/vyvoj.md](docs/vyvoj.md).

## Licence

GPLv3, viz [LICENSE](LICENSE). Autor: Martin Lukášek.
