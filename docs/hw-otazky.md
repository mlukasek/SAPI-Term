# SAPI-Term – otázky k ověření na skutečném HW

Ověřuje autor dávkově. Před zkouškou říct, co se stane.

## Fáze 1 (SAPITERM 0.1)

1. **Start a detekce:** spustit `SAPITERM` na SAPI-1 V. Na AND-1V má ukázat CGA-1V ano, MPH-1V ano, DPI-1L ano
   a verzi firmwaru (0.5). Na CGA-1V 16 barevných pruhů (černý, modrý … bílý).
   - Ověřuje, že detekce nespoléhá na nic, co se na skutečné sběrnici chová jinak než v emulátoru.
2. **Počítadla:** VBI CGA-1V i tik MPH-1V mají přibývat zhruba o 3Ch (60) za sekundu.
3. **Klávesnice EKL-1:** kód klávesy `a` = 61, šipka nahoru = 05, Ctrl+] vrátí do CP/M. Po návratu je CGA-1V
   černá, AND-1V smazaná s `A>` nahoře a `DIR` funguje.

## Na později

- **Čekání DPI-1L (WAIT) při TCP:** jak dlouho drží Z80 jeden TCPRECV a TCPSTATUS při běžném provozu
  (rychlost příjmu, plynulost kreslení). V emulátoru se to nedá zjistit.
- **TCPSEND chyba 5** (plné odesílání lwIP) a odmítnuté spojení (stav 3 hned).
- **RTC DPI-1L (60–63h):** vrací UTC, nebo místní čas? (`repo.c` čte časovač AON, který podle `systime.h` drží UTC.)
- **Sníh palety Bt476** při zápisu mimo VBI a při 2 MHz (zápis 112 dvojic trvá 6,8 ms, víc než VBI).
