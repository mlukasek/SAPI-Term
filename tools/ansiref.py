"""Reference model of the SAPI-Term ANSI terminal (src/ansi.asm, src/screen.asm) for the tests.

The same parser and the same screen operations as the Z80 code, on an 80x25 screen of characters (CP437) and
attributes (background << 4 | foreground, CGA colours). Any change in the asm must be made here too.
Also renders the expected CGA-1V picture (font 4x8, a dot 2x2 like the emulator's screenshot).
  python tools/ansiref.py FILE.ANS        prints the final screen (characters) and the attributes per domain
"""
import os
import sys
import zlib
import struct

COLS, ROWS = 80, 25
A2C = [0, 4, 2, 6, 1, 5, 3, 7]          # ANSI colour -> CGA colour
RGB6 = [(0, 0, 0), (0, 0, 42), (0, 42, 0), (0, 42, 42), (42, 0, 0), (42, 0, 42), (42, 21, 0), (42, 42, 42),
        (21, 21, 21), (21, 21, 63), (21, 63, 21), (21, 63, 63), (63, 21, 21), (63, 21, 63), (63, 63, 21),
        (63, 63, 63)]


class Term:
    def __init__(self, ice=False):
        self.ice = ice
        self.chr = [[0x20] * COLS for _ in range(ROWS)]
        self.att = [[0x07] * COLS for _ in range(ROWS)]
        self.row = self.col = 0
        self.wrap_pend = 0
        self.wrap_off = 0
        self.cur_off = 0
        self.reg_top, self.reg_bot = 0, ROWS - 1
        self.state = 0
        self.np = 0
        self.par = [0] * 8
        self.priv = 0
        self.inter = 0
        self.reset_sgr()
        self.sv_row = self.sv_col = 0
        self.sv_sgr = list(self.sgr)
        self.apply()
        self.max_pairs = [0] * 7                # the most attributes a domain had at once
        self.track = False
        self.history = []                       # (characters, attributes) of the rows scrolled off the top

    # --- screen ---
    def reset_sgr(self):
        self.sgr = [7, 0, 0, 0, 0, 0]           # fg, bg, bold, blink, rev, bghi

    def apply(self):
        fg, bg, bold, blink, rev, bghi = self.sgr
        f = A2C[fg & 7] | (8 if bold else 0)
        b = A2C[bg & 7] | (8 if bghi or blink else 0)  # bit 7: blink, or a bright background with iCE
        if rev:
            f, b = b, f
        self.cur_att = b << 4 | f

    def note(self):
        if not self.track:
            return
        for d in range(7):
            rows = range(4 * d, min(4 * d + 4, ROWS))
            n = len({self.att[r][c] for r in rows for c in range(COLS)})
            self.max_pairs[d] = max(self.max_pairs[d], n)

    def set(self, r, c, ch):
        self.chr[r][c] = ch
        self.att[r][c] = self.cur_att
        self.note()

    def blank_row(self):
        return [0x20] * COLS, [self.cur_att] * COLS

    def cls(self):
        for r in range(ROWS):
            self.chr[r], self.att[r] = self.blank_row()
        self.row = self.col = 0
        self.wrap_pend = 0
        self.reg_top, self.reg_bot = 0, ROWS - 1
        self.note()

    def erase(self, r, c, n):
        for i in range(c, min(c + n, COLS)):
            self.chr[r][i] = 0x20
            self.att[r][i] = self.cur_att
        self.note()

    def region_up(self, t, b):
        if t == 0:                              # a row that leaves the top of the screen: the history
            self.history.append((self.chr[0], self.att[0]))
        del self.chr[t]
        del self.att[t]
        ch, at = self.blank_row()
        self.chr.insert(b, ch)
        self.att.insert(b, at)
        self.note()

    def region_down(self, t, b):
        del self.chr[b]
        del self.att[b]
        ch, at = self.blank_row()
        self.chr.insert(t, ch)
        self.att.insert(t, at)
        self.note()

    def insert_chars(self, r, c, n):
        n = min(n, COLS - c)
        if n == 0:
            return
        self.chr[r][c:] = [0x20] * n + self.chr[r][c:COLS - n]
        self.att[r][c:] = [self.cur_att] * n + self.att[r][c:COLS - n]
        self.note()

    def delete_chars(self, r, c, n):
        n = min(n, COLS - c)
        if n == 0:
            return
        self.chr[r][c:] = self.chr[r][c + n:] + [0x20] * n
        self.att[r][c:] = self.att[r][c + n:] + [self.cur_att] * n
        self.note()

    def lf(self):
        if self.row == self.reg_bot:
            self.region_up(self.reg_top, self.reg_bot)
        elif self.row + 1 < ROWS:
            self.row += 1

    def ri(self):
        if self.row == self.reg_top:
            self.region_down(self.reg_top, self.reg_bot)
        elif self.row > 0:
            self.row -= 1

    def putc(self, ch):
        if self.wrap_pend:
            self.wrap_pend = 0
            self.col = 0
            self.lf()
        self.set(self.row, self.col, ch)
        if self.col == COLS - 1:
            if not self.wrap_off:
                self.wrap_pend = 1
        else:
            self.col += 1

    def set_row(self, v):
        self.row = min(v, ROWS - 1)
        self.wrap_pend = 0

    def set_col(self, v):
        self.col = min(v, COLS - 1)
        self.wrap_pend = 0

    # --- parser ---
    def feed(self, data):
        for b in data:
            self.byte(b)

    def byte(self, b):
        if self.state == 0:
            if b >= 0x20:
                self.putc(b)
            elif b == 0x1B:
                self.state = 1
            elif b == 0x0D:
                self.col = 0
                self.wrap_pend = 0
            elif b == 0x0A:
                self.wrap_pend = 0
                self.lf()
            elif b == 0x08:
                self.wrap_pend = 0
                if self.col:
                    self.col -= 1
            elif b == 0x09:
                self.wrap_pend = 0
                self.col = min((self.col + 8) & 0xF8, COLS - 1)
            elif b == 0x0C:
                self.cls()
            elif b in (0x07, 0x00):
                pass
            else:
                self.putc(b)
        elif self.state == 1:
            self.state = 0
            if b == ord('['):
                self.state = 2
                self.np = 0
                self.priv = self.inter = 0
                self.par = [0] * 8
            elif b == ord('7'):
                self.save()
            elif b == ord('8'):
                self.restore()
            elif b == ord('D'):
                self.wrap_pend = 0
                self.lf()
            elif b == ord('M'):
                self.wrap_pend = 0
                self.ri()
            elif b == ord('E'):
                self.col = 0
                self.wrap_pend = 0
                self.lf()
            elif b == ord('c'):
                self.ansi_reset()
                self.cls()
            elif b in b'()*+#%':
                self.state = 3
            elif b == 0x1B:
                self.state = 1
        elif self.state == 3:
            self.state = 0
        else:
            self.csi(b)

    def ansi_reset(self):
        self.state = 0
        self.wrap_off = self.cur_off = 0
        self.reset_sgr()
        self.sv_sgr = list(self.sgr)
        self.sv_row = self.sv_col = 0
        self.reg_top, self.reg_bot = 0, ROWS - 1
        self.apply()

    def save(self):
        self.sv_row, self.sv_col = self.row, self.col
        self.sv_sgr = list(self.sgr)

    def restore(self):
        self.set_row(self.sv_row)
        self.set_col(self.sv_col)
        self.sgr = list(self.sv_sgr)
        self.apply()

    def csi(self, b):
        if 0x30 <= b <= 0x39:
            p = self.par[self.np]
            self.par[self.np] = 255 if p >= 26 else min(255, p * 10 + b - 0x30)
        elif b in (0x3B, 0x3A):
            if self.np < 7:
                self.np += 1
        elif 0x3C <= b <= 0x3F:
            self.priv = b
        elif b >= 0x40:
            self.state = 0
            if b >= 0x7F or self.inter:
                return
            if self.priv == ord('?'):
                self.private(b)
            elif not self.priv:
                self.command(chr(b))
        elif b >= 0x20:
            self.inter = b
        elif b == 0x1B:
            self.state = 1
        elif b in (0x18, 0x1A):
            self.state = 0

    def private(self, b):
        if b not in (ord('h'), ord('l')):
            return
        c = 1 if b == ord('l') else 0
        if self.par[0] == 7:
            self.wrap_off = c
            self.wrap_pend = 0
        elif self.par[0] == 25:
            self.cur_off = c
        elif self.par[0] == 33:
            self.ice = not c
            self.apply()

    def command(self, f):
        p0 = self.par[0]
        p1 = p0 or 1
        p1b = self.par[1] or 1
        if f == 'A':
            self.set_row(max(self.row - p1, 0))
        elif f in 'Be':
            self.set_row(min(self.row + p1, 255))
        elif f in 'Ca':
            self.set_col(min(self.col + p1, 255))
        elif f == 'D':
            self.set_col(max(self.col - p1, 0))
        elif f == 'E':
            self.set_row(min(self.row + p1, 255))
            self.col = 0
        elif f == 'F':
            self.set_row(max(self.row - p1, 0))
            self.col = 0
        elif f in 'G`':
            self.set_col(p1 - 1)
        elif f == 'd':
            self.set_row(p1 - 1)
        elif f in 'Hf':
            self.set_col(p1b - 1)
            self.set_row(p1 - 1)
        elif f == 'J':
            if p0 == 0:
                self.erase(self.row, self.col, COLS - self.col)
                for r in range(self.row + 1, ROWS):
                    self.erase(r, 0, COLS)
            elif p0 == 1:
                self.erase(self.row, 0, self.col + 1)
                for r in range(self.row):
                    self.erase(r, 0, COLS)
            else:
                self.cls()
        elif f == 'K':
            if p0 == 0:
                self.erase(self.row, self.col, COLS - self.col)
            elif p0 == 1:
                self.erase(self.row, 0, self.col + 1)
            else:
                self.erase(self.row, 0, COLS)
        elif f in 'LM':
            if not (self.reg_top <= self.row <= self.reg_bot):
                return
            self.col = 0
            self.wrap_pend = 0
            for _ in range(min(p1, ROWS)):
                if f == 'L':
                    self.region_down(self.row, self.reg_bot)
                else:
                    self.region_up(self.row, self.reg_bot)
        elif f == '@':
            self.insert_chars(self.row, self.col, p1)
        elif f == 'P':
            self.delete_chars(self.row, self.col, p1)
        elif f == 'X':
            self.erase(self.row, self.col, min(p1, COLS - self.col))
        elif f in 'ST':
            for _ in range(min(p1, ROWS)):
                if f == 'S':
                    self.region_up(self.reg_top, self.reg_bot)
                else:
                    self.region_down(self.reg_top, self.reg_bot)
        elif f == 'm':
            self.sgr_params()
        elif f == 'r':
            top = p1 - 1
            bot = self.par[1] or ROWS
            bot = (bot if bot < ROWS else ROWS) - 1
            if top < bot:
                self.reg_top, self.reg_bot = top, bot
                self.row = self.col = 0
                self.wrap_pend = 0
        elif f == 's':
            self.save()
        elif f == 'u':
            self.restore()

    def sgr_params(self):
        n = self.np + 1
        i = 0
        while n:
            v = self.par[i]
            i += 1
            if v in (38, 48):
                n -= 1
                if n == 0:
                    break
                v2 = self.par[i]
                i += 1
                if v2 == 5:
                    c = 1
                elif v2 == 2:
                    c = 3
                else:
                    n -= 1
                    continue
                done = False
                while True:
                    n -= 1
                    if n == 0:
                        done = True
                        break
                    i += 1
                    c -= 1
                    if c == 0:
                        break
                if done:
                    break
                n -= 1
                continue
            self.sgr_one(v)
            n -= 1
        self.apply()

    def sgr_one(self, v):
        s = self.sgr
        if v == 0:
            self.reset_sgr()
        elif v == 1:
            s[2] = 1
        elif v == 22:
            s[2] = 0
        elif v in (5, 6):
            s[3] = 1
        elif v == 25:
            s[3] = 0
        elif v == 7:
            s[4] = 1
        elif v == 27:
            s[4] = 0
        elif v == 39:
            s[0] = 7
        elif v == 49:
            s[1] = 0
            s[5] = 0
        elif 30 <= v <= 37:
            s[0] = v - 30
        elif 40 <= v <= 47:
            s[1] = v - 40
            s[5] = 0
        elif 90 <= v <= 97:
            s[0] = v - 90
            s[2] = 1
        elif 100 <= v <= 107:
            s[1] = v - 100
            s[5] = 1


def strip_sauce(data):
    """(art bytes up to 1Ah, iCE flag of the SAUCE record)."""
    ice = False
    k = data.rfind(b'SAUCE00')
    if k >= 0 and len(data) - k >= 128:
        ice = bool(data[k + 105] & 1)
    end = data.find(b'\x1a')
    return (data if end < 0 else data[:end]), ice


def run(data):
    art, ice = strip_sauce(data)
    t = Term(ice)
    t.track = True
    t.feed(art)
    return t


def render(t, font_cp437, blink_on=True):
    """RGB bytes of 640x400 (a CGA dot = 2x2), like the emulator's screenshot of the CGA-1V. Without iCE bit 7
    of the attribute is blink: the background 0-7, the foreground hidden when not blink_on."""
    pal = [tuple((v << 2 | v >> 4) for v in c) for c in RGB6]
    out = bytearray(640 * 400 * 3)
    for r in range(ROWS):
        for c in range(COLS):
            g = font_cp437[t.chr[r][c]]
            a = t.att[r][c]
            fg, bg = pal[a & 15], pal[a >> 4]
            if not t.ice and a & 0x80:
                bg = pal[a >> 4 & 7]
                fg = fg if blink_on else bg
            for y in range(8):
                for x in range(4):
                    col = fg if g[y][x] == '#' else bg
                    for dy in range(2):
                        p = ((r * 8 + y) * 2 + dy) * 640 + (c * 4 + x) * 2
                        out[p * 3:p * 3 + 6] = bytes(col) * 2
    return bytes(out)


def png_rgb(path):
    """(width, height, RGB bytes) of a PNG (8-bit RGB or RGBA, any filter), standard library only."""
    data = open(path, 'rb').read()
    pos, idat, w = 8, b'', 0
    while pos < len(data):
        n = struct.unpack('>I', data[pos:pos + 4])[0]
        kind, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + n]
        pos += 12 + n
        if kind == b'IHDR':
            w, h, depth, ctype = struct.unpack('>IIBB', body[:10])
            assert depth == 8 and ctype in (2, 6), (depth, ctype)
            bpp = 3 if ctype == 2 else 4
        elif kind == b'IDAT':
            idat += body
    raw = zlib.decompress(idat)
    stride = w * bpp
    prev = bytearray(stride)
    out = bytearray()
    for y in range(h):
        f = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        prev = line
        if bpp == 4:
            out += b''.join(line[i:i + 3] for i in range(0, stride, 4))
        else:
            out += line
    return w, h, bytes(out)


def main():
    t = run(open(sys.argv[1], 'rb').read())
    for r in range(ROWS):
        print(bytes(t.chr[r]).decode('cp437').rstrip())
    print('cursor', t.row, t.col, 'max pairs per domain', t.max_pairs)


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
