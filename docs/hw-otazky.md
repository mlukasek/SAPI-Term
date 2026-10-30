# SAPI-Term – otázky k ověření na skutečném HW

Ověřuje autor dávkově. Před zkouškou říct, co se stane.

## SAPITERM 0.2 (fáze 1 a 2)

1. **Start a detekce:** `SAPITERM` na SAPI-1 V. Stavová obrazovka na AND-1V ukáže CGA-1V, AND-1V, MPH-1V
   a DPI-1L „ano“ a firmware 0.5. Ověřuje, že detekce nespoléhá na nic, co se na skutečné sběrnici chová jinak než
   v emulátoru.
2. **Čitelnost fontu 4×8** na skutečném monitoru VGA přes CGA-1V: malá písmena, číslice, rámečky a velká písmena
   s diakritikou, která mají výšku malých (`docs/rozhodnuti.md`).
3. **Barvy:** testovací obrazovka (Ctrl+T) má bílý nadpis, žlutou tabulku, azurové rámečky a zelenou nápovědu.
   Při psaní nesmí na obraze blikat rušení (sníh Bt476).
4. **Klávesnice EKL-1:** psaní, šipky (pohyb kurzoru), Ctrl+P/Ctrl+O barvy, Tab výměna karet. Kurzor bliká asi
   1,5× za sekundu.
5. **Návrat Ctrl+]:** CGA-1V černá, AND-1V smazaná s `A>` nahoře, `DIR` funguje.

## SAPITERM 0.3 (fáze 3)

1. **Soubory ANSI z RAM disku:** `SAPITERM SUNSET.ANS` (západ slunce z půlbloků, barvy iCE), `MENU.ANS`,
   `ANSITEST.ANS`, `SCROLL.ANS`. Obraz má být stejný jako na snímcích v emulátoru, bez sněhu.
2. **Rychlost:** SCROLL.ANS při 4 MHz asi 4 s, SUNSET.ANS asi 3 s (v emulátoru). Na skutečném HW s čekáním
   CGA-1V by mělo vyjít stejně (čekání je změřené a emulované).

## SAPITERM 0.4 (fáze 4)

1. **Spojení přes DPI-1L a Wi-Fi:** `SAPITERM` a zadat BBS (seznam přijde ve fázi 5; zatím třeba známá
   Synchronet BBS). Má se ukázat úvodní obrazovka BBS a BBS má poznat ANSI a velikost 80×25.
2. **Rychlost a plynulost příjmu** se skutečným čekáním DPI (WAIT po příkazech TCP): rolování a kreslení ANSI artu
   z BBS.
3. **Klávesy EKL-1 na BBS:** šipky v menu BBS, Enter, Backspace, Ctrl+C.

## SAPITERM 0.5 (fáze 5)

1. **Adresář na RAM disku:** `SAPITERM` ukáže 13 BBS z `SAPITERM.CFG`. Číslo připojí, např. `1` (Vertrauen).
   V menu (Ctrl+]) T přepne klávesnici a uloží. Po novém startu musí typ zůstat (zápis na ZRD-1V).
2. **Jiný disk:** je-li v sestavě další disk, `B:SAPITERM` má číst a psát `B:SAPITERM.CFG`.
3. **Čeština z EKL-1:** na BBS se sadou UTF-8 nebo Latin-2 napsat „Příliš žluťoučký kůň“ (třeba do vyhledávání
   nebo zprávy, bez odeslání) a podívat se, co BBS ukáže. Na Liane (`bbs.vslib.cz`, účet guest) zjistit její
   znakovou sadu: Z v menu, dokud čeština nesedí, pak U.
4. **Seznam BBS přes skutečnou DPI-1L:** projít pár BBS z adresáře (úvodní obrazovka, odpojení O).

## SAPITERM 0.5 (fáze 6)

1. **Rychlost linky:** v menu R nastavit 2400 Bd, pak `SAPITERM SUNSET.ANS`. Obraz se má kreslit plynule asi
   37 s (8,9 KB). Ověřuje čítač 0 MPH-1V jako hodiny. Na konci R zpět na MAX.
2. **Blikání:** BBS s blikajícím textem bez iCE (třeba výzva „press any key“). Text bliká asi 1,5× za sekundu bez
   sněhu na obrazovce.
3. **40 sloupců:** na BBS menu S. Písmo 4×8 se zdvojenými body, čitelnost na monitoru.

## Na později

- **Čekání DPI-1L (WAIT) při TCP:** jak dlouho drží Z80 jeden TCPRECV a TCPSTATUS při běžném provozu
  (rychlost příjmu, plynulost kreslení). V emulátoru se to nedá zjistit.
- **TCPSEND chyba 5** (plné odesílání lwIP) a odmítnuté spojení (stav 3 hned).
- **RTC DPI-1L (60–63h):** vrací UTC, nebo místní čas? (`repo.c` čte časovač AON, který podle `systime.h` drží UTC.)
- **Sníh palety Bt476** při 2 MHz: zápis barev jedné dvojice (7 domén) trvá asi 0,4 ms, všech 16 asi 6 ms, víc
  než VBI (4 ms).
