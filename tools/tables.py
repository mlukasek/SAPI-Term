"""Tables of SAPI-Term -> build/tables.inc (docs/technika.md).

and_map_cp437  256 B  CP437 -> character of the AND-1V (box drawing single only, blocks as 2x3 graphics,
                      accented letters as KOI-8cs2 where it has them, else ASCII)
col_dist       256 B  distance of two of the 16 text colours (index c1 * 16 + c2), for the nearest pair
wide_l, wide_r 2x256 B glyph byte (4 dots in D7..D4) -> its dots doubled for 40 columns: the left two dots as
                      four in D7..D4 (wide_l), the right two (wide_r)
cga_rows        50 B  address of each text row on the CGA-1V (C000h + row * 640)
The include starts on a page boundary, so these three are page aligned (the code indexes them by the low byte).
Then the character sets of BBS (src/charset.asm), a glyph is a CP437 code or a KOI-8cs2 letter (C0-FF + EXT_KOI;
Czech and Slovak letters always from KOI-8cs2, so they look alike whatever the BBS sends):
cs_in_<SET>    128 + 16 B  bytes 80-FF of a one-byte set -> glyph code, then its KOI bits (bit i & 7 of byte i >> 3)
u_lat_code     224 + 28 B  Unicode 00A0-017F -> glyph (UTF-8), u_lat_koi its KOI bits
u_box          256 B       Unicode 2500-25FF -> CP437 (box drawing, blocks, shapes; nearest when CP437 lacks it)
u_list                     other Unicode -> CP437: word, byte; 0000h ends it (code 0 = nothing is shown)
koi_out        7 x 64 B    KOI-8cs2 letter C0-FF typed on the EKL-1 -> byte of each set (UTF-8: ASCII, unused)
koi_uni        64 words    KOI-8cs2 letter C0-FF -> Unicode (UTF-8)
  python tools/tables.py
"""
import os
import unicodedata

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


def wide(two):
    """Two dots (bit 1 = left) doubled to four in D7..D4."""
    return (0xC0 if two & 2 else 0) | (0x30 if two & 1 else 0)


def rows(name, data, per=16):
    out = [name + ':']
    for i in range(0, len(data), per):
        out.append('        defb ' + ','.join('%03Xh' % v for v in data[i:i + per]))
    return out


# --- character sets of BBS (src/charset.asm) ---

# the sets in the order of CS_* in src/charset.asm
SETS = ['CP437', 'UTF-8', 'LATIN2', 'CP1250', 'CP852', 'KAMENICKY', 'KOI8']
KOI_REV = {v: k for k, v in KOI.items()}
# CP437 glyphs of the codes 01-1F and 7F (the codec gives controls there)
CP437_LOW = '☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼'
# Kamenicky (KEYBCS2) 80-AF, B0-FF as CP437
KAMENICKY = 'ČüéďäĎŤčěĚĹÍľĺÄÁÉžŽôöÓůÚýÖÜŠĽÝŘťáíóúňŇŮÔšřŕŔ¼§«»'
# Unicode without a CP437 glyph: the nearest one
NEAR = {'‘': "'", '’': "'", '‚': "'", '‛': "'", '′': "'", '“': '"', '”': '"', '„': '"', '‟': '"', '″': '"',
        '‐': '-', '‑': '-', '‒': '-', '–': '-', '—': '-', '―': '-', '‹': '<', '›': '>', '€': 'E', '‣': '►',
        'ł': 'l', 'Ł': 'L', 'đ': 'd', 'Đ': 'D', 'ı': 'i', 'ĸ': 'k', 'ŉ': 'n', 'ŋ': 'n', 'Ŋ': 'N', 'ſ': 's',
        'ħ': 'h', 'Ħ': 'H', 'ŧ': 't', 'Ŧ': 'T', 'œ': 'o', 'Œ': 'O', ' ': ' ', '­': '-', '×': 'x',
        '©': 'c', '®': 'R', '¤': '*', '¦': '|', '¨': '"', '¯': '-', '´': "'", '¸': ',', '³': '3', '¹': '1',
        '¾': '3', 'Ø': 'O', 'ø': 'o', 'Þ': 'P', 'þ': 'p', 'Ð': 'D', 'ð': 'd', '˘': "'", '˛': ',', 'ˇ': "'",
        '˙': "'", '˝': '"', '▪': '■', '●': '•', '◆': '♦', '◊': '♦', '▶': '►', '◀': '◄', '▸': '►', '◂': '◄',
        '▴': '▲', '▾': '▼', '△': '▲', '▽': '▼', '◯': '○', '◦': '○', '□': '■', '▫': '■', '❤': '♥'}
NOTHING = '​‌‍⁠﻿︎️'   # shown as nothing (zero width)


def cp437_glyphs():
    """Unicode of each CP437 glyph 0-255 (00 = none)."""
    g = [''] + list(CP437_LOW) + [chr(c) for c in range(0x20, 0x7F)] + ['⌂']
    g += [bytes([c]).decode('cp437') for c in range(0x80, 0x100)]
    return g


UNI2CP = {}
for _c, _ch in enumerate(cp437_glyphs()):
    if _c and _ch not in UNI2CP and _ch != ' ':
        UNI2CP[_ch] = _c
UNI2CP['β'] = 0xE1          # CP437 E1 is the German sharp s and the Greek beta


def box_near(ch):
    """A box drawing character CP437 lacks: the single line one with the same arms (double when all double)."""
    name = unicodedata.name(ch, '')
    if not name.startswith('BOX DRAWINGS'):
        return None
    words = name.split()[2:]
    if 'DIAGONAL' in words:
        return {'UPPER RIGHT TO LOWER LEFT': '/', 'UPPER LEFT TO LOWER RIGHT': '\\'}.get(
            ' '.join(words[words.index('DIAGONAL') + 1:]), 'X')
    arms = set()
    for w in words:
        if w == 'VERTICAL':
            arms |= {'UP', 'DOWN'}
        elif w == 'HORIZONTAL':
            arms |= {'LEFT', 'RIGHT'}
        elif w in ('UP', 'DOWN', 'LEFT', 'RIGHT'):
            arms.add(w)
    if arms in ({'UP'}, {'DOWN'}):
        arms = {'UP', 'DOWN'}
    if arms in ({'LEFT'}, {'RIGHT'}):
        arms = {'LEFT', 'RIGHT'}
    double = 'DOUBLE' in words and not ({'LIGHT', 'HEAVY', 'SINGLE'} & set(words))
    for code, ch2 in enumerate(cp437_glyphs()):
        n2 = unicodedata.name(ch2, '') if ch2 else ''
        if not (0xB3 <= code <= 0xDA) or not n2.startswith('BOX DRAWINGS'):
            continue
        if CP_BOX[code] == tuple(int(a in arms) for a in ('UP', 'DOWN', 'LEFT', 'RIGHT')):
            w2 = n2.split()[2:]
            if (('DOUBLE' in w2 and 'SINGLE' not in w2) if double else 'DOUBLE' not in w2):
                return ch2
    return None


BLOCKS = {'▁': '_', '▂': '▄', '▃': '▄', '▅': '▄', '▆': '█', '▇': '█', '▉': '█', '▊': '█', '▋': '▌', '▍': '▌',
          '▎': '|', '▏': '|', '▔': '▀', '▕': '|', '▖': '▄', '▗': '▄', '▘': '▀', '▝': '▀', '▙': '█', '▛': '█',
          '▜': '█', '▟': '█', '▚': '▒', '▞': '▒'}


def glyph(ch):
    """(code, KOI) of the glyph SAPI-Term shows for the Unicode character ch; ('?', 0) when there is none."""
    if ch in KOI:
        return KOI[ch], 1
    ch = NEAR.get(ch, BLOCKS.get(ch, ch))
    if ch in UNI2CP:
        return UNI2CP[ch], 0
    near = box_near(ch)
    if near:
        return UNI2CP[near], 0
    base = unicodedata.normalize('NFKD', ch)[:1]
    if base and 0x20 <= ord(base) < 0x7F and len(ch) == 1 and ord(ch) >= 0x80:
        return ord(base), 0
    return ord('?'), 0


def set_char(name, b):
    """Unicode of byte b (80-FF) of a one-byte set, or None."""
    if name == 'KAMENICKY':
        return KAMENICKY[b - 0x80] if b < 0xB0 else bytes([b]).decode('cp437')
    if name == 'KOI8':
        return KOI_REV.get(b)
    codec = {'LATIN2': 'iso8859_2', 'CP1250': 'cp1250', 'CP852': 'cp852', 'CP437': 'cp437'}[name]
    try:
        ch = bytes([b]).decode(codec)
    except UnicodeDecodeError:
        return None
    return None if unicodedata.category(ch) == 'Cc' else ch


def set_glyph(name, b):
    if name == 'KOI8' and b >= 0xC0:
        return b, 1                     # every KOI-8cs2 code has its glyph in the font
    ch = set_char(name, b)
    return glyph(ch) if ch else (ord('?'), 0)


def koi_bits(glyphs):
    bits = [0] * ((len(glyphs) + 7) // 8)
    for i, (_, k) in enumerate(glyphs):
        if k:
            bits[i >> 3] |= 1 << (i & 7)
    return bits


def encode_key(name, ch):
    """Byte the BBS of set name gets for the KOI-8cs2 letter ch typed on the EKL-1."""
    if name == 'KOI8':
        return KOI[ch]
    if name == 'KAMENICKY':
        if ch in KAMENICKY:
            return 0x80 + KAMENICKY.index(ch)
        name = 'CP437'
    codec = {'LATIN2': 'iso8859_2', 'CP1250': 'cp1250', 'CP852': 'cp852', 'CP437': 'cp437'}.get(name)
    if codec:
        try:
            return ch.encode(codec)[0]
        except UnicodeEncodeError:
            pass
    base = unicodedata.normalize('NFKD', ch)[:1]
    return ord(base) if base.isascii() and base.isprintable() else ord('?')


def ulist():
    """(Unicode, CP437 code) of the characters outside 0000-017F and 2500-25FF that have a glyph (0 = shown as
    nothing), sorted."""
    seen = set(range(0x80)) | set(range(0xA0, 0x180)) | set(range(0x2500, 0x2600))
    items = []
    for ch in list(UNI2CP) + list(NEAR) + list(NOTHING):
        u = ord(ch)
        if u in seen or u == 0x2026:
            continue
        seen.add(u)
        items.append((u, 0 if ch in NOTHING else glyph(ch)[0]))
    return sorted(items)


def utf8_glyphs(ch):
    """The glyphs (code, KOI) SAPI-Term shows for ch received in UTF-8, as src/charset.asm does."""
    u = ord(ch)
    if u < 0x80:
        return [(u, 0)]
    if u < 0xA0 or u > 0xFFFF:
        return [(ord('?'), 0)]
    if u < 0x180 or 0x2500 <= u < 0x2600:
        return [glyph(ch)]
    if 0x300 <= u < 0x370:
        return []
    if u == 0x2026:
        return [(ord('.'), 0)] * 3
    c = dict(ulist()).get(u)
    if c is None:
        return [(ord('?'), 0)]
    return [(c, 0)] if c else []


def charsets():
    out = ['; character sets of BBS (src/charset.asm)']
    for name in SETS:
        if name in ('CP437', 'UTF-8'):
            continue
        g = [set_glyph(name, b) for b in range(0x80, 0x100)]
        label = 'cs_in_' + name.replace('-', '').lower()
        out += rows(label, [c for c, _ in g]) + rows(label + '_koi', koi_bits(g))
    g = [glyph(chr(u)) for u in range(0xA0, 0x180)]
    out += rows('u_lat_code', [c for c, _ in g]) + rows('u_lat_koi', koi_bits(g))
    box = []
    for u in range(0x2500, 0x2600):
        c, k = glyph(chr(u))
        assert not k
        box.append(c)
    out += rows('u_box', box)
    out.append('u_list:')
    for u, c in ulist():
        out.append('        defw %05Xh' % u)
        out.append('        defb %03Xh' % c)
    out.append('        defw 0')
    data = []
    for name in SETS:
        for code in range(0xC0, 0x100):
            ch = KOI_REV.get(code)
            data.append(encode_key(name, ch) if ch and name != 'UTF-8' else
                        (ord(unicodedata.normalize('NFKD', ch)[0]) if ch else ord('?')))
    out += rows('koi_out', data)
    out.append('koi_uni:')
    uni = [ord(KOI_REV.get(code, '?')) for code in range(0xC0, 0x100)]
    for i in range(0, 64, 8):
        out.append('        defw ' + ','.join('%05Xh' % u for u in uni[i:i + 8]))
    return out


def main():
    out = ['; Generated by tools/tables.py, do not edit. Starts on a page boundary: every table is page aligned.', '']
    out += rows('and_map_cp437', and_map()) + ['']
    out += rows('col_dist', col_dist()) + ['']
    out += rows('wide_l', [wide(g >> 6) for g in range(256)]) + ['']
    out += rows('wide_r', [wide(g >> 4 & 3) for g in range(256)]) + ['']
    out += ['; text row addresses of the CGA-1V (row * 640 + C000h)', 'cga_rows:']
    out.append('        defw ' + ','.join('%05Xh' % (0xC000 + r * 640) for r in range(25)))
    out += [''] + charsets()
    path = os.path.join(ROOT, 'build', 'tables.inc')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'w', encoding='ascii', newline='\n').write('\n'.join(out))
    print('build/tables.inc')


if __name__ == '__main__':
    main()
