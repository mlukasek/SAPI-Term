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
- **Fáze 5 hotová:** `SAPITERM.COM` 0.5 (19,8 KB), skutečné BBS, adresář a znakové sady.
  - **`SAPITERM.CFG` vedle `SAPITERM.COM`:**
    - disk se pozná z příkazové řádky v CCP (`B:SAPITERM`), jinak je to aktuální disk;
    - v souboru je typ klávesnice, karta terminálu a až 16 BBS se znakovou sadou;
    - program ho přepíše hned po změně (menu T, Tab, U, smazání z adresáře).
  - **Úvodní obrazovka:**
    - adresář je ve dvou sloupcích po osmi;
    - číslo připojí BBS z adresáře, `-číslo` ji smaže;
    - Tab přesune terminál na druhou kartu;
    - `SAPITERM číslo` se připojí rovnou.
  - **Menu na BBS:**
    - Z přepíná znakovou sadu: CP437, UTF-8, Latin-2, CP1250, CP852, Kamenický, KOI-8čs;
    - U uloží BBS (jméno = adresa) i se sadou do adresáře.
  - **Znakové sady:**
    - příchozí bajty 80h–FFh se převedou na glyf CP437 nebo na české písmeno z KOI-8čs2;
    - v UTF-8 rámečky, bloky, uvozovky a řecká písmena dostanou nejbližší znak CP437;
    - česká písmena z EKL-1 jdou na BBS v její sadě.
  - **Výchozí adresář (13 BBS)**, ověřený z PC i v emulátoru (úvodní obrazovka, bez přihlášení): Vertrauen, Liane
    (česká, Liberec), Level 29, Particles!, Retro Campus, 20 For Beers, Xibalba, Agency, Distortion, Dark Realms,
    Heatwave, Bottomless Abyss, Clutch. Nástroj `tools/emu/realbbs.py`, snímky `build/preview/bbs_*.png`.
  - **Ověřeno** skriptem `tools/emu/phase5.py`:
    - adresář, mazání, uložení z menu, výběr číslem, Tab, obsah souboru po návratu (`TYPE`);
    - všech šest sad glyf po glyfu proti modelu v `tools/tables.py`, odeslaná písmena „čŘ“ v každé sadě.
    - Fáze 2 až 4 procházejí dál, i na sestavě s Consulem.

## Plán (schválený 2026-10-30, rozhodnutí v `docs/rozhodnuti.md`)

0. ~~Kostra~~
1. ~~Start a návrat~~
2. ~~Výstup: font 4×8, CGA 80×25, AND-1V 64×20, stavová obrazovka, testovací obrazovka, české texty~~
3. ~~Parser ANSI, prohlížeč `.ANS`, dvojice barev po doménách, skokové rolování~~
4. ~~Síť: DNS, TCP, telnet, zadání adresy, menu, `tools/testbbs.py`~~
5. ~~Skutečné BBS: ověřený seznam, adresář a nastavení v `SAPITERM.CFG` vedle `SAPITERM.COM`, znakové sady
   (UTF-8, Latin-2, CP1250, CP852, Kamenický, KOI-8čs) a čeština z EKL-1~~
6. **ANSI art a animace:**
   - rychlost modemu, blikání (SGR 5 bez iCE), režim 40×25 8×8;
   - rychlejší kreslení znaků (teď asi 1 ms na znak s pomocnými operacemi).
7. **Historie a záznam relace**, stahování XMODEM/YMODEM (SD karta nebo A:).
8. **PETSCII, ATASCII, Viewdata** (40 sloupců, vlastní fonty, případně overlay).
9. **Skutečný HW** dávkově s autorem.

## Další krok

Fáze 6: ANSI art a animace. Rychlost modemu (animace ANSI počítají s pomalou linkou), blikání (SGR 5 bez iCE),
režim 40×25 s fontem 8×8 a rychlejší kreslení znaků.

## Otevřené drobnosti

- **EKL-1 a Consul se nedají rozlišit.** Velká česká písmena z EKL-1 (KOI XOR 20h: Á = C1h, Č = C3h, Ď = C4h)
  mají stejné kódy jako šipky Consulu (C1–C4).
  - Rozhoduje typ klávesnice v menu (výchozí EKL-1), od fáze 5 uložený v `SAPITERM.CFG`.
  - S typem EKL-1 jsou C1–C4 velká písmena Á Č Ď, s typem Consul šipky (i v psacím stroji).
- **Consul 262.3 bez úpravy 7474 věrně jako HW (`strict`):** při rolování se může ztratit klávesa. Některé smyčky
  pořád trvají až asi 2 ms a impuls STROBE je jen 1 ms. Výchozí sestava V v emulátoru impuls zopakuje.
  EKL-1 (autorova) drží znak do potvrzení, jí se to netýká.
- **Velká písmena s diakritikou** mají ve fontu 4×8 výšku malých písmen (`docs/rozhodnuti.md`). Autor je viděl
  a souhlasí (2026-10-30).
- **BEL** zatím nepípá, blikání (SGR 5 bez iCE) se neukazuje.
- **Znaková sada BBS Liane** (`bbs.vslib.cz`) není známá: úvodní obrazovka je v ASCII a hlubší pohled chce
  přihlášení (BBS nabízí veřejný účet `guest`). V adresáři je zatím CP437. Na BBS se dá vyzkoušet Z a uložit U.
- **Aleco Experience BBS** (Praha, Atari, `bbs.alecoexp.cz`) 2026-10-30 spojení na port 23 odmítala, web běží.
  Zkusit později a případně přidat.
