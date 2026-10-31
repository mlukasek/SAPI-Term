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
  - MPH-1V: čítač 2 82C54 čte dvakrát různé hodnoty do 932, první až asi 0,1 ms po zápisu dělitele (82C54 ho
    nahraje až dalším pulzem CLK, do té doby je obsah čítače nedefinovaný);
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

## 2026-10-30: fáze 5, adresář, nastavení a znakové sady

- **`SAPITERM.CFG` leží vedle `SAPITERM.COM`** (přání autora).
  - **Disk programu:** CP/M 2.2 programu neřekne, odkud se nahrál. Příkazová řádka je ale po startu ještě v CCP
    (CCP = vstup BDOS − 806h, ověřené dvěma skoky na začátku CCP; +7 délka, +8 text, CCP ji převede na velká
    písmena). Začíná-li `X:`, je to disk X, jinak aktuální disk (0004h).
  - Ověřeno v emulátoru, CCP na CE00 začíná `C3 04 CF C3 00 CF`.
- **Formát:** text s řádky `KLÍČ=hodnota` a komentáři `;`, aby šel upravit editorem na SAPI i na PC (CR LF,
  `.gitattributes` drží CRLF i v repu). Program soubor při uložení napíše celý znovu se svou hlavičkou. Vlastní
  komentáře a neznámé řádky se ztratí, je to zapsané v hlavičce.
- **Ukládá se hned při změně** (T, Tab, U, `-číslo`). Zvláštní „uložit nastavení“ není potřeba a nic se neztratí
  při Ctrl+] nebo pádu spojení. Zápis na RAM disk trvá chvilku.
- **Adresář:**
  - nejvýš 16 BBS, jméno do 31 znaků, adresa do 63;
  - na úvodní obrazovce ve dvou sloupcích po osmi, vejde se i na AND-1V (64×20);
  - číslo na výzvě nebo `SAPITERM číslo` připojí, `-číslo` smaže;
  - U v menu na BBS uloží právě připojenou BBS se jménem = adresa (přejmenovat jde v souboru); je-li tam už,
    uloží jen její znakovou sadu.
- **Typ klávesnice a karta terminálu** (`KEYBOARD`, `SCREEN`) jsou v souboru. Karta platí, jen když jsou obě.
  Tab na výzvě a v menu ji přepne a uloží.
- **Znaková sada se volí u každé BBS** (`BBS=jméno,adresa,sada`, menu Z):
  - sady: CP437 (výchozí, ANSI art), UTF-8, Latin-2 (ISO 8859-2), CP1250, CP852, Kamenický, KOI-8čs2;
  - Latin-2 a CP1250 jsou zvlášť, liší se na místech š, ť, ž, Š, Ť, Ž a Ľ, ľ;
  - **česká a slovenská písmena jsou vždy glyfy KOI-8čs2** (jako texty programu), i když je CP437 má (á é í ó ú
    ä ö ü ô). V jedné větě tak nejsou dva styly písmen;
  - co v písmu není: nejbližší znak CP437 (tučné a zaoblené rámečky jako jednoduché, ▁▂▃ jako ▄ nebo _, ●
    jako •), jinak písmeno bez diakritiky, jinak `?`;
  - UTF-8 do FFFFh: 00A0–017F a 2500–25FF přes tabulky, ostatní ze seznamu. 4bajtové znaky (emoji) jsou `?`,
    nulová šířka a kombinující diakritika se nezobrazí, `…` jsou tři tečky.
  - Tabulky dělá `tools/tables.py` z kodeků Pythonu, Kamenický a KOI-8čs2 jsou ve skriptu.
- **Psaní česky:** EKL-1 posílá KOI-8čs XOR 20h, program písmeno převede do sady BBS. V CP437 jdou á é í ó ú ä ö
  ü ô ve kódech CP437, ostatní bez diakritiky. Consul česká písmena nemá.
- **Psací stroj** bere C1–C4 jako šipky jen s typem Consul, s EKL-1 jsou to Á Č Ď.
- **Výchozí adresář:** BBS z PC i z emulátoru ukázaly úvodní obrazovku, bez přihlášení.
  - Vynechané: Black Flag („BLOCKED“), Starbase21 (odmítá spojení), Absinthe (jen vyjednání telnetu),
    csbbs.dyndns.org (Mystic jen anglicky).
  - Aleco Experience (Praha) 2026-10-30 odmítala spojení, viz `docs/stav.md`.
  - Česká BBS Liane (TU Liberec, `bbs.vslib.cz`) je v adresáři, sadu bez přihlášení nevíme.
- **DNS čeká 10 s** (bylo 6 s). V emulátoru běží tiky rychleji než skutečný čas a pomalejší odpověď DNS (neznámé
  jméno, první dotaz) občas skončila „Vypršel čas“.
- **Plný kruh kláves (16) klávesu nepotvrdí.** EKL-1 ji drží, dokud není místo, a nic se neztratí. Dřív se klávesa
  přečetla a zahodila: test psal adresu, zatímco se kreslila úvodní obrazovka s adresářem, a ztratil se Enter.

## 2026-10-30: fáze 6, ANSI art a animace

Autor byl pryč a požádal, abych rozhodoval sám a pokračoval podle plánu. Tato rozhodnutí jsou tedy moje.

- **Rychlost linky** (menu R, `SPEED=` v `SAPITERM.CFG`, jedna pro všechno):
  - 38400 až 300 Bd (10 bitů na bajt), MAX = bez omezení;
  - platí na BBS i v prohlížeči `.ANS`, aby šly přehrát ANSI animace z disku.
  - **Čas měří volně běžící čítač 0 na MPH-1V** (55 930 Hz, dělitel 65536, oběh 1,17 s), ne tiky. Tik je jen
    příznak a když smyčka déle čeká (paleta ve VBI, rolování), tik se ztratí a linka zpomalí. Bajty, které terminál
    nestihl, dožene jako po modemu (nejvýš 64 najednou, aby se dál četla klávesnice a síť). Po vyprázdnění bufferu
    se čas nepřenáší (modem pak také neposílá rychleji). Bez MPH-1V se počítá po ticích.
  - Při omezené rychlosti je skokové rolování vypnuté. Modem ukazuje řádek po řádku a o to v animacích jde.
- **Blikání jako na PC:** bit 7 atributu je bez iCE blikání (pozadí 0–7), s iCE jasné pozadí.
  - Jasná pozadí 100–107 bez iCE proto také blikají. Osmibitový atribut nemá místo pro obojí. CTerm se chová
    stejně.
  - Blikání dělá paleta: dvojice s bitem 7 se každých 20 tiků přepíše na popředí = pozadí a zpět (`blink_tick`,
    `blink_mark`). Přepnutí `?33h/l` přepíše paletu těchto dvojic hned.
- **Do jednoho VBI 14 dvojic barev**, ne 16. Test blikání v `pal_slot` přidal čas a 16 dvojic se do VBI (125
  řádků, 3,97 ms) už nevešlo (5 zápisů mimo VBI u SCROLL.ANS).
- **40×25 je písmo 4×8 se zdvojenými body:**
  - písmo 8×8 se tak nekreslí ručně (320 znaků), zůstává naše a ve stylu 40sloupcových počítačů (tahy 2 body);
  - zdvojuje se při kreslení přes tabulky `wide_l` a `wide_r`;
  - vlastní jemnější 8×8 (a PETSCII, ATASCII) může přijít ve fázi 8.
- **40 sloupců jen na BBS a jen na CGA-1V** (menu S, `COLUMNS=40`).
  - Úvodní obrazovka (nápověda, adresář), prohlížeč i stavová obrazovka potřebují 64 nebo 80 sloupců.
  - Stín zůstává 80 sloupců, rutiny CGA ořežou sloupce od 40 výš a buňka je 2 bajty.
- **Rychlejší kreslení podle profilu**, ne odhadem (`tools/emu/profile.py`, PC každou emulovanou milisekundu).
  Zrychlení od 12 do 33 %, obraz zůstal přesně podle modelu.

## 2026-10-30: fáze 7, záznam relace, historie, stahování

Autor byl stále pryč, rozhodoval jsem sám.

- **Záznam relace** se zapisuje jako `.ANS`: data po telnetu, beze změny. Prohlížeč ho přehraje (iCE přes `?33h`,
  rychlost linky), záznam je tedy hned k užitku. Jméno `LOGnn.ANS` (první volné 00–99) vedle programu. Během
  stahování se nezapisuje.
- **Stahování jen na disk programu**, ne na SD kartu DPI-1L: jedna cesta přes BDOS. Soubory pro CP/M patří na
  disk CP/M. SD karta může přijít později.
- **Stahuje se jen na pokyn** (menu D), bez automatického rozpoznání: XMODEM ani YMODEM začátek přenosu
  neohlašuje (ZMODEM ano, ten zatím ne).
- **XMODEM i YMODEM jedním přijímačem:** blok 0 znamená YMODEM (jméno, velikost), blok 1 hned na začátku XMODEM
  (jméno `XMODEM.BIN`). 'C' žádá CRC, po třech marných pokusech NAK a součet. Velikost z YMODEMu ořízne poslední
  záznam (zbytek 1Ah, jak to CP/M u textu čeká). Jméno, které na disku je, dostane číslici místo přepsání.
- **Historie v paměti nad zásobníkem až po D5FF:** C000–D5FF je při MAP = 0 obyčejná RAM, TPA pod CCP. Do ní se
  sahá jen s MAP = 0. Řádek 170 B (znaky, atributy, bity KOI), 77 řádků. Ukládá se při rolování oblasti od řádku 0
  (i skokovém), ne při mazání obrazovky (jako u terminálů na PC).
- **Prohlížení historie kreslí přes `scr_set`**, jako by psala BBS: počty dvojic barev zůstanou správné. Živá
  obrazovka se na tu dobu uloží na konec historie a pak se z ní vrátí. Když je historie plná, přijde se tak o
  nejstarších 25 řádků. Síť mezitím čeká (TCP okno karty).

## 2026-10-30: fáze 8, PETSCII

Autor byl stále pryč, rozhodoval jsem sám.

- **PETSCII je další „sada“ v menu Z a v adresáři**, ne zvláštní nabídka. Přepne ale celý terminál:
  - parser (`term_putc` → `pet_putc`);
  - 40 sloupců, barvy C64, klávesy jako z C64;
  - bez skokového rolování (PETSCII nemá LF).
  - Zpět na jinou sadu se obrazovka smaže a terminál je zase ANSI. Uloží se s BBS jako `,PETSCII`.
- **Stín drží kód obrazovky C64** (0–127) a v bitu 7 sadu malých písmen, s příznakem EXT_8X8.
  - Přepnutí sad (0Eh/8Eh) přepíše bit 7 všech buněk PETSCII a překreslí obrazovku, jako to dělá C64.
  - Reverz prohodí barvy (pozadí je černé). Jinak by písmo potřebovalo i obrácené glyfy, tedy 2 KB navíc.
- **Barvy C64 jen na CGA-1V** (`rgb_tab`). Když je terminál na AND-1V, stavová karta na CGA-1V má dál barvy ANSI.
  Hodnoty palety jsou běžně uváděné barvy VIC-II převedené na 6 bitů.
- **Na AND-1V 40×20:** PETSCII potřebuje 40 sloupců, jinak by se kresby zalamovaly jinde.
- **Písmo 8×8 vlastní, generované skriptem:**
  - písmena, číslice a znaky z písma 4×8 SAPI-Termu se zdvojenými body (stejný vzhled jako zbytek);
  - grafika podle významu znaků (Unicode Symbols for Legacy Computing, článek PETSCII na Wikipedii): čáry a
    bloky po osminách, rámečky dva body silné, kvadranty, stínování;
  - několik symbolů (♠ ♥ ♦ ♣ ● ○ π ✓, oblouky, úhlopříčky) nakreslených ručně;
  - ROM Commodore se nepoužila.
- **Přijímací stránka testu** je vlastní (`pet_bytes` v `tools/testbbs.py`). Model `tools/petref.py` popisuje,
  co terminál má udělat. Rozdíl proti C64: DEL a INST posouvají i skrytou část řádku stínu (sloupce 40–79). Ta je
  prázdná a test bere atributy prázdných buněk volně.

## 2026-10-30: fáze 8, ATASCII

- **ATASCII stejně jako PETSCII:** další sada v menu Z a v adresáři, vlastní parser (`ata_putc`), písmo
  (`font_ata`, příznak EXT_ATA), klávesy a barvy. Odchod a paletu sdílí s PETSCII (`term8_enter`,
  `term8_leave`, `pet_palette`).
- **40×24**, jak má Atari v GR.0. Okraj vlevo je 0, ne 2 jako po startu Atari OS: terminálové programy pro BBS
  (a kresby z nich) počítají se 40 sloupci.
- **Inverze po znacích** (80h–FFh) prohozenými barvami, ne obrácenými glyfy (o 1 KB méně). Barvy jsou modrá
  Atari a světlý text, hodnoty odhadnuté podle běžného vzhledu GR.0.
- **Kurzorové kódy obtáčejí po obrazovce** (nahoře dolů, vlevo doprava v řádku), jako editor Atari. Konec řádku
  (9Bh) a tisk na konci řádku rolují.
- **Telnet zůstává** i pro BBS Atari. Některé BBS běží „raw“ (bez telnetu): bajt FFh (vložit znak) by se pak bral
  jako IAC. U vyzkoušených BBS to nevadilo. Volba raw pro BBS může přijít později.
- **Historie si u řádku pamatuje písmo** (bajt příznaků EXT_8X8 a EXT_ATA, záznam 171 B). Jinak by se řádky
  PETSCII a ATASCII v historii ukázaly písmem CP437.
- **Historie ve stránce B CGA-1V:** terminál kreslí jen do stránky A, stránka B (16 000 B) byla volná. Kruh je tam
  93 řádků a nezmenšuje se, když program roste. Přístup přes MAP_CGA a CONFIG D1 (procesor na stránce B), potom
  zpět A. Záznam se skládá a čte v bufferu `hv_line` v RAM. Bez CGA-1V zůstává kruh v RAM za zásobníkem.

## 2026-10-30: fáze 8, Viewdata

- **Kódy zvlášť, obrazovka ze stínu:** sériové atributy teletextu platí od své buňky do konce řádku. Přijaté kódy
  jsou proto ve `vdt_raw` (960 B) a řádek se z nich dekóduje zleva do stínu přes `scr_set` (počty dvojic barev
  zůstanou správné).
  - Celý řádek se přepočte, když atribut přijde nebo zmizí, nebo když má řádek či řádek nad ním dvojitou výšku.
  - Jinak se přepočte jen jedna buňka (stav od začátku řádku).
- **Glyf se dělá při kreslení** (`ga_vdt` do `vdt_glyph`): písmena z písma ATASCII a sedmi britských znaků
  (`vdt_extra`), mozaiky jako bloky 2×3 (řádky 3/2/3, oddělené bez posledního sloupce a řádku bloku), polovina
  glyfu dvakrát pro dvojitou výšku. Tabulka 128 mozaik by stála 1 KB.
- **Atribut „set-at“ a „set-after“** podle teletextu úrovně 1: hned platí ustálené písmo, normální výška, skrytí,
  souvislé a oddělené mozaiky, černé a nové pozadí; od další buňky barvy, blikání a dvojitá výška. Bez „hold
  mosaics“.
- **Enter posílá `_`** (5Fh, klávesa # Prestelu, kterou Telstar čeká na potvrzení volby).
- **Telstar není ve výchozím adresáři:** byl by šestnáctou položkou a uživateli by nezbylo místo. Je v dokumentaci.
  (2026-10-31: šestnáctou položkou je nakonec telehack.com, přidal ho autor.)

## 2026-10-30: raw TCP

- **Volba pro každou BBS:** bit 7 bajtu sady v adresáři (`,RAW` v souboru), v menu N. Některé BBS pro Atari a C64
  běží bez telnetu. FFh (π v PETSCII, vložení znaku v ATASCII) by se jinak bralo jako IAC a další bajt jako
  příkaz telnetu. Telnet je výchozí, protože ho používá většina BBS.
- **PETSCII začíná v sadě malých písmen** (jako terminálové programy C64, např. CCGMS), ne ve velkých jako C64 po
  zapnutí. Retro Campus si sadu přepíná sám, výsledek je stejný. (Důvod „The Basement posílá malá písmena
  PETSCII“ byl omyl, viz 2026-10-31.)
- **The Basement je jednolinková:** po opakovaných spojeních hlásí obsazeno („Please try again in a few
  minutes“). V adresáři zůstává, zkoušet ji jen občas.

## 2026-10-30: písma 8×8 z původních strojů

- **Písma podle strojů, z jejich ROM** (rozhodnutí autora, nahrazuje „40×25 je písmo 4×8 se zdvojenými body“
  a „Písmo 8×8 vlastní“):
  - PETSCII: písmo C64 (znaková ROM 901225-01, obě sady);
  - ATASCII: písmo Atari 400/800 (OS rev. B, v 800XL stejné), z něj i písmena Viewdata;
  - ANSI ve 40 sloupcích: písmo Sharp MZ (oblíbené autorem), nakonec z ROM MZ-800 (níže).
- **Jsou v programu i v repu** (`fonts/c64.txt`, `atari.txt`, `mz800.txt`, `mz800cs.txt`). Riziko autorských práv
  (Commodore, Atari, Sharp, autor českého CP/M) nese autor. ROM a CP/M samotné v repu nejsou (`work/roms`,
  `docs/vyvoj.md`). Atari dalo autorům PC Xformer svolení ROM šířit, u ostatních svolení nemáme.
- **Vlastní písma 8×8 končí.** Generátory po nich jsou v historii gitu (do commitu bcdd256).
- **MZ-800, ne MZ-700:** ROM `CGROM.ROM` od autora. Evropská ROM MZ-700 (MAME) se liší jen v A C D G 4 5 9
  a čárce, MZ-800 je má užší a kulatější. Autor vybral MZ-800.
- **Znaky ASCII 20h–7Fh** (96 glyfů):
  - ASCII 20h–5Dh podle převodní tabulky monitoru 1Z-013A, malá písmena jsou kódy obrazovky 81h–9Ah;
  - ``^ _ ` { | } ~`` jako je převádí české CP/M pro MZ-800 (BEh, BFh, A4h, BCh, 80h, 40h, A5h; `_` je
    podtržení na úrovni řádku písmen, ne čára přes celou buňku);
  - jen ⌂ (7Fh) MZ nemá, je nakreslený v jeho stylu.
- **Znaky CP437, které MZ má** (20 glyfů z ROM): £ ä ö ü ß Ä Ö Ü ¥ π ♠ ♥ ♦ ♣ ● ○ ↑ ↓ ← →. Dělítko ÷ v ROM
  není. Rámečky, bloky a ostatní znaky CP437 jsou ve 40 sloupcích dál písmo 4×8 se zdvojenými body, aby na sebe
  navazovaly. `glyph_addr` je hledá v tabulce `mz_extra` (20 dvojic), rámečky a bloky B0h–DFh přeskočí hned.
- **Česká a slovenská písmena jako v českém CP/M pro MZ-800 (Lamač):** jeho BIOS je s písmem ROM skládá ze dvou
  řádků znaménka (u verzálky i s jejím horním řádkem) a řádků 2–7 základního písmene. Verzálky tak mají plnou
  výšku a znaménko jeden řádek. `tools/romfont.py --cpm` tabulku znamének čte přímo z `BIOS.mac`.
  - Opravené chyby CP/M: Ň měl v řádku 1 cikcak, ô měl místo stříšky vodorovnou čárku.
  - ˇ ¬ ´ (DCh, DEh, E0h) CP/M nemá, jsou nakreslené ve stylu MZ.
  - Vlastní písmo BIOSu CP/M (tučné ASCII) není písmo Sharp, nepoužívá se.
  - Varianta s vlastními znaménky ve dvou řádcích a verzálkami na 5 řádků (jako písmo 4×8) byla čitelnější,
    autor vybral podobu z CP/M.
- **Viewdata:** £ je z písma C64, ½ ¼ ÷ zůstávají zdvojené z 4×8, ¾ ‖ ■ nakreslené.
- **Paměť:** písma C64 a Atari mají stejnou velikost jako vlastní. MZ-800 přidalo 165 glyfů a tabulky (1,4 KB):
  program má 32 840 B, buffery a zásobník končí na BCAAh, do C000h zbývá 853 B. Historie bez CGA-1V má 37
  řádků.

## 2026-10-31: The Basement je BBS pro Atari

- **The Basement není C64, ale Atari** (BBS Express! Professional od Orion Micro Systems, „ExpressNET“). Autor ji
  na SAPI viděl s prohozenými malými a velkými písmeny a sekvencemi `[1;34m` jako text.
  - Po připojení se ptá „Go ASCII/ATASCII, press <return>“. Na 9Bh (Return z Atari) jede v ATASCII, na CR nabídne
    převod: ASCII, ANSI (IBM), VT52.
  - V sadě PETSCII posílal SAPI-Term na Enter CR, BBS přešla na ASCII s ANSI. ASCII ve znakové sadě C64 má
    prohozená velká a malá písmena, ESC PETSCII nezná.
  - Běží bez telnetu a uvítací text skládá znaky „kurzor vlevo“ (1Eh) a „vlož znak“ (FFh). S telnetem se FFh bralo
    jako IAC a horní řádky se rozpadly.
- **V adresáři je teď `The Basement (Atari),…,ATASCII,RAW`.** Ověřeno v emulátoru, obrazovka je celá a správně.
  Kdo ji má v `SAPITERM.CFG` jako PETSCII, opraví ji v menu: Z až na ATASCII, N na raw TCP, U uloží.
- **Pro PETSCII zůstává Retro Campus** (číslo 5): v menu Z až na PETSCII, pak volba 1. Adresář jinou ověřenou
  BBS pro C64 nemá.

## 2026-10-31: rychlejší příjem (akvárium z telehack.com)

- **Měřeno na záznamu akvária telehacku** (`aquarium`, zachycený jako terminál ANSI 80×25). Telehack posílá
  průměrně 17 KB/s, ve špičkách 35 KB/s. Na jeden nakreslený znak je to asi 23 bajtů: posun kurzoru a dvě až
  čtyři SGR (`ESC[13;49H ESC[1m ESC[30m X ESC[39m ESC[22m`). V 32 KB je jen 1405 tisknutelných znaků.
- **Čas nejde do kreslení, ale do zpracování bajtů** (profil po síti): telnet po bajtech 27 %, předávání
  terminálu 12 %, parser ANSI 23 %, kreslení na CGA-1V asi 12 %.
- **Úpravy podle profilu:**
  - telnet kopíruje data rychlou smyčkou až po IAC nebo NUL, ty bere `tn_byte` (asi 64 místo 255 taktů na bajt);
  - CSI maže parametry po slovech, číslice jdou přes ukazatel `ans_pp`, skok na příkaz bez `add_hl_a`;
  - SGR zkouší nejdřív barvy 30–49, `ansi_to_cga` bez `add_hl_a` (ten si uchovává AF, 68 taktů).
- **Výsledek:** akvárium po síti 4,3 → 6,0 KB/s (1,38×), obraz přesně podle modelu. Prohlížeč souborů nezpomalil
  (SUNSET 3,25 → 3,14 s). Akvárium tím dál nestíhá: chce 17 KB/s, i VT100 na 19200 Bd by zvládl jen 1,9 KB/s.
- **`msg_buf` a `cfg_fcb` jsou za písmy:** kód narostl přes hranici stránky a zarovnání písem by stálo 195 B
  výplně.
- **Na skutečném HW bude příjem pomalejší:** DPI-1L drží Z80 po příkazu TCP ve WAIT až asi 8 ms, na 253 B to je
  kolem 120 taktů na bajt navíc. Emulátor to nemodeluje (`docs/hw-otazky.md`).

## 2026-10-31: menu na obrazovce terminálu, stav spojení

- **Menu Ctrl+] na kartě terminálu** (přání autora): skok ovládání na druhou kartu mátl a terminál během menu stejně
  stojí. Menu zabere celou kartu terminálu (`om_here` přesměruje výstup `stat_` na `term_dev`, barvy ANSI), Esc
  nakreslí terminál znovu ze stínu (`om_back`: paleta terminálu, `scr_redraw`, stav). Okno přes terminál by stálo
  víc kódu a ve 40 sloupcích by se vešlo jen těsně.
  - Bez druhé karty menu teď funguje také (dřív Ctrl+] spojení rovnou ukončilo).
  - Po T, U, L, N a R se jen přepíšou řádky menu (hodnoty doplněné mezerami), celé znovu jen po Tab, S, Z a D.
  - T, R, S a Tab se do `SAPITERM.CFG` zapíšou až při odchodu z menu (`om_flush`): zápis trvá 0,3 s a stisk R
    se tak zkrátil z 0,6 na 0,2 s. U (adresář) se zapíše hned, jak dřív.
  - `stat_putc` volá `pal_flush` jen po nové dvojici barev; `scr_redraw` počítá řádek jednou (1,07 → 0,79 s).
- **Stavová karta při spojení:** protokol (telnet / raw TCP), doba spojení (h:mm:ss) a přijatá data (KB a KB/s za
  poslední sekundu, `rx_total`, `ol_second`). Čas z čítače 0 MPH-1V (v osminách, sekunda = 6991), bez MPH-1V
  z tiků v nečinnosti (při zátěži se zpožďuje). Dvojice barev a poslední klávesa byly jen pro vývoj.
- **Písma a tabulky zarovnané na stránku na začátku programu:** kód rostl přes hranici stránky a výplň před písmy
  skákala až o 256 B (dvakrát během dne). Teď je od 0200h, před nimi nulové buffery a za `font_ata.inc` pevných
  72 B výplně; `check_build.py` hlídá, že písmo začíná na 0200h.

## 2026-10-31: doba spojení bez MPH-1V z RTC DPI-1L, BSS bez zarovnání

- **MPH-1V není nutná** (ověřeno na sestavě s Consulem: stránka podle modelu, 2400 Bd). Bez ní je potichu zvonek
  a tiky jdou ze zatemnění CGA-1V. Doba spojení z tiků v klidu se ale při provozu zpožďovala (5 s místo 15 s).
- **Bez MPH-1V se doba spojení bere z RTC DPI-1L** (přání autora): RTCGETT (63h) dá hodinu, minutu a sekundu,
  doba = teď − začátek spojení (i přes půlnoc), rychlost = přírůstek dat za uplynulé sekundy. Karta DPI-1L je
  v sestavě vždy (bez ní nejde síť).
  - Čtení jen když je potřeba: v klidu 4× za sekundu (15 tiků), při provozu po 2 KB přijatých dat. Příkaz karty
    drží na HW Z80 ve WAIT až asi 8 ms, čtení při každém průchodu smyčkou by zdržovalo.
  - Když karta čas nevrátí, počítají se tiky v klidu jako dřív. S MPH-1V zůstává čítač 0 (přesnější).
- **`att_slot` a `att_pref` pevně na B800h–BFFFh,** ostatní BSS hned za programem: dřív začínalo BSS na další
  stránce za programem a konec BSS skákal po 256 B (zase se to stalo s kódem RTC). Historie bez CGA-1V je teď od
  C000h (32 řádků), s `att_slot` se nepotká: ten se bez CGA-1V nepoužívá a historie s CGA-1V je ve stránce B.
- **Rychlost na stavové kartě je klouzavý průměr za 5 s** (přání autora): kruh bajtů po sekundách (`rate_push`),
  průměr přes sekundy, které už uběhly (nejvýš 5). Z RTC, kde mezi čteními může uběhnout víc sekund, dostane každá
  z nich stejný díl. Ověřeno s MPH-1V i bez ní (v reálném čase): po stránce SUNSET 1753 B/s a za 5 s nula.

## 2026-10-31: buffery v RAM C000h–D5FFh

- **S CGA-1V ležela RAM C000h–D5FFh ladem** (historie je ve stránce B karty). Autor navrhl historii od C000h;
  ta drahou paměť pod C000h už nezabírala, místo ní jdou nahoru velké, zřídka používané buffery: adresář BBS
  (1552 B), blok XMODEM/YMODEM s `cfg_rec` a `cfg_line` (1030 B) a kódy Viewdata (984 B). Pod C000h se uvolnilo
  3,5 KB (zbývá 3838 B).
- **Jen to, na co kreslení nesahá:** CGA-1V se mapuje jen uvnitř `cga_draw` (a při historii a rolování), tyto
  buffery se čtou a píšou mimo něj, s MAP_CPM. Žádné další přepínání mapy, rychlost stejná. `in_buf`, stín
  a `hv_line` (historie ve stránce B se skládá při namapované CGA-1V) zůstávají pod C000h.
- **Konec TPA:** vše končí pod D600h (BDOS od D606h); `check_build.py` hlídá, že na historii bez CGA-1V zbude
  aspoň 8 řádků. CCP od CE00h se přepíše, SAPI-Term končí warm bootem (`JP 0`), který ho nahraje znovu.
- **Cena:** historie bez CGA-1V má 12 řádků místo 32.
- **Konec TPA se zjišťuje za běhu** (upozornění autora: jiný build CP/M má BDOS jinde): mez je stránka vstupu do
  BDOS z adresy na 0006h (sériové číslo BDOS ani rezidentní rozšíření se nepřepíšou). `tpa_check` hned po zjištění
  karet, ještě než `cfg_load` zapíše od C000h; při malé TPA hláška a návrat do CP/M. Ověřeno skokem do BDOS na
  CC00h a 0006h = CC00h: hláška, warm boot vrátí 0006h, `DIR` funguje.
- **Hlášky při startu vidět** (`quit_say`): `quit` maže konzoli ECMONu, hláška se proto píše až po smazání.
