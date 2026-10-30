# SAPI-Term – stav a další kroky

## Stav (2026-10-30)

- **Fáze 0–2 hotové:** kostra, start a návrat do CP/M, výstup na CGA-1V (80×25, vlastní font 4×8) a AND-1V
  (64×20), stavová obrazovka, testovací obrazovka.
- **Fáze 3 hotová:** parser ANSI-BBS a VT100, prohlížeč `SAPITERM SOUBOR.ANS` (iCE podle SAUCE), dvojice barev po
  doménách, skokové rolování, paleta po dávkách ve VBI. Podrobně v `docs/rozhodnuti.md` a `docs/technika.md`.
- **Fáze 4 hotová:** `SAPITERM.COM` 0.4 (15 KB), terminál pro BBS po síti přes DPI-1L.
  - **Spuštění:**
    - `SAPITERM` nabídne zadání adresy (prázdný Enter = testovací obrazovka);
    - `SAPITERM HOST[:PORT]` se rovnou připojí (port 23, když chybí);
    - `SAPITERM SOUBOR.ANS` zobrazí soubor, existuje-li.
  - **Síť:** DNS, TCP (jedno spojení), příjem po 253 B do 2KB bufferu (skokové rolování), odesílání s opakováním
    při chybě 5.
  - **Telnet:**
    - zahodí IAC a odpoví jen na změnu stavu volby;
    - TTYPE `ANSI`, NAWS 80×25 nebo 64×20 (po výměně karet znovu), ECHO, SGA, BINARY;
    - Enter = CR NUL, odpovědi parseru (CPR, DA) jdou do sítě.
  - **Klávesy:** šipky, Home, End, PgUp, Ins, Del jako sekvence ANSI. EKL-1 je posílá kódy WordStar, Consul C1–C4.
    Typ klávesnice se přepíná v menu.
  - **Menu Ctrl+]** na stavové kartě: odpojit, konec, Tab (výměna obrazovek a NAWS), typ klávesnice.
  - **Konec spojení** od BBS, chyby (neznámé jméno, odmítnuté spojení, vypršení) se ukážou na úvodní obrazovce.
  - **iCE barvy** zapíná i `ESC [ ? 33 h` (CTerm), jak to dělají BBS.
  - **Ověřeno** skriptem `tools/emu/phase4.py` proti místní testovací BBS `tools/testbbs.py`:
    - vyjednání telnetu, odpovědi CPR a DA, odeslané klávesy;
    - tři stránky ANSI po síti přesně podle modelu (stín i obraz bod po bodu);
    - NAWS po výměně karet;
    - konec spojení od BBS, odmítnutý port, neznámé jméno.
    - Fáze 2 a 3 procházejí dál, i na sestavě s Consulem.
  - **Rychlost při 4 MHz** (soubory z RAM disku): SUNSET 3,6 s, SCROLL 4,8 s. Častější čtení klávesnice kvůli
    Consulu je zpomalilo asi o 15 %.

## Plán (schválený 2026-10-30, rozhodnutí v `docs/rozhodnuti.md`)

0. ~~Kostra~~
1. ~~Start a návrat~~
2. ~~Výstup: font 4×8, CGA 80×25, AND-1V 64×20, stavová obrazovka, testovací obrazovka, české texty~~
3. ~~Parser ANSI, prohlížeč `.ANS`, dvojice barev po doménách, skokové rolování~~
4. ~~Síť: DNS, TCP, telnet, zadání adresy, menu, `tools/testbbs.py`~~
5. **Skutečné BBS:**
   - ověřený seznam BBS a adresář v souboru (`SAPITERM.CFG` na A: nebo na SD kartě DPI);
   - nastavení (typ klávesnice, výchozí karta) uložené;
   - UTF-8 → CP437 a čeština (psaní z EKL-1 v kódování BBS);
   - doladění podle skutečných BBS.
6. **ANSI art a animace:**
   - rychlost modemu, blikání (SGR 5 bez iCE), režim 40×25 8×8;
   - rychlejší kreslení znaků (teď asi 1 ms na znak s pomocnými operacemi).
7. **Historie a záznam relace**, stahování XMODEM/YMODEM (SD karta nebo A:).
8. **PETSCII, ATASCII, Viewdata** (40 sloupců, vlastní fonty, případně overlay).
9. **Skutečný HW** dávkově s autorem.

## Další krok

Fáze 5: skutečné BBS. Sestavit a v emulátoru vyzkoušet seznam BBS vhodných pro 8bitové počítače (Synchronet,
Mystic, retro BBS), adresář a nastavení v souboru, UTF-8 a češtinu.

## Otevřené drobnosti

- **EKL-1 a Consul se nedají rozlišit.** Velká česká písmena z EKL-1 (KOI XOR 20h: Á = C1h, Č = C3h, Ď = C4h)
  mají stejné kódy jako šipky Consulu (C1–C4).
  - Na BBS rozhoduje typ klávesnice v menu (výchozí EKL-1).
  - Psací stroj (bez spojení) zatím bere C1–C4 jako šipky.
  - Typ se zatím neukládá (fáze 5).
- **Consul 262.3 bez úpravy 7474 věrně jako HW (`strict`):** při rolování se může ztratit klávesa. Některé smyčky
  pořád trvají až asi 2 ms a impuls STROBE je jen 1 ms. Výchozí sestava V v emulátoru impuls zopakuje.
  EKL-1 (autorova) drží znak do potvrzení, jí se to netýká.
- **Velká písmena s diakritikou** mají ve fontu 4×8 výšku malých písmen (`docs/rozhodnuti.md`). Autor je viděl
  a souhlasí (2026-10-30).
- **BEL** zatím nepípá, blikání (SGR 5 bez iCE) se neukazuje.
