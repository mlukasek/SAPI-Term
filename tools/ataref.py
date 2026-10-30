"""Reference model of the ATASCII terminal of SAPI-Term (src/ata.asm): 40x24, the Atari screen editor codes.

Term.feed(bytes) -> chr (ATASCII 00h-7Fh), att (01h, inverse 10h: colour 1 on 0 of the Atari colours), row, col.
render() draws it like the CGA-1V of the emulator (font_ata of tools/atafont.py, each dot 2x2, 6 bit colours).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import atafont  # noqa: E402

COLS, ROWS = 40, 24
ATT, INV = 0x01, 0x10
ATA_RGB6 = {0: (0x00, 0x0E, 0x22), 1: (0x20, 0x30, 0x3F)}


class Term:
    def __init__(self):
        self.chr = [[0x20] * COLS for _ in range(ROWS)]
        self.att = [[ATT] * COLS for _ in range(ROWS)]
        self.row = self.col = 0
        self.esc = False

    def blank(self):
        return [0x20] * COLS, [ATT] * COLS

    def down(self):
        if self.row == ROWS - 1:
            del self.chr[0]
            del self.att[0]
            c, a = self.blank()
            self.chr.append(c)
            self.att.append(a)
        else:
            self.row += 1

    def put(self, b):
        self.chr[self.row][self.col] = b & 0x7F
        self.att[self.row][self.col] = INV if b & 0x80 else ATT
        self.col += 1
        if self.col == COLS:
            self.col = 0
            self.down()

    def feed(self, data):
        for b in data:
            self.byte(b)

    def byte(self, b):
        if self.esc:
            self.esc = False
            self.put(b)
        elif b == 0x1B:
            self.esc = True
        elif b == 0x1C:
            self.row = (self.row - 1) % ROWS
        elif b == 0x1D:
            self.row = (self.row + 1) % ROWS
        elif b == 0x1E:
            self.col = (self.col - 1) % COLS
        elif b == 0x1F:
            self.col = (self.col + 1) % COLS
        elif b == 0x7D:
            for r in range(ROWS):
                self.chr[r], self.att[r] = self.blank()
            self.row = self.col = 0
        elif b == 0x7E:
            if self.col:
                self.col -= 1
                self.chr[self.row][self.col], self.att[self.row][self.col] = 0x20, ATT
        elif b == 0x7F:
            self.col = (self.col | 7) + 1
            if self.col >= COLS:
                self.col = 0
                self.down()
        elif b == 0x9B:
            self.col = 0
            self.down()
        elif b == 0x9C:
            del self.chr[self.row]
            del self.att[self.row]
            c, a = self.blank()
            self.chr.append(c)
            self.att.append(a)
            self.col = 0
        elif b == 0x9D:
            del self.chr[ROWS - 1]
            del self.att[ROWS - 1]
            c, a = self.blank()
            self.chr.insert(self.row, c)
            self.att.insert(self.row, a)
        elif b in (0x9E, 0x9F, 0xFD):
            pass
        elif b == 0xFE:
            r, c = self.row, self.col
            self.chr[r][c:] = self.chr[r][c + 1:] + [0x20]
            self.att[r][c:] = self.att[r][c + 1:] + [ATT]
        elif b == 0xFF:
            r, c = self.row, self.col
            self.chr[r][c:] = [0x20] + self.chr[r][c:COLS - 1]
            self.att[r][c:] = [ATT] + self.att[r][c:COLS - 1]
        else:
            self.put(b)


def render(t, glyphs=None):
    """RGB bytes of 640x400 like the screenshot of the CGA-1V (24 rows of 8x8 cells, each dot 2x2; the 25th text
    row of the card stays as SAPI-Term cleared it: the colour 0)."""
    glyphs = glyphs or atafont.build()
    pal = {k: tuple((v << 2 | v >> 4) for v in c) for k, c in ATA_RGB6.items()}
    out = bytearray(bytes(pal[0]) * (640 * 400))
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
