"""Phase 5 check: settings and the address book in SAPITERM.CFG next to SAPITERM.COM, character sets of BBS.

The RAM disk has the default SAPITERM.CFG (src/sapiterm.cfg, 16 BBS). In CP/M "SAPITERM": the book on the start
screen; "-16" deletes the last BBS, a number not in the book gives a message. On line with the local test BBS
(tools/testbbs.py, started here): for each character set (menu Z) its text page on the screen glyph by glyph as
the model of tools/tables.py says, and Czech letters typed on the EKL-1 sent in that set; the menu saves the BBS
with UTF-8 into the book (U) and the keyboard type (T); the number of the new entry connects again with UTF-8;
Tab at the prompt moves the terminal to the AND-1V. Back in CP/M, TYPE shows the file as SAPI-Term wrote it;
"SAPITERM 16" then connects at once with the terminal on the AND-1V and the Consul keyboard type from the file.
Needs the emulator with MCP (tools/emu/sapiemu.cmd) and build.cmd.
  python tools/emu/phase5.py
"""
import os
import subprocess
import sys
import time

sys.stdout.reconfigure(encoding='utf-8')
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..'))
import emu  # noqa: E402
from emu import mcp  # noqa: E402
from phase4 import check, failed, keys, log, run_until, row_koi, LOG, PORT  # noqa: E402
import tables  # noqa: E402
import testbbs  # noqa: E402

PREVIEW = os.path.join(emu.REPO, 'build', 'preview')
BOOK_ROW = 8
MSG_ROW = 6
PROMPT_ROW = 18
DEV_AND = 2


def rows(sym, n=25):
    return [row_koi(sym, r) for r in range(n)]


def at_prompt(sym):
    return row_koi(sym, PROMPT_ROW).startswith('BBS:')


def byte(sym, name):
    return emu.read(sym[name], 1)[0]


def row_glyphs(sym, r):
    """Row r of the shadow as (code, KOI)."""
    offs = emu.read(sym['row_off'] + 2 * r, 2)
    o = offs[0] | offs[1] << 8
    chars = emu.read(sym['scr_chr'] + o, 80)
    ext = emu.read(sym['scr_ext'] + o, 80)
    return [(c, e & 1) for c, e in zip(chars, ext)]


def expect_glyphs(text, name):
    """The glyphs of text sent by the BBS in the character set name."""
    if name == 'UTF-8':
        return [g for ch in text for g in tables.utf8_glyphs(ch)]
    return [(b, 0) if b < 0x80 else tables.set_glyph(name, b) for b in testbbs.encode(text, name)]


def show_glyphs(glyphs):
    cp = tables.cp437_glyphs()
    return ''.join(tables.KOI_REV.get(c, '?') if k else (cp[c] or ' ') for c, k in glyphs)


def charsets(sym):
    """Menu Z through the sets after CP437; each: its text page, Czech letters typed in echo mode."""
    for cs, (key, name) in enumerate(testbbs.CHARSET_PAGES.items(), 1):
        keys('\x1d', 500)
        keys('z', 800)
        check(byte(sym, 'cs_type') == cs, 'Z: the set %s' % name)
        check(name in mcp.call('screen_text'), 'Z: the menu shows %s' % name)
        keys('\x1b', 800)
        want = [expect_glyphs(t, name) for t in testbbs.charset_lines(key)]
        keys(key, 100)
        ok = run_until(lambda: all(row_glyphs(sym, r)[:len(w)] == w for r, w in enumerate(want)), ms=10000)
        check(ok, '%s: the text page glyph by glyph' % name)
        for r, w in enumerate(want):
            got = row_glyphs(sym, r)[:len(w)]
            if got != w or name == 'UTF-8':
                print('      %s %s' % ('  ' if got == w else 'em', show_glyphs(got)))
            if got != w:
                print('      mo %s' % show_glyphs(w))
        if name == 'UTF-8':
            emu.screenshot(os.path.join(PREVIEW, 'f5_utf8.png'), display='CGA-1V')
        keys('E', 300)
        before = len(log().get('keys', ''))
        keys('čŘ', 600)
        keys('!', 300)
        sent = bytes.fromhex(log().get('keys', '')[before:])
        want_keys = testbbs.encode('čŘ', name)
        check(sent.startswith(want_keys), '%s: čŘ typed as %s (sent %s)' % (name, want_keys.hex(' '), sent.hex(' ')))


def main():
    os.makedirs(PREVIEW, exist_ok=True)
    sym = emu.symbols()
    if os.path.exists(LOG):
        os.remove(LOG)
    srv = subprocess.Popen([sys.executable, '-I', os.path.join(emu.REPO, 'tools', 'testbbs.py'), '--port',
                            str(PORT), '--log', LOG], stdout=subprocess.DEVNULL)
    time.sleep(1)
    try:
        emu.use_machine('sapi1v_term')
        emu.checkpoint()
        mcp.call('resume')
        mcp.call('type_text', text='SAPITERM\r')
        check(run_until(lambda: at_prompt(sym), ms=5000), 'the start screen')
        scr = rows(sym)
        check(scr[BOOK_ROW].startswith('Adres?? BBS v A:SAPITERM.CFG:'), 'the book from A:SAPITERM.CFG')
        check(byte(sym, 'book_n') == 16, 'the book has the 16 BBS of the default file')
        check(scr[BOOK_ROW + 1].startswith(' 1 Vertrauen'), 'entry 1: %r' % scr[BOOK_ROW + 1].rstrip())
        check(scr[BOOK_ROW + 2].startswith(' 2 Liane (CZ Liberec)'), 'entry 2: %r' % scr[BOOK_ROW + 2].rstrip())
        entry = emu.read(sym['book'] + sym['BOOK_ENTRY'], sym['BOOK_ENTRY'])
        name, addr, rest = entry.split(b'\0', 2)
        check(addr == b'bbs.vslib.cz' and rest[0] == 0, 'entry 2: address %r, set %d' % (addr, rest[0]))
        check(scr[BOOK_ROW + 5][40:].startswith('13 Clutch'), 'entry 13 in the second column')
        check(scr[BOOK_ROW + 6][40:].startswith('14 The Basement (Atari)'), 'entry 14: the Atari BBS')
        entry = emu.read(sym['book'] + 13 * sym['BOOK_ENTRY'], sym['BOOK_ENTRY'])
        name, addr, rest = entry.split(b'\0', 2)
        check(rest[0] == 0x88, 'entry 14: ATASCII and raw TCP (the set byte %02X)' % rest[0])
        check(scr[BOOK_ROW + 7][40:].startswith('15 Southern Amis (Atari)'), 'entry 15: the ATASCII BBS')
        check(scr[BOOK_ROW + 8][40:].startswith('16 telehack.com'), 'entry 16: telehack.com')
        mcp.call('run_for', ms=300)             # the colours go to the palette in the next VBI
        mcp.call('pause')
        emu.screenshot(os.path.join(PREVIEW, 'f5_prompt.png'), display='CGA-1V')

        keys('-16\r', 300)                      # delete the last one
        check(run_until(lambda: byte(sym, 'book_n') == 15 and at_prompt(sym), ms=5000), '-16: 15 BBS left')
        check(row_koi(sym, MSG_ROW).startswith('Ulo?eno do SAPITERM.CFG.'), '-16: saved')
        check(not row_koi(sym, BOOK_ROW + 8)[40:].strip(), '-16: entry 16 gone from the screen')
        keys('40\r', 300)
        check(run_until(lambda: row_koi(sym, MSG_ROW).startswith('Takov?'), ms=5000), '40: no such number')
        keys('-0\r', 300)
        check(run_until(lambda: byte(sym, 'book_n') == 15 and at_prompt(sym), ms=5000), '-0: nothing deleted')

        keys('127.0.0.1:%d\r' % PORT, 300)      # on line: the sets, U saves the BBS, T the keyboard type
        check(run_until(lambda: log().get('menu', 0) >= 1, ms=15000), 'connected to the test BBS')
        check(byte(sym, 'cs_type') == 0, 'not in the book: CP437')
        charsets(sym)
        keys('\x1d', 500)
        for _ in range(12):                     # KOI8 -> PETSCII -> ATASCII -> CP437 -> UTF-8
            keys('z', 2000)
            if byte(sym, 'cs_type') == 1:
                break
        check(byte(sym, 'cs_type') == 1, 'Z further round: UTF-8')
        keys('u', 1500)
        check(run_until(lambda: byte(sym, 'book_n') == 16, ms=5000), 'U: the BBS in the book')
        check('Uloženo do SAPITERM.CFG.' in mcp.call('screen_text'), 'U: saved (status card)')
        keys('u', 1500)
        check(byte(sym, 'book_n') == 16 and 'Uloženo do SAPITERM.CFG.' in mcp.call('screen_text'),
              'U again: the same entry saved again')
        keys('t', 1500)
        check(byte(sym, 'kbd_type') == 1, 'T: the Consul keyboard type')
        keys('o', 300)
        check(run_until(lambda: at_prompt(sym), ms=8000), 'O: back at the prompt')
        check(row_koi(sym, BOOK_ROW + 8)[40:].startswith('16 127.0.0.1'),
              'entry 16 = 127.0.0.1: %r' % row_koi(sym, BOOK_ROW + 8)[40:].rstrip())

        n = log().get('connects', 0)
        keys('16\r', 300)                       # the number from the book
        check(run_until(lambda: log().get('connects', 0) > n and log().get('menu', 0) >= 1, ms=15000),
              '16: connected to the test BBS again')
        text = mcp.call('screen_text')
        check('BBS: 127.0.0.1:%d' % PORT in text, '16: the status card shows the address')
        check(byte(sym, 'cs_type') == 1 and 'UTF-8' in text, '16: UTF-8 from the book')
        keys('\x1d', 500)
        keys('o', 300)
        check(run_until(lambda: at_prompt(sym), ms=8000), 'O: back at the prompt')

        keys('\t', 3000)                        # Tab: the terminal on the AND-1V, saved
        check(run_until(lambda: byte(sym, 'term_dev') == DEV_AND and at_prompt(sym), ms=8000),
              'Tab: the terminal on the AND-1V')
        check(byte(sym, 'cfg_term') == 1, 'Tab: SCREEN=AND kept')
        text = mcp.call('screen_text')
        check('BBS:' in text and '127.0.0.1' in text, 'the AND-1V shows the start screen with the book')

        keys('\x1d', 1500)
        res = mcp.call('run_until', screen_text='A>', timeout_ms=5000)
        check(res.get('stopped') != 'timeout', 'Ctrl+] at the prompt returns to CP/M')
        mcp.call('pause')
        text = emu.command_lines('TYPE SAPITERM.CFG')
        print('      ' + '\n      '.join(ln for ln in text.split('\n') if ln.startswith(('KEY', 'SCR', 'SPE',
                                                                                          'COL', 'BBS=12', 'BBS=127'))))
        check('KEYBOARD=CONSUL' in text, 'the file: KEYBOARD=CONSUL')
        check('SCREEN=AND' in text, 'the file: SCREEN=AND')
        check('BBS=127.0.0.1,127.0.0.1:%d,UTF-8' % PORT in text, 'the file: the new BBS with UTF-8')
        check('telehack' not in text, 'the file: the deleted BBS is not there')

        n = log().get('connects', 0)
        mcp.call('resume')
        mcp.call('type_text', text='SAPITERM 16\r')
        ok = run_until(lambda: log().get('connects', 0) > n and log().get('menu', 0) >= 1, ms=15000)
        check(ok, 'SAPITERM 16: connected at once')
        if not ok:
            for line in mcp.call('screen_text').rstrip().split('\n'):
                print('      ' + line)
            print('      mode %d, book_n %d, ui_line %r' % (byte(sym, 'mode'), byte(sym, 'book_n'),
                  emu.read(sym['ui_line'], 64).split(b'\0')[0]))
        check(byte(sym, 'term_dev') == DEV_AND, 'SAPITERM 15: the terminal on the AND-1V (SCREEN=AND)')
        check(byte(sym, 'kbd_type') == 1, 'SAPITERM 15: the Consul keyboard type from the file')
        check(log().get('naws') == [[64, 20]], 'SAPITERM 15: NAWS 64x20: %r' % log().get('naws'))
        keys('\x1d', 500)
        keys('k', 1500)
        res = mcp.call('run_until', screen_text='A>', timeout_ms=5000)
        check(res.get('stopped') != 'timeout', 'K: back in CP/M')
        mcp.call('pause')
    finally:
        srv.terminate()
    if failed:
        sys.exit('%d check(s) failed' % len(failed))
    print('all checks passed')


if __name__ == '__main__':
    main()
