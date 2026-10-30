"""Fonts 8x8 of the original machines for SAPI-Term: ROM dumps -> fonts/c64.txt, fonts/atari.txt, fonts/mz700.txt
(the sources of tools/petfont.py, tools/atafont.py and tools/mzfont.py; docs/rozhodnuti.md "Písma 8x8").

Run by hand only when a source changes; the ROMs are not in the repository (work/roms, docs/vyvoj.md).
  python tools/romfont.py --c64 chargen-901225-01.bin --atari ATARIOSB.ROM --mz mz700fon.int
Sources (checked by their CRC32):
  C64    chargen-901225-01.bin of VICE (data/C64), 4096 B: screen codes 00-7F of the upper case set at 000h, of
         the lower case set at 800h (the inverse halves are not used: SAPI-Term swaps the colours).
  Atari  ATARIOSB.ROM (OS rev. B, D800-FFFF) of PC Xformer 2.5 (xf25.zip of the Atari800 project at
         SourceForge), the font at E000h = offset 800h in the internal order: 00-3F = ATASCII 20-5F,
         40-5F = 00-1F, 60-7F = 60-7F. The 800XL has the same font.
  MZ     mz700fon.int (MZ-700, the European CGROM) of MAME, 4096 B, dots D0 (left) to D7: ASCII 20-5D as the
         monitor 1Z-013A converts them to display codes (its table at 0A92h + the code), a-z = display codes
         81-9A, _ and | its lines 3C and 79; ^ ` { } ~ and the house 7F (CP437) the MZ-700 lacks are drawn here
         in its style (dots one wide, capitals rows 0-6).
"""
import os
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CRC = {'c64': 0xEC4272EE, 'atari': 0x3E28A1FE, 'mz': 0x42B9E8FB}

# MZ-700: ASCII -> display code (the monitor's table for 20-5D, a-z, two of its lines)
MZ_CODES = {0x20: 0x00, 0x21: 0x61, 0x22: 0x62, 0x23: 0x63, 0x24: 0x64, 0x25: 0x65, 0x26: 0x66, 0x27: 0x67,
            0x28: 0x68, 0x29: 0x69, 0x2A: 0x6B, 0x2B: 0x6A, 0x2C: 0x2F, 0x2D: 0x2A, 0x2E: 0x2E, 0x2F: 0x2D,
            0x3A: 0x4F, 0x3B: 0x2C, 0x3C: 0x51, 0x3D: 0x2B, 0x3E: 0x57, 0x3F: 0x49, 0x40: 0x55, 0x5B: 0x52,
            0x5C: 0x59, 0x5D: 0x54, 0x5F: 0x3C, 0x7C: 0x79}
MZ_CODES.update({0x30 + i: 0x20 + i for i in range(10)})
MZ_CODES.update({0x41 + i: 0x01 + i for i in range(26)})
MZ_CODES.update({0x61 + i: 0x81 + i for i in range(26)})
MZ_HAND = {
    0x5E: ['...##...', '..#..#..', '.#....#.', '........', '........', '........', '........', '........'],
    0x60: ['..#.....', '...#....', '....#...', '........', '........', '........', '........', '........'],
    0x7B: ['....##..', '...#....', '...#....', '..#.....', '...#....', '...#....', '....##..', '........'],
    0x7D: ['..##....', '....#...', '....#...', '.....#..', '....#...', '....#...', '..##....', '........'],
    0x7E: ['........', '........', '..##..#.', '.#..##..', '........', '........', '........', '........'],
    0x7F: ['........', '...##...', '..#..#..', '.#....#.', '.#....#.', '.#....#.', '.######.', '........'],
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


def mz700(path):
    data = load(path, 'mz')
    font = {c: rows(data, MZ_CODES[c] * 8, mirror=True) for c in MZ_CODES}
    font.update(MZ_HAND)
    names = {c: printable(c) for c in range(0x20, 0x80)}
    names[0x7F] = '⌂'
    write('mz700.txt', header('Font 8x8 of the Sharp MZ-700 (its character ROM), for ANSI in 40 columns in SAPI-Term.', [
        'Copied from mz700fon.int of MAME by tools/romfont.py, (c) Sharp; in SAPI-Term by the decision of its',
        'author (docs/rozhodnuti.md). Section ascii 20-7F: ^ ` { } ~ and 7F (the house of CP437) are drawn for',
        'SAPI-Term in the style of the MZ-700, which lacks them; the rest is the ROM.']) +
        section('ascii', font, names))


def main():
    args = sys.argv[1:]
    done = False
    for opt, fn in (('--c64', c64), ('--atari', atari), ('--mz', mz700)):
        if opt in args:
            fn(args[args.index(opt) + 1])
            done = True
    if not done:
        sys.exit(__doc__)


if __name__ == '__main__':
    main()
