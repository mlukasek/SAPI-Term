"""Phase 3 check: the ANSI terminal against the reference model tools/ansiref.py.

For every test file of tools/mkart.py: "SAPITERM NAME.ANS" in CP/M, then the shadow screen (characters and
attributes of all 2000 cells, the cursor) must equal the model, and the screenshot of the CGA-1V must equal the
model drawn with the font and the palette, dot by dot (every domain of the files has at most 16 pairs).
Screenshots go to build/preview/f3_*.png. Needs the emulator with MCP (tools/emu/sapiemu.cmd) and build.cmd.
  python tools/emu/phase3.py [NAME ...]
"""
import os
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

NAMES = ['ANSITEST', 'SUNSET', 'MENU', 'SCROLL']
PREVIEW = os.path.join(emu.REPO, 'build', 'preview')
failed = []


def check(ok, what):
    print(('ok    ' if ok else 'FAIL  ') + what)
    if not ok:
        failed.append(what)


def shadow(sym):
    offs = emu.read(sym['row_off'], 50)
    chars = emu.read(sym['scr_chr'], 2000)
    atts = emu.read(sym['scr_att'], 2000)
    rows = []
    for r in range(25):
        o = offs[2 * r] | offs[2 * r + 1] << 8
        rows.append((list(chars[o:o + 80]), list(atts[o:o + 80])))
    return rows


def wait_shown(sym, timeout=60):
    t0 = time.time()
    mcp.call('resume')
    while time.time() - t0 < timeout:
        mcp.call('run_for', ms=500)
        if emu.read(sym['view_state'], 1)[0]:
            mcp.call('pause')
            return True
    mcp.call('pause')
    return False


def one(name, sym, font):
    data = open(os.path.join(emu.REPO, 'build', 'art', name + '.ANS'), 'rb').read()
    model = ansiref.run(data)
    emu.checkpoint()
    mcp.call('resume')
    mcp.call('type_text', text='SAPITERM %s.ANS\r' % name)
    mcp.call('run_for', ms=600)
    t0 = mcp.call('machine_info')['cycles']
    check(wait_shown(sym), '%s: shown' % name)
    cycles = mcp.call('machine_info')['cycles'] - t0
    mcp.call('run_for', ms=100)                 # a palette written in the last VBI shows in the next frame
    mcp.call('pause')
    cga = [c for c in mcp.call('machine_info')['cards'] if c['type'] == 'CGA-1V'][0]['details']
    check(cga['palette_writes_visible'] == 0,
          '%s: no palette write outside the VBI (%d)' % (name, cga['palette_writes_visible']))
    print('      %.1f s at 4 MHz for %d B' % (cycles / 4e6, len(data)))
    rows = shadow(sym)
    bad = [r for r in range(25) if rows[r][0] != model.chr[r]]
    check(not bad, '%s: characters of all rows%s' % (name, ' (rows %s differ)' % bad if bad else ''))
    for r in bad[:3]:
        print('      emu   %r' % bytes(rows[r][0]).decode('cp437'))
        print('      model %r' % bytes(model.chr[r]).decode('cp437'))
    bad = [r for r in range(25) if rows[r][1] != model.att[r]]
    check(not bad, '%s: attributes of all rows%s' % (name, ' (rows %s differ)' % bad if bad else ''))
    for r in bad[:2]:
        print('      emu   %s' % ' '.join('%02X' % a for a in rows[r][1]))
        print('      model %s' % ' '.join('%02X' % a for a in model.att[r]))
    cur = (emu.read(sym['cur_row'], 1)[0], emu.read(sym['cur_col'], 1)[0])
    check(cur == (model.row, model.col), '%s: cursor %s (model %s)' % (name, cur, (model.row, model.col)))
    path = os.path.join(PREVIEW, 'f3_%s.png' % name.lower())
    emu.screenshot(path, display='CGA-1V')
    w, h, got = ansiref.png_rgb(path)
    want = ansiref.render(model, font)
    if not model.cur_off:                       # the cursor cell may blink: not compared
        want = bytearray(want)
        got = bytearray(got)
        for y in range(16):
            for x in range(8):
                p = ((model.row * 8 * 2 + y) * 640 + model.col * 8 + x) * 3
                want[p:p + 3] = got[p:p + 3]
    diff = sum(1 for i in range(0, len(want), 3) if want[i:i + 3] != got[i:i + 3])
    check((w, h) == (640, 400) and diff == 0, '%s: CGA-1V picture equals the model (%d dots differ)' % (name, diff))
    mcp.call('resume')
    mcp.call('type_text', text='\x1d', run_ms=1500)
    res = mcp.call('run_until', screen_text='A>', timeout_ms=5000)
    check(res.get('stopped') != 'timeout', '%s: Ctrl+] returns to CP/M' % name)
    mcp.call('pause')


def main():
    os.makedirs(PREVIEW, exist_ok=True)
    sym = emu.symbols()
    font = fontgen.parse()['cp437']
    emu.use_machine('sapi1v_term')
    for name in sys.argv[1:] or NAMES:
        one(name, sym, font)
    if failed:
        sys.exit('%d check(s) failed' % len(failed))
    print('all checks passed')


if __name__ == '__main__':
    main()
