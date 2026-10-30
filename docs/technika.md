# SAPI-Term – technika

Podklady jsou v dokumentaci SAPIemu-release (`..\SAPIemu-release\docs\desky\*.md`: CGA-1V, AND-1V, JPR-1V, RAM-1V,
ZRMD-1, DPI-1L, MPH-1V, `klavesnice.md`) a ve firmwaru DPI (`..\SAPI_DPI-firmware\docs\unicard.md`, `common/net.c`).

## Paměť a mapování

- **CP/M** (ECMON IDE-1, volba 3, CP/M 2.2 z RAM disku ZRD-1V):

  | Adresa | Obsah |
  |---|---|
  | 0100–D5FF | TPA (CCP na CE00 se smí přepsat, warm boot ho nahraje znovu) |
  | D606 | BDOS |
  | E400 | BIOS |
  | F000–F78F | monitor (kopie z ROM) |
  | pod F800 | zásobník CP/M |
  | F800–FFFF | AND-1V (řádky 20–31 = FD00–FFFF jsou volná RAM) |

- **ECMON:**
  - proměnné konzole F786–F794 a bajt 003Bh (varianta bootu) se nesmí přepsat;
  - konzole píše přímo do VRAM AND-1V, kurzor je znak 7Fh;
  - obrazovku maže `1D 1F` (domů, smazat do konce obrazovky), 0Ch ne.
- **Registr MAP** RAM-1V na portu 63h: MAP1 = bit 6, MAP2 = bit 7. Bity 0–5 jsou A16–A21 RAM disku, BIOS je
  nastavuje před každým přístupem na disk (a nechá MAP = 0).
  - `OUT 63h,00h`: RAM v C000–F7FF, AND-1V na F800.
  - `OUT 63h,C0h`: CGA-1V na C000–FFFF. RAM tam není (díra RAM-1V), CP/M je schované.
- **SAPI-Term:**
  - kód, data a zásobník pod C000h; buffery za programem (`BSS` v `src/sapiterm.asm`, hlídá
    `tools/check_build.py`);
  - CGA-1V se mapuje jen na kreslení nebo čtení stavu a hned zpátky;
  - BDOS jen s MAP = 0.
- **Přerušení:** celý program s DI. Přerušení přijaté s PC v okně videokarty (CGA-1V ≥ C000h při MAP = C0h) zamrazí
  JPR-1V natrvalo, nepomůže ani RESET.

## Prázdná sběrnice

Čtení, na které nikdo neodpoví, vrátí poslední bajt na datové sběrnici: `IN A,(n)` → n, `LD A,(HL)` → 7Eh,
`LD A,(nn)` → horní bajt nn. Na FFh se spoléhat nedá. Detekce karet proto zkouší chování, které prázdná sběrnice
nenapodobí (`docs/rozhodnuti.md`).

## CGA-1V (báze C000h, s MAP = C0h)

- 320×200, 80 bajtů na řádek, dvě stránky (A, B) po 16 000 B, 3E80–3FBF nezobrazená RAM, registry v 3FC0–3FFF
  (zápis jde i do SRAM).
- **CONFIG** (zápis FFFBh):
  - D0 = zobrazená stránka B, D1 = stránka B pro CPU, D2 = režim CGA (0 = EGA), D3 = povolení IRQ;
  - D7 = 1 potvrdí VBI.
- **STATUS** (čtení FFFBh): D7 = požadavek VBI (60 Hz, začátek zatemnění, řádek 400), D0–D6 ze SRAM.
- **Bt476:** FFFCh adresa palety, FFFDh data R, G, B (6 bitů, pak adresa + 1), FFFEh COLMASK.
- **Režim EGA:**
  - bajt = 4 body (D7..D4, D7 vlevo) + atribut D3..D0 společný čtveřici;
  - index barvy = `(y >> 5) << 5 | atribut << 1 | bod`;
  - na každou doménu 32 řádků (4 textové řádky, poslední doména jen 8 řádků) tedy připadá 16 dvojic
    pozadí/popředí.
  - SAPI-Term: dvojice n = paleta `d*32 + 2n` (pozadí) a `d*32 + 2n + 1` (popředí) pro domény d = 0–6.
- **Paleta se zapisuje jen ve VBI.** VBI trvá 125 řádků = 4 ms (16 000 taktů při 4 MHz). Celá paleta černá trvá
  2,7 ms, 112 dvojic textu 3,4 ms při 4 MHz.
- **Čekání karty:** zápis asi +2,4 T, čtení +1,3 T na bajt `LDIR` při 4 MHz. Smazání stránky přes `LDIR` asi 98 ms.
- Hardwarový posun obrazu karta nemá.

## Text na CGA-1V (`src/cgatext.asm`)

- Znak 4×8 = 1 bajt na každém z 8 řádků: body z fontu v D7..D4, číslo dvojice barev (slot 0–15) v D3..D0.
  Adresa buňky = `cga_rows[řádek] + sloupec`, další řádek znaku +80.
- **Font:**
  - `font_cp437` (2 KB) a `font_koi` (KOI-8čs2 C0–FF, 512 B), 8 bajtů na znak, zarovnané na stránku;
  - `tools/fontgen.py` je vyrobí z `fonts/sapiterm4x8.txt`, `--preview` uloží náhled PNG.
- **Dvojice barev:**
  - `att_slot[256]`: slot atributu (FFh nemá), `slot_att[16]`, `slot_ref[16]`: počet buněk;
  - `pal_dirty`: sloty, jejichž barvy čekají na zápis do palety;
  - `pal_flush` počká na VBI a zapíše položky `d*32 + 2*slot` (pozadí) a `+1` (popředí) pro domény d = 0–6.
- **Rolování:** kopie řádků 1–24 o 640 B výš po kusech 80 B rozvinutým `LDI`, mezi kusy se čte klávesnice. Nový
  řádek se vyplní slotem atributu (body 0).
- **Kurzor:** XOR F0h na posledním řádku buňky.

## Stínová obrazovka (`src/screen.asm`)

- `scr_chr`, `scr_att`, `scr_ext` po 2000 B. Řádek obrazovky r je na `row_off[r]` (posun v polích), rolování
  posouvá jen tabulku `row_off`.
- `term_dev` = karta terminálu (1 CGA-1V, 2 AND-1V), `term_cols` × `term_rows` = 80×25 nebo 64×20. `stat_dev` =
  karta stavové obrazovky.
- `scr_putc` píše znak `cur_att`/`cur_ext` na kurzor s odloženým zalomením (`wrap_pend`). `scr_lf` dole roluje.
  `scr_set` zapíše buňku do stínu i na kartu. `scr_redraw` překreslí vše po výměně karty.
- **AND-1V jako terminál:** okno 64×20 od `view_x`, `view_y` (zatím vždy 0, 0). Znak CP437 jde přes
  `and_map_cp437`: dvojité rámečky jako jednoduché, bloky jako semigrafika 2×3, akcentovaná písmena jako
  KOI-8čs2, jinak podobný znak ASCII.

## AND-1V (F800h, s MAP = 0)

- 64×20 znaků, VRAM řádek·64 + sloupec, jednobarevná, bez atributů, kurzoru a inverze.
- **Znaky:**
  - 00–0F jednoduché rámečky: 00 ╰, 01 ╭, 02 ╮, 03 ╯, 04 └, 05 ┌, 06 ┐, 07 ┘, 08 ┴, 09 ├, 0A ┬, 0B ┤, 0C │,
    0D ─, 0E ┼, 0F █ (10–1F plné bloky);
  - 5E ↑, 7F šachovnice;
  - 80–BF semigrafika 2×3 (bit 0 vlevo nahoře, 1 vpravo nahoře, 2 vlevo uprostřed, 3 vpravo uprostřed,
    4 vlevo dole, 5 vpravo dole);
  - C0–FF KOI-8čs2.

## MPH-1V (báze 50h)

- 82C54: CLK0 = CLK2 = 55 930,4 Hz.
- SAPI-Term spustí čítač 2 v režimu 2 s dělitelem 932 (60,01 Hz), hradlo G2 v IEN = 20h, bez přerušení.
- Tik: STATUS (53h) D7 = F2, nuluje se `OUT 55h,80h`.
- Při návratu IEN = 0 a IACK = C0h.

## Klávesnice (JPR-1V, porty 01h a 02h)

- **Protokol MikroMonu:**
  1. `IN 01h` bit 0 = 0 znamená, že je klávesa připravená;
  2. `IN 02h` a CPL dá kód;
  3. `OUT 01h,03h` (ACK);
  4. čekat, až bit 0 = 1 (nejvýš 256 čtení);
  5. `OUT 01h,02h`.
  - Bit 1 portu 01h = 0 rozezní bzučák EKL-1.
- **EKL-1** drží znak do ACK. **Consul 262.3** na JPR-1V dává jen impuls 1 ms bez zachycení, proto se klávesnice
  čte (`kbd_scan`) i v dlouhých smyčkách, nejméně jednou za ~0,5 ms. Klávesy čekají v kruhové frontě 16 znaků.
- **Kódy:**

  | Klávesa | EKL-1 | Consul 262.3 |
  |---|---|---|
  | šipky ↑ ↓ ← → | 05 18 13 04 (WordStar) | C1 C2 C4 C3 |
  | Home / End | 1E / 11 | 8D / – |
  | PgUp / PgDn | 12 / 03 (= Ctrl+C) | – |
  | Ins / Del | 16 / 0B | – / 7F |
  | F1 / F2 / F3 | – | 80 / 82 / 84 |
  | F4 / F6 / F7 | – | D0 / D1 / D2 |
  | Esc, BS, Tab, Enter | 1B, 08, 09, 0D | 1B, 08, 09, 0D |
  | Ctrl+písmeno, Ctrl+] | 01–1A, 1D | 01–1A, 1D |
  | čeština | KOI-8čs XOR 20h (C0–FF) | – |

- **Klávesa menu SAPI-Termu: Ctrl+] (1Dh).**

## DPI-1L (Repository API, báze B0h)

- OUT B0h příkaz, IN B0h stav (4 bajty, pak 00h), OUT B1h parametr, IN B1h výstup. Ukazatel stavu se vrací na
  bajt 0 každým zápisem na B0h a každým přístupem na B1h.
- **Stav:**
  - bajt 0: 01 PARAMRQ, 02 DOUTRQ, 40 IN_PROGRESS, 80 ERROR;
  - bajt 1: poslední příkaz;
  - bajt 2: chyba, nebo volné místo na parametry, nebo zbývající výstup;
  - bajt 3: výsledek FatFs.
- **Detekce:** REVD 06h → stav `02 06 04 00`, výstup `major minor 'D' deska` (deska bit 0 = DPI-1L). Firmware
  0.5.3 a SAPIemu 0.7.0-beta dávají `00 05 44 01`.
- **TCP a DNS** (jedno spojení, IPv4, bez TLS a bez telnetu):

  | Příkaz | Parametry | Výstup |
  |---|---|---|
  | 80 TCPSTATUS | – | připojeno, stav (0 nic, 1 připojuje, 2 připojeno, 3 selhalo, 4 zavřela protistrana), WORD bajtů k přečtení, IP, port |
  | 81 TCPIP | 4 B | – |
  | 82 TCPPORT | WORD | – |
  | 83 TCPOPEN | – | běží na pozadí, limit 10 s |
  | 84 TCPCLOSE | – | přijaté se dá dočíst |
  | 85 TCPSEND | WORD délka, 1–252 B | chyba 5 = poslat znovu; bez spojení se tiše zahodí |
  | 86 TCPRECV | WORD max | WORD n, n ≤ 253 B |
  | 88 DNSREQ | jméno (řetězec) | běží na pozadí, limit 5 s |
  | 89 DNSRES | – | stav (0, 1 hledá, 2 nalezeno, 3 neznámé, 4 chyba), IP |

  - Fronta příjmu na kartě má 16 KB s řízením okna TCP.
  - RESET 00h spojení zavře. /RES spojení nezavře.
- **Čekání na skutečné kartě:** příkaz TCP vyřizuje jádro 0. Další přístup na B0h/B1h drží Z80 ve WAIT, dokud
  ho jádro nevyřídí: obvykle do 7–8 ms, při zátěži 61–220 ms. Emulátor odpoví hned.
- **Vzor kódu:** `..\SAPI-BomberNet\sapi\uc_sapi.c`, `..\BomberNet\c\common\netdev_card.c`.

## Návrat do CP/M (`quit` v `src/sapiterm.asm`)

1. TCPCLOSE (je-li DPI-1L);
2. MPH-1V: IEN = 0, IACK = C0h;
3. CGA-1V: obě stránky smazat, paleta černá, CONFIG = potvrzení VBI, stránka A, bez IRQ;
4. `OUT 63h,0`, klávesnice ACK 0;
5. AND-1V smazat, BDOS konzole `1D 1F`;
6. obnovit IFF (EI, bylo-li při startu povolené), `JP 0` (warm boot).
