"""Phase 7 check: the session log, the history and downloads (YMODEM batch, XMODEM).

With the local test BBS (tools/testbbs.py, started here): menu L starts the log LOG00.ANS, the MENU page comes,
L stops it. SCROLL (51 rows scroll off), menu H: the history as the model has it, PgUp, up, End, Esc: the screen
as it was. Y on the BBS and menu D: YMODEM of two files (sunset-down.ans -> SUNSET-D.ANS, menu.ans -> MENU1.ANS
because MENU.ANS is on the disk already); X and menu D: XMODEM -> XMODEM.BIN. Back in CP/M SAPI-Term shows each
file, the screen must equal the model of the bytes sent (the log: the MENU page, the downloads: SUNSET.ANS with
its SAUCE, MENU.ANS, ANSITEST.ANS). Needs the emulator with MCP (tools/emu/sapiemu.cmd) and build.cmd.
  python tools/emu/phase7.py
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
import ansiref  # noqa: E402
import testbbs  # noqa: E402
import fontgen  # noqa: E402
from phase3 import shadow  # noqa: E402
from cgaread import term_text  # noqa: E402
from phase4 import check, failed, keys, log, run_until, screen_matches, LOG, PORT  # noqa: E402

PREVIEW = os.path.join(emu.REPO, 'build', 'preview')


def download(sym, key, want, name=None, xfer='ok'):
    """Key starts a download on the test BBS, menu D receives it; XMODEM: name typed when it is asked for."""
    keys(key, 300)                              # the BBS waits for the receiver
    keys('\x1d', 500)
    keys('d', 300)
    if name is not None:
        ok = run_until(lambda: 'Jméno souboru (Enter = XMODEM.BIN):' in term_text(sym), ms=60000, step=500)
        check(ok, '%s: the name asked for after XMODEM' % key)
        keys(name + '\r', 1500)
    ok = run_until(lambda: log().get('xfer') is not None and want in term_text(sym), ms=60000, step=500)
    text = term_text(sym)
    line = [ln for ln in text.split('\n') if 'staženo' in ln.lower() or 'Stahov' in ln or 'Soubor' in ln]
    check(ok and log().get('xfer') == xfer, '%s: the BBS: %r' % (key, log().get('xfer')))
    check(any(want in ln for ln in line), '%s: %r' % (key, line))
    keys('\x1b', 800)


def history(sym, font):
    """SCROLL from the BBS (51 rows scroll off), menu H, PgUp: the rows of the history as in the model; End, Esc:
    the screen as it was (shadow, cursor and the CGA-1V picture)."""
    model = ansiref.Term()
    model.feed(testbbs.page_bytes('4'))
    keys('4', 100)
    check(run_until(lambda: screen_matches(sym, model), ms=30000, step=500), 'SCROLL on the screen')
    cur = (emu.read(sym['cur_row'], 1)[0], emu.read(sym['cur_col'], 1)[0])
    count = emu.read(sym['hist_count'], 1)[0]
    check(count >= len(model.history), 'the history has %d rows (the model %d)' % (count, len(model.history)))
    keys('\x1d', 500)
    keys('h', 6000)
    check(screen_matches(sym, model), 'H: the screen as it was, now the end of the history')
    keys('\x12', 6000)                          # PgUp (Ctrl+R) of the EKL-1
    rows = shadow(sym)
    want = [(list(c), list(a)) for c, a in model.history[-24:]]
    check([r for r in rows[:24]] == want, 'PgUp: rows 0-23 are the last 24 rows of the history')
    check(rows[24] == (model.chr[0], model.att[0]), 'PgUp: row 24 is the first row of the screen')
    emu.screenshot(os.path.join(PREVIEW, 'f7_history.png'), display='CGA-1V')
    keys('\x05', 2000)                          # up a row
    check(shadow(sym)[1] == want[0], 'up: the rows moved down by one')
    keys('\x11', 6000)                          # End
    check(screen_matches(sym, model), 'End: the screen again')
    keys('\x1b', 6000)
    check(screen_matches(sym, model), 'Esc: the screen as it was')
    check((emu.read(sym['cur_row'], 1)[0], emu.read(sym['cur_col'], 1)[0]) == cur, 'Esc: the cursor where it was')
    cap = emu.read(sym['hist_cap'], 1)[0]
    left = min(count, cap - 25)                 # a full ring lent its oldest rows to the screen
    check(emu.read(sym['hist_count'], 1)[0] == left, 'Esc: the history has %d rows (%d before, %d at most)'
          % (left, count, cap))
    path = os.path.join(PREVIEW, 'f7_after_history.png')
    want_rgb = ansiref.render(model, font)
    for _ in range(10):
        mcp.call('run_for', ms=200)
        mcp.call('pause')
        emu.screenshot(path, display='CGA-1V')
        w, h, got = ansiref.png_rgb(path)
        want_b, got = bytearray(want_rgb), bytearray(got)
        for y in range(16):
            for x in range(8):
                p = ((cur[0] * 16 + y) * 640 + cur[1] * 8 + x) * 3
                want_b[p:p + 3] = got[p:p + 3]
        diff = sum(1 for i in range(0, len(want_b), 3) if want_b[i:i + 3] != got[i:i + 3])
        if diff == 0:
            break
    check(diff == 0, 'Esc: the CGA-1V picture equals the model (%d dots differ)' % diff)


def view(sym, name, model):
    mcp.call('resume')
    mcp.call('type_text', text='SAPITERM %s\r' % name)
    mcp.call('run_for', ms=600)
    ok = run_until(lambda: emu.read(sym['view_state'], 1)[0] != 0, ms=30000)
    state = emu.read(sym['view_state'], 1)[0]
    check(ok and state == 1 and screen_matches(sym, model), '%s: shown, the screen equals the model (state %d)'
          % (name, state))
    mcp.call('resume')
    mcp.call('type_text', text='\x1d', run_ms=1500)
    res = mcp.call('run_until', screen_text='A>', timeout_ms=5000)
    mcp.call('pause')
    check(res.get('stopped') != 'timeout', '%s: Ctrl+] back in CP/M' % name)


def main():
    sym = emu.symbols()
    if os.path.exists(LOG):
        os.remove(LOG)
    srv = subprocess.Popen([sys.executable, '-I', os.path.join(emu.REPO, 'tools', 'testbbs.py'), '--port',
                            str(PORT), '--log', LOG], stdout=subprocess.DEVNULL)
    time.sleep(1)
    try:
        emu.use_machine('sapi1v_term')
        emu.checkpoint()
        for name in ['X.BIN'] + ['X%d.BIN' % n for n in range(1, 10)] + ['XMODEM%d.BIN' % n for n in range(1, 10)]:
            emu.command('SAVE 0 %s' % name)     # names taken: the typed X.BIN, later XMODEM.BIN
        mcp.call('resume')
        mcp.call('type_text', text='SAPITERM 127.0.0.1:%d\r' % PORT)
        check(run_until(lambda: log().get('menu', 0) >= 1, ms=15000), 'connected to the test BBS')

        keys('\x1d', 500)
        keys('l', 1500)
        check('LOG00.ANS' in term_text(sym), 'L: the log LOG00.ANS')
        keys('\x1b', 800)
        model = ansiref.Term()
        model.feed(testbbs.page_bytes('3'))
        keys('3', 100)
        check(run_until(lambda: screen_matches(sym, model), ms=10000), 'MENU on the screen')
        keys('\x1d', 500)
        keys('l', 1500)
        check('vypnutý' in term_text(sym), 'L again: the log off')
        keys('\x1b', 800)

        history(sym, fontgen.parse()['cp437'])
        download(sym, 'Y', 'Staženo: MENU1.ANS, 2 KB')
        download(sym, 'X', 'Staženo: MENU2.ANS, 2 KB', name='menu.ans')     # MENU.ANS, MENU1.ANS are there
        download(sym, 'X', 'Staženo: XMODEM.BIN, 2 KB. Nové jméno je obsazené.', name='x.bin')
        download(sym, 'X', 'Nestaženo, jméno je na disku i s číslicemi 1-9.', xfer='the client cancelled')

        keys('\x1d', 500)
        keys('k', 1500)
        res = mcp.call('run_until', screen_text='A>', timeout_ms=5000)
        check(res.get('stopped') != 'timeout', 'K: back in CP/M')
        mcp.call('pause')
    finally:
        srv.terminate()
    text = emu.command_lines('DIR')
    print('      ' + ' | '.join(ln for ln in text.split('\n') if 'LOG00' in ln or 'SUNSET-D' in ln or 'MENU1' in ln
                                or 'XMODEM' in ln or 'MENU2' in ln))

    view(sym, 'LOG00.ANS', model)
    view(sym, 'SUNSET-D.ANS', ansiref.run(testbbs.art_file('SUNSET')))
    view(sym, 'MENU1.ANS', ansiref.run(testbbs.art_file('MENU')))
    view(sym, 'MENU2.ANS', ansiref.run(testbbs.art_file('ANSITEST')))
    view(sym, 'XMODEM.BIN', ansiref.run(testbbs.art_file('ANSITEST')))
    if failed:
        sys.exit('%d check(s) failed' % len(failed))
    print('all checks passed')


if __name__ == '__main__':
    main()
