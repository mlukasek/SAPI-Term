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

## Na později

- **Čekání DPI-1L (WAIT) při TCP:** jak dlouho drží Z80 jeden TCPRECV a TCPSTATUS při běžném provozu
  (rychlost příjmu, plynulost kreslení). V emulátoru se to nedá zjistit.
- **TCPSEND chyba 5** (plné odesílání lwIP) a odmítnuté spojení (stav 3 hned).
- **RTC DPI-1L (60–63h):** vrací UTC, nebo místní čas? (`repo.c` čte časovač AON, který podle `systime.h` drží UTC.)
- **Sníh palety Bt476** při 2 MHz: zápis barev jedné dvojice (7 domén) trvá asi 0,4 ms, všech 16 asi 6 ms, víc
  než VBI (4 ms).
