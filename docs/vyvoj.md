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
   - `tools\texts.py`: texty UI z `src\texts.txt` (UTF-8) v KOI-8čs2 → `texts.inc`;
2. pasmo → `build\sapiterm.com`, `.sym` a `.hex` (Intel HEX od 0100h);
3. `tools\check_build.py`: rozložení paměti (vše pod C000h, tabulky zarovnané na stránku), vypíše
   `SAVE n SAPITERM.COM`;
4. `tools\cpmdisk.py` (převzatý z SAPI-Bad-Apple): `build\ramdisk.bin` = RAM disk CP/M sestavy V
   se `SAPITERM.COM`.

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
| `phase2.py [--consul]` | fáze 2: SAPITERM z disku, stavová obrazovka, stínová obrazovka v paměti (titulek, tabulka CP437), psaní a rolování, Tab na AND-1V a zpět, Ctrl+L, Ctrl+T, Ctrl+] a `DIR` po návratu; snímky `build/preview/f2_*.png` |
| `emu.py` | společné: sestava, kontrolní bod CP/M, příkaz CP/M, čtení paměti, symboly, snímek obrazovky |
| `sapimcp.py` | klient MCP (`python tools\emu\sapimcp.py NÁSTROJ "{json}"`) |
| `sapiemu.cmd [consul\|gui]` | spustí release emulátor s MCP |

## Pasti

- **pasmo:**
  - unární minus na začátku výrazu neguje celý zbytek (`-1*40+1` = −41); psát hotová čísla;
  - operand začínající závorkou je adresa: `ld a,(X+3) & 0FFh` nejde, použít `low`/`high` nebo `0+(…)`;
  - ALIGN není: `defs (256 - ($ & 0FFh)) & 0FFh`;
  - návěští `.x` jsou globální, `DEFL` v `REPT` nefunguje.
- **`jr` přes rozvinutou smyčku** (`rept 80 / ldi`) nedosáhne, pasmo hlásí „Relative jump out of range“.
- **Rutiny, které mění A** (`and_at`, `and_putc`…): před voláním si příznak v A uložit. Na tom se spálila první
  verze `show_yes_no`.
- **MCP:**
  - `read_memory` vrací nejvýš 4096 B (`emu.read` dělí);
  - `cycles` počítá takty 4 MHz i při CPU 2 MHz;
  - `run_until` s textem, který už na obrazovce je (starý `A>`), skončí hned. `emu.command` proto nejdřív
    nechá běžet dobu psaní.
  - Consul bez úpravy 7474 dostává z `type_text` znak po 20 ms.
  - Výpis `screen_text` obsahuje znaky mimo cp1252 (kurzor ▒, čeština). `python -I` proměnnou
    `PYTHONIOENCODING` ignoruje, skripty proto volají `sys.stdout.reconfigure(encoding='utf-8')`.
  - Kodek `cp437` v Pythonu dává pro 00–1F řídicí znaky, ne ☺☻. Testy porovnávají kódy znaků.
- **ECMON bez DSM-1V** přepne konzoli na sériovou linku a visí na portu 11h. Sestavy proto DSM-1V mají.
- **Konce řádků:** soubory v gitu s LF, `.cmd` s CRLF (`.gitattributes`). Python na Windows píše v textovém
  režimu CRLF, proto `newline='\n'`. Cesty s `\` v řetězcích Pythonu psát jako `r'...'`, jinak z `\f` a `\t`
  vzniknou řídicí znaky (tak se rozbil `build.cmd`).
