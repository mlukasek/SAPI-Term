# SAPI-Term – rozhodnutí

Nové rozhodnutí dopsat s datem a důvodem.

## 2026-10-30: zadání a plán (autor)

- **Program pro CP/M** `SAPITERM.COM` pro sestavu V (JPR-1V, RAM-1V, AND-1V, CGA-1V, ZRD-1V, DPI-1L, volitelně
  MPH-1V), návrat do CP/M. Telnet klient pro internetové BBS vhodné pro 8bitové počítače, včetně ANSI artu
  a animací.
- **Jazyk: pasmo, čistý asm Z80.** Důvod: úplná kontrola nad MAP, DI, zásobníkem a časováním (čtení klávesnice,
  kreslení a rolování CGA-1V), malý kód pod C000h. Stejně jako Bomberman, Flappy a PoP.
- **CGA-1V:**
  - hlavní režim 80×25 s fontem 4×8 v režimu EGA (barva po znacích);
  - přepínatelný režim 40×25 s fontem 8×8, pro BBS se 40 sloupci a pro PETSCII, ATASCII a Viewdata.
  - Důvod: 80 sloupců je standard BBS a ANSI artu. Bajt EGA = 4 body + atribut sedí přesně na znak 4×8.
- **AND-1V (64×20, jednobarevný):** terminál ohlásí BBS velikost 64×20 (telnet NAWS a odpověď na CPR). Když
  BBS posílá pevné 80×25, AND-1V ukazuje okno 64×20, které jde za kurzorem a dá se posouvat.
- **Obě karty v sestavě:** terminál běží na zvolené kartě, druhá ukazuje stav spojení, nápovědu kláves a ladicí
  výpis telnetu.
- **Emulace:**
  - základ ANSI-BBS (CP437, barvy) a VT100;
  - později UTF-8 → CP437 a čeština (na SAPI KOI-8čs, na BBS UTF-8, Latin-2, CP852, Kamenický, podle tabulek);
  - pak PETSCII, ATASCII a Viewdata/teletext.
  - Českou BBS dostupnou přes telnet zatím neznáme.
- **Doplňky:** prohlížeč `.ANS`, emulace rychlosti modemu (pro animace), stahování souborů (XMODEM/YMODEM),
  historie a záznam relace.
- **Klávesnice:**
  - na autorově SAPI je EKL-1: drží znak do ACK, šipky posílá ve WordStar kódech, češtinu v KOI-8čs XOR 20h;
  - podporovat i Consul 262.3 (sestavy V v emulátoru): šipky C1–C4, impuls STROBE 1 ms bez zachycení.
  - Firmware DPI-1L kvůli čekání (WAIT) není nutné měnit: EKL-1 při čekání znak neztratí.
- **MPH-1V** se použije, když je v sestavě (časovač 82C54, zvonek na YM3812).

## 2026-10-30: technická rozhodnutí z fáze 0 a 1

- **Celý program běží s DI.** VBI CGA-1V i tik MPH-1V se zjišťují čtením stavu. Důvod: přerušení přijaté s PC
  v okně videokarty zamrazí JPR-1V natrvalo. CP/M ani ECMON EI nepoužívají. Při návratu se obnoví IFF2
  z doby startu.
- **Kód, data i zásobník pod C000h**, buffery za programem (mimo `.COM`), hlídá `tools/check_build.py`.
- **Klávesa menu Ctrl+] (1Dh)** na obou klávesnicích. EKL-1 nemá funkční klávesy (F1–F12 dávají 0) a Ctrl+]
  dává 1Dh (`TR_CTRL` ve firmwaru `KEYB_REPAIR.a51`: `']' AND 1Fh`).
- **Klávesnice přímo z portů** (protokol MikroMonu), ne přes BIOS CONIN. CONIN spolkne Ctrl+L a kvůli chybě CINIT
  je v 8bitovém režimu.
- **Detekce karet** podle chování, které prázdná sběrnice nenapodobí (čte poslední bajt na sběrnici):
  - AND-1V a CGA-1V: vzorek 55h/AAh v nezobrazené RAM karty;
  - CGA-1V navíc: požadavek VBI po potvrzení zmizí a do 52 ms se vrátí;
  - MPH-1V: čítač 2 82C54 čte dvakrát různé hodnoty do 932;
  - DPI-1L: REVD se stavem `02 06 04` a `'D'` ve výstupu, pak RESET 00h (zavře spojení po dřívějším programu).
- **Při návratu je CGA-1V černá** (obě stránky smazané, paleta černá, stránka A, bez IRQ), aby po SAPI-Termu
  neukazovala zbytek obrazu.
- **Texty UI zatím ASCII bez diakritiky.** Diakritika přijde ve fázi 2 s vlastními fonty a převodem znaků (KOI-8čs
  pro AND-1V).
- **Testovací sestavy mají DSM-1V**, i když ji terminál nepoužívá. Bez ní ECMON přepne konzoli na sériovou linku
  a stojí v čekání na port 11h (F326: `IN A,(11h)`, `AND 40h`). Autorovo SAPI V ji má.
- **Testy jen v SAPIemu-release, MCP zapínám parametrem** (`sapiemu-cli --mcp --mcp-port 8595`, GUI
  `--mcp-port 8596`), bez změny nastavení release emulátoru. Port 8580 patří vývojovému SAPIemu.
