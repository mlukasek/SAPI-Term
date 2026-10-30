"""Fonts 8x8 of the original machines for SAPI-Term: ROM dumps -> fonts/c64.txt, fonts/atari.txt, fonts/mz800.txt
(the sources of tools/petfont.py, tools/atafont.py and tools/mzfont.py; docs/rozhodnuti.md "Písma 8x8").

Run by hand only when a source changes; the ROMs are not in the repository (work/roms, docs/vyvoj.md).
  python tools/romfont.py --c64 chargen-901225-01.bin --atari ATARIOSB.ROM --mz CGROM.ROM --cpm BIOS.mac
Sources (checked by their CRC32):
  C64    chargen-901225-01.bin of VICE (data/C64), 4096 B: screen codes 00-7F of the upper case set at 000h, of
         the lower case set at 800h (the inverse halves are not used: SAPI-Term swaps the colours).
  Atari  ATARIOSB.ROM (OS rev. B, D800-FFFF) of PC Xformer 2.5 (xf25.zip of the Atari800 project at
         SourceForge), the font at E000h = offset 800h in the internal order: 00-3F = ATASCII 20-5F,
         40-5F = 00-1F, 60-7F = 60-7F. The 800XL has the same font.
  MZ     CGROM.ROM of the MZ-800 (from the author), 4096 B, dots D0 (left) to D7; the European CGROM of the
         MZ-700 (mz700fon.int of MAME) differs only in A C D G 4 5 9 and the comma. ASCII 20-5D as the monitor
         1Z-013A of the MZ-700 converts them to display codes (its table at 0A92h + the code), a-z = display
         codes 81-9A, the rest as the Czech CP/M of the MZ-800 converts them (_ BF, ^ BE, ` A4, { BC, | 80,
         } 40, ~ A5); only the house 7F of CP437, which the MZ lacks, is drawn here in its style (dots one wide,
         capitals rows 0-6). Section cp437: the characters of CP437 outside ASCII the MZ has (MZ_CP437).
  CP/M   BIOS.mac of the Czech CP/M of the MZ-800 (Lamač; Cpm_v41 from the author), its block "BIOS CG ZNAKY"
         (cpm_block): the Czech and Slovak letters of KOI-8cs2 as it shows them with the ROM font, its two
         accent rows over the rows 2-7 of the base letter of the ROM -> fonts/mz800cs.txt (with --mz).
"""
import os
import re
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CRC = {'c64': 0xEC4272EE, 'atari': 0x3E28A1FE, 'mz': 0x2A62D77E, 'cpm': 0xC28F2248}

# MZ: ASCII -> display code (the monitor's table for 20-5D, a-z, the rest as the Czech CP/M of the MZ-800)
MZ_CODES = {0x20: 0x00, 0x21: 0x61, 0x22: 0x62, 0x23: 0x63, 0x24: 0x64, 0x25: 0x65, 0x26: 0x66, 0x27: 0x67,
            0x28: 0x68, 0x29: 0x69, 0x2A: 0x6B, 0x2B: 0x6A, 0x2C: 0x2F, 0x2D: 0x2A, 0x2E: 0x2E, 0x2F: 0x2D,
            0x3A: 0x4F, 0x3B: 0x2C, 0x3C: 0x51, 0x3D: 0x2B, 0x3E: 0x57, 0x3F: 0x49, 0x40: 0x55, 0x5B: 0x52,
            0x5C: 0x59, 0x5D: 0x54, 0x5E: 0xBE, 0x5F: 0xBF, 0x60: 0xA4, 0x7B: 0xBC, 0x7C: 0x80, 0x7D: 0x40,
            0x7E: 0xA5}
MZ_CODES.update({0x30 + i: 0x20 + i for i in range(10)})
MZ_CODES.update({0x41 + i: 0x01 + i for i in range(26)})
MZ_CODES.update({0x61 + i: 0x81 + i for i in range(26)})
MZ_HAND = {
    0x7F: ['........', '...##...', '..#..#..', '.#....#.', '.#....#.', '.#....#.', '.######.', '........'],
}
# MZ: CP437 -> display code for the characters outside ASCII it has (the ROM has no divide sign)
MZ_CP437 = {0x03: 0x53, 0x04: 0x44, 0x05: 0x46, 0x06: 0x41, 0x07: 0x47, 0x09: 0x48, 0x18: 0x50, 0x19: 0x58,
            0x1A: 0x5A, 0x1B: 0x45, 0x81: 0xAB, 0x84: 0x9B, 0x8E: 0xAE, 0x94: 0xAC, 0x99: 0xAF, 0x9A: 0xAD,
            0x9C: 0x1B, 0x9D: 0xCD, 0xE1: 0xAA, 0xE3: 0x60}

CP437_LOW = {0x03: '♥', 0x04: '♦', 0x05: '♣', 0x06: '♠', 0x07: '•', 0x09: '○', 0x18: '↑', 0x19: '↓', 0x1A: '→',
             0x1B: '←'}

# KOI-8cs2 C0-FF as the AND-1V has it (- none); the CP/M has also ë Ë (C2, E2)
KOI_NAMES = ('-á-čďěŕ-üíůĺľöňóôäřšťú-éàýž-ˇ-¬-'
             '´Á-ČĎĚŔ-ÜÍŮĹĽÖŇÓÔÄŘŠŤÚ-ÉÀÝŽ-----')
# the CP/M letters fixed (rows 0-1): Ň had a zigzag, ô a bar instead of the circumflex
CPM_FIX = {0xEE: ['...#.#..', '.##...#.'], 0xD0: ['...##...', '..#..#..']}
# the signs of KOI-8cs2 the CP/M has not, drawn in the style of the MZ
CPM_HAND = {
    0xDC: ['........', '..#..#..', '...##...', '........', '........', '........', '........', '........'],
    0xDE: ['........', '........', '........', '.######.', '......#.', '........', '........', '........'],
    0xE0: ['........', '....#...', '...#....', '........', '........', '........', '........', '........'],
}

C64_TEXT = '@ABCDEFGHIJKLMNOPQRSTUVWXYZ[£]↑← !"#$%&\'()*+,-./0123456789:;<=>?'


def load(path, kind):
    data = open(path, 'rb').read()
    if zlib.crc32(data) != CRC[kind]:
        sys.exit('%s: CRC32 %08X, expected %08X' % (path, zlib.crc32(data), CRC[kind]))
    return data


def rows(data, off, mirror=False):
    out = []
    for b in data[off:off + 8]:
        if mirror:
            b = int('{:08b}'.format(b)[::-1], 2)
        out.append(''.join('#' if b & (0x80 >> x) else '.' for x in range(8)))
    return out


def section(name, glyphs, names):
    """'[name]' and blocks of 8 glyphs: a header with the codes and names, 8 rows below."""
    out = ['[%s]' % name, '']
    codes = sorted(glyphs)
    for i in range(0, len(codes), 8):
        block = codes[i:i + 8]
        out.append('    ' + '   '.join(('%02X %s' % (c, names.get(c, '-'))).ljust(8) for c in block).rstrip())
        for y in range(8):
            out.append('    ' + '   '.join(glyphs[c][y] for c in block))
        out.append('')
    return out


def header(title, lines):
    return ['# ' + title] + ['# ' + s if s else '#' for s in lines] + [
        '#',
        '# Format: as fonts/sapiterm4x8.txt (tools/fontgen.py parse), glyphs 8 dots wide: a line "[section]", then',
        '# blocks of glyphs: a header line with the codes (hex, then a name), 8 lines of the glyphs below it ("#" dot,',
        '# "." empty) in the same columns as their codes, glyphs separated by spaces.', '']


def write(name, lines):
    path = os.path.join(ROOT, 'fonts', name)
    open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines).rstrip('\n') + '\n')
    print('fonts/' + name)


def printable(c):
    return chr(c) if 0x21 <= c <= 0x7E else '-'


def c64(path):
    data = load(path, 'c64')
    upper = {c: rows(data, c * 8) for c in range(128)}
    lower = {c: rows(data, 0x800 + c * 8) for c in range(128)}
    up_names = {c: C64_TEXT[c] for c in range(1, 0x40) if C64_TEXT[c] != ' '}
    low_names = {c: (C64_TEXT[c].lower() if 1 <= c <= 0x1A else C64_TEXT[c]) for c in range(1, 0x40)
                 if C64_TEXT[c] != ' '}
    low_names.update({c: chr(c) for c in range(0x41, 0x5B)})
    write('c64.txt', header('Font 8x8 of the Commodore 64 (its character ROM 901225-01), for PETSCII in SAPI-Term.', [
        'Copied from chargen-901225-01.bin of the emulator VICE by tools/romfont.py, (c) Commodore; in SAPI-Term',
        'by the decision of its author (docs/rozhodnuti.md). Sections by the screen code 00-7F: upper = the upper',
        'case and graphics set, lower = the lower and upper case set (codes 80-FF are the same inverse).']) +
        section('upper', upper, up_names) + section('lower', lower, low_names))


def atari(path):
    data = load(path, 'atari')
    font = {}
    for a in range(128):
        internal = a + 0x40 if a < 0x20 else a - 0x20 if a < 0x60 else a
        font[a] = rows(data, 0x800 + internal * 8)
    write('atari.txt', header('Font 8x8 of the Atari 400/800 (its OS ROM rev. B), for ATASCII in SAPI-Term.', [
        'Copied from ATARIOSB.ROM of PC Xformer 2.5 by tools/romfont.py, (c) Atari; in SAPI-Term by the decision',
        'of its author (docs/rozhodnuti.md). Section atascii by the ATASCII code 00-7F (80-FF are the same',
        'inverse).']) + section('atascii', font, {c: printable(c) for c in range(128)}))


def cpm_block(path):
    """The block "BIOS CG ZNAKY" of BIOS.mac, 1216 B: ASCII 20-7F -> display code (96 B), 80-BF -> display code
    (64 B), the base letters of KOI C0-DF (32 B), its own font for ASCII 20-7F (768 B), the two accent rows of each
    KOI code C0-FF for its font (128 B) and for the ROM font (128 B, dots D0 left)."""
    lines = open(path, encoding='latin-1').read().splitlines()
    first = next(n for n, line in enumerate(lines) if 'BIOS CG ZNAKY' in line)
    data = bytearray()
    for line in lines[first + 2:]:
        m = re.match(r'(?:\w+:)?\s*DB\s+([^;]*)', line, re.I)
        if m:
            data += bytes(int(v.strip().rstrip('Hh'), 16) for v in m.group(1).split(',') if v.strip())
        elif line.strip() and not line.strip().startswith(';'):
            break
    if zlib.crc32(data) != CRC['cpm']:
        sys.exit('%s: the block BIOS CG ZNAKY has CRC32 %08X, expected %08X' % (path, zlib.crc32(data), CRC['cpm']))
    return bytes(data)


def cpm_letters(block, font):
    """{KOI code: glyph} of the letters as the CP/M composes them with the ROM font (font: ASCII -> rows)."""
    base, accents = block[160:192], block[1088:1216]
    out = {}
    for n, name in enumerate(KOI_NAMES):
        code = 0xC0 + n
        if code in CPM_HAND:
            out[code] = CPM_HAND[code]
            continue
        if name == '-':
            continue
        letter = base[n & 0x1F]
        assert letter != 0x20, name
        letter |= 0x20 if code < 0xE0 else 0
        out[code] = CPM_FIX.get(code, rows(accents, 2 * n, mirror=True)[:2]) + font[letter][2:8]
    return out


def mz800(path, cpm=None):
    data = load(path, 'mz')
    font = {c: rows(data, MZ_CODES[c] * 8, mirror=True) for c in MZ_CODES}
    font.update(MZ_HAND)
    names = {c: printable(c) for c in range(0x20, 0x80)}
    names[0x7F] = '⌂'
    extra = {c: rows(data, MZ_CP437[c] * 8, mirror=True) for c in MZ_CP437}
    write('mz800.txt', header('Font 8x8 of the Sharp MZ-800 (its character ROM), for ANSI in 40 columns in '
                              'SAPI-Term.', [
        'Copied from CGROM.ROM of the MZ-800 by tools/romfont.py, (c) Sharp; in SAPI-Term by the decision of its',
        'author (docs/rozhodnuti.md). Section ascii 20-7F: 7F (the house of CP437) is drawn for SAPI-Term in the',
        'style of the MZ, which lacks it; the rest is the ROM. Section cp437: the characters of CP437 outside',
        'ASCII the MZ has. The Czech and Slovak letters are in fonts/mz800cs.txt.']) +
        section('ascii', font, names) +
        section('cp437', extra, {c: CP437_LOW.get(c) or bytes([c]).decode('cp437') for c in MZ_CP437}))
    if cpm:
        letters = cpm_letters(cpm_block(cpm), font)
        write('mz800cs.txt', header('Czech and Slovak letters of KOI-8cs2 in the font of the Sharp MZ-800, for ANSI '
                                    'in 40 columns.', [
            'As the Czech CP/M of the MZ-800 (Lamač) shows them with the ROM font: its two accent rows (with the top',
            'row of a capital) over the rows 2-7 of the base letter of fonts/mz800.txt; made by tools/romfont.py from',
            'BIOS.mac of the CP/M. Fixed for SAPI-Term: Ň (row 1 was a zigzag), ô (a bar instead of the',
            'circumflex); the signs ˇ ¬ ´ are drawn in the style of the MZ.']) +
            section('koi8cs', letters, {c: KOI_NAMES[c - 0xC0] for c in letters}))


def main():
    args = sys.argv[1:]
    done = False
    for opt, fn in (('--c64', c64), ('--atari', atari)):
        if opt in args:
            fn(args[args.index(opt) + 1])
            done = True
    if '--mz' in args:
        mz800(args[args.index('--mz') + 1], args[args.index('--cpm') + 1] if '--cpm' in args else None)
        done = True
    if not done:
        sys.exit(__doc__)


if __name__ == '__main__':
    main()
