"""Tables of SAPI-Term -> build/tables.inc (docs/technika.md).

and_map_cp437  256 B  CP437 -> character of the AND-1V (box drawing single only, blocks as 2x3 graphics,
                      accented letters as KOI-8cs2 where it has them, else ASCII)
col_dist       256 B  distance of two of the 16 text colours (index c1 * 16 + c2), for the nearest pair
cga_rows        50 B  address of each text row on the CGA-1V (C000h + row * 640)
The include starts on a page boundary, so all three are page aligned (the code indexes them by the low byte).
  python tools/tables.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 16 text colours in the CGA order, 6-bit RGB as in src/cga.asm (ansi_rgb)
RGB = [(0, 0, 0), (0, 0, 42), (0, 42, 0), (0, 42, 42), (42, 0, 0), (42, 0, 42), (42, 21, 0), (42, 42, 42),
       (21, 21, 21), (21, 21, 63), (21, 63, 21), (21, 63, 63), (63, 21, 21), (63, 21, 63), (63, 63, 21),
       (63, 63, 63)]

# AND-1V box drawing: arms (up, down, left, right) -> code
AND_BOX = {(1, 1, 0, 0): 0x0C, (0, 0, 1, 1): 0x0D, (0, 1, 0, 1): 0x05, (0, 1, 1, 0): 0x06,
           (1, 0, 0, 1): 0x04, (1, 0, 1, 0): 0x07, (1, 1, 0, 1): 0x09, (1, 1, 1, 0): 0x0B,
           (0, 1, 1, 1): 0x0A, (1, 0, 1, 1): 0x08, (1, 1, 1, 1): 0x0E}
# CP437 B3-DA box drawing: arms (up, down, left, right), single or double does not matter on the AND-1V
CP_BOX = {
    0xB3: (1, 1, 0, 0), 0xB4: (1, 1, 1, 0), 0xB5: (1, 1, 1, 0), 0xB6: (1, 1, 1, 0), 0xB7: (0, 1, 1, 0),
    0xB8: (0, 1, 1, 0), 0xB9: (1, 1, 1, 0), 0xBA: (1, 1, 0, 0), 0xBB: (0, 1, 1, 0), 0xBC: (1, 0, 1, 0),
    0xBD: (1, 0, 1, 0), 0xBE: (1, 0, 1, 0), 0xBF: (0, 1, 1, 0), 0xC0: (1, 0, 0, 1), 0xC1: (1, 0, 1, 1),
    0xC2: (0, 1, 1, 1), 0xC3: (1, 1, 0, 1), 0xC4: (0, 0, 1, 1), 0xC5: (1, 1, 1, 1), 0xC6: (1, 1, 0, 1),
    0xC7: (1, 1, 0, 1), 0xC8: (1, 0, 0, 1), 0xC9: (0, 1, 0, 1), 0xCA: (1, 0, 1, 1), 0xCB: (0, 1, 1, 1),
    0xCC: (1, 1, 0, 1), 0xCD: (0, 0, 1, 1), 0xCE: (1, 1, 1, 1), 0xCF: (1, 0, 1, 1), 0xD0: (1, 0, 1, 1),
    0xD1: (0, 1, 1, 1), 0xD2: (0, 1, 1, 1), 0xD3: (1, 0, 0, 1), 0xD4: (1, 0, 0, 1), 0xD5: (0, 1, 0, 1),
    0xD6: (0, 1, 0, 1), 0xD7: (1, 1, 1, 1), 0xD8: (1, 1, 1, 1), 0xD9: (1, 0, 1, 0), 0xDA: (0, 1, 0, 1),
}
# AND-1V 2x3 block graphics: 80h + bits (0 top left, 1 top right, 2 middle left, 3 middle right,
# 4 bottom left, 5 bottom right)
SEMI = 0x80
# KOI-8cs2 codes of the AND-1V (SAPIemu src/core/charset.cpp)
KOI = {'á': 0xC1, 'č': 0xC3, 'ď': 0xC4, 'ě': 0xC5, 'ŕ': 0xC6, 'ü': 0xC8, 'í': 0xC9, 'ů': 0xCA, 'ĺ': 0xCB,
       'ľ': 0xCC, 'ö': 0xCD, 'ň': 0xCE, 'ó': 0xCF, 'ô': 0xD0, 'ä': 0xD1, 'ř': 0xD2, 'š': 0xD3, 'ť': 0xD4,
       'ú': 0xD5, 'é': 0xD7, 'à': 0xD8, 'ý': 0xD9, 'ž': 0xDA, '¬': 0xDE,
       'Á': 0xE1, 'Č': 0xE3, 'Ď': 0xE4, 'Ě': 0xE5, 'Ŕ': 0xE6, 'Ü': 0xE8, 'Í': 0xE9, 'Ů': 0xEA, 'Ĺ': 0xEB,
       'Ľ': 0xEC, 'Ö': 0xED, 'Ň': 0xEE, 'Ó': 0xEF, 'Ô': 0xF0, 'Ä': 0xF1, 'Ř': 0xF2, 'Š': 0xF3, 'Ť': 0xF4,
       'Ú': 0xF5, 'É': 0xF7, 'À': 0xF8, 'Ý': 0xF9, 'Ž': 0xFA}
# CP437 symbols 01-1F, 7F and the rest above 7F without a KOI-8cs2 letter: ASCII look-alikes
ASCII_LIKE = {
    0x01: 'o', 0x02: 'o', 0x03: '*', 0x04: '*', 0x05: '*', 0x06: '*', 0x07: '.', 0x09: 'o', 0x0A: 'O',
    0x0B: 'o', 0x0C: 'o', 0x0D: 'd', 0x0E: 'd', 0x0F: '*', 0x10: '>', 0x11: '<', 0x12: '|', 0x13: '!',
    0x14: 'P', 0x15: 'S', 0x17: '|', 0x19: 'v', 0x1A: '>', 0x1B: '<', 0x1D: '-', 0x1F: 'v',
    0x80: 'C', 0x83: 'a', 0x86: 'a', 0x87: 'c', 0x88: 'e', 0x89: 'e', 0x8A: 'e', 0x8B: 'i', 0x8C: 'i',
    0x8D: 'i', 0x8F: 'A', 0x91: 'a', 0x92: 'A', 0x95: 'o', 0x96: 'u', 0x97: 'u', 0x98: 'y', 0x9B: 'c',
    0x9C: 'L', 0x9D: 'Y', 0x9E: 'P', 0x9F: 'f', 0xA4: 'n', 0xA5: 'N', 0xA6: 'a', 0xA7: 'o', 0xA8: '?',
    0xA9: '-', 0xAB: '/', 0xAC: '/', 0xAD: '!', 0xAE: '<', 0xAF: '>',
    0xE0: 'a', 0xE1: 'B', 0xE2: 'G', 0xE3: 'n', 0xE4: 'E', 0xE5: 'o', 0xE6: 'u', 0xE7: 't', 0xE8: 'O',
    0xE9: 'O', 0xEA: 'O', 0xEB: 'd', 0xEC: '8', 0xED: 'o', 0xEE: 'e', 0xEF: 'n', 0xF0: '=', 0xF1: '+',
    0xF2: '>', 0xF3: '<', 0xF4: '(', 0xF5: ')', 0xF6: '/', 0xF7: '~', 0xF8: 'o', 0xF9: '.', 0xFA: '.',
    0xFB: 'v', 0xFC: 'n', 0xFD: '2', 0xFE: '#',
}


def and_map():
    m = []
    for c in range(256):
        if c in (0x00, 0xFF):
            v = 0x20
        elif 0x20 <= c < 0x7F:
            v = c
        elif c in CP_BOX:
            v = AND_BOX[CP_BOX[c]]
        elif c in ASCII_LIKE:
            v = ord(ASCII_LIKE[c])
        elif c == 0x08:
            v = 0x7F                                    # inverse bullet: checkerboard
        elif c == 0x16:
            v = SEMI | 0x30                             # thick bar at the bottom
        elif c == 0x18 or c == 0x1E or c == 0x7F:
            v = 0x5E                                    # the AND-1V shows 5Eh as an up arrow
        elif c == 0x1C:
            v = 0x04                                    # right angle: corner
        elif c == 0xB0:
            v = SEMI | 0x01 | 0x08 | 0x10               # light shade: 3 of 6 sparse
        elif c == 0xB1:
            v = 0x7F                                    # medium shade: checkerboard
        elif c == 0xB2:
            v = SEMI | 0x02 | 0x04 | 0x20 | 0x01 | 0x08  # dark shade: 5 of 6
        elif c == 0xDB:
            v = SEMI | 0x3F
        elif c == 0xDC:
            v = SEMI | 0x0C | 0x30                      # lower half: middle and bottom
        elif c == 0xDD:
            v = SEMI | 0x01 | 0x04 | 0x10
        elif c == 0xDE:
            v = SEMI | 0x02 | 0x08 | 0x20
        elif c == 0xDF:
            v = SEMI | 0x03 | 0x0C                      # upper half: top and middle
        else:
            ch = bytes([c]).decode('cp437')
            v = KOI.get(ch)
            if v is None:
                raise SystemExit('no AND-1V character for CP437 %02X %s' % (c, ch))
        m.append(v)
    return m


def col_dist():
    d = []
    for a in range(16):
        for b in range(16):
            ra, ga, ba = RGB[a]
            rb, gb, bb = RGB[b]
            # weighted RGB distance (green counts most), scaled to 0-255
            v = (2 * (ra - rb) ** 2 + 4 * (ga - gb) ** 2 + 3 * (ba - bb) ** 2) ** 0.5
            d.append(min(255, int(v * 255 / (9 * 63 * 63) ** 0.5 + 0.5)))
    return d


def rows(name, data, per=16):
    out = [name + ':']
    for i in range(0, len(data), per):
        out.append('        defb ' + ','.join('%03Xh' % v for v in data[i:i + per]))
    return out


def main():
    out = ['; Generated by tools/tables.py, do not edit. Starts on a page boundary: every table is page aligned.', '']
    out += rows('and_map_cp437', and_map()) + ['']
    out += rows('col_dist', col_dist()) + ['']
    out += ['; text row addresses of the CGA-1V (row * 640 + C000h)', 'cga_rows:']
    out.append('        defw ' + ','.join('%05Xh' % (0xC000 + r * 640) for r in range(25)))
    path = os.path.join(ROOT, 'build', 'tables.inc')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'w', encoding='ascii', newline='\n').write('\n'.join(out))
    print('build/tables.inc')


if __name__ == '__main__':
    main()
