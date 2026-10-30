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

## Na později

- **Čekání DPI-1L (WAIT) při TCP:** jak dlouho drží Z80 jeden TCPRECV a TCPSTATUS při běžném provozu
  (rychlost příjmu, plynulost kreslení). V emulátoru se to nedá zjistit.
- **TCPSEND chyba 5** (plné odesílání lwIP) a odmítnuté spojení (stav 3 hned).
- **RTC DPI-1L (60–63h):** vrací UTC, nebo místní čas? (`repo.c` čte časovač AON, který podle `systime.h` drží UTC.)
- **Sníh palety Bt476** při 2 MHz: zápis barev jedné dvojice (7 domén) trvá asi 0,4 ms, všech 16 asi 6 ms, víc
  než VBI (4 ms).
