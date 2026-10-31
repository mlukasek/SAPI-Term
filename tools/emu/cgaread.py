"""Text of the CGA-1V read from a screenshot: each cell is matched against the glyphs SAPI-Term draws there (the font
4x8 in 80 columns; in 40 columns the font of the MZ-800 and the font 4x8 with its dots doubled), CP437 and the Czech
letters of KOI-8cs2. For the tests: the menu and the status drawn on the CGA-1V are not in the shadow.
  term_text(sym) -> the text of the card of the terminal (the AND-1V by MCP screen_text, the CGA-1V read here)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..'))
import emu  # noqa: E402
from emu import mcp  # noqa: E402
import ansiref  # noqa: E402
import fontgen  # noqa: E402
import mzfont  # noqa: E402
import tables  # noqa: E402

DEV_AND = 2
_tables = {}


def _cp(code):
    return bytes([code]).decode('cp437')


def glyph_table(wide):
    """{dots (rows of bools): character} for 80 (wide 0) or 40 columns; ASCII wins over look-alikes."""
    if wide in _tables:
        return _tables[wide]
    banks = fontgen.parse()
    cp, koi = banks['cp437'], banks['koi8cs']
    out = {}

    def add(dots, ch):
        out.setdefault(tuple(tuple(r) for r in dots), ch)
    if not wide:
        def m4(rows):
            return [[ch == '#' for ch in r] for r in rows]
        for c in range(0x20, 0x7F):
            add(m4(cp[c]), _cp(c))
        for c in sorted(koi):
            add(m4(koi[c]), tables.KOI_REV.get(c, '?'))
        for c in range(256):
            add(m4(cp[c]), _cp(c))
    else:
        mz = mzfont.build()
        for c in range(0x20, 0x7F):
            add(mz['cp437'][c], _cp(c))
        for c, g in mz['koi'].items():
            if c in tables.KOI_REV:
                add(g, tables.KOI_REV[c])
        for c, g in mz['cp437'].items():
            add(g, _cp(c))
        for c in range(256):
            add([[r[x // 2] == '#' for x in range(8)] for r in cp[c]], _cp(c))
    _tables[wide] = out
    return out


def cga_text(rgb, wide, width=640):
    """25 lines of the CGA-1V picture rgb (640x400, each dot 2x2), 80 or 40 (wide) columns."""
    cw = 8 if wide else 4
    table = glyph_table(wide)
    lines = []
    for r in range(25):
        line = ''
        for c in range(80 // (2 if wide else 1)):
            dots = []
            for y in range(8):
                p0 = ((r * 8 + y) * 2 * width + c * cw * 2) * 3
                dots.append([bytes(rgb[p0 + x * 6:p0 + x * 6 + 3]) for x in range(cw)])
            colours = {d for row in dots for d in row}
            if len(colours) == 1:
                line += ' '
                continue
            ch = '?'
            for fg in colours:
                found = table.get(tuple(tuple(d == fg for d in row) for row in dots))
                if found:
                    ch = found
                    if found.strip():
                        break
            line += ch
        lines.append(line.rstrip())
    return lines


def term_text(sym, path=None):
    """The text of the card of the terminal; the CGA-1V screenshot is kept in path (build/preview/term_text.png)."""
    if emu.read(sym['term_dev'], 1)[0] == DEV_AND:
        return mcp.call('screen_text')
    path = path or os.path.join(emu.REPO, 'build', 'preview', 'term_text.png')
    emu.screenshot(path, display='CGA-1V')
    w, h, rgb = ansiref.png_rgb(path)
    return '\n'.join(cga_text(rgb, emu.read(sym['cga_wide'], 1)[0], w))
