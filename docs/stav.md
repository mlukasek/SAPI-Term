# SAPI-Term – stav a další kroky

## Shrnutí (2026-10-30, `SAPITERM.COM` 0.8, 32,8 KB)

- **Hotové fáze 0–8,** zbývá fáze 9: zkouška na skutečném SAPI-1 s autorem (`docs/hw-otazky.md`).
- **Terminál ANSI-BBS a VT100:**
  - 80×25 na CGA-1V (vlastní písmo 4×8, dvojice barev po doménách), 64×20 na AND-1V;
  - menu Ctrl+] na kartě terminálu, stav spojení (protokol, doba, přijatá data a rychlost) na druhé kartě.
- **Spuštění:** `SAPITERM` (úvodní obrazovka s adresářem), `SAPITERM číslo`, `SAPITERM host[:port]`,
  `SAPITERM soubor.ANS` (prohlížeč).
- **`SAPITERM.CFG` vedle programu:** klávesnice, karta terminálu, rychlost linky, sloupce a adresář až 16 BBS se
  sadou a volbou RAW. Výchozí adresář má 16 ověřených BBS (je plný).
- **Menu Ctrl+] na BBS:**
  - O odpojit, K konec, Tab výměna karet, T klávesnice;
  - Z sada (CP437, UTF-8, LATIN2, CP1250, CP852, KAMENICKY, KOI8, PETSCII, ATASCII, VIEWDATA);
  - R rychlost linky, S 80/40 sloupců, U do adresáře, L záznam relace, D stažení XMODEM/YMODEM, H historie,
    N telnet / raw TCP.
- **Terminály C64 (PETSCII), Atari (ATASCII) a Prestel (Viewdata)** s písmy C64 a Atari z jejich ROM a jejich
  barvami. ANSI ve 40 sloupcích má písmo Sharp MZ-800 a česká písmena jako české CP/M pro MZ-800.
- **Dál:**
  - blikání, zvonek na MPH-1V;
  - historie 93 řádků ve stránce B CGA-1V;
  - čeština z EKL-1 v sadě BBS.
- **Testy:** `tools/emu/phase2.py` až `phase8.py` (i `phase2.py --consul`) procházejí všechny,
  `tools/emu/realbbs.py` připojí všech 16 BBS adresáře.
- Níže je postup po fázích. Starší údaje tam platí v době fáze, novější je nahrazují.

## Stav po fázích (2026-10-30)

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
- **Fáze 6 hotová:** `SAPITERM.COM` 0.6 (21,8 KB), ANSI art a animace.
  - **Rychlost linky** (menu R, `SPEED=`): bez omezení, 38400, 19200, 9600, 4800, 2400, 1200 a 300 Bd.
    - Bajty jdou do terminálu ve svém čase, na BBS i v prohlížeči `.ANS`, takže ANSI animace běží, jak mají.
    - Čas měří volně běžící čítač 0 na MPH-1V (bez ní tiky 60 Hz). Co terminál nestihne (rolování), dožene.
    - Ověřeno: MENU při 2400 Bd za 4,96 s místo 4,70 s, rozdíl je režie testu.
  - **Blikání** (SGR 5 bez iCE) paletou každou 1/3 s. S iCE je to jasné pozadí jako dřív. Jasná pozadí
    100–107 bez iCE blikají, stejně jako v textovém režimu PC.
  - **40×25 na CGA-1V** (menu S, `COLUMNS=40`, jen na BBS):
    - písmo 4×8 se zdvojenými body (8×8), NAWS 40×25;
    - úvodní obrazovka a prohlížeč zůstávají 80×25.
  - **Rychlejší kreslení** podle profilu (`tools/emu/profile.py`):
    - rozskok CSI tabulkou;
    - uvolnění dvojice barev bez procházení 256 atributů;
    - buňka se stejným atributem bez přepočtu dvojic;
    - rozvinuté kreslení glyfu.
    - Výsledek: SUNSET 3,6 → 3,0 s, SCROLL 4,8 → 4,2 s, MENU a ANSITEST 1,8 → 1,2 s.
  - **Ověřeno** skriptem `tools/emu/phase6.py`:
    - blikání v obou fázích a iCE bez blikání (obraz proti modelu);
    - 40 sloupců (stín proti modelu 40×25, obraz proti zdvojenému písmu, NAWS);
    - rychlost 2400 Bd na BBS a v prohlížeči, `SPEED=2400` v souboru.
    - Fáze 2 až 5 procházejí dál.
- **Fáze 7 hotová:** `SAPITERM.COM` 0.7 (24,6 KB), záznam relace, historie a stahování souborů.
  - **Záznam relace** (menu L): přijatá data (po telnetu) jdou do `LOGnn.ANS` vedle programu.
    `SAPITERM LOGnn.ANS` relaci přehraje, i nastavenou rychlostí linky.
  - **Historie:**
    - 77 řádků, které odrolovaly z obrazovky, v paměti A298–D5FF;
    - menu H na BBS, PgUp (Ctrl+R) v psacím stroji;
    - šipky po řádku, PgUp a PgDn po obrazovce, Home a End, Esc zpět na obrazovku, jak byla.
  - **Stahování** (menu D, BBS musí začít posílat první):
    - XMODEM (bloky 128 B a 1K, CRC nebo součet) a dávkový YMODEM;
    - soubor jde vedle programu; jméno, které na disku už je, dostane číslici (MENU.ANS → MENU1.ANS);
    - průběh je na stavové kartě, Esc stahování přeruší.
  - **Telnet** zahodí NUL za CR, když BBS neposílá binárně (RFC 854). Stahování je pak čisté i bez binárního
    režimu.
  - **Ověřeno** skriptem `tools/emu/phase7.py` proti testovací BBS:
    - záznam, historie (řádky proti modelu, obnovená obrazovka bod po bodu);
    - YMODEM se dvěma soubory a XMODEM;
    - každý stažený soubor i záznam program zobrazí a obraz se porovná s modelem odeslaných bajtů.
    - Fáze 2 až 6 procházejí dál.
- **Fáze 8, část PETSCII hotová:** `SAPITERM.COM` 0.8 (27,9 KB): terminál C64.
  - **Zapnutí:** sada PETSCII v menu Z (osmá) nebo v adresáři (`BBS=…,PETSCII`).
  - **Obrazovka:** 40×25 na CGA-1V s barvami C64, na AND-1V 40×20.
  - **Řídicí kódy editoru obrazovky C64:**
    - 16 barev, reverz;
    - kurzor, HOME, CLR, DEL, INST;
    - přepnutí velkých a malých písmen (celá obrazovka jako na C64);
    - zalomení hned na konci řádku.
  - **Klávesy jako z C64:** malá písmena 41h–5Ah, velká C1h–DAh, šipky, Home, Backspace = DEL, Ins = INST.
  - **Písmo 8×8 vlastní** (`tools/petfont.py`, náhled `build/preview/font_pet.png`):
    - písmena z písma 4×8 se zdvojenými body;
    - grafika nakreslená podle významu znaků;
    - z ROM Commodore nic.
  - **Ověřeno:**
    - `tools/emu/phase8.py`: testovací stránka (barvy, reverz, celá grafika, kurzor, DEL, INST, obě sady,
      rolování) proti modelu `tools/petref.py`, stín i obraz bod po bodu; klávesy; Tab na AND-1V a zpět;
      uložení do adresáře;
    - skutečná BBS: Retro Campus, volba 1 (CBM PETSCII), správně (`build/preview/f8_real_retrocampus.png`).
  - **Výchozí adresář má 14 BBS:** přibyla The Basement (C64) se sadou PETSCII.
  - Historie má teď 65 řádků (písmo PETSCII zabralo 2 KB). Blok XMODEMu sdílí místo s bufferem
    `SAPITERM.CFG`.
- **Fáze 8, část ATASCII hotová:** `SAPITERM.COM` 0.8 (29,8 KB): terminál Atari 8-bit.
  - **Zapnutí:** sada ATASCII (devátá v menu Z, v adresáři `,ATASCII`).
  - **Obrazovka:** 40×24 v barvách Atari (světlý text na modré), na AND-1V 40×20.
  - **Řídicí kódy editoru Atari:**
    - EOL 9Bh, ESC (další bajt doslova);
    - kurzor obtáčí po obrazovce;
    - smazání obrazovky, Backspace, Tab;
    - mazání a vkládání řádků i znaků;
    - 80h–FFh inverzně.
  - **Klávesy jako z Atari:** Enter = 9Bh, Backspace = 7Eh, šipky 1Ch–1Fh, Tab, Del, Ins.
  - **Písmo 128 znaků vlastní** (`tools/atafont.py`): písmena ze zdvojeného 4×8, grafika podle významu.
  - **Ověřeno:**
    - `tools/emu/phase8.py`: stránka A testovací BBS proti modelu `tools/ataref.py` (stín i obraz bod po bodu),
      klávesy;
    - skutečné BBS: AMIS (Southern Amis) a Clacker Works, správně (`build/preview/f8_ata_*.png`).
  - **Výchozí adresář má 15 BBS:** přibyla Southern Amis (Atari) se sadou ATASCII.
  - **Historie** je ve stránce B videopaměti CGA-1V, kterou terminál nezobrazuje: 93 řádků. Bez CGA-1V je v RAM
    (53 řádků). Řádek si pamatuje i písmo (PETSCII, ATASCII), záznam má 171 B.
- **Fáze 8 hotová:** `SAPITERM.COM` 0.8 (31,2 KB), poslední část Viewdata (Prestel).
  - **Zapnutí:** sada VIEWDATA (desátá v menu Z, v adresáři `,VIEWDATA`).
  - **Obrazovka:** 40×24 v 8 barvách teletextu.
  - **Sériové atributy úrovně 1:** barvy písmen a mozaik, pozadí (černé, nové), blikání, skrytý text, dvojitá
    výška (řádek pod ní ukazuje dolní poloviny), mozaiky 2×3 souvislé i oddělené.
  - **Kódy:** atribut jako ESC + 40h–5Fh i jako 80h–9Fh. Kurzor obtáčí, nic neroluje (jako Prestel).
  - **Klávesy:** Enter posílá `_` (klávesa # Prestelu), šipky 08h–0Bh.
  - **Bez „hold mosaics“:** buňka atributu je vždy mezera.
  - **Ověřeno:**
    - `tools/emu/phase8.py`: stránka V testovací BBS proti modelu `tools/vdtref.py` (stín i obraz v obou fázích
      blikání), klávesy;
    - skutečná služba Telstar (`glasstty.com:6502`), správně (`build/preview/f8_vdt_telstar.png`). V adresáři
      není: zbylo by jediné volné místo. Připojit adresou, v menu Z zvolit VIEWDATA, U ji uloží.
  - **Paměť:** `SAPITERM.CFG` se čte a píše po záznamech 128 B (dřív celý soubor v bufferu 2,7 KB). Buffery
    a zásobník končí na B5AAh, pod C000h zbývá 2,6 KB. Historie bez CGA-1V má 48 řádků.
- **Písma 8×8 z původních strojů:** `SAPITERM.COM` 0.8 (32,8 KB).
  - PETSCII má písmo C64, ATASCII a Viewdata písmo Atari 400/800.
  - ANSI ve 40 sloupcích má písmo Sharp MZ-800: ASCII, 20 znaků CP437 (£ ä ö ü ß ♥ ↑ …) a česká a slovenská
    písmena, jak je skládá české CP/M pro MZ-800 (opravené Ň a ô). Rámečky, bloky a ostatní znaky jsou zdvojené
    4×8.
  - Zdroje a převod: `tools/romfont.py` → `fonts/*.txt`, `docs/vyvoj.md` (Písma z ROM).
  - Ověřeno:
    - `tools/emu/phase6.py`: 40 sloupců proti modelu s písmem MZ-800; v UTF-8 stránka U (čeština, rámečky, ß, π)
      na CGA-1V bod po bodu proti obrazu ze stínu (`build/preview/f6_utf8_40.png`);
    - `phase3` až `phase8` procházejí, modely berou písma ze stejných předloh.
  - Buffery a zásobník končí na BCAAh, pod C000h zbývá 853 B. Historie bez CGA-1V má 37 řádků.
- **The Basement opravená (2026-10-31):** je to BBS pro Atari (BBS Express! Pro), ne C64. V adresáři je teď
  jako ATASCII s raw TCP (`docs/rozhodnuti.md`). Ověřeno v emulátoru, snímek `build/preview/f8_ata_basement.png`.
- **telehack.com v adresáři (2026-10-31):** šestnáctá položka, uložil ji autor. Adresář je teď plný; `phase8.py`
  proto na začátku šestnáctku smaže, aby U mohlo uložit testovací BBS.
- **Menu na obrazovce terminálu (2026-10-31):** Ctrl+] ukáže menu přes celou kartu terminálu (terminál mezitím
  stojí), Esc ho nakreslí znovu ze stínu (CGA-1V 80×25 asi 0,8 s). Funguje i se sestavou s jedinou kartou.
  - T, R, S a Tab se do `SAPITERM.CFG` zapíšou až při odchodu z menu (zápis trvá 0,3 s), U hned.
  - Stavová karta při spojení: protokol, doba spojení, přijato KB a KB/s za poslední sekundu. Řádky „Dvojice
    barev“ a „Poslední klávesa“ (pro vývoj) jsou pryč, titulek bez „vývojová verze“.
  - Písma a tabulky zarovnané na stránku jsou na začátku programu (od 0200h), jejich výplň už neroste s kódem.
    Pod C000h zbývá 597 B.
  - Testy čtou menu z obrazu CGA-1V (`tools/emu/cgaread.py`), celá sada prochází i s Consulem.
- **Doba spojení bez MPH-1V z RTC DPI-1L (2026-10-31):** rozdíl času RTCGETT proti začátku spojení, rychlost
  z přírůstku dat za uplynulé sekundy. RTC se čte v klidu 4× za sekundu, při provozu po 2 KB dat. Ověřeno na sestavě
  s Consulem: karta ukázala stejný čas jako hodiny PC. Tabulky dvojic barev jsou pevně na B800h–BFFFh, BSS
  za programem bez výplně (`check_build.py` vypíše, kolik zbývá). Historie bez CGA-1V má 32 řádků od C000h.
- **KB/s na stavové kartě je průměr za posledních 5 s (2026-10-31).**
- **Buffery nad C000h (2026-10-31):** adresář BBS, blok XMODEM/`SAPITERM.CFG` a kódy Viewdata jsou v RAM
  C000h–D5FFh (konec TPA), kterou s CGA-1V nic nepoužívalo. Pod tabulkami dvojic barev zbývá 3838 B. Historie bez
  CGA-1V má 12 řádků (s CGA-1V dál 93 ve stránce B). Testy fází 2–8 procházejí.
- **Konec TPA za běhu (2026-10-31):** BDOS se bere z adresy na 0006h, ne pevně D600h (jiné buildy CP/M). S CGA-1V
  je potřeba BDOS aspoň od CE00h, bez ní od D100h; jinak hláška „málo paměti“ a návrat do CP/M (ověřeno
  s podvrženým BDOS na CC00h). Hlášky při startu (i „chybí karta AND-1V i CGA-1V“) teď zůstanou vidět.
- **Rychlejší příjem (2026-10-31):** akvárium z telehack.com po síti 4,3 → 6,0 KB/s (telnet rychlou smyčkou,
  parser CSI a SGR bez `add_hl_a`), `docs/rozhodnuti.md`. Testy fází 3–8 procházejí.

## Plán (schválený 2026-10-30, rozhodnutí v `docs/rozhodnuti.md`)

0. ~~Kostra~~
1. ~~Start a návrat~~
2. ~~Výstup: font 4×8, CGA 80×25, AND-1V 64×20, stavová obrazovka, testovací obrazovka, české texty~~
3. ~~Parser ANSI, prohlížeč `.ANS`, dvojice barev po doménách, skokové rolování~~
4. ~~Síť: DNS, TCP, telnet, zadání adresy, menu, `tools/testbbs.py`~~
5. ~~Skutečné BBS: ověřený seznam, adresář a nastavení v `SAPITERM.CFG` vedle `SAPITERM.COM`, znakové sady
   (UTF-8, Latin-2, CP1250, CP852, Kamenický, KOI-8čs) a čeština z EKL-1~~
6. ~~ANSI art a animace: rychlost modemu, blikání, 40×25 (písmo 4×8 zdvojené), rychlejší kreslení~~
7. ~~Historie a záznam relace, stahování XMODEM/YMODEM (na disk programu)~~
8. ~~PETSCII, ATASCII, Viewdata (40 sloupců, vlastní písma)~~
9. **Skutečný HW** dávkově s autorem.

## Další krok

Fáze 9: skutečný HW dávkově s autorem (`docs/hw-otazky.md`). Všechny ostatní body plánu jsou hotové.

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
- **Raw TCP** (menu N, v adresáři `,RAW`): pro BBS, které telnet nemluví. Přijaté bajty jdou beze změny, FFh se
  neposílá dvakrát a za CR nejde NUL. Ověřeno v `phase8.py` (FFh jako π: s telnetem jedno, raw dvě).
- **BEL** (v ATASCII bzučák FDh) zahraje krátký tón 880 Hz na YM3812 MPH-1V (asi 1/15 s, program na tu dobu
  čeká). Bez MPH-1V je ticho. Ověřeno nahrávkou zvuku v `tools/emu/phase6.py`.
- **Blikání a kurzor stojí, když běží data:** tiky pro blikání se počítají jen v klidu. Při pomalé lince se kurzor
  ukazuje stále.
- **Znaková sada BBS Liane** (`bbs.vslib.cz`) není známá: úvodní obrazovka je v ASCII a hlubší pohled chce
  přihlášení (BBS nabízí veřejný účet `guest`). V adresáři je zatím CP437. Na BBS se dá vyzkoušet Z a uložit U.
- **Paměť:** program má 31,2 KB a pod C000h zbývají 2,6 KB. Historie bez CGA-1V (v RAM) se s každým dalším kódem
  zmenšuje (48 řádků). Víc místa by daly písma PETSCII a ATASCII nahrávaná ze souboru až při potřebě.
- **Aleco Experience BBS** (Praha, Atari, `bbs.alecoexp.cz`) 2026-10-30 spojení na port 23 odmítala, web běží.
  Zkusit později a případně přidat.
