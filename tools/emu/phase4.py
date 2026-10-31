"""Phase 4 check: SAPI-Term on line with the local test BBS (tools/testbbs.py, started here).

"SAPITERM 127.0.0.1:6023" in CP/M: the telnet negotiation (TTYPE ANSI, NAWS 80x25, DO ECHO and SGA), pages of
the BBS on the screen equal to the reference model (shadow cell by cell, CGA-1V dot by dot), the position
report, the keys sent (Enter as CR NUL, arrows as ANSI sequences), the new size after swapping the cards, the
end of the connection by the BBS and the prompt again; then the errors: a refused port, an unknown name.
Needs the emulator with MCP (tools/emu/sapiemu.cmd) and build.cmd. Screenshots to build/preview/f4_*.png.
  python tools/emu/phase4.py
"""
import json
import os
import re
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
import fontgen  # noqa: E402
import testbbs  # noqa: E402
from phase3 import shadow  # noqa: E402

PORT = 6023
LOG = os.path.join(emu.REPO, 'build', 'testbbs.json')
PREVIEW = os.path.join(emu.REPO, 'build', 'preview')
failed = []


def check(ok, what):
    print(('ok    ' if ok else 'FAIL  ') + what)
    if not ok:
        failed.append(what)


def log():
    for _ in range(20):
        try:
            with open(LOG) as f:
                return json.load(f)
        except (OSError, ValueError):
            time.sleep(0.02)
    return {}


def run_until(cond, ms=20000, step=200):
    """Run the emulator until cond() is true (checked every step ms of emulation)."""
    mcp.call('resume')
    t = 0
    while t < ms:
        mcp.call('run_for', ms=step)
        t += step
        if cond():
            mcp.call('pause')
            return True
    mcp.call('pause')
    return False


def keys(text, ms=300):
    mcp.call('resume')
    mcp.call('type_text', text=text, run_ms=ms)
    mcp.call('pause')


def screen_matches(sym, model):
    rows = shadow(sym)
    return all(rows[r][0] == model.chr[r] and rows[r][1] == model.att[r] for r in range(25))


def page(sym, font, key, name):
    model = ansiref.Term()
    model.feed(testbbs.page_bytes(key))
    keys(key, 100)
    ok = run_until(lambda: screen_matches(sym, model), ms=30000, step=500)
    check(ok, '%s from the BBS: shadow screen equals the model' % name)
    diff, ms = picture(sym, font, model, os.path.join(PREVIEW, 'f4_%s.png' % name.lower()))
    check(diff == 0, '%s: CGA-1V picture equals the model (%d dots differ, after %d ms)' % (name, diff, ms))
    return model


def picture(sym, font, model, path):
    """Dots of the CGA-1V screenshot (kept in path) that differ from the model, the cursor cell taken as it is;
    the best of a few tries while the palette follows, and the ms it took."""
    want0 = ansiref.render(model, font)
    for t in range(15):                         # the palette may follow a few frames later
        mcp.call('run_for', ms=200)
        mcp.call('pause')
        emu.screenshot(path, display='CGA-1V')
        w, h, got = ansiref.png_rgb(path)
        want = want0
        cur = (emu.read(sym['cur_row'], 1)[0], emu.read(sym['cur_col'], 1)[0])
        if not model.cur_off:
            want, got = bytearray(want), bytearray(got)
            for y in range(16):
                for x in range(8):
                    p = ((cur[0] * 16 + y) * 640 + cur[1] * 8 + x) * 3
                    want[p:p + 3] = got[p:p + 3]
        diff = sum(1 for i in range(0, len(want), 3) if want[i:i + 3] != got[i:i + 3])
        if diff == 0:
            break
    return diff, (t + 1) * 200


def menu_on_terminal(sym, font, model):
    """Ctrl+]: the menu on the card of the terminal (the CGA-1V), the AND-1V keeps the status with the protocol, the
    time and the data on line; Esc: the terminal drawn again from the shadow equals the model."""
    from cgaread import term_text
    keys('\x1d', 800)
    text = term_text(sym, os.path.join(PREVIEW, 'f4_menu.png'))
    check('Menu (Ctrl+])' in text and 'O  odpojit' in text and 'Esc' in text, 'Ctrl+]: the menu on the CGA-1V')
    status = mcp.call('screen_text')
    check('Menu' not in status and 'BBS: 127.0.0.1' in status, 'the menu: the status stays on the AND-1V')
    check(re.search(r'Protokol:\s+telnet', status), 'the status card: the protocol')
    check(re.search(r'Spojení:\s+0:\d\d:\d\d', status), 'the status card: the time on line')
    m = re.search(r'Přijato:\s+(\d+) KB, \d+,\d KB/s', status)
    check(m and int(m.group(1)) >= 10, 'the status card: the data received (%s)' % (m.group(0) if m else None))
    keys('\x1b', 1500)
    diff, ms = picture(sym, font, model, os.path.join(PREVIEW, 'f4_after_menu.png'))
    check(diff == 0, 'Esc: the terminal drawn again equals the model (%d dots differ)' % diff)


def main():
    os.makedirs(PREVIEW, exist_ok=True)
    sym = emu.symbols()
    font = fontgen.parse()['cp437']
    srv = subprocess.Popen([sys.executable, '-I', os.path.join(emu.REPO, 'tools', 'testbbs.py'), '--port',
                            str(PORT), '--log', LOG], stdout=subprocess.DEVNULL)
    time.sleep(1)
    try:
        emu.use_machine('sapi1v_term')
        emu.checkpoint()
        mcp.call('resume')
        mcp.call('type_text', text='SAPITERM 127.0.0.1:%d\r' % PORT)
        check(run_until(lambda: log().get('menu', 0) >= 1, ms=15000), 'connected, the BBS sent its menu')
        mcp.call('run_for', ms=500)
        mcp.call('pause')
        lg = log()
        check(lg.get('ttype') == 'ANSI', 'TTYPE: %r' % lg.get('ttype'))
        check(lg.get('naws') == [[80, 25]], 'NAWS: %r' % lg.get('naws'))
        check(set(lg.get('client_will', [])) >= {testbbs.TTYPE, testbbs.NAWS}, 'WILL TTYPE, NAWS')
        check(set(lg.get('client_do', [])) >= {testbbs.ECHO, testbbs.SGA}, 'DO ECHO, SGA')
        check('BBS: 127.0.0.1:6023' in mcp.call('screen_text'), 'status card: the BBS')
        emu.screenshot(os.path.join(PREVIEW, 'f4_menu_bbs.png'), display='CGA-1V')

        page(sym, font, '2', 'SUNSET')
        page(sym, font, '4', 'SCROLL')
        model = page(sym, font, '1', 'ANSITEST')
        menu_on_terminal(sym, font, model)

        keys('C', 100)
        check(run_until(lambda: log().get('cpr') is not None, ms=5000), 'position report answered')
        check(log().get('cpr') == '\x1b[10;20R', 'position report: %r' % log().get('cpr'))
        keys('D', 100)
        check(run_until(lambda: log().get('da') is not None, ms=5000), 'device attributes answered')
        check(log().get('da') == '\x1b[?1;0c', 'device attributes: %r' % log().get('da'))

        keys('E', 300)
        before = len(log().get('keys', ''))
        keys('Ahoj\r', 600)
        mcp.call('press_key', key='up', run_ms=300)
        mcp.call('pause')
        sent = bytes.fromhex(log().get('keys', '')[before:])
        check(b'Ahoj\r\x00' in sent, 'Enter as CR NUL: %r' % sent)
        check(b'\x1b[A' in sent, 'arrow up as ESC [ A')
        keys('!', 500)

        keys('\x1d', 500)                       # the menu: Tab swaps the cards, the BBS gets 64x20
        keys('\t', 3000)
        check(run_until(lambda: log().get('naws', [])[-1:] == [[64, 20]], ms=5000), 'Tab: NAWS 64x20')
        keys('\x1b', 500)
        keys('\x1d', 500)
        keys('\t', 3000)
        check(run_until(lambda: log().get('naws', [])[-1:] == [[80, 25]], ms=5000), 'Tab again: NAWS 80x25')
        keys('\x1b', 500)

        keys('Q', 100)
        check(run_until(lambda: log().get('closed'), ms=5000), 'Q: the BBS closed the connection')
        check(run_until(lambda: 'BBS:' in bytes(shadow(sym)[18][0]).decode('cp437'), ms=8000),
              'back at the prompt')
        check('BBS' in bytes(shadow(sym)[6][0]).decode('cp437').upper(), 'message: the BBS ended it')

        keys('127.0.0.1:%d\r' % (PORT + 1), 300)  # nobody listens there
        check(run_until(lambda: 'P?ipojen? se nepoda?ilo' in row_koi(sym, 6), ms=20000), 'refused port: message')
        keys('neexistuje.invalid\r', 300)
        check(run_until(lambda: 'Adresu se nepoda?ilo' in row_koi(sym, 6), ms=20000), 'unknown name: message')

        keys('\x1d', 1500)
        keys('k', 1500)
        res = mcp.call('run_until', screen_text='A>', timeout_ms=5000)
        check(res.get('stopped') != 'timeout', 'Ctrl+] and K at the prompt return to CP/M')
        mcp.call('pause')
    finally:
        srv.terminate()
    if failed:
        sys.exit('%d check(s) failed' % len(failed))
    print('all checks passed')


def row_koi(sym, r):
    """Row r of the shadow, KOI letters as '?'."""
    offs = emu.read(sym['row_off'] + 2 * r, 2)
    o = offs[0] | offs[1] << 8
    chars = emu.read(sym['scr_chr'] + o, 80)
    ext = emu.read(sym['scr_ext'] + o, 80)
    return ''.join('?' if e & 1 else chr(c) for c, e in zip(chars, ext))


if __name__ == '__main__':
    main()
