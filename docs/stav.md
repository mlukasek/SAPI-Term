# SAPI-Term – stav a další kroky

## Stav (2026-10-30)

- **Fáze 0 hotová:** kostra repa, `build.cmd`, testovací sestavy, skripty MCP, kontrolní bod CP/M.
- **Fáze 1 hotová:** `SAPITERM.COM` 0.1 (1,4 KB).
  - Najde karty AND-1V, CGA-1V, MPH-1V a DPI-1L (u DPI-1L i verzi firmwaru).
  - Na AND-1V ukáže stav, na CGA-1V 16 barevných pruhů v režimu EGA.
  - Počítá VBI CGA-1V a tik MPH-1V (60 Hz), ukazuje kód poslední klávesy.
  - Ctrl+] vrátí do CP/M: TCP zavřené, MPH-1V ztišená, CGA-1V černá, MAP = 0, warm boot.
  - Ověřeno v SAPIemu 0.7.0-beta skriptem `tools/emu/phase1.py` na obou sestavách (EKL-1 i Consul 262.3 `strict`).
    Na skutečném HW zatím ne (`docs/hw-otazky.md`).

## Plán (schválený 2026-10-30, rozhodnutí v `docs/rozhodnuti.md`)

0. ~~Kostra~~ (hotovo)
1. ~~Start a návrat: detekce karet, klávesnice, návrat do CP/M~~ (hotovo)
2. **Výstup:**
   - font 4×8 (CP437, vlastní, generovaný skriptem);
   - CGA 80×25: znak, mazání, rolování, kurzor, přidělování dvojic barev;
   - AND-1V 64×20 s převodem znaků;
   - stavová obrazovka na druhé kartě;
   - testovací obrazovka CP437 a barev;
   - texty UI česky s diakritikou (KOI-8čs).
3. **Parser ANSI** (ANSI-BBS + VT100) a prohlížeč `.ANS` (A: nebo SD karta DPI, SAUCE).
4. **Síť:**
   - DNS, TCP, telnet (IAC, NAWS, TTYPE, ECHO, SGA, BINARY);
   - host:port, seznam BBS;
   - `tools/testbbs.py` (místní telnet server pro testy).
5. **Skutečné BBS:** ověřený seznam, doladění, UTF-8 → CP437 a čeština.
6. **ANSI art a animace:** rychlost modemu, blikání, iCE barvy, režim 40×25 8×8, rychlejší rolování, barvy po
   doménách.
7. **Historie a záznam relace**, stahování XMODEM/YMODEM (SD karta nebo A:).
8. **PETSCII, ATASCII, Viewdata** (40 sloupců, vlastní fonty, případně overlay).
9. **Skutečný HW** dávkově s autorem.

## Další krok

Fáze 2: font 4×8 a výstup na CGA-1V. Předlohu fontu kreslit v textovém souboru (`fonts/`), `tools/fontgen.py` z ní
udělá tabulku pro asm (horní půlbajt = 4 body řádku znaku).
