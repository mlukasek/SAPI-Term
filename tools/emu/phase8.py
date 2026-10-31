"""Phase 8 check: PETSCII (the terminal of a C64), ATASCII (of an Atari) and Viewdata (Prestel).

With the local test BBS (tools/testbbs.py, started here): menu Z seven times to PETSCII (40 columns, NAWS 40x25),
the PETSCII page G (colours, reverse, all graphics, cursor keys, DEL, INST, both letter sets, scrolling): the
shadow and the CGA-1V picture equal the model tools/petref.py (font_pet, the colours of the C64); keys as a C64
sends them; Tab: the page on the AND-1V, Tab: the CGA-1V picture again; U keeps the BBS with PETSCII, its number
connects in PETSCII at once; Z to ATASCII (40x24): the page A against
the model tools/ataref.py, the picture, keys as an Atari sends them; Z to VIEWDATA: the page V against
tools/vdtref.py, keys; Z back to CP437 (80x25). Needs the emulator with MCP (tools/emu/sapiemu.cmd) and
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
import ataref  # noqa: E402
import vdtref  # noqa: E402
import petfont  # noqa: E402
import petref  # noqa: E402
import testbbs  # noqa: E402
from phase3 import shadow  # noqa: E402
from phase4 import check, failed, keys, log, run_until, LOG, PORT  # noqa: E402
from phase5 import at_prompt  # noqa: E402
from cgaread import term_text  # noqa: E402

PREVIEW = os.path.join(emu.REPO, 'build', 'preview')
CS_PETSCII = 7
CS_ATASCII = 8
CS_VIEWDATA = 9


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


def ata_matches(sym, model):
    rows = shadow(sym)
    return all(rows[r][0][:40] == model.chr[r] and rows[r][1][:40] == model.att[r] for r in range(24))


def atascii(sym):
    """The ATASCII page A against the model tools/ataref.py, the picture, keys as an Atari sends them."""
    model = ataref.Term()
    model.feed(testbbs.ata_bytes())
    keys('a', 100)
    ok = run_until(lambda: ata_matches(sym, model), ms=20000, step=500)
    check(ok, 'the ATASCII page: shadow equals the model')
    if not ok:
        for r, (chars, atts) in enumerate(shadow(sym)[:24]):
            if chars[:40] != model.chr[r]:
                print('      em %2d %r' % (r, bytes(c if 0x20 <= c < 0x7F else 0x23 for c in chars[:40])))
                print('      mo %2d %r' % (r, bytes(c if 0x20 <= c < 0x7F else 0x23 for c in model.chr[r])))
    cur = (emu.read(sym['cur_row'], 1)[0], emu.read(sym['cur_col'], 1)[0])
    check(cur == (model.row, model.col), 'ATASCII: the cursor %s (the model %s)' % (cur, (model.row, model.col)))
    want0 = ataref.render(model)
    path = os.path.join(PREVIEW, 'f8_atascii.png')
    for _ in range(15):
        mcp.call('run_for', ms=200)
        mcp.call('pause')
        emu.screenshot(path, display='CGA-1V')
        w, h, got = ansiref.png_rgb(path)
        want, got = bytearray(want0), bytearray(got)
        for y in range(16):
            for x in range(16):
                p = ((cur[0] * 16 + y) * 640 + cur[1] * 16 + x) * 3
                want[p:p + 3] = got[p:p + 3]
        diff = sum(1 for i in range(0, len(want), 3) if want[i:i + 3] != got[i:i + 3])
        if diff == 0:
            break
    check(diff == 0, 'ATASCII: the CGA-1V picture equals the model (%d dots differ)' % diff)
    keys('e', 300)
    before = len(log().get('keys', ''))
    keys('Ab\r', 600)
    mcp.call('press_key', key='up', run_ms=300)
    mcp.call('pause')
    sent = bytes.fromhex(log().get('keys', '')[before:])
    check(sent.startswith(bytes([0x41, 0x62, 0x9B, 0x1C])), 'ATASCII keys: A b Enter up as 41 62 9B 1C (%s)'
          % sent.hex(' '))
    keys('!', 500)


def vdt_matches(sym, want):
    """The shadow (characters, attributes, flags of 40x24) equals the display of the model."""
    offs = emu.read(sym['row_off'], 48)
    chars = emu.read(sym['scr_chr'], 2000)
    atts = emu.read(sym['scr_att'], 2000)
    exts = emu.read(sym['scr_ext'], 2000)
    for r in range(24):
        o = offs[2 * r] | offs[2 * r + 1] << 8
        got = [(c, a, 8 if c == 0x20 and e == 0 else e)    # a space never written is a space of Viewdata
               for c, a, e in zip(chars[o:o + 40], atts[o:o + 40], exts[o:o + 40])]
        if got != want[r]:
            return False
    return True


def viewdata(sym):
    """The Viewdata page V against the model tools/vdtref.py (shadow, picture in either phase of flash), keys."""
    model = vdtref.Term()
    model.feed(testbbs.vdt_bytes())
    want = model.display()
    keys('v', 100)
    ok = run_until(lambda: vdt_matches(sym, want), ms=20000, step=500)
    check(ok, 'the Viewdata page: shadow equals the model')
    if not ok:
        offs = emu.read(sym['row_off'], 48)
        for r in range(24):
            o = offs[2 * r] | offs[2 * r + 1] << 8
            got = list(zip(emu.read(sym['scr_chr'] + o, 40), emu.read(sym['scr_att'] + o, 40),
                           emu.read(sym['scr_ext'] + o, 40)))
            if got != want[r]:
                c = next(i for i in range(40) if got[i] != want[r][i])
                print('      row %d col %d: emu %s model %s' % (r, c, got[c], want[r][c]))
    cur = (emu.read(sym['cur_row'], 1)[0], emu.read(sym['cur_col'], 1)[0])
    check(cur == (model.row, model.col), 'Viewdata: the cursor %s (the model %s)' % (cur, (model.row, model.col)))
    renders = [vdtref.render(model, True), vdtref.render(model, False)]
    path = os.path.join(PREVIEW, 'f8_viewdata.png')
    best = None
    for _ in range(15):
        mcp.call('run_for', ms=200)
        mcp.call('pause')
        emu.screenshot(path, display='CGA-1V')
        w, h, got = ansiref.png_rgb(path)
        for want_rgb in renders:
            diff = sum(1 for i in range(0, len(want_rgb), 3) if want_rgb[i:i + 3] != got[i:i + 3])
            best = diff if best is None else min(best, diff)
        if best == 0:
            break
    check(best == 0, 'Viewdata: the CGA-1V picture equals the model (%d dots differ)' % best)
    keys('e', 300)
    before = len(log().get('keys', ''))
    keys('Ab\r', 600)
    mcp.call('press_key', key='up', run_ms=300)
    mcp.call('pause')
    sent = bytes.fromhex(log().get('keys', '')[before:])
    check(sent.startswith(bytes([0x41, 0x62, 0x5F, 0x0B])), 'Viewdata keys: A b Enter up as 41 62 5F 0B (%s)'
          % sent.hex(' '))
    keys('!', 500)


def to_petscii(sym, presses):
    keys('\x1d', 500)
    for _ in range(presses):
        keys('z', 1500)
    check(emu.read(sym['cs_type'], 1)[0] == CS_PETSCII, 'Z: PETSCII')
    check('PETSCII' in term_text(sym), 'the menu shows PETSCII')
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
        mcp.call('type_text', text='SAPITERM\r')
        check(run_until(lambda: at_prompt(sym), ms=5000), 'the start screen')
        keys('-16\r', 300)                      # the default book is full: room for the BBS that U saves
        check(run_until(lambda: emu.read(sym['book_n'], 1)[0] == 15 and at_prompt(sym), ms=5000),
              '-16: room in the book')
        keys('127.0.0.1:%d\r' % PORT, 300)
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

        for raw in (False, True, False):        # FFh (pi): telnet one, raw TCP two (the test BBS doubles it)
            if raw != bool(emu.read(sym['tn_raw'], 1)[0]):
                keys('\x1d', 500)
                keys('n', 1500)
                keys('\x1b', 800)
            model = petref.Term()
            model.feed(b'\x93\x05\x8e\xff\xff' if raw else b'\x93\x05\x8e\xff')
            keys('f', 100)
            check(run_until(lambda: pet_matches(sym, model), ms=5000),
                  '%s: FFh as %s' % ('raw TCP' if raw else 'telnet', 'two pi' if raw else 'one pi'))
        keys('\x1d', 500)                       # U: the BBS with PETSCII; Z: ATASCII
        keys('u', 1500)
        keys('z', 2000)
        check(emu.read(sym['cs_type'], 1)[0] == CS_ATASCII, 'Z: ATASCII')
        check(emu.read(sym['term_cols'], 1)[0] == 40 and emu.read(sym['term_rows'], 1)[0] == 24, 'ATASCII: 40x24')
        check(run_until(lambda: log().get('naws', [])[-1:] == [[40, 24]], ms=5000), 'NAWS 40x24')
        keys('\x1b', 800)
        atascii(sym)
        keys('\x1d', 500)                       # Z: Viewdata
        keys('z', 2000)
        check(emu.read(sym['cs_type'], 1)[0] == CS_VIEWDATA, 'Z: VIEWDATA')
        check(emu.read(sym['term_cols'], 1)[0] == 40 and emu.read(sym['term_rows'], 1)[0] == 24, 'VIEWDATA: 40x24')
        keys('\x1b', 800)
        viewdata(sym)
        keys('\x1d', 500)                       # Z: CP437 again
        keys('z', 2000)
        check(emu.read(sym['cs_type'], 1)[0] == 0 and emu.read(sym['term_cols'], 1)[0] == 80, 'Z: CP437, 80 columns')
        check(run_until(lambda: log().get('naws', [])[-1:] == [[80, 25]], ms=5000), 'NAWS 80x25')
        keys('o', 300)
        check(run_until(lambda: emu.read(sym['mode'], 1)[0] == 0, ms=8000), 'O: disconnected')
        n = log().get('connects', 0)
        keys('16\r', 300)                       # the new entry of the book
        check(run_until(lambda: log().get('connects', 0) > n and log().get('menu', 0) >= 1, ms=15000),
              '16: connected again')
        check(emu.read(sym['cs_type'], 1)[0] == CS_PETSCII and emu.read(sym['cga_wide'], 1)[0] == 1,
              '16: PETSCII from the book, 40 columns')
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
