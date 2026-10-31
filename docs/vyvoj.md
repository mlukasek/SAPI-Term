# SAPI-Term – vývoj: překlad, emulátor, ověřování

## Co je potřeba

| Co | Kde (u autora) | Na co |
|---|---|---|
| pasmo 0.5.3 | `E:\SAPI_GIT\Tools\pasmo-0.5.3\pasmo.exe` (proměnná `PASMO`) | překlad |
| Python 3 | jen standardní knihovna | kontrola rozložení, RAM disk, skripty emulátoru |
| SAPIemu release | `E:\SAPI_GIT\SAPIemu-release` (0.7.0-beta, proměnná `SAPIEMU_DIR`) | běh a ověřování přes MCP |
| obraz CP/M | `SAPIemu-release\media\zrmd-1\SAPI_CPM_Martin_2019-10-07.bin` (proměnná `CPM_IMAGE`) | RAM disk A: |

## Překlad

`build.cmd`:
1. generátory do `build\`:
   - `tools\fontgen.py`: font z `fonts\sapiterm4x8.txt` → `font4x8.inc` (`--preview SOUBOR.png` uloží náhled);
   - `tools\tables.py`: převod CP437 → AND-1V, vzdálenosti barev, adresy řádků CGA → `tables.inc`;
   - `tools\petfont.py`, `tools\atafont.py`, `tools\mzfont.py`: písma 8×8 C64 (PETSCII), Atari (ATASCII) a
     Sharp MZ-800 (ANSI ve 40 sloupcích) z `fonts\c64.txt`, `atari.txt`, `mz800.txt` a `mz800cs.txt` →
     `font_pet.inc`, `font_ata.inc`, `font_mz.inc`, s mapami pro AND-1V;
   - `tools\texts.py`: texty UI z `src\texts.txt` (UTF-8) v KOI-8čs2 → `texts.inc`;
   - `tools\mkart.py`: testovací soubory ANSI → `build\art\*.ANS` (každá doména nejvýš 16 dvojic, hlídá
     `tools\ansiref.py`), používá je i `tools\testbbs.py`;
2. pasmo → `build\sapiterm.com`, `.sym` a `.hex` (Intel HEX od 0100h);
3. `tools\check_build.py`: rozložení paměti (vše pod C000h, tabulky zarovnané na stránku, písmo 4×8 na 0200h),
   vypíše
   `SAVE n SAPITERM.COM`;
4. `tools\cpmdisk.py` (převzatý z SAPI-Bad-Apple): `build\ramdisk.bin` = RAM disk CP/M sestavy V
   se `SAPITERM.COM` a testovacími soubory `*.ANS`.

### Písma z ROM

`fonts\c64.txt`, `atari.txt`, `mz800.txt` a `mz800cs.txt` jsou v repu. Dělá je jednorázově `tools\romfont.py`
z ROM a z BIOSu českého CP/M, které v repu nejsou (`work\roms`, git je ignoruje). Skript kontroluje CRC32 a ROM
MZ otáčí (bit 0 = levý bod).

| Písmo | Soubor (CRC32) | Odkud |
|---|---|---|
| C64 | `chargen-901225-01.bin` (EC4272EE) | VICE, `data/C64` (zrcadlo SVN na GitHubu `VICE-Team/svn-mirror`) |
| Atari | `ATARIOSB.ROM` (3E28A1FE), písmo na E000h | `xf25.zip` (PC Xformer 2.5) v projektu Atari800 na SourceForge |
| MZ-800 | `CGROM.ROM` (2A62D77E) | od autora; MZ-700 pro srovnání: `mz700fon.int` ze sady MAME 0.221 `mz700.zip` |
| čeština MZ | `BIOS.mac`, blok „BIOS CG ZNAKY“ (C28F2248) | české CP/M pro MZ-800 (Lamač), `Cpm_v41` od autora |

```
python tools\romfont.py --c64 work\roms\c64\chargen-901225-01.bin --atari work\roms\atari\ATARIOSB.ROM --mz work\roms\mz800\CGROM.ROM --cpm work\roms\CPM_gen\Cpm_v41\BIOS.mac
```

## Emulátor

- **Bez okna pro skripty:** `tools\emu\sapiemu.cmd` (otevře okno se `sapiemu-cli --mcp --mcp-port 8595`). Nebo
  přímo ve složce `SAPIemu-release`:
  `sapiemu-cli --machine E:/SAPI_GIT/SAPI-Term/machines/sapi1v_term.sapi --mcp --mcp-port 8595`.
- **GUI pro ruční zkoušky:** `tools\emu\sapiemu.cmd gui` (MCP na 8596, skripty pak
  s `SAPIEMU_MCP=http://127.0.0.1:8596/mcp`).
- **Vypínat přes MCP:** `python tools\emu\sapimcp.py power "{\"state\":\"off\"}"`, pak `quit`. Nezabíjet.
- **Sestavy:**
  - `machines\sapi1v_term.sapi`: jako autorovo SAPI (EKL-1, MPH-1V);
  - `machines\sapi1v_term_consul.sapi`: Consul 262.3 bez úpravy 7474, `strict` (klávesy se mohou ztratit jako na
    HW), bez MPH-1V.
  - Obě mají RAM disk `build\ramdisk.bin` v režimu `nosave` a SD kartu DPI-1L ve `work\sdcard` (mimo git).
- **Po novém překladu** musí emulátor znovu načíst `build\ramdisk.bin`: `emu.use_machine(...)` (MCP
  `load_machine`). Skripty to dělají samy.
- **CP/M naběhne volbou 3 ECMONu.** `emu.checkpoint()` to udělá sám a stav uloží jako
  `cpm-<sestava>-<čas ramdisk.bin>`. Stav nese sestavu i RAM disk, proto je zvlášť pro každou sestavu a překlad.

## Skripty `tools/emu`

| Skript | Co dělá |
|---|---|
| `phase2.py [--consul]` | fáze 2: SAPITERM z disku, stavová obrazovka, stínová obrazovka v paměti (titulek, tabulka CP437), psaní a rolování, Tab na AND-1V a zpět, Ctrl+G (tón MPH-1V 880 Hz, bez ní bzučák klávesnice: frekvence a délka z nahrávky `build/preview/f2_bell.wav`), Ctrl+L, Ctrl+T, Ctrl+] zpět na výběr BBS, Ctrl+] do CP/M a `DIR` po návratu; snímky `build/preview/f2_*.png` |
| `phase3.py [JMÉNO...]` | fáze 3: každý testovací soubor `SAPITERM JMÉNO.ANS`, stínová obrazovka a kurzor proti `tools/ansiref.py`, snímek CGA-1V proti modelu vykreslenému fontem (bod po bodu), žádný zápis palety mimo VBI; snímky `build/preview/f3_*.png` |
| `phase4.py` | fáze 4: spustí `tools/testbbs.py` (127.0.0.1:6023), `SAPITERM 127.0.0.1:6023`; vyjednání telnetu, tři stránky po síti proti modelu (stín i obraz), CPR a DA, menu Ctrl+] na CGA-1V (text z obrazu, `cgaread.py`) a stav na AND-1V (protokol, doba, data), po Esc obraz proti modelu, odeslané klávesy, NAWS po Tab, konec spojení od BBS, odmítnutý port, neznámé jméno |
| `phase5.py` | fáze 5: výchozí `SAPITERM.CFG`, adresář na úvodní obrazovce, mazání, chybné číslo; na testovací BBS všech šest znakových sad (stránka glyf po glyfu proti `tools/tables.py`, odeslaná „čŘ“), U, T; výběr číslem se sadou z adresáře, Tab na výzvě; `TYPE SAPITERM.CFG` po návratu; `SAPITERM 13` s AND-1V a Consulem ze souboru |
| `phase6.py` | fáze 6: blikání (obraz v obou fázích proti modelu), iCE bez blikání, 40 sloupců (stín proti modelu 40×25, obraz s písmem MZ-800, stránka UTF-8 s češtinou, NAWS), rychlost 2400 Bd na BBS a v prohlížeči, `SPEED=` v souboru |
| `phase7.py` | fáze 7: záznam relace (L), historie (H, PgUp, šipka, End, Esc proti modelu a obraz po návratu), YMODEM se dvěma soubory a XMODEM z testovací BBS; záznam i stažené soubory program zobrazí a obraz se porovná s modelem |
| `phase8.py` | fáze 8: PETSCII přes menu Z, stránka G testovací BBS proti modelu `tools/petref.py` (stín i obraz s písmem `font_pet` a barvami C64), klávesy, Tab na AND-1V a zpět; ATASCII, stránka A proti `tools/ataref.py`, klávesy; Viewdata, stránka V proti `tools/vdtref.py` (obraz v obou fázích blikání), klávesy; uložení do adresáře a připojení s PETSCII |
| `profile.py "PŘÍKAZ"` | statistický profil: PC každou emulovanou milisekundu, počty podle návěští z `.sym` |
| `realbbs.py [ČÍSLO\|ADRESA…]` | skutečné BBS z adresáře nebo podle adresy: připojení, úvodní obrazovka (text a snímek `build/preview/bbs_*.png`), vyjednané volby telnetu, odpojení; bez přihlášení a bez kláves; čeká ve skutečném čase |
| `emu.py` | společné: sestava, kontrolní bod CP/M, příkaz CP/M, čtení paměti, symboly, snímek obrazovky |
| `cgaread.py` | text CGA-1V ze snímku (buňky proti glyfům písma 4×8, ve 40 sloupcích MZ-800 a zdvojeného 4×8, čeština KOI); `term_text(sym)` = text karty terminálu, pro kontrolu menu |
| `sapimcp.py` | klient MCP (`python tools\emu\sapimcp.py NÁSTROJ "{json}"`) |
| `sapiemu.cmd [consul\|gui]` | spustí release emulátor s MCP |

## Pasti

- **pasmo:**
  - unární minus na začátku výrazu neguje celý zbytek (`-1*40+1` = −41); psát hotová čísla;
  - operand začínající závorkou je adresa: `ld a,(X+3) & 0FFh` nejde, použít `low`/`high` nebo `0+(…)`;
  - ALIGN není: `defs (256 - ($ & 0FFh)) & 0FFh`;
  - návěští `.x` jsou globální, `DEFL` v `REPT` nefunguje.
- **pasmo a `equ` s pozdějším symbolem:** `equ`, jehož výraz používá symbol definovaný až za ním (i jiný `equ`),
  dá kódu před sebou hodnotu z prvního průchodu, kde ten symbol ještě není (0). `.sym` přitom ukazuje správnou
  hodnotu. Tak skončil `ld sp,STACK_TOP` uvnitř vstupního bufferu (`IN_RECORDS` bylo až za `sauce_buf`).
  Konstanty definovat před prvním použitím ve výrazu `equ`. `check_build.py` hlídá aspoň `LD SP`.
- **Znak pro kreslení v RAM musí být zarovnaný na 8:** `cga_draw` a `cga_draw_8` posouvají ukazatel jen `inc e`.
  `vdt_glyph` v BSS bez zarovnání vyšel po přidání pár bajtů kódu na A8FAh–A901h, poslední dva řádky bodů se
  četly z A800h a obraz Viewdata nesouhlasil (`phase8.py`). Teď `(… + 7) & 0FFF8h`, `check_build.py` to hlídá.
- **`jr` přes rozvinutou smyčku** (`rept 80 / ldi`) nedosáhne, pasmo hlásí „Relative jump out of range“. Rychlá
  oprava: smyčka v Bashi, která pasmo pustí a nahlášený řádek změní z `jr` na `jp`.
- **Rutiny, které mění A** (`and_at`, `and_putc`…): před voláním si příznak v A uložit. Na tom se spálila první
  verze `show_yes_no`.
- **MCP:**
  - `read_memory` vrací nejvýš 4096 B (`emu.read` dělí);
  - `read_memory` ukazuje paměť z pohledu CPU: kdyby se emulátor zastavil, když má SAPI-Term namapovanou CGA-1V,
    četlo by se nad C000h z karty, ne z RAM (adresář BBS, buffery). `emu.read` proto nad C000h nejdřív počká
    po 1 ms, až `machine_info` ukáže MAP1 i MAP2 = 0 (`emu.ram_view`). Pojistka po jednom selhání `phase5.py`
    (2026-10-31: položky adresáře přečtené jako nuly). Příčina ověřená není, ve 36 dalších startech se to
    nezopakovalo a karta v tu chvíli namapovaná nebyla.
  - `cycles` počítá takty 4 MHz i při CPU 2 MHz;
  - `run_until` s textem, který už na obrazovce je (starý `A>`), skončí hned. `emu.command` proto nejdřív
    nechá běžet dobu psaní.
  - Consul bez úpravy 7474 dostává z `type_text` znak po 20 ms.
  - Výpis `screen_text` obsahuje znaky mimo cp1252 (kurzor ▒, čeština). `python -I` proměnnou
    `PYTHONIOENCODING` ignoruje, skripty proto volají `sys.stdout.reconfigure(encoding='utf-8')`.
  - Kodek `cp437` v Pythonu dává pro 00–1F řídicí znaky, ne ☺☻. Testy porovnávají kódy znaků.
  - Emulátor kreslí CGA-1V s paprskem: paleta zapsaná ve VBI se ve snímku obrazovky projeví až v dalším snímku
    obrazu. Před `screenshot` nechat běžet aspoň 20 ms.
  - `machine_info` u CGA-1V hlásí `palette_writes_visible` (zápisy palety mimo VBI, na monitoru sníh).
- **ECMON bez DSM-1V** přepne konzoli na sériovou linku a visí na portu 11h. Sestavy proto DSM-1V mají.
- **Konce řádků:** soubory v gitu s LF, `.cmd` s CRLF (`.gitattributes`). Python na Windows píše v textovém
  režimu CRLF, proto `newline='\n'`. Cesty s `\` v řetězcích Pythonu psát jako `r'...'`, jinak z `\f` a `\t`
  vzniknou řídicí znaky (tak se rozbil `build.cmd`).
- **Bash nástroj a dlouhý heredoc** občas skončí chybou „unexpected EOF“ a neprovede nic. Delší úpravy psát jako
  skript do scratchpadu a spustit ho. Pozor také na `\r` v heredocu: do souboru se dostal skutečný znak CR.
- **Windows a soubor, který jiný proces čte:** `os.replace` na něj hlásí „Access is denied“. `tools/testbbs.py` to
  zkouší znovu, test čte přes `with open`.
- **Snímek obrazovky s málo barvami** ukládá emulátor jako PNG s paletou (1 bit na bod u ATASCII).
  `ansiref.png_rgb` čte i takové.
- **Testy podle počtu sad v menu Z:** mačkat Z, dokud není požadovaná sada (`phase5.py`), ne pevný počet.
- **Write a koncové mezery:** nástroj Write maže mezery na konci řádků. Text v `src/texts.txt`, který na mezeře
  končí, proto končí značkou `\s`. Testovací YMODEM musí blok 0 doplnit nulami: s 1Ah ho přijímač bral jako
  další soubor (`________.`).
- **Konzole ECMONu stránkuje:** když výstup zaplní obrazovku AND-1V, čeká na klávesu. `TYPE` delšího souboru
  tak skončí bez `A>` a první znak dalšího příkazu se spotřebuje (příkaz pak chybí první písmeno).
  `emu.command_lines` po 1 s beze změny stiskne Enter a sebere všechny řádky, které konzolí proběhly.
- **Sestava `.sapi` je JSON:** uvozovky v textu popisu ho rozbijí („syntax error in machine file“).
- **Escape sekvence ve skriptu v heredocu:** `'\x1b'` uvnitř `'''...'''` v Pythonu z heredocu se do souboru
  zapíše jako skutečný znak ESC (a `\r\n` jako konec řádku). Úpravy s escape sekvencemi dělat nástrojem Edit
  nebo skriptem uloženým přes Write.
- **Tiky v emulátoru nejsou skutečný čas:** bez GUI běží emulátor rychleji, limity v ticích (DNS, spojení)
  vypršejí dřív, než síť odpoví. Testy se skutečnou sítí (`realbbs.py`) proto běží podle hodin PC.
