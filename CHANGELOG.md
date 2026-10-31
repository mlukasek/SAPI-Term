# Změny

## 1.0.0 (2026-10-31)

První vydání. Terminál pro internetové BBS pro SAPI-1 V s kartou DPI-1L jako `SAPITERM.COM` pro CP/M.

- **ANSI-BBS a VT100:** 80×25 v 16 barvách na CGA-1V (vlastní písmo 4×8, iCE barvy, blikání), nebo 64×20 na
  AND-1V. Druhá karta ukazuje stav spojení: BBS, protokol, dobu spojení, přijatá data a rychlost.
- **40 sloupců** s písmem Sharp MZ-800, **PETSCII**, **ATASCII** a **Viewdata** s písmy a barvami C64, Atari a
  Prestelu.
- **Znakové sady BBS:** CP437, UTF-8, Latin-2, CP1250, CP852, Kamenický, KOI-8čs. Česky se píše z EKL-1.
- **Telnet** (NAWS, TTYPE, ECHO, SGA, BINARY) i raw TCP pro BBS bez telnetu.
- **Adresář 16 BBS** a nastavení v `SAPITERM.CFG` vedle programu. Menu Ctrl+] na BBS i na úvodní obrazovce.
- **Rychlost linky** 300 až 38400 Bd jako modem, pro ANSI animace.
- **Záznam relace**, **historie** odrolovaných řádků, **stahování** XMODEM (po stažení se zeptá na jméno) a
  YMODEM, **prohlížeč** souborů `.ANS`.
- **MPH-1V není nutná.** Bez ní je doba spojení z RTC karty DPI-1L a zvonek pípá bzučákem klávesnice.
- Ověřeno na skutečném SAPI-1 V (autor, 2026-10-31) a v SAPIemu 0.7.0 beta.
