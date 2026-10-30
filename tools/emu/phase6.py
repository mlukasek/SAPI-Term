"""Phase 6 check: blinking text and the speed of the line.

With the local test BBS (tools/testbbs.py, started here): the blink page without iCE (SGR 5, backgrounds
100-107) on the shadow screen as the model says, the CGA-1V picture seen in both phases of the blink (each equal
to the model drawn with the text shown or hidden); with iCE the same page has bright backgrounds and does not
blink. Menu R to 2400 Bd: the MENU page takes its time at 240 bytes a second and ends equal to the model. Back
in CP/M "SAPITERM MENU.ANS" shows the file at the same speed (SPEED=2400 in SAPITERM.CFG). Needs the emulator
with MCP (tools/emu/sapiemu.cmd) and build.cmd. Screenshots to build/preview/f6_*.png.
  python tools/emu/phase6.py
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
import fontgen  # noqa: E402
import testbbs  # noqa: E402
from phase3 import shadow  # noqa: E402
from phase4 import check, failed, keys, log, run_until, screen_matches, LOG, PORT  # noqa: E402

PREVIEW = os.path.join(emu.REPO, 'build', 'preview')
CPS_2400 = 240


def picture(sym, model, font, blink_on, path):
    """Number of dots of the CGA-1V screenshot that differ from the model (the cursor cell not compared)."""
    emu.screenshot(path, display='CGA-1V')
    w, h, got = ansiref.png_rgb(path)
    want = bytearray(ansiref.render(model, font, blink_on))
    got = bytearray(got)
    cur = (emu.read(sym['cur_row'], 1)[0], emu.read(sym['cur_col'], 1)[0])
    for y in range(16):
        for x in range(8):
            p = ((cur[0] * 16 + y) * 640 + cur[1] * 8 + x) * 3
            want[p:p + 3] = got[p:p + 3]
    return sum(1 for i in range(0, len(want), 3) if want[i:i + 3] != got[i:i + 3])


def blink(sym, font):
    model = ansiref.Term()
    model.feed(testbbs.blink_bytes(False))
    keys('B', 100)
    check(run_until(lambda: screen_matches(sym, model), ms=10000), 'blink page: shadow equals the model')
    row0 = shadow(sym)[0][1]
    check(any(a & 0x80 for a in row0), 'blink page: bit 7 in the attributes of the blinking text')
    seen = {}
    for _ in range(60):                         # 6 s: both phases, each equal to the model
        mcp.call('run_for', ms=100)
        mcp.call('pause')
        for phase in (True, False):
            if phase not in seen:
                path = os.path.join(PREVIEW, 'f6_blink_%s.png' % ('on' if phase else 'off'))
                if picture(sym, model, font, phase, path) == 0:
                    seen[phase] = True
        if len(seen) == 2:
            break
    check(seen.get(True), 'blink: the picture with the blinking text shown')
    check(seen.get(False), 'blink: the picture with the blinking text hidden')

    model = ansiref.Term()
    model.feed(testbbs.blink_bytes(True))
    keys('I', 100)
    check(run_until(lambda: screen_matches(sym, model), ms=10000), 'iCE page: shadow equals the model')
    diffs = []
    for _ in range(10):                         # 2 s: always bright backgrounds, nothing blinks
        mcp.call('run_for', ms=200)
        mcp.call('pause')
        diffs.append(picture(sym, model, font, True, os.path.join(PREVIEW, 'f6_ice.png')))
    check(diffs[1:] == [0] * 9, 'iCE: bright backgrounds, no blinking (dots differing: %s)' % diffs)


def timed_page(sym, key, model):
    """Emulated seconds until the shadow equals the model after key."""
    c0 = mcp.call('machine_info')['cycles']
    keys(key, 50)
    ok = run_until(lambda: screen_matches(sym, model), ms=60000, step=100)
    return ok, (mcp.call('machine_info')['cycles'] - c0) / 4e6


def main():
    os.makedirs(PREVIEW, exist_ok=True)
    sym = emu.symbols()
    font = fontgen.parse()['cp437']
    if os.path.exists(LOG):
        os.remove(LOG)
    srv = subprocess.Popen([sys.executable, '-I', os.path.join(emu.REPO, 'tools', 'testbbs.py'), '--port',
                            str(PORT), '--log', LOG], stdout=subprocess.DEVNULL)
    time.sleep(1)
    try:
        emu.use_machine('sapi1v_term')
        emu.checkpoint()
        mcp.call('resume')
        mcp.call('type_text', text='SAPITERM 127.0.0.1:%d\r' % PORT)
        check(run_until(lambda: log().get('menu', 0) >= 1, ms=15000), 'connected to the test BBS')
        blink(sym, font)

        model = ansiref.Term()
        model.feed(testbbs.page_bytes('3'))
        ok, secs = timed_page(sym, '3', model)
        check(ok and secs < 2, 'MENU at full speed: %.2f s' % secs)
        keys('\x1d', 500)
        for _ in range(5):                      # MAX, 38400, 19200, 9600, 4800, 2400
            keys('r', 400)
        check(emu.read(sym['speed'], 1)[0] == 5, 'R five times: 2400 Bd')
        check('2400 Bd' in mcp.call('screen_text'), 'the menu shows 2400 Bd')
        check(emu.read(sym['js_enable'], 1)[0] == 0, 'no jump scroll at 2400 Bd')
        keys('\x1b', 500)
        model = ansiref.Term()
        model.feed(testbbs.page_bytes('3'))
        want = len(testbbs.page_bytes('3')) / CPS_2400
        ok, secs = timed_page(sym, '3', model)
        check(ok, 'MENU at 2400 Bd: the screen equals the model')
        check(abs(secs - want) < 0.1 * want + 0.3, 'MENU at 2400 Bd: %.2f s (%d B at 240 B/s = %.2f s)'
              % (secs, len(testbbs.page_bytes('3')), want))
        emu.screenshot(os.path.join(PREVIEW, 'f6_menu_2400.png'), display='CGA-1V')

        keys('\x1d', 500)
        keys('k', 1500)
        res = mcp.call('run_until', screen_text='A>', timeout_ms=5000)
        check(res.get('stopped') != 'timeout', 'K: back in CP/M')
        mcp.call('pause')
    finally:
        srv.terminate()

    data = open(os.path.join(emu.REPO, 'build', 'art', 'MENU.ANS'), 'rb').read()
    model = ansiref.run(data)
    art = data[:data.find(b'\x1a')] if b'\x1a' in data else data
    mcp.call('resume')
    mcp.call('type_text', text='SAPITERM MENU.ANS\r')
    mcp.call('run_for', ms=600)                 # the typing (as phase3.py)
    c0 = mcp.call('machine_info')['cycles']
    ok = run_until(lambda: emu.read(sym['view_state'], 1)[0] == 1, ms=30000, step=100)
    secs = (mcp.call('machine_info')['cycles'] - c0) / 4e6
    want = len(art) / CPS_2400
    check(ok and screen_matches(sym, model), 'MENU.ANS at 2400 Bd: the screen equals the model')
    check(want - 0.1 < secs < want + 1.2, 'MENU.ANS at 2400 Bd: %.2f s (%d B: %.2f s, and the start of the program'
          ' about 0.9 s)' % (secs, len(art), want))
    mcp.call('resume')
    mcp.call('type_text', text='\x1d', run_ms=1500)
    res = mcp.call('run_until', screen_text='A>', timeout_ms=5000)
    mcp.call('pause')
    mcp.call('resume')
    mcp.call('type_text', text='TYPE SAPITERM.CFG\r', run_ms=3000)
    mcp.call('pause')
    check('SPEED=2400' in mcp.call('screen_text'), 'the file: SPEED=2400')
    if failed:
        sys.exit('%d check(s) failed' % len(failed))
    print('all checks passed')


if __name__ == '__main__':
    main()
