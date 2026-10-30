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

## 2026-10-30: fáze 2, výstup terminálu

- **Vlastní font 4×8** (`fonts/sapiterm4x8.txt`, mřížka upravitelná v editoru, `tools/fontgen.py`). Cizí fonty ne
  (MZ CGROM je chráněný, licence jiných nejisté).
  - Verzálky a číslice mají řádky 0–5. Malá písmena mají střední výšku v řádcích 2–5 a dotahy v řádcích 6–7.
    Sloupec 3 je mezera mezi písmeny.
  - Rámečky: jednoduchá čára ve sloupci 1 a řádku 3, dvojitá ve sloupcích 0 a 2 a řádcích 2 a 4. U dvojité svislé
    čáry nejde vidět rameno doleva (╢ vypadá jako ║), na šířku 4 body se nevejde.
  - **Velká písmena s diakritikou mají výšku malých** (tvar verzálky v řádcích 2–5) a stejné dvouřádkové
    znaménko jako malá písmena. Znaménko v jediném řádku nad plnou verzálkou splývalo s písmenem a nebylo vidět.
    Plná verzálka, mezera a znaménko se do 8 řádků nevejdou.
- **Dvě sady glyfů:** CP437 (256) a KOI-8čs2 C0–FF (64 českých písmen, jak je má AND-1V). Buňka nese příznak
  sady (`EXT_KOI`). Texty programu jsou v KOI-8čs2 (`src/texts.txt`, `tools/texts.py`). AND-1V je zobrazí přímo,
  CGA-1V je vezme z druhé sady.
- **Stínová obrazovka 80×25** (znak, atribut, příznak; 6 KB). Rolování posouvá jen tabulku řádků. Slouží
  k překreslení po výměně karet, pro okno AND-1V a pro počty dvojic barev.
- **Atribut jako na PC:** `pozadí << 4 | popředí`, barvy v pořadí CGA (0 černá, 1 modrá … 15 bílá). ANSI SGR 30–37
  jde v jiném pořadí, převede ho parser.
- **Dvojice barev na CGA-1V:**
  - 16 slotů (pozadí, popředí) se přidělují za běhu a u každého se počítají buňky, které ho používají;
  - volný slot (počet 0) dostane nový atribut a jeho barvy jdou do palety v příštím VBI;
  - když volný není, vezme se nejbližší dvojice (vzdálenost barev popředí + 2× pozadí, `tools/tables.py`).
  - Zatím společně pro celou obrazovku. Dvojice po doménách (7×16) přijdou ve fázi 3, protože 16 dvojic
    na menu a ANSI art BBS nestačí.
- **Odložené zalomení řádku** jako VT100: znak v posledním sloupci nechá kurzor tam, zalomí až další znak. Řádky
  ANSI artu s přesně 80 znaky a CR LF pak nedělají prázdné řádky navíc.
- **Výměna karet (Tab):** stínová obrazovka zůstává. Při zmenšení z 25 na 20 řádků se posune nahoru, aby kurzor
  zůstal na posledním řádku, jako u terminálu na PC.
- **Kurzor:** na CGA-1V podtržení (XOR posledního řádku buňky), na AND-1V znak 7Fh. Bliká po 20 tikách (1/3 s).
  Tik 60 Hz dává MPH-1V, bez ní VBI CGA-1V, bez obou počítání průchodů smyčkou.
- **Testovací obrazovka se vejde do 64×20**, aby šla na obě karty.

## 2026-10-30: fáze 3, terminál ANSI

- **Chování podle ANSI-BBS, kde se liší od VT100:**
  - ESC [ 2 J smaže a dá kurzor domů (ANSI.SYS);
  - FF (0Ch) smaže obrazovku;
  - ostatní řídicí znaky kromě CR, LF, BS, TAB, BEL, ESC a 00h se zobrazí jako znaky CP437 (☺, ♥ …).
  - ESC [ M je mazání řádků, ne ANSI hudba.
- **Referenční model `tools/ansiref.py` je specifikace.** Parser a obrazovka v asm dělají přesně totéž a testy to
  porovnávají buňku po buňce a bod po bodu. Každá změna chování se dělá v obou.
- **SGR:**
  - tučné = jasné popředí;
  - 90–97 jasné popředí, 100–107 jasné pozadí;
  - blikání dá jasné pozadí jen v režimu iCE (podle SAUCE), jinak se zatím neukazuje;
  - inverze prohodí vypočtené barvy;
  - 38/48 (256 barev, RGB) se přeskočí i s parametry.
- **Parametry nad 255 se ořežou na 255**, nejvýš 8 parametrů. Sekvence s mezilehlým bajtem nebo s `=`, `<`, `>`
  se spolknou (rozšíření SyncTERM). Z `?` jen 7 a 25.
- **Dvojice barev po doménách:**
  - každá doména (4 řádky) má svých 16 slotů a vlastní počty buněk;
  - atribut dostane v každé doméně přednostně stejné číslo slotu (`att_pref`);
  - řádek, který rolováním přejde do jiné domény, si číslo slotu nechá, když je tam volné (`pair_get_hint`).
    Ve VRAM se přepíšou (nibble atributu) jen úseky, které ho změnit musí.
- **Skokové rolování:**
  - při LF na konci oblasti se spočítá, kolik dalších LF čeká ve vstupním bufferu, než přijde něco jiného než
    text, CR, BS, TAB, BEL a CSI…m;
  - odroluje se o všechny najednou (nejvýš výška oblasti − 1);
  - řádek, do kterého kurzor vstoupí, se znovu smaže, když se mezitím změnil atribut (barva pozadí nového řádku).
  - Mezi započtenými LF není žádné absolutní umístění kurzoru, výsledek je proto stejný jako při rolování po
    řádku. SCROLL.ANS je 2,7× rychlejší.
- **Vstupní buffer 2 KB** (`in_buf`, `in_ptr`, `in_end`). Prohlížeč do něj čte 16 záznamů najednou, ve fázi 4 do
  něj půjde příjem z TCP.
- **Paleta po dávkách:** nejvýš 16 dvojic na jedno VBI, zbytek v dalších. Zápis dvojice jedné domény trvá asi
  460 T, VBI 4 ms = 8000 T při 2 MHz. Emulátor (`palette_writes_visible`) ukázal zápisy mimo VBI, když se paleta
  psala celá najednou.

## 2026-10-30: fáze 4, síť a telnet

- **Spuštění podle argumentu:** existuje-li soubor (BDOS OPEN na FCB z CCP), zobrazí se, jinak je argument adresa
  BBS. Bez argumentu se program zeptá na adresu. CCP převede argument na velká písmena, DNS na tom nezáleží.
- **Telnet:**
  - na volbu se odpovídá jen při změně jejího stavu (zkrácený RFC 1143), tedy bez smyček;
  - klient udělá TTYPE (`ANSI`, Synchronet a další tak poznají ANSI-BBS), NAWS, BINARY, SGA, ostatní WONT;
  - server smí ECHO, SGA, BINARY, ostatní DONT;
  - Enter se posílá jako CR NUL (RFC 854), v binárním režimu jen CR.
- **NAWS podle karty terminálu:** 80×25 na CGA-1V, 64×20 na AND-1V. Po výměně karet v menu se pošle znovu.
- **Příjem:**
  - v jednom kole nejvýš 8 × TCPRECV po 253 B, dokud karta má data a v bufferu je místo;
  - telnet je filtruje rovnou do vstupního bufferu, takže skokové rolování vidí čistá data.
  - Bez dat se jednou za 0,5 s ověří TCPSTATUS (konec spojení).
  - Na skutečné kartě každý přístup po příkazu TCP čeká na jádro 0 (až asi 8 ms). Pro EKL-1 to nevadí.
- **Paleta se zapíše po každém zpracovaném bloku dat** (ve VBI), nejen v klidu. Jinak by nové barvy během dlouhého
  proudu dat zůstaly špatně až do konce.
- **Klávesy na BBS:**
  - šipky ESC[A–D, Home ESC[H, End ESC[K, PgUp ESC[V, Ins ESC[@ (jako SyncTERM), Del 7Fh;
  - PgDn z EKL-1 (03h) zůstává Ctrl+C, na BBS je důležitější;
  - česká písmena se zatím neposílají (fáze 5).
- **Menu Ctrl+]** je na stavové kartě, aby nerušilo obrazovku BBS. Bez druhé karty Ctrl+] rovnou odpojí.
- **iCE přes `ESC [ ? 33 h/l`** (CTerm, SyncTERM): BBS tak zapínají jasná pozadí pro ANSI art. Je i v modelu.
- **Testovací BBS `tools/testbbs.py`** (jen standardní knihovna) vyjedná telnet jako běžná BBS, posílá testovací
  soubory a vše, co klient pošle, zapisuje do JSON. Test pak ověří odpovědi i obraz.
- **`add_hl_a` a `add_de_a` zachovávají A.** Tři místa počítala s původním A jako s délkou a rozbila odesílání
  (za každým bajtem nuly).
- **Klávesnice Consul bez úpravy 7474:**
  - čtení klávesnice přidané do dlouhých smyček (plnění řádků po 80 B, `fill` po 256 B, přesuny dvojic po
    úsecích, zápis palety po dvojici);
  - stavová obrazovka se obnovuje až v klidu, ne po každé klávese.
  - Test na Consulu běží ve výchozím režimu emulátoru, věrný režim `strict` občas klávesu ztratí
    (`docs/stav.md`).
