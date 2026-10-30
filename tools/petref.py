"""Reference model of the PETSCII terminal of SAPI-Term (src/pet.asm): 40x25, the C64 screen editor codes.

Term.feed(bytes) -> chr (screen code of the C64, bit 7 = the lower case set), att (background << 4 | colour,
reverse swaps them; the background is black), row, col. render() draws it like the CGA-1V of the emulator
(font_pet of tools/petfont.py, each dot 2x2, the colours of the C64 as 6 bits like the Bt476).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import petfont  # noqa: E402

COLS, ROWS = 40, 25
FG = 15
COLORS = [0x90, 0x05, 0x1C, 0x9F, 0x9C, 0x1E, 0x1F, 0x9E, 0x81, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B]
C64_RGB6 = [(0x00, 0x00, 0x00), (0x3F, 0x3F, 0x3F), (0x1A, 0x0D, 0x0A), (0x1C, 0x29, 0x2C), (0x1B, 0x0F, 0x21),
            (0x16, 0x23, 0x10), (0x0D, 0x0A, 0x1E), (0x2E, 0x31, 0x1B), (0x1B, 0x13, 0x09), (0x10, 0x0E, 0x00),
            (0x26, 0x19, 0x16), (0x11, 0x11, 0x11), (0x1B, 0x1B, 0x1B), (0x26, 0x34, 0x21), (0x1B, 0x17, 0x2D),
            (0x25, 0x25, 0x25)]


class Term:
    def __init__(self):
        self.fg, self.rvs, self.lower = FG, False, 0
        self.chr = [[0x20] * COLS for _ in range(ROWS)]
        self.att = [[self.attr()] * COLS for _ in range(ROWS)]
        self.pet = [[False] * COLS for _ in range(ROWS)]   # a PETSCII cell (blank ones are not)
        self.row = self.col = 0

    def attr(self):
        return self.fg << 4 if self.rvs else self.fg

    def blank(self):
        return [0x20] * COLS, [self.attr()] * COLS

    def down(self):
        if self.row == ROWS - 1:
            del self.chr[0]
            del self.att[0]
            del self.pet[0]
            c, a = self.blank()
            self.chr.append(c)
            self.att.append(a)
            self.pet.append([False] * COLS)
        else:
            self.row += 1

    def put(self, code):
        self.chr[self.row][self.col] = code | self.lower
        self.att[self.row][self.col] = self.attr()
        self.pet[self.row][self.col] = True
        self.col += 1
        if self.col == COLS:
            self.col = 0
            self.down()

    def feed(self, data):
        for b in data:
            self.byte(b)

    def byte(self, b):
        if 0x20 <= b < 0x80 or b >= 0xA0:
            if b == 0xFF:
                code = 0x5E
            elif b < 0x40:
                code = b
            elif b < 0x60:
                code = b - 0x40
            elif b < 0x80:
                code = b - 0x20
            elif b < 0xC0:
                code = b - 0x40
            else:
                code = b - 0x80
            self.put(code)
        elif b in COLORS:
            self.fg = COLORS.index(b)
        elif b in (0x0D, 0x8D):
            self.col = 0
            self.rvs = False
            self.down()
        elif b == 0x11:
            self.down()
        elif b == 0x91:
            self.row = max(0, self.row - 1)
        elif b == 0x1D:
            self.col += 1
            if self.col == COLS:
                self.col = 0
                self.down()
        elif b == 0x9D:
            if self.col:
                self.col -= 1
            elif self.row:
                self.row -= 1
                self.col = COLS - 1
        elif b == 0x13:
            self.row = self.col = 0
        elif b == 0x93:
            for r in range(ROWS):
                self.chr[r], self.att[r] = self.blank()
                self.pet[r] = [False] * COLS
            self.row = self.col = 0
        elif b == 0x12:
            self.rvs = True
        elif b == 0x92:
            self.rvs = False
        elif b == 0x14:
            if self.col:
                self.col -= 1
                r = self.row
                self.chr[r][self.col:] = self.chr[r][self.col + 1:] + [0x20]
                self.att[r][self.col:] = self.att[r][self.col + 1:] + [self.attr()]
                self.pet[r][self.col:] = self.pet[r][self.col + 1:] + [False]
        elif b == 0x94:
            r = self.row
            self.chr[r][self.col:] = [0x20] + self.chr[r][self.col:COLS - 1]
            self.att[r][self.col:] = [self.attr()] + self.att[r][self.col:COLS - 1]
            self.pet[r][self.col:] = [False] + self.pet[r][self.col:COLS - 1]
        elif b in (0x0E, 0x8E):
            low = 0x80 if b == 0x0E else 0
            if low != self.lower:
                self.lower = low
                self.chr = [[c & 0x7F | low if p else c for c, p in zip(cr, pr)]
                            for cr, pr in zip(self.chr, self.pet)]


def render(t, glyphs=None):
    """RGB bytes of 640x400 like the screenshot of the CGA-1V (a cell is 8x8 CGA dots, each 2x2)."""
    glyphs = glyphs or petfont.build()
    pal = [tuple((v << 2 | v >> 4) for v in c) for c in C64_RGB6]
    out = bytearray(640 * 400 * 3)
    for r in range(ROWS):
        for c in range(COLS):
            g = glyphs[t.chr[r][c]]
            a = t.att[r][c]
            fg, bg = pal[a & 15], pal[a >> 4]
            for y in range(8):
                for x in range(8):
                    col = bytes(fg if g[y][x] else bg) * 2
                    for dy in range(2):
                        p = ((r * 8 + y) * 2 + dy) * 640 + (c * 8 + x) * 2
                        out[p * 3:p * 3 + 6] = col
    return bytes(out)
