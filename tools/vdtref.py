"""Reference model of the Viewdata terminal of SAPI-Term (src/vdt.asm): 40x24, serial attributes of teletext
level 1, mosaics, double height; nothing scrolls.

Term.feed(bytes) keeps the codes (raw); display() -> rows of (character, attribute, flags) as SAPI-Term puts
them into its shadow; render() draws them like the CGA-1V of the emulator (vdt glyphs: font_ata and vdt_extra
of tools/atafont.py for letters, 2x3 blocks for mosaics; each dot 2x2; the 8 colours of teletext, flash shown).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import atafont  # noqa: E402

COLS, ROWS = 40, 24
EXT_VDT, MOS, SEP, DHT, DHB = 0x08, 0x10, 0x20, 0x40, 0x80
RGB6 = [(0, 0, 0), (0x3F, 0, 0), (0, 0x3F, 0), (0x3F, 0x3F, 0), (0, 0, 0x3F), (0x3F, 0, 0x3F), (0, 0x3F, 0x3F),
        (0x3F, 0x3F, 0x3F)]
ALPHA = {0x23: ('x', 0), 0x5B: ('a', 0x1E), 0x5C: ('x', 1), 0x5D: ('a', 0x1F), 0x5E: ('a', 0x1C), 0x5F: ('a', 0x23),
         0x60: ('a', 0x12), 0x7B: ('x', 2), 0x7C: ('x', 4), 0x7D: ('x', 3), 0x7E: ('x', 5), 0x7F: ('x', 6)}


class Term:
    def __init__(self):
        self.raw = [[0x20] * COLS for _ in range(ROWS)]
        self.row = self.col = 0
        self.esc = False

    def feed(self, data):
        for b in data:
            self.byte(b)

    def byte(self, b):
        if self.esc:
            self.esc = False
            self.write(b & 0x1F | 0x80)
            return
        if 0x80 <= b < 0xA0:
            self.write(b)
            return
        b &= 0x7F
        if b >= 0x20:
            self.write(b)
        elif b == 0x1B:
            self.esc = True
        elif b == 0x08:
            if self.col:
                self.col -= 1
            else:
                self.col = COLS - 1
                self.row = (self.row - 1) % ROWS
        elif b == 0x09:
            self.right()
        elif b == 0x0A:
            self.row = (self.row + 1) % ROWS
        elif b == 0x0B:
            self.row = (self.row - 1) % ROWS
        elif b == 0x0C:
            self.raw = [[0x20] * COLS for _ in range(ROWS)]
            self.row = self.col = 0
        elif b == 0x0D:
            self.col = 0
        elif b == 0x1E:
            self.row = self.col = 0

    def right(self):
        self.col += 1
        if self.col == COLS:
            self.col = 0
            self.row = (self.row + 1) % ROWS

    def write(self, code):
        self.raw[self.row][self.col] = code
        self.right()

    @staticmethod
    def decode(raw):
        """[(character, attribute, flags)] of a row from its codes."""
        fg, bg, mos, sep, flash, dh, conc = 7, 0, 0, 0, 0, 0, 0
        out = []
        for code in raw:
            if code < 0x80:
                ch = code
            else:
                ch = 0x20
                if code == 0x89:
                    flash = 0
                elif code == 0x8C:
                    dh = 0
                elif code == 0x98:
                    conc = 1
                elif code == 0x99:
                    sep = 0
                elif code == 0x9A:
                    sep = SEP
                elif code == 0x9C:
                    bg = 0
                elif code == 0x9D:
                    bg = fg
            att = (0x80 if flash else 0) | bg << 4 | (bg if conc else fg)
            out.append((ch, att, EXT_VDT | mos | sep | dh))   # an attribute shows as a space
            if code >= 0x80:
                if code == 0x88:
                    flash = 1
                elif code == 0x8D:
                    dh = DHT
                elif 1 <= code & 0x0F <= 7:
                    fg, conc, mos = code & 0x0F, 0, code & MOS
        return out

    def display(self):
        rows, upper = [], False
        for r in range(ROWS):
            if upper:
                above = self.decode(self.raw[r - 1])
                row = []
                for ch, att, ext in above:
                    if ext & DHT:
                        row.append((ch, att, ext ^ (DHT | DHB)))
                    else:
                        bg = att >> 4 & 7
                        row.append((0x20, bg << 4 | bg, EXT_VDT))
                rows.append(row)
                upper = False
            else:
                row = self.decode(self.raw[r])
                rows.append(row)
                upper = any(ext & DHT for _, _, ext in row)
        return rows


def glyph(ch, ext, font=None, extra=None):
    """The 8 rows (bit 7 = left) SAPI-Term draws for a Viewdata cell (src/vdt.asm ga_vdt)."""
    font = font or [atafont.pf.glyph_bytes(g) for g in atafont.build()]
    extra = extra or [atafont.pf.glyph_bytes(g) for g in atafont.vdt_extra()]
    if ch >= 0x80:
        g = [0] * 8
    elif ext & MOS and ch & 0x20:
        def pair(bits):
            return (0xF0 if bits & 1 else 0) | (0x0F if bits & 2 else 0)
        g = [pair(ch & 3)] * 3 + [pair(ch >> 2 & 3)] * 2 + [pair(ch >> 4 & 1 | ch >> 5 & 2)] * 3
        if ext & SEP:
            g = [b & 0xEE for b in g]
            for r in (2, 4, 7):
                g[r] = 0
    elif ch in ALPHA:
        kind, i = ALPHA[ch]
        g = list(extra[i] if kind == 'x' else font[i])
    else:
        g = list(font[ch])
    if ext & DHT:
        g = [g[i // 2] for i in range(8)]
    elif ext & DHB:
        g = [g[4 + i // 2] for i in range(8)]
    return g


def render(t, flash_on=True):
    """RGB bytes of 640x400 like the screenshot of the CGA-1V (24 rows of 8x8 cells, each dot 2x2; the 25th row
    of the card as SAPI-Term cleared it: black). Flash: the colour hidden when not flash_on."""
    font = [atafont.pf.glyph_bytes(g) for g in atafont.build()]
    extra = [atafont.pf.glyph_bytes(g) for g in atafont.vdt_extra()]
    pal = [tuple((v << 2 | v >> 4) for v in c) for c in RGB6]
    out = bytearray(640 * 400 * 3)
    for r, row in enumerate(t.display()):
        for c, (ch, att, ext) in enumerate(row):
            g = glyph(ch, ext, font, extra)
            fg, bg = pal[att & 7], pal[att >> 4 & 7]
            if att & 0x80 and not flash_on:
                fg = bg
            for y in range(8):
                for x in range(8):
                    col = bytes(fg if g[y] & 0x80 >> x else bg) * 2
                    for dy in range(2):
                        p = ((r * 8 + y) * 2 + dy) * 640 + (c * 8 + x) * 2
                        out[p * 3:p * 3 + 6] = col
    return bytes(out)
