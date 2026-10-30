"""Phase 8 check: PETSCII (the terminal of a C64).

With the local test BBS (tools/testbbs.py, started here): menu Z seven times to PETSCII (40 columns, NAWS 40x25),
the PETSCII page G (colours, reverse, all graphics, cursor keys, DEL, INST, both letter sets, scrolling): the
shadow and the CGA-1V picture equal the model tools/petref.py (font_pet, the colours of the C64); keys as a C64
sends them; Tab: the page on the AND-1V, Tab: the CGA-1V picture again; U keeps the BBS with PETSCII, its number
connects in PETSCII at once; Z back to CP437 (80x25). Needs the emulator with MCP (tools/emu/sapiemu.cmd) and
build.cmd. Screenshots to build/preview/f8_*.png.
  python tools/emu/phase8.py
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
import petfont  # noqa: E402
import petref  # noqa: E402
import testbbs  # noqa: E402
from phase3 import shadow  # noqa: E402
from phase4 import check, failed, keys, log, run_until, LOG, PORT  # noqa: E402

PREVIEW = os.path.join(emu.REPO, 'build', 'preview')
CS_PETSCII = 7


def pet_matches(sym, model):
    """Characters of the 40 columns equal; attributes where a cell is seen (a blank one on black is the same
    whatever its colour of text, and the hidden columns 40-79 may differ after DEL)."""
    for (chars, atts), mc, ma in zip(shadow(sym), model.chr, model.att):
        for c in range(40):
            if chars[c] != mc[c]:
                return False
            blank = (mc[c] & 0x7F) == 0x20 and atts[c] >> 4 == 0 and ma[c] >> 4 == 0
            if not blank and atts[c] != ma[c]:
                return False
    return True


def picture(sym, model, glyphs, path):
    want0 = petref.render(model, glyphs)
    for _ in range(15):
        mcp.call('run_for', ms=200)
        mcp.call('pause')
        emu.screenshot(path, display='CGA-1V')
        w, h, got = ansiref.png_rgb(path)
        want, got = bytearray(want0), bytearray(got)
        cur = (emu.read(sym['cur_row'], 1)[0], emu.read(sym['cur_col'], 1)[0])
        for y in range(16):
            for x in range(16):
                p = ((cur[0] * 16 + y) * 640 + cur[1] * 16 + x) * 3
                want[p:p + 3] = got[p:p + 3]
        diff = sum(1 for i in range(0, len(want), 3) if want[i:i + 3] != got[i:i + 3])
        if diff == 0:
            break
    return diff


def to_petscii(sym, presses):
    keys('\x1d', 500)
    for _ in range(presses):
        keys('z', 1500)
    check(emu.read(sym['cs_type'], 1)[0] == CS_PETSCII, 'Z: PETSCII')
    check('PETSCII' in mcp.call('screen_text'), 'the menu shows PETSCII')
    keys('\x1b', 800)


def main():
    sym = emu.symbols()
    glyphs = petfont.build()
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
        to_petscii(sym, 7)
        check(emu.read(sym['cga_wide'], 1)[0] == 1 and emu.read(sym['term_cols'], 1)[0] == 40, '40 columns')
        check(run_until(lambda: log().get('naws', [])[-1:] == [[40, 25]], ms=5000), 'NAWS 40x25')

        model = petref.Term()
        model.feed(testbbs.pet_bytes())
        keys('g', 100)
        check(run_until(lambda: pet_matches(sym, model), ms=20000, step=500), 'the PETSCII page: shadow equals the model')
        cur = (emu.read(sym['cur_row'], 1)[0], emu.read(sym['cur_col'], 1)[0])
        check(cur == (model.row, model.col), 'the cursor %s (the model %s)' % (cur, (model.row, model.col)))
        diff = picture(sym, model, glyphs, os.path.join(PREVIEW, 'f8_petscii.png'))
        check(diff == 0, 'the CGA-1V picture equals the model (%d dots differ)' % diff)

        keys('e', 300)                          # echo: keys as a C64 sends them
        before = len(log().get('keys', ''))
        keys('Ahoj', 600)
        mcp.call('press_key', key='up', run_ms=300)
        mcp.call('pause')
        sent = bytes.fromhex(log().get('keys', '')[before:])
        check(sent.startswith(bytes([0xC1, 0x48, 0x4F, 0x4A, 0x91])), 'keys: A h o j up as C1 48 4F 4A 91 (%s)'
              % sent.hex(' '))
        keys('!', 500)
        model = petref.Term()
        model.feed(testbbs.pet_bytes())
        keys('g', 100)
        check(run_until(lambda: pet_matches(sym, model), ms=20000, step=500), 'the page again')

        keys('\x1d', 500)                       # Tab: the AND-1V
        keys('\t', 3000)
        keys('\x1b', 1500)
        text = mcp.call('screen_text')
        check('LINE 11' in text and '123I45' in text, 'Tab: the page on the AND-1V')
        check(run_until(lambda: log().get('naws', [])[-1:] == [[40, 20]], ms=5000), 'NAWS 40x20 on the AND-1V')
        keys('\x1d', 500)
        keys('\t', 4000)
        keys('\x1b', 1500)
        model = petref.Term()
        model.feed(testbbs.pet_bytes())
        keys('g', 100)
        check(run_until(lambda: pet_matches(sym, model), ms=20000, step=500), 'Tab again: the page on the CGA-1V')
        diff = picture(sym, model, glyphs, os.path.join(PREVIEW, 'f8_petscii_again.png'))
        check(diff == 0, 'Tab again: the colours of the C64 (%d dots differ)' % diff)

        keys('\x1d', 500)                       # U: the BBS with PETSCII; Z: CP437 again
        keys('u', 1500)
        keys('z', 2000)
        check(emu.read(sym['cs_type'], 1)[0] == 0 and emu.read(sym['term_cols'], 1)[0] == 80, 'Z: CP437, 80 columns')
        check(run_until(lambda: log().get('naws', [])[-1:] == [[80, 25]], ms=5000), 'NAWS 80x25')
        keys('o', 300)
        check(run_until(lambda: emu.read(sym['mode'], 1)[0] == 0, ms=8000), 'O: disconnected')
        n = log().get('connects', 0)
        keys('15\r', 300)                       # the new entry of the book
        check(run_until(lambda: log().get('connects', 0) > n and log().get('menu', 0) >= 1, ms=15000),
              '15: connected again')
        check(emu.read(sym['cs_type'], 1)[0] == CS_PETSCII and emu.read(sym['cga_wide'], 1)[0] == 1,
              '15: PETSCII from the book, 40 columns')
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
