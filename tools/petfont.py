"""Font 8x8 of PETSCII for SAPI-Term (own design): build/font_pet.inc (+ a preview PNG).

256 glyphs indexed by the screen code of the C64 (0-127) with bit 7 = the lower case set: letters, digits and
punctuation are the font 4x8 of SAPI-Term with each dot doubled (fonts/sapiterm4x8.txt, so they look like the
rest of the terminal), the graphics are drawn here from what each character means (lines and blocks by eighths,
box drawing, quadrants, shades, a few symbols drawn by hand). Nothing is taken from a Commodore ROM.
Also and_map_pet: each glyph as a character of the AND-1V (64x20 alphanumeric, KOI-8cs2 and 2x3 graphics).
  python tools/petfont.py [--preview build/preview/font_pet.png]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fontgen  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEMI = 0x80                                     # AND-1V 2x3 graphics: 80h + bits (tables.py)


def grid(rows):
    return [[ch == '#' for ch in r] for r in rows]


def empty():
    return [[False] * 8 for _ in range(8)]


def cells(pred):
    return [[bool(pred(x, y)) for x in range(8)] for y in range(8)]


def mirror_x(g):
    return [list(reversed(r)) for r in g]


def mirror_y(g):
    return list(reversed(g))


def union(*gs):
    return [[any(g[y][x] for g in gs) for x in range(8)] for y in range(8)]


# box drawing: lines two dots thick through the middle (rows 3-4, columns 3-4)
def box(up, down, left, right):
    def p(x, y):
        mid_x, mid_y = x in (3, 4), y in (3, 4)
        return ((mid_x and (y <= 4 if up else False)) or (mid_x and (y >= 3 if down else False)) or
                (mid_y and (x <= 4 if left else False)) or (mid_y and (x >= 3 if right else False)))
    return cells(p)


HAND = {
    'heart': ['.##..##.', '########', '########', '########', '.######.', '..####..', '...##...', '........'],
    'diamond': ['...##...', '..####..', '.######.', '########', '.######.', '..####..', '...##...', '........'],
    'spade': ['...##...', '..####..', '.######.', '########', '########', '...##...', '..####..', '........'],
    'club': ['...##...', '..####..', '..####..', '##.##.##', '########', '##.##.##', '...##...', '..####..'],
    'dot': ['........', '..####..', '.######.', '.######.', '.######.', '.######.', '..####..', '........'],
    'circle': ['........', '..####..', '.##..##.', '.#....#.', '.#....#.', '.##..##.', '..####..', '........'],
    'pi': ['........', '........', '########', '.##..##.', '.##..##.', '.##..##.', '.##..##.', '........'],
    'check': ['........', '.......#', '......##', '#....##.', '##..##..', '.####...', '..##....', '........'],
    'arc': ['........', '........', '........', '.....###', '....####', '...##...', '...##...', '...##...'],
    'diag': ['##......', '.##.....', '..##....', '...##...', '....##..', '.....##.', '......##', '.......#'],
}
ARC_DR = grid(HAND['arc'])                      # ╭: from the right down
DIAG = grid(HAND['diag'])                       # ╲

# graphics of the upper case set by screen code 40h-7Fh (PETSCII 60h-7Fh and A0h-BFh)
GRAPHICS = {
    0x40: box(0, 0, 1, 1),                                  # ─
    0x41: grid(HAND['spade']),
    0x42: cells(lambda x, y: x == 3),                       # vertical eighth 4
    0x43: cells(lambda x, y: y == 3),                       # horizontal eighth 4
    0x44: cells(lambda x, y: y == 2),
    0x45: cells(lambda x, y: y == 1),
    0x46: cells(lambda x, y: y == 5),
    0x47: cells(lambda x, y: x == 2),
    0x48: cells(lambda x, y: x == 5),
    0x49: mirror_x(ARC_DR),                                 # ╮
    0x4A: mirror_y(ARC_DR),                                 # ╰
    0x4B: mirror_x(mirror_y(ARC_DR)),                       # ╯
    0x4C: cells(lambda x, y: x == 0 or y == 7),             # left and lower eighth
    0x4D: DIAG,                                             # ╲
    0x4E: mirror_x(DIAG),                                   # ╱
    0x4F: cells(lambda x, y: x == 0 or y == 0),             # left and upper eighth
    0x50: cells(lambda x, y: x == 7 or y == 0),             # right and upper eighth
    0x51: grid(HAND['dot']),
    0x52: cells(lambda x, y: y == 6),
    0x53: grid(HAND['heart']),
    0x54: cells(lambda x, y: x == 1),
    0x55: ARC_DR,                                           # ╭
    0x56: union(DIAG, mirror_x(DIAG)),                      # ╳
    0x57: grid(HAND['circle']),
    0x58: grid(HAND['club']),
    0x59: cells(lambda x, y: x == 6),
    0x5A: grid(HAND['diamond']),
    0x5B: box(1, 1, 1, 1),                                  # ┼
    0x5C: cells(lambda x, y: x < 4 and (x + y) % 2 == 0),   # left half shade
    0x5D: box(1, 1, 0, 0),                                  # │
    0x5E: grid(HAND['pi']),
    0x5F: cells(lambda x, y: x >= y),                       # ◥
    0x60: empty(),
    0x61: cells(lambda x, y: x < 4),                        # ▌
    0x62: cells(lambda x, y: y >= 4),                       # ▄
    0x63: cells(lambda x, y: y == 0),                       # ▔
    0x64: cells(lambda x, y: y == 7),                       # ▁
    0x65: cells(lambda x, y: x == 0),                       # ▏
    0x66: cells(lambda x, y: (x + y) % 2 == 0),             # ▒
    0x67: cells(lambda x, y: x == 7),                       # ▕
    0x68: cells(lambda x, y: y >= 4 and (x + y) % 2 == 0),  # lower half shade
    0x69: cells(lambda x, y: x + y <= 7),                   # ◤
    0x6A: cells(lambda x, y: x >= 6),                       # right quarter
    0x6B: box(1, 1, 0, 1),                                  # ├
    0x6C: cells(lambda x, y: x >= 4 and y >= 4),            # ▗
    0x6D: box(1, 0, 0, 1),                                  # └
    0x6E: box(0, 1, 1, 0),                                  # ┐
    0x6F: cells(lambda x, y: y >= 6),                       # ▂
    0x70: box(0, 1, 0, 1),                                  # ┌
    0x71: box(1, 0, 1, 1),                                  # ┴
    0x72: box(0, 1, 1, 1),                                  # ┬
    0x73: box(1, 1, 1, 0),                                  # ┤
    0x74: cells(lambda x, y: x < 2),                        # ▎
    0x75: cells(lambda x, y: x < 3),                        # ▍
    0x76: cells(lambda x, y: x >= 5),                       # right three eighths
    0x77: cells(lambda x, y: y < 2),                        # upper quarter
    0x78: cells(lambda x, y: y < 3),                        # upper three eighths
    0x79: cells(lambda x, y: y >= 5),                       # ▃
    0x7A: cells(lambda x, y: x == 7 or y == 7),             # right and lower eighth
    0x7B: cells(lambda x, y: x < 4 and y >= 4),             # ▖
    0x7C: cells(lambda x, y: x >= 4 and y < 4),             # ▝
    0x7D: box(1, 0, 1, 0),                                  # ┘
    0x7E: cells(lambda x, y: x < 4 and y < 4),              # ▘
    0x7F: cells(lambda x, y: (x < 4) == (y < 4)),           # ▚
}
# the lower case set: as the upper case one except these
LOWER_GRAPHICS = {
    0x5E: cells(lambda x, y: (x + y) % 2 == 1),             # inverse checker board
    0x5F: cells(lambda x, y: (x - y) % 4 < 2),              # fill upper left to lower right
    0x69: cells(lambda x, y: (x + y) % 4 < 2),              # fill upper right to lower left
    0x7A: grid(HAND['check']),
}
# screen codes 00h-3Fh as CP437 characters of the font 4x8 (the C64 has £ ↑ ← at 1Ch, 1Eh, 1Fh)
TEXT = '@ABCDEFGHIJKLMNOPQRSTUVWXYZ[£]↑← !"#$%&\'()*+,-./0123456789:;<=>?'


def doubled(rows4):
    """A glyph of the font 4x8 with each dot doubled."""
    return [[r[x // 2] == '#' for x in range(8)] for r in rows4]


def build():
    cp = fontgen.parse()['cp437']
    to437 = {ch: code for code, ch in enumerate(bytes(range(256)).decode('cp437'))}
    to437.update({'↑': 0x18, '←': 0x1B})
    glyphs = [None] * 256
    for code in range(0x40):
        ch = TEXT[code]
        glyphs[code] = doubled(cp[to437[ch]])
        low = ch.lower() if 1 <= code <= 0x1A else ch
        glyphs[0x80 + code] = doubled(cp[to437[low]])
    for code in range(0x40, 0x80):
        glyphs[code] = GRAPHICS[code]
        if 0x41 <= code <= 0x5A:                            # the lower case set has the capitals here
            glyphs[0x80 + code] = doubled(cp[code])
        else:
            glyphs[0x80 + code] = LOWER_GRAPHICS.get(code, GRAPHICS[code])
    return glyphs


def glyph_bytes(g):
    return [sum(0x80 >> x for x in range(8) if g[y][x]) for y in range(8)]


# AND-1V: letters and signs as they are, lines as its box drawing, blocks as its 2x3 graphics, the rest alike
AND_BOX = {(1, 1, 0, 0): 0x0C, (0, 0, 1, 1): 0x0D, (0, 1, 0, 1): 0x05, (0, 1, 1, 0): 0x06, (1, 0, 0, 1): 0x04,
           (1, 0, 1, 0): 0x07, (1, 1, 0, 1): 0x09, (1, 1, 1, 0): 0x0B, (0, 1, 1, 1): 0x0A, (1, 0, 1, 1): 0x08,
           (1, 1, 1, 1): 0x0E}
AND_GRAPHICS = {0x40: AND_BOX[(0, 0, 1, 1)], 0x5D: AND_BOX[(1, 1, 0, 0)], 0x5B: AND_BOX[(1, 1, 1, 1)],
                0x6B: AND_BOX[(1, 1, 0, 1)], 0x6D: AND_BOX[(1, 0, 0, 1)], 0x6E: AND_BOX[(0, 1, 1, 0)],
                0x70: AND_BOX[(0, 1, 0, 1)], 0x71: AND_BOX[(1, 0, 1, 1)], 0x72: AND_BOX[(0, 1, 1, 1)],
                0x73: AND_BOX[(1, 1, 1, 0)], 0x7D: AND_BOX[(1, 0, 1, 0)], 0x55: AND_BOX[(0, 1, 0, 1)],
                0x49: AND_BOX[(0, 1, 1, 0)], 0x4A: AND_BOX[(1, 0, 0, 1)], 0x4B: AND_BOX[(1, 0, 1, 0)],
                0x41: ord('*'), 0x53: ord('*'), 0x58: ord('*'), 0x5A: ord('*'), 0x51: ord('o'), 0x57: ord('o'),
                0x56: ord('X'), 0x4D: ord('\\'), 0x4E: ord('/'), 0x5E: ord('n'), 0x60: 0x20, 0x66: 0x7F,
                0x5C: 0x7F, 0x68: 0x7F}


def and_semi(g):
    """The 2x3 graphics of the AND-1V nearest to a glyph: a part is set when half of its dots are."""
    bits = 0
    for i, (x0, y0, x1, y1) in enumerate([(0, 0, 4, 3), (4, 0, 8, 3), (0, 3, 4, 5), (4, 3, 8, 5), (0, 5, 4, 8),
                                          (4, 5, 8, 8)]):
        n = sum(g[y][x] for y in range(y0, y1) for x in range(x0, x1))
        if 2 * n >= (x1 - x0) * (y1 - y0):
            bits |= 1 << i
    return SEMI | bits


def and_map(glyphs):
    m = []
    for code in range(256):
        c = code & 0x7F
        if c < 0x40:
            ch = TEXT[c]
            ch = {'£': 'L', '↑': '^', '←': '<'}.get(ch, ch)
            if code & 0x80 and 1 <= c <= 0x1A:
                ch = ch.lower()
            m.append(ord(ch))
        elif code & 0x80 and 0x41 <= c <= 0x5A:
            m.append(c)                                     # capitals of the lower case set
        elif code & 0x80 and c in LOWER_GRAPHICS:
            m.append(0x7F if c != 0x7A else ord('v'))
        elif c in AND_GRAPHICS:
            m.append(AND_GRAPHICS[c])
        else:
            m.append(and_semi(glyphs[code]))
    return m


def main():
    glyphs = build()
    out = ['; Generated by tools/petfont.py, do not edit. Starts on a page boundary.',
           '; font_pet: 256 glyphs 8x8 (the screen code of the C64, bit 7 = the lower case set), dots D7 (left)',
           '; to D0; and_map_pet: the same as characters of the AND-1V.', '', 'font_pet:']
    for code, g in enumerate(glyphs):
        out.append('        defb %s   ; %02X' % (','.join('%03Xh' % b for b in glyph_bytes(g)), code))
    out.append('and_map_pet:')
    m = and_map(glyphs)
    for i in range(0, 256, 16):
        out.append('        defb ' + ','.join('%03Xh' % v for v in m[i:i + 16]))
    path = os.path.join(ROOT, 'build', 'font_pet.inc')
    open(path, 'w', encoding='ascii', newline='\n').write('\n'.join(out) + '\n')
    print('build/font_pet.inc: 256 glyphs 8x8')
    if '--preview' in sys.argv:
        prev = sys.argv[sys.argv.index('--preview') + 1]
        w, h, sc = 16 * 10, 16 * 10, 3                      # 16 x 16 glyphs, a gap of 2, each dot 3x3
        rgb = bytearray(w * sc * h * sc * 3)
        for code, g in enumerate(glyphs):
            gx, gy = (code % 16) * 10 + 1, (code // 16) * 10 + 1
            for y in range(8):
                for x in range(8):
                    if g[y][x]:
                        for dy in range(sc):
                            for dx in range(sc):
                                p = (((gy + y) * sc + dy) * w * sc + (gx + x) * sc + dx) * 3
                                rgb[p:p + 3] = b'\xd0\xd0\xd0'
        fontgen.png(prev, w * sc, h * sc, bytes(rgb))
        print(prev)


if __name__ == '__main__':
    main()
