# SAPI-Term – stav a další kroky

## Stav (2026-10-30)

- **Fáze 0–2 hotové:** kostra, start a návrat do CP/M, výstup na CGA-1V (80×25, vlastní font 4×8) a AND-1V
  (64×20), stavová obrazovka, testovací obrazovka.
- **Fáze 3 hotová:** `SAPITERM.COM` 0.3 (12 KB), terminál ANSI.
  - **Parser ANSI-BBS a VT100** (`src/ansi.asm`, seznam sekvencí v hlavičce):
    - SGR včetně jasných barev 90–97 a 100–107 a iCE;
    - pohyb kurzoru, mazání, vkládání a mazání znaků a řádků;
    - oblast rolování, uložení a obnova kurzoru, režimy ?7 a ?25;
    - odpovědi na DSR a DA (zatím nikam).
  - **Prohlížeč souborů ANSI:** `SAPITERM SOUBOR.ANS` zobrazí soubor z disku CP/M. iCE barvy zapne podle záznamu
    SAUCE. Pak se dá psát, Ctrl+] = konec.
  - **Dvojice barev po doménách:** 16 dvojic na každé 4 řádky (až 7×16 na obrazovku). Řádek, který rolováním
    přejde do jiné domény, dostane dvojice tam a zachová si číslo slotu, když to jde.
  - **Skokové rolování:** se 2KB vstupním bufferem se odroluje o všechny konce řádků, které čekají ve vstupu,
    najednou. Výsledek je stejný jako po jednom řádku.
  - **Paleta po dávkách:** nejvýš 16 dvojic na jedno VBI, aby zápis nikdy nepřesáhl zatemnění (ani při 2 MHz).
  - **Ověřeno** v SAPIemu 0.7.0-beta skriptem `tools/emu/phase3.py`: čtyři testovací soubory z `tools/mkart.py`.
    - Stínová obrazovka (2000 buněk, kurzor) sedí přesně s referenčním modelem `tools/ansiref.py`.
    - Snímek CGA-1V sedí s modelem vykresleným fontem bod po bodu.
    - Žádný zápis palety mimo VBI.
    - Fáze 2 (`phase2.py`) prochází dál.
  - **Rychlost při 4 MHz** (soubor z RAM disku včetně čtení přes BDOS):

    | Soubor | Velikost | Čas |
    |---|---|---|
    | ANSITEST.ANS | 1,2 KB | 1,2 s |
    | MENU.ANS | 1,1 KB | 1,2 s |
    | SUNSET.ANS (2000 půlbloků, hodně SGR) | 8,9 KB | 3,0 s |
    | SCROLL.ANS (75 barevných řádků) | 5,8 KB | 4,2 s, dřív bez skokového rolování 11,2 s |

## Plán (schválený 2026-10-30, rozhodnutí v `docs/rozhodnuti.md`)

0. ~~Kostra~~
1. ~~Start a návrat~~
2. ~~Výstup: font 4×8, CGA 80×25, AND-1V 64×20, stavová obrazovka, testovací obrazovka, české texty~~
3. ~~Parser ANSI, prohlížeč `.ANS`, dvojice barev po doménách, skokové rolování~~
4. **Síť:**
   - DNS, TCP, telnet (IAC, NAWS, TTYPE, ECHO, SGA, BINARY);
   - příjem do vstupního bufferu (skokové rolování), odpovědi parseru (CPR, DA) do sítě;
   - host:port, seznam BBS, volba typu klávesnice;
   - `tools/testbbs.py`.
5. **Skutečné BBS:** ověřený seznam, doladění, UTF-8 → CP437 a čeština.
6. **ANSI art a animace:**
   - rychlost modemu, blikání (SGR 5 bez iCE), režim 40×25 8×8;
   - rychlejší kreslení znaků (teď asi 1 ms na znak s pomocnými operacemi).
7. **Historie a záznam relace**, stahování XMODEM/YMODEM (SD karta nebo A:).
8. **PETSCII, ATASCII, Viewdata** (40 sloupců, vlastní fonty, případně overlay).
9. **Skutečný HW** dávkově s autorem.

## Další krok

Fáze 4: síť přes DPI-1L (`src/dpi.asm`: DNS, TCP), telnet (`src/telnet.asm`), místní testovací server
`tools/testbbs.py` a jednoduché zadání adresy BBS.

## Otevřené drobnosti

- **EKL-1 a Consul se nedají rozlišit.** Velká česká písmena z EKL-1 (KOI XOR 20h: Á = C1h, Č = C3h, Ď = C4h)
  mají stejné kódy jako šipky Consulu (C1–C4). Program je teď bere jako šipky. Typ klávesnice bude volba (fáze 4).
- **Velká písmena s diakritikou** mají ve fontu 4×8 výšku malých písmen (`docs/rozhodnuti.md`). Autor je viděl
  a souhlasí (2026-10-30).
- **BEL** zatím nepípá, blikání (SGR 5 bez iCE) se neukazuje.
