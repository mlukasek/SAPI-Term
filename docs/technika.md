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
- **Dvojice barev po doménách** (doména = 4 textové řádky = 32 řádků obrazu, sedmá jen řádek 24):
  - `att_slot` (7 stránek): slot atributu v doméně (FFh nemá);
  - `slot_att[7][16]`, `slot_ref[7][16]`: atribut a počet buněk slotu;
  - `att_pref[256]`: preferované číslo slotu atributu (první, které dostal);
  - `pal_dirty[7]`: sloty, jejichž barvy čekají na zápis.
  - `pair_setdom` vybere doménu, pak `pair_get` (`pair_get_hint`), `pair_sub`, `pair_add`.
  - `pal_flush` počká na VBI a zapíše položky `d*32 + 2*slot` (pozadí) a `+1` (popředí), nejvýš 16 dvojic na jedno
    VBI.
- **Rolování:**
  - oblast `reg_top`..`reg_bot` o k řádků (`scr_region_upk`), dolů o jeden (`scr_region_down`);
  - kopie řádků po 640 B po kusech 80 B rozvinutým `LDI`, mezi kusy se čte klávesnice (83 ms za celou obrazovku
    při 4 MHz);
  - řádky, které přejdou do jiné domény, převezme `pair_move_row` po úsecích jednoho atributu a změněné sloty
    přepíše `cga_fix_cells`;
  - nové řádky vyplní `new_row` slotem atributu (body 0).
- **Vkládání a mazání znaků:** `cga_move_cells` posune bajty buněk ve všech 8 řádcích (1 bajt = 1 znak).
- **Kurzor:** XOR F0h na posledním řádku buňky.

## Stínová obrazovka (`src/screen.asm`)

- `scr_chr`, `scr_att`, `scr_ext` po 2000 B. Řádek obrazovky r je na `row_off[r]` (posun v polích), rolování
  posouvá jen tabulku `row_off`.
- `term_dev` = karta terminálu (1 CGA-1V, 2 AND-1V), `term_cols` × `term_rows` = 80×25 nebo 64×20. `stat_dev` =
  karta stavové obrazovky.
- `scr_putc` píše znak `cur_att`/`cur_ext` na kurzor s odloženým zalomením (`wrap_pend`, `?7l` vypne zalomení).
  `scr_set` zapíše buňku do stínu i na kartu. `scr_redraw` překreslí vše po výměně karty.
- `scr_lf` dole v oblasti roluje, se vstupem v bufferu skokově (`js_count`, `js_pending`, `js_att`).
  `scr_erase`, `scr_insert_chars`, `scr_delete_chars`, `scr_region_down` slouží parseru ANSI.

## Parser ANSI (`src/ansi.asm`) a vstup

- Stavy: normální, ESC, CSI (parametry `ans_par[8]`, `ans_priv`, `ans_inter`), přeskočit jeden bajt.
- Stav SGR: `sgr_fg`, `sgr_bg` (barvy ANSI), `sgr_bold`, `sgr_blink`, `sgr_rev`, `sgr_bghi`. Z něj `sgr_apply`
  spočítá `cur_att` (barvy CGA). Převod ANSI → CGA: 0 4 2 6 1 5 3 7.
- Odpovědi (CPR, DA) jsou v `ans_reply` a jdou přes `reply_hook` (zatím 0 = nikam).
- **Vstupní buffer:** `in_buf` (16 záznamů = 2 KB), `in_ptr`, `in_end`. Prohlížeč souborů ho plní záznamy přes
  BDOS (náhodné čtení podle čísla záznamu). `js_enable` povolí skokové rolování.
- **SAUCE:** posledních 256 B souboru (dva záznamy) se prohledá na `SAUCE00`. TFlags (posun 105) bit 0 = iCE.
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
- Čítač 0 běží od detekce volně (režim 2, dělitel 0 = 65536, hradlo G0, IEN = 28h) jako hodiny rychlosti linky.
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

## Síť a telnet (`src/dpi.asm`, `src/telnet.asm`, `src/online.asm`)

- **Repository API:**
  - `dpi_cmd`: příkaz a parametry přes `OTIR`, pak `dpi_status` (4 bajty stavu, NZ při ERROR, A = kód | 80h);
  - `dpi_output`: výstup přes `INIR`.
- **DNS a TCP:**
  - `net_dns`: DNSREQ a dotazování DNSRES jednou za tik, limit 10 s;
  - `net_open`: TCPIP, TCPPORT, TCPOPEN a TCPSTATUS jednou za tik, limit 12 s;
  - v obou Esc nebo Ctrl+] zastaví;
  - `net_recv` (TCPRECV), `net_send` (TCPSEND s bitem 15), `net_status`.
- **Telnet:**
  - `tn_filter`: stavy data, IAC, volba, SB, IAC v SB;
  - `tn_us` / `tn_them`: stav voleb 0–31;
  - TTYPE SEND → `IAC SB 24 0 "ANSI" IAC SE`, NAWS → `IAC SB 31 0 cols 0 rows IAC SE`.
- **Odesílání:**
  - `tx_buf` (128 B): `tx_data` zdvojí FFh a za CR dá NUL, `tx_raw` posílá beze změny;
  - `tx_flush` posílá přes TCPSEND, při chybě 5 to zkouší další tiky až 2 s.
- **Online smyčka (`online`):**
  1. klávesa → `key_send` (tabulky `keys_ekl`, `keys_consul`);
  2. `tx_flush`;
  3. `net_rx` (až 8 × 253 B přes telnet do `in_buf`) → `feed_input` (parser ANSI) → paleta;
  4. v klidu kurzor, tik a jednou za 30 tiků TCPSTATUS.
- **Režimy (`mode`):** 0 místní (testovací obrazovka, psací stroj), 1 soubor, 2 na lince. Podle nich vypadá stavová
  obrazovka.
- **Menu Ctrl+] (`ol_menu`):** O odpojit, K konec, Tab výměna karet (a NAWS), T typ klávesnice, Z znaková sada,
  R rychlost linky, S 80/40 sloupců, U do adresáře, L záznam relace, D stáhnout, H historie, Esc zpět. Co volba
  udělala, ukáže řádek 15 (`om_msg`), průběh stahování řádek 16.

## Nastavení a adresář (`src/config.asm`)

- **Disk:** `cfg_find_drive` hned po startu (dokud je CCP v paměti), `cfg_drive` 0 = A.
- **FCB** `cfg_fcb` (36 B) se jménem `SAPITERMCFG` a diskem `cfg_drive` + 1.
- **Načtení** (`cfg_load` po detekci karet):
  - až 20 záznamů sekvenčně (B_READSEQ) do `cfg_buf`, DMA mimo 0080h, takže argumenty v 0080h zůstanou;
  - řádky `KEYBOARD=`, `SCREEN=`, `BBS=` (klíče bez ohledu na velikost písmen), ostatní se přeskočí.
- **Položka adresáře** (`book`, 16 × 97 B): jméno 00h, adresa 00h, znaková sada (CS_*).
  - `book_find` hledá adresu `ui_line`;
  - `book_pick` dá do `ui_line` adresu podle čísla;
  - `book_add` přidá nebo opraví;
  - `book_delete` smaže a posune zbytek.
- **Uložení** (`cfg_save`, s MAP = 0):
  1. text do `cfg_buf`, za ním 1Ah až do konce záznamu;
  2. B_DELETE, B_MAKE, B_WRITESEQ po 128 B, B_CLOSE.
  - A = 0 uloženo, jinak plný adresář nebo disk. Hlášení dá `cfg_save_msg` do `ui_msg` a `om_msg`.

## Rychlost linky a blikání

- **Rychlost:** `speed` (index do `speed_counts`, počet taktů 55 930 Hz na bajt; 0 = bez omezení).
  - `pace_reset` (začátek dat), `pace_due` (přičte uplynulý čas k `pace_acc`, A = 1, když je bajt na řadě),
    `pace_feed` (pošle splatné bajty, nejvýš 64);
  - `pace_elapsed`: čítač 0 MPH-1V (`t0_read`, počítá dolů, rozdíl modulo 65536), bez MPH-1V tik = 932.
  - Online smyčka (`ol_slow`) a prohlížeč (`vf_paced`, konec umění u 1Ah najde `vf_cut_eof`).
- **Blikání:** `blink_on`, `blink_ticks`. `pal_slot` u atributu s bitem 7 bez iCE vezme pozadí `& 7` a ve
  skryté fázi popředí = pozadí.

## 40 sloupců na CGA-1V

- `cols40` (nastavení) a `cga_wide` (teď platí). `term_size` je nastaví podle karty a režimu, `term_resize` pak
  posune kurzor a překreslí.
- `cga_cell_addr` násobí sloupec 2, `cga_draw_wide` kreslí 2 bajty na řádek glyfu (`wide_l`, `wide_r` podle
  bajtu glyfu). `cga_clip` ořeže rozsah buněk na sloupce 0–39 a přepočte ho na bajty (vyplnění, oprava slotů),
  `cga_move_cells` totéž pro posun.

## Záznam relace a stahování (`src/xfer.asm`)

- **Záznam:** `log_on`, `log_fcb` (`LOGnn.ANS`, `log_num`), `log_buf` (záznam 128 B), `log_ptr`.
  - `net_rx` po každém příjmu volá `log_data`, plný záznam zapíše `log_record`.
  - `log_stop` doplní 1Ah a soubor zavře. Volá se při menu L, konci spojení a `quit`.
- **Stahování** (`xm_run`):
  - bajty z `net_rx` skládá `xm_rx_byte` do `xm_pkt` (1030 B): číslo bloku, doplněk, data, CRC nebo součet;
  - `xm_packet` blok ověří (`xm_check`, CRC-16/XMODEM bit po bitu, 1K asi 64 ms), pak hlavička YMODEMu
    (`xm_create`, `parse_dec32` do `xm_left`) nebo data (`xw_record` po 128 B);
  - čekání `XM_WAIT` (3 s) na blok, `XM_TRIES` (10) pokusů;
  - výsledek v `xm_result`, zpráva pro menu v `msg_buf`.
- **Telnet:** `tn_cr` = poslední datový bajt byl CR. NUL za ním se bez binárního režimu serveru zahodí.

## Historie (`src/history.asm`)

- Kruh `hist_buf` (= `STACK_TOP`, A298h) až po D5FFh, `HIST_LINES` = 77 řádků po `HIST_REC` = 170 B.
  - `hist_head` je další zapisovaný řádek, `hist_count` počet řádků.
  - Záznam řádku: 80 znaků, 80 atributů, 10 B bitů EXT_KOI (buňka 0 v bitu 0).
- `scr_region_upk` při horní hranici 0 volá `hist_push_top` (řádky 0 až `rg_k` − 1). Během prohlížení
  (`hv_on`) ne.
- `hist_view`:
  1. uloží kurzor, atribut a oblast, vloží obrazovku do historie;
  2. `hv_top` je první zobrazený řádek historie, `hv_row` kreslí řádek přes `scr_set`;
  3. o řádek se roluje přes `scr_region_down`/`scr_region_up`;
  4. při návratu se obrazovka nakreslí z historie a řádky se z ní zase vyjmou.

## PETSCII (`src/pet.asm`)

- `cs_type` = CS_PETSCII (7). `pet_enter` / `pet_leave` přepnou `term_putc` (skok v RAM: `jp ansi_putc` nebo
  `jp pet_putc`), `ice_mode` = 1 (bit 7 atributu je barva pozadí 8–15), `rgb_tab` (`pet_palette`), velikost
  (`term_size`) a smažou obrazovku.
- Buňka: znak = kód obrazovky C64 | `pet_lower` (80h), `cur_ext` = EXT_8X8 (02h), `cur_att` = barva textu
  (`pet_fg`), při reverzu ×16 (`pet_att`).
- PETSCII → kód obrazovky: 20–3F stejně, 40–5F −40h, 60–7F −20h, A0–BF −40h, C0–FE −80h, FF → 5Eh.
- Glyf: `glyph_addr` s EXT_8X8 bere `font_pet` (stránkově zarovnané, 256 × 8 B). `cga_draw_wide` pozná glyf
  `font_pet` podle adresy a kreslí ho bez zdvojení (`cga_draw_8`: levé 4 body do prvního bajtu, pravé do druhého).
  AND-1V: `and_map_pet`.
- Klávesy: `pet_key` (tabulka `pet_keys`, písmena podle velikosti).

## ATASCII (`src/ata.asm`)

- `cs_type` = CS_ATASCII (8), `ata_enter` (odchod `pet_leave`). Paleta `ata_rgb` (0 = modrá, 1 = světlý text,
  dál barvy ANSI pro texty programu).
- Buňka: znak = kód 00–7Fh, `cur_ext` = EXT_ATA (04h), atribut 01h, inverzně 10h. `ata_esc` = další bajt doslova.
- Glyf `font_ata` (128 × 8 B, za `font_pet`, kreslí se také bez zdvojení), AND-1V `and_map_ata`.
- Klávesy `ata_key` (tabulka `ata_keys`).

## Znakové sady (`src/charset.asm`)

- `cs_type` (CS_CP437 … CS_KOI8) se nastaví v `online` z adresáře (podle adresy), jinak CP437. Menu Z ho přepíná,
  po odpojení je zase 0.
- **Příjem:** `ansi_putc` pošle bajty 80h–FFh v normálním stavu do `cs_byte`.
  - CP437 je beze změny;
  - jednobajtové sady přes `cs_in_<sada>` (128 kódů) a `cs_in_<sada>_koi` (16 B bitů, 1 = písmeno KOI-8čs2,
    tedy EXT_KOI);
  - UTF-8 skládá znak v `utf_need` a `utf_cp`, `uni_put` ho najde v `u_lat_code`/`u_lat_koi` (00A0–017F),
    `u_box` (2500–25FF) nebo v seznamu `u_list`.
- **Klávesy:** `key_send` pošle písmeno EKL-1 (≥ C0h, XOR 20h = KOI-8čs2) do `cs_key`. Tabulka `koi_out` má
  7 × 64 B, pro UTF-8 je `koi_uni` (Unicode, posílá se 2 bajty).
- **Model** je v `tools/tables.py` (`glyph`, `set_glyph`, `utf8_glyphs`, `encode_key`), z něj jsou tabulky i
  očekávané výsledky testu.

## Návrat do CP/M (`quit` v `src/sapiterm.asm`)

1. TCPCLOSE (je-li DPI-1L);
2. MPH-1V: IEN = 0, IACK = C0h;
3. CGA-1V: obě stránky smazat, paleta černá, CONFIG = potvrzení VBI, stránka A, bez IRQ;
4. `OUT 63h,0`, klávesnice ACK 0;
5. AND-1V smazat, BDOS konzole `1D 1F`;
6. obnovit IFF (EI, bylo-li při startu povolené), `JP 0` (warm boot).
