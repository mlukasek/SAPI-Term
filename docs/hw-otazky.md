# SAPI-Term – otázky k ověření na skutečném HW

Ověřuje autor dávkově. Před zkouškou říct, co se stane.

## SAPITERM 0.2 (fáze 1 a 2)

1. **Start a detekce:** `SAPITERM` na SAPI-1 V. Stavová obrazovka na AND-1V ukáže CGA-1V, AND-1V, MPH-1V
   a DPI-1L „ano“ a firmware 0.5. Ověřuje, že detekce nespoléhá na nic, co se na skutečné sběrnici chová jinak než
   v emulátoru.
   - **2026-10-31, autor na skutečném HW, studený start** (zapnout, ECMON 3, `SAPITERM`): MPH-1V „ano“
     s detekcí, která čeká na nahrání dělitele. Na čase od zapnutí nezáleží, jen aby čítač 2 mezitím nepoužil
     jiný program. Obsah čítače po zapnutí je náhodný, takže jedna zkouška nedokazuje, že by stará detekce selhala.
     Ještě 3× zopakováno, pokaždé „ano“.
2. **Čitelnost fontu 4×8** na skutečném monitoru VGA přes CGA-1V: malá písmena, číslice, rámečky a velká písmena
   s diakritikou, která mají výšku malých (`docs/rozhodnuti.md`).
   - **2026-10-31, autor na skutečném HW:** ověřeno.
3. **Barvy:** testovací obrazovka (Ctrl+T) má bílý nadpis, žlutou tabulku, azurové rámečky a zelenou nápovědu.
   Při psaní nesmí na obraze blikat rušení (sníh Bt476).
   - **2026-10-31, autor na skutečném HW:** ověřeno.
4. **Klávesnice EKL-1:** psaní, šipky (pohyb kurzoru), Ctrl+P/Ctrl+O barvy, Tab výměna karet. Kurzor bliká asi
   1,5× za sekundu.
5. **Návrat Ctrl+]:** CGA-1V černá, AND-1V smazaná s `A>` nahoře, `DIR` funguje.
   - **2026-10-31, autor na skutečném HW:** ověřeno.

## SAPITERM 0.3 (fáze 3)

1. **Soubory ANSI z RAM disku:** `SAPITERM SUNSET.ANS` (západ slunce z půlbloků, barvy iCE), `MENU.ANS`,
   `ANSITEST.ANS`, `SCROLL.ANS`. Obraz má být stejný jako na snímcích v emulátoru, bez sněhu.
   - **2026-10-31, autor na skutečném HW:** ověřeno.
2. **Rychlost:** SCROLL.ANS při 4 MHz asi 4 s, SUNSET.ANS asi 3 s (v emulátoru). Na skutečném HW s čekáním
   CGA-1V by mělo vyjít stejně (čekání je změřené a emulované).
   - **2026-10-31, autor na skutečném HW:** ověřeno.

## SAPITERM 0.4 (fáze 4)

1. **Spojení přes DPI-1L a Wi-Fi:** `SAPITERM` a zadat BBS (seznam přijde ve fázi 5; zatím třeba známá
   Synchronet BBS). Má se ukázat úvodní obrazovka BBS a BBS má poznat ANSI a velikost 80×25.
2. **Rychlost a plynulost příjmu** se skutečným čekáním DPI (WAIT po příkazech TCP): rolování a kreslení ANSI artu
   z BBS.
3. **Klávesy EKL-1 na BBS:** šipky v menu BBS, Enter, Backspace, Ctrl+C.
   - **2026-10-31, autor na skutečném HW (Vertrauen):** šipky, Backspace a Ctrl+C fungují.

## SAPITERM 0.5 (fáze 5)

1. **Adresář na RAM disku:** `SAPITERM` ukáže 16 BBS z `SAPITERM.CFG`. Číslo připojí, např. `1` (Vertrauen).
   V menu (Ctrl+]) T přepne klávesnici a uloží. Po novém startu musí typ zůstat (zápis na ZRD-1V).
   - **2026-10-31, autor na skutečném HW:** uložení typu klávesnice funguje.
2. **Jiný disk:** je-li v sestavě další disk, `B:SAPITERM` má číst a psát `B:SAPITERM.CFG`.
   - **2026-10-31, autor na skutečném HW:** `B:SAPITERM` funguje, jak má, a otevírá `SAPITERM.CFG` z B:.
3. **Čeština z EKL-1:** na BBS se sadou UTF-8 nebo Latin-2 napsat „Příliš žluťoučký kůň“ (třeba do vyhledávání
   nebo zprávy, bez odeslání) a podívat se, co BBS ukáže. Na Liane (`bbs.vslib.cz`, účet guest) zjistit její
   znakovou sadu: Z v menu, dokud čeština nesedí, pak U.
   - **2026-10-31, autor na skutečném HW:** na testovací obrazovce se české znaky z EKL-1 píšou i zobrazují
     správně. Na BBS neověřeno: Liane píše vše anglicky a česká BBS dnes skoro není (ani dřív se čeština kvůli
     problémům moc nepoužívala). Autor to dál neřeší, převody sad jsou ověřené jen v emulátoru (`phase5.py`).
4. **Seznam BBS přes skutečnou DPI-1L:** projít pár BBS z adresáře (úvodní obrazovka, odpojení O).

## SAPITERM 0.5 (fáze 6)

1. **Rychlost linky:** v menu R nastavit 2400 Bd, pak `SAPITERM SUNSET.ANS`. Obraz se má kreslit plynule asi
   37 s (8,9 KB). Ověřuje čítač 0 MPH-1V jako hodiny. Na konci R zpět na MAX. Menu je od 2026-10-31 i na úvodní
   obrazovce (Ctrl+] na výzvě „BBS:“), spojení k tomu není potřeba.
   - **2026-10-31, autor na skutečném HW bez MPH-1V** (tiky z VBI CGA-1V): 39 s i se spuštěním programu.
     Proti výpočtu 37 s tedy nanejvýš asi o 2 s déle.
   - **2026-10-31, autor na skutečném HW s MPH-1V** (čas z čítače 0): necelých 39 s i se spuštěním programu,
     menu na úvodní obrazovce funguje. Obě cesty měření času vycházejí stejně, ztráta tiků bez MPH-1V se
     neprojevila.
2. **Blikání:** BBS s blikajícím textem bez iCE (třeba výzva „press any key“). Text bliká asi 1,5× za sekundu bez
   sněhu na obrazovce.
3. **40 sloupců:** na BBS menu S. Písmo Sharp MZ-800 (i čeština podle CP/M pro MZ-800), čitelnost na monitoru.
   - **Obojí na testovací BBS z PC** (`docs/vyvoj.md`, „Testovací BBS pro skutečné SAPI“): na PC
     `python tools\testbbs.py --host 0.0.0.0`, na SAPI `SAPITERM IP_PC:6023`. B = blikající text (SGR 5 bez iCE),
     I = totéž s iCE (nebliká, světlá pozadí). Pak Ctrl+], Z na UTF-8, S, Esc a U = „Příliš žluťoučký kůň…“ ve
     40 sloupcích písmem MZ-800 (i rámečky a další znaky Unicode).
   - **2026-10-31, autor na skutečném HW, testovací BBS z PC** (`testbbs.py --host 0.0.0.0`): blikání (B, I)
     i čeština ve 40 sloupcích (U) fungují, jak mají.

## SAPITERM 0.7 (fáze 7)

1. **Záznam relace:** na BBS menu L, chvíli procházet, L. V CP/M `SAPITERM LOG00.ANS` relaci přehraje.
2. **Historie:** na BBS po delším výpisu menu H, PgUp, šipky, Esc. Obrazovka se má vrátit beze změny.
   - **2026-10-31, autor na skutečném HW:** záznam relace i historie fungují.
3. **Stahování:** na BBS, kde je účet (třeba Vertrauen), zvolit stažení malého souboru protokolem YMODEM nebo
   XMODEM, pak menu D. Soubor má být vedle `SAPITERM.COM`. Zajímá mě rychlost se skutečnou DPI-1L.
   - **2026-10-31, autor na skutečném HW** (Vertrauen, nový účet): XMODEM i YMODEM fungují skvěle. XMODEM jméno
     nepřenáší, soubor je `XMODEM.BIN` (další `XMODEM1.BIN` až `XMODEM9.BIN`). Rychlost neměřena.
   - **Od 2026-10-31 jméno po XMODEM:** po stažení se pod průběhem objeví „Jméno souboru (Enter = XMODEM.BIN):“.
     Napsat jméno a Enter: hláška v menu má ukázat nové jméno a `DIR` po návratu ho má mít místo `XMODEM.BIN`.
     **2026-10-31, autor na skutečném HW:** funguje.

## SAPITERM 0.8 (fáze 8, PETSCII)

1. **PETSCII:** Retro Campus (`SAPITERM 5`), v menu Z až na PETSCII, Esc, pak volba 1 (CBM PETSCII). Grafika C64
   a barvy na monitoru, čitelnost písma 8×8.
   - **2026-10-31, autor na skutečném HW, testovací BBS z PC** (`testbbs.py --host 0.0.0.0`): stránka G funguje.
   - **2026-10-31, autor na skutečném HW:** PETSCII na skutečných BBS funguje.

## SAPITERM 0.8 (fáze 8, ATASCII)

1. **ATASCII:** `SAPITERM 15` (Southern Amis), Return. Kresba Atari 800XL a inverzní text, barvy Atari.
   - **2026-10-31, autor na skutečném HW, testovací BBS z PC** (`testbbs.py --host 0.0.0.0`): stránka A funguje.
   - **2026-10-31, autor na skutečném HW:** ATASCII na skutečných BBS funguje.
2. **ATASCII s raw TCP:** `SAPITERM 14` (The Basement, jednolinková, bývá obsazená), na „press <return>“ Return.
   Text „Are you ready to do things tonight…“ se skládá vkládáním znaků (FFh) a má vyjít celý.

## SAPITERM 0.8 (fáze 8, Viewdata)

1. **Viewdata:** připojit `glasstty.com:6502` (Telstar), v menu Z zvolit VIEWDATA. Barvy teletextu, dvojitá výška,
   mozaiky. Enter = # (pokračovat).
   - **2026-10-31, autor na skutečném HW, testovací BBS z PC** (`testbbs.py --host 0.0.0.0`): stránka V funguje.
     Na Telstar neověřeno. Telstar 2026-10-31 18:46 UTC odpovídal (z PC: úvodní stránka „GOOD EVENING“). Adresář
     je plný (16 BBS), U ji neuloží: připojit adresou, Ctrl+], Z až na VIEWDATA, Esc.

## Zvonek

1. **BEL:** na testovací obrazovce (prázdný Enter na výzvě „BBS:“) Ctrl+G, nebo na BBS, která pípá (třeba při
   chatu). Má zaznít krátký tón z MPH-1V, zajímá mě hlasitost a jestli YM3812 stihne zápisy s pauzami podle
   `ym_regs`.
   - **2026-10-31, autor na skutečném HW:** Ctrl+G na testovací obrazovce krátce pípne přes MPH-1V. YM3812 zápisy
     s pauzami podle `ym_regs` stíhá.
2. **Bzučák klávesnice bez MPH-1V** (kartu vytáhnout): Ctrl+G na testovací obrazovce má krátce (asi 1/15 s)
   pípnout bzučák EKL-1 a po pípnutí být ticho. Zajímá mě, jestli není moc hlasitý nebo moc krátký, a jestli se při
   rychlém psaní hned za Ctrl+G neztratí znak. U Consulu 262.3 (jestli ho máte): má bzučák na stejném vývodu?
   - **2026-10-31, autor na skutečném HW:** bez MPH-1V vše funguje výborně, zvonek na bzučáku EKL-1 také. Consul
     zatím neověřený.

## Doba spojení bez MPH-1V (RTC DPI-1L)

1. **Bez MPH-1V** (kartu vytáhnout, nebo sestava, která ji nemá): na BBS běží doba spojení na stavové kartě
   z hodin RTC DPI-1L (RTCGETT). Má jít stejně jako hodinky, i při stahování dlouhé stránky. Zajímá mě, jestli RTC
   karty po zapnutí běží (bez nastavení času) a jestli čtení asi 4× za sekundu nebo po 2 KB dat znatelně
   nezpomalí příjem (WAIT karty).
   - **2026-10-31, autor:** RTC DPI-1L se nastaví z NTP pár sekund po zapnutí. Doba spojení je rozdíl dvou
     čtení RTC, proti stopkám se tedy nerozejde. Stačí kontrola za běhu: asi 5 minut stopkami od změny sekundy
     na stavové kartě a pohled, jestli sekundy při velkém toku dat (akvárium) neskáčou.
   - **2026-10-31, autor na skutečném HW (bez MPH-1V, akvárium):** za 6:00 na stopkách se doba spojení posunula
     přesně o 6:00. Sekundy jdou po jedné, ale nerovnoměrně (občas dřív, občas o chvilku později): změna se ukáže
     až při čtení RTC (v klidu 4× za sekundu, při datech po 2 KB), tedy se zpožděním 0–0,3 s. Součet to nekazí,
     častější čtení by znamenalo víc čekání na kartu. Necháno tak.

## Na později

- **Čekání DPI-1L (WAIT) při TCP:** jak dlouho drží Z80 jeden TCPRECV a TCPSTATUS při běžném provozu
  (rychlost příjmu, plynulost kreslení). V emulátoru se to nedá zjistit.
  - **2026-10-31, autor na skutečném HW:** SAPI-Term jede perfektně, akvárium na telehack.com je stejně rychlé
    jako v SAPIemu. WAIT karty příjem znatelně nezpomaluje.
- **TCPSEND chyba 5** (plné odesílání lwIP) a odmítnuté spojení (stav 3 hned).
  - **2026-10-31, autor na skutečném HW:** odmítnuté spojení se chová správně.
  - **Chyba 5 není ověřená nikde,** ani v emulátoru (test na ni není). `tx_flush` posílá znovu po každém tiku, nejvýš
    2 s (120 tiků), pak data zahodí. Na skutečné kartě se ručně vyvolat nedá: firmware má `TCP_SND_BUF` = 8 × 1460 B
    (`SAPI_DPI-firmware/firmware/lwipopts.h`), chyba přijde, až když protistrana nečte a zaplní se její okno
    i těchto 11,7 KB. Terminál posílá jen to, co se napíše, takže by to chtělo desítky KB psaní.
- **RTC DPI-1L (60–63h):** vrací UTC, nebo místní čas? (`repo.c` čte časovač AON, který podle `systime.h` drží UTC.)
- **Sníh palety Bt476** při 2 MHz: zápis barev jedné dvojice (7 domén) trvá asi 0,4 ms, všech 16 asi 6 ms, víc
  než VBI (4 ms).
  - **2026-10-31, autor na skutečném HW:** sníh na obraze zkoumal a žádný neviděl.
