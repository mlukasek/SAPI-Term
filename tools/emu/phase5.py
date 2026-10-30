"""Phase 5 check: settings and the address book in SAPITERM.CFG next to SAPITERM.COM.

The RAM disk has the default SAPITERM.CFG (src/sapiterm.cfg, 12 BBS). In CP/M "SAPITERM": the book on the start
screen; "-12" deletes the last BBS, a number not in the book gives a message; on line with the local test BBS
(tools/testbbs.py, started here) the menu saves it into the book (U) and the keyboard type (T); the number of
the new entry connects again; Tab at the prompt moves the terminal to the AND-1V. Back in CP/M, TYPE shows the
file as SAPI-Term wrote it; "SAPITERM 12" then connects at once with the terminal on the AND-1V and the Consul
keyboard type from the file. Needs the emulator with MCP (tools/emu/sapiemu.cmd) and build.cmd.
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
        check(byte(sym, 'book_n') == 12, 'the book has the 12 BBS of the default file')
        check(scr[BOOK_ROW + 1].startswith(' 1 Vertrauen'), 'entry 1: %r' % scr[BOOK_ROW + 1].rstrip())
        check(scr[BOOK_ROW + 4][40:].startswith('12 Clutch'), 'entry 12 in the second column')
        emu.screenshot(os.path.join(PREVIEW, 'f5_prompt.png'), display='CGA-1V')

        keys('-12\r', 300)                      # delete the last one
        check(run_until(lambda: byte(sym, 'book_n') == 11 and at_prompt(sym), ms=5000), '-12: 11 BBS left')
        check(row_koi(sym, MSG_ROW).startswith('Ulo?eno do SAPITERM.CFG.'), '-12: saved')
        check(not row_koi(sym, BOOK_ROW + 4)[40:].strip(), '-12: entry 12 gone from the screen')
        keys('40\r', 300)
        check(run_until(lambda: row_koi(sym, MSG_ROW).startswith('Takov?'), ms=5000), '40: no such number')
        keys('-0\r', 300)
        check(run_until(lambda: byte(sym, 'book_n') == 11 and at_prompt(sym), ms=5000), '-0: nothing deleted')

        keys('127.0.0.1:%d\r' % PORT, 300)      # on line: U saves the BBS, T the keyboard type
        check(run_until(lambda: log().get('menu', 0) >= 1, ms=15000), 'connected to the test BBS')
        keys('\x1d', 500)
        keys('u', 1500)
        check(run_until(lambda: byte(sym, 'book_n') == 12, ms=5000), 'U: the BBS in the book')
        check('Uloženo do SAPITERM.CFG.' in mcp.call('screen_text'), 'U: saved (status card)')
        keys('u', 1500)
        check('Tahle BBS už v adresáři je.' in mcp.call('screen_text'), 'U again: there already')
        keys('t', 1500)
        check(byte(sym, 'kbd_type') == 1, 'T: the Consul keyboard type')
        keys('o', 300)
        check(run_until(lambda: at_prompt(sym), ms=8000), 'O: back at the prompt')
        check(row_koi(sym, BOOK_ROW + 4)[40:].startswith('12 127.0.0.1'),
              'entry 12 = 127.0.0.1: %r' % row_koi(sym, BOOK_ROW + 4)[40:].rstrip())

        n = log().get('connects', 0)
        keys('12\r', 300)                       # the number from the book
        check(run_until(lambda: log().get('connects', 0) > n and log().get('menu', 0) >= 1, ms=15000),
              '12: connected to the test BBS again')
        check('BBS: 127.0.0.1:%d' % PORT in mcp.call('screen_text'), '12: the status card shows the address')
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
        mcp.call('resume')
        mcp.call('type_text', text='TYPE SAPITERM.CFG\r', run_ms=3000)
        mcp.call('pause')
        text = mcp.call('screen_text')
        print('      ' + '\n      '.join(text.rstrip().split('\n')[-12:]))
        check('KEYBOARD=CONSUL' in text, 'the file: KEYBOARD=CONSUL')
        check('SCREEN=AND' in text, 'the file: SCREEN=AND')
        check('BBS=127.0.0.1,127.0.0.1:%d' % PORT in text, 'the file: the new BBS')
        check('Clutch' not in text, 'the file: the deleted BBS is not there')

        n = log().get('connects', 0)
        mcp.call('resume')
        mcp.call('type_text', text='SAPITERM 12\r')
        check(run_until(lambda: log().get('connects', 0) > n and log().get('menu', 0) >= 1, ms=15000),
              'SAPITERM 12: connected at once')
        check(byte(sym, 'term_dev') == DEV_AND, 'SAPITERM 12: the terminal on the AND-1V (SCREEN=AND)')
        check(byte(sym, 'kbd_type') == 1, 'SAPITERM 12: the Consul keyboard type from the file')
        check(log().get('naws') == [[64, 20]], 'SAPITERM 12: NAWS 64x20: %r' % log().get('naws'))
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
