# SAPI-Term – stav a další kroky

## Stav (2026-10-30)

- **Fáze 0 a 1 hotové:** kostra repa, překlad, testovací sestavy, skripty MCP. Program najde karty a vrací se do
  CP/M.
- **Fáze 2 hotová:** `SAPITERM.COM` 0.2 (8,2 KB), výstup terminálu na obě karty.
  - **Vlastní font 4×8** (`fonts/sapiterm4x8.txt`): CP437 a české znaky KOI-8čs2.
  - **CGA-1V:** text 80×25 v režimu EGA, barva po znacích (dvojice popředí/pozadí), rolování, kurzor
    (podtržení, bliká).
  - **AND-1V:** terminál 64×20, převod CP437 na znaky karty, kurzor 7Fh.
  - **Stavová obrazovka** na druhé kartě: nalezené karty, dvojice barev, poslední klávesa, nápověda kláves.
  - **Tab vymění karty.** Stínová obrazovka 80×25 zůstává. Při zmenšení na 20 řádků zůstanou vidět řádky
    s kurzorem.
  - **Testovací obrazovka (Ctrl+T):** tabulka CP437, barvy, bloky, rámečky, česká věta. Psaní na klávesnici
    jako na psacím stroji: Ctrl+P a Ctrl+O mění barvu, Ctrl+L maže.
  - Ověřeno v SAPIemu 0.7.0-beta skriptem `tools/emu/phase2.py` na obou sestavách (EKL-1 i Consul 262.3
    `strict`). Snímky jsou v `build/preview/f2_*.png`.
- **Známé omezení:** na CGA-1V je zatím jen 16 dvojic barev na celou obrazovku, nad ně se bere nejbližší dvojice.
  Na testovací obrazovce je to vidět v řádku „Pozadí“.

## Plán (schválený 2026-10-30, rozhodnutí v `docs/rozhodnuti.md`)

0. ~~Kostra~~
1. ~~Start a návrat~~
2. ~~Výstup: font 4×8, CGA 80×25, AND-1V 64×20, stavová obrazovka, testovací obrazovka, české texty~~
3. **Parser ANSI** (ANSI-BBS + VT100) a prohlížeč `.ANS` (A: nebo SD karta DPI, SAUCE). Spolu s ním:
   - **dvojice barev zvlášť pro každou doménu** (7×16, přemapování při rolování), dřív plánované ve fázi 6.
     ANSI art a menu BBS potřebují víc než 16 dvojic.
   - skokové rolování o víc řádků najednou.
4. **Síť:**
   - DNS, TCP, telnet (IAC, NAWS, TTYPE, ECHO, SGA, BINARY);
   - host:port, seznam BBS;
   - `tools/testbbs.py`.
5. **Skutečné BBS:** ověřený seznam, doladění, UTF-8 → CP437 a čeština.
6. **ANSI art a animace:** rychlost modemu, blikání, iCE barvy, režim 40×25 8×8, rychlejší rolování.
7. **Historie a záznam relace**, stahování XMODEM/YMODEM (SD karta nebo A:).
8. **PETSCII, ATASCII, Viewdata** (40 sloupců, vlastní fonty, případně overlay).
9. **Skutečný HW** dávkově s autorem.

## Další krok

Fáze 3: parser ANSI nad `scr_putc` (`src/ansi.asm`) a dvojice barev po doménách v `src/cgatext.asm`.
Testovací soubory `.ANS` kreslit vlastní (`art/`).

## Otevřené drobnosti

- **EKL-1 a Consul se nedají rozlišit.** Velká česká písmena z EKL-1 (KOI XOR 20h: Á = C1h, Č = C3h, Ď = C4h)
  mají stejné kódy jako šipky Consulu (C1–C4). Program je teď bere jako šipky. Typ klávesnice bude volba
  v nastavení (fáze 4).
- **Velká písmena s diakritikou** mají ve fontu 4×8 výšku malých písmen. Ve 3 bodech šířky a 8 řádcích se plná
  verzálka a čitelný háček nevejdou zároveň (`docs/rozhodnuti.md`). Autor posoudí podle náhledu.
