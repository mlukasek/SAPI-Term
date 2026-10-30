# SAPI-Term – kontext projektu

Terminál pro internetové BBS (telnet klient) pro Tesla SAPI-1, sestavu V z Liborových desek: JPR-1V (Z80
4 MHz), RAM-1V, AND-1V, CGA-1V, ZRD-1V rev 1.1, MPH-1V, s Martinovou kartou DPI-1L pro síť. Program pro CP/M
`SAPITERM.COM`, vrací se do CP/M. Autor: Martin Lukášek (mlukasek). Komunikace **česky**.

## Kde co je

- **Pro práci začni v `docs/stav.md`** (stav, další kroky).
- `docs/vyvoj.md`: nástroje, překlad, emulátor, skripty, ověřování, pasti.
- `docs/technika.md`: paměť, mapování, karty, klávesnice, protokoly.
- `docs/rozhodnuti.md`: rozhodnutí s důvody. Nové dopisovat.
- `docs/hw-otazky.md`: otázky k ověření na skutečném HW.
- **Zdroj:** `src/sapiterm.asm` (hlavní soubor, vkládá ostatní moduly `src/*.asm`), `src/hw.inc` (porty a adresy).
- **Sestavy pro emulátor:** `machines/sapi1v_term.sapi` (EKL-1, jako autorovo SAPI) a
  `machines/sapi1v_term_consul.sapi` (Consul 262.3 věrně jako HW, bez MPH-1V).
- **Emulátor:** jen release SAPIemu v `..\SAPIemu-release` (0.7.0-beta), MCP přes `sapiemu-cli --mcp` na portu
  **8595** (GUI pro ruční zkoušky `--mcp-port 8596`). **Vývojový `..\SAPIemu` nepoužívat ani neměnit**, nanejvýš
  číst dokumentaci desek (`docs/desky/`). Chyby emulátoru zapsat a nahlásit autorovi.
- **Sesterské projekty se stejným stylem:** `..\SAPI-BomberNet` (DPI-1L, CGA-1V, návrat do CP/M),
  `..\SAPI-Bad-Apple` a `..\SAPI-Prince-of-Persia` (RAM disk, CGA-1V; odtud `tools/cpmdisk.py`, `tools/emu/`),
  `..\SAPI-Bomberman`, `..\SAPI-Flappy`. Firmware DPI-1L: `..\SAPI_DPI-firmware` (`docs/unicard.md`, `common/net.c`).

## Pravidla

- **Jazyk:** kód, komentáře v asm a skripty **anglicky**, dokumentace **česky**.
- **Asm:** pasmo 0.5.3 (`E:\SAPI_GIT\Tools\pasmo-0.5.3\pasmo.exe`), pasti v `~/.claude/CLAUDE.md` a
  `docs/vyvoj.md`.
- **Python 3, jen standardní knihovna.**
- **Paměť:** kód, data i zásobník pod C000h (při `OUT 63h,C0h` je tam CGA-1V a CP/M je schované). S namapovanou
  CGA-1V nevolat BDOS. Celý program běží s DI (přerušení s PC v okně karty zamrazí JPR-1V).
- **Měřit v emulátoru, nehádat.** Na skutečném HW (má ho autor) se ověřuje dávkově, otázky do
  `docs/hw-otazky.md`. Před akcí na hardwaru říct, co se stane.
- **„Dvakrát měř, jednou řež“:** na nejasné se zeptat, doporučení dávat jako první možnost.
- **Autorská práva:** žádné cizí ROM, fonty ani obrázky bez ověřené licence.
  - Výjimka z rozhodnutí autora (2026-10-30): písma 8×8 z ROM C64, Atari a Sharp MZ-800 a česká písmena z CP/M
    pro MZ-800 (`fonts/c64.txt`, `atari.txt`, `mz800.txt`, `mz800cs.txt`, `docs/rozhodnuti.md`).
  - Písmo 4×8 a testovací ANSI art jsou vlastní.
- **Dokumentace:** důležité poznatky zapisovat do `docs/` (pracuje se z více počítačů).
- **Git:** lokální commity průběžně, push jen na výslovné vyžádání. Na konec commitu řádek Co-Authored-By.
- **Nic neukládat mimo `E:\SAPI_GIT\`.** SAPIemu vypínat přes MCP `power off`, ne zabít.
