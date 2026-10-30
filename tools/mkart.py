"""Test ANSI files of SAPI-Term (own, made by this script) -> build/art/*.ANS, put on the RAM disk by build.cmd.

ANSITEST.ANS  the parser: SGR, cursor, erase, insert / delete, scroll region, wrap, controls, unknown sequences
SUNSET.ANS    a picture of half blocks with iCE colours (bright backgrounds through blink), SAUCE record
MENU.ANS      a BBS-like menu with frames and colours
SCROLL.ANS    75 coloured lines: scrolling through all the domains of the CGA-1V
Every file keeps at most 16 attributes in a domain (4 text rows) at any time, checked with tools/ansiref.py,
so the picture on the CGA-1V must match the reference exactly.
  python tools/mkart.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ansiref  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'build', 'art')
ESC = b'\x1b'


def csi(s):
    return ESC + b'[' + s.encode('ascii')


def cp(s):
    return s.encode('cp437')


def at(r, c):
    return csi('%d;%dH' % (r, c))


def ansitest():
    b = csi('0m') + csi('2J')
    b += csi('1;37m') + cp('SAPI-Term ANSI test') + csi('0m')
    # row 2: 16 foregrounds on black (domain 0: these 16 attributes only)
    b += at(2, 1)
    for f in range(8):
        b += csi('0;%dm' % (30 + f)) + cp('%d' % f)
    for f in range(8):
        b += csi('1;%dm' % (30 + f)) + cp('%d' % f)
    b += csi('0m') + at(3, 1) + cp('cursor:') + at(3, 20) + cp('X') + csi('A') + csi('B') + csi('2C') + cp('R')
    b += csi('3D') + cp('L') + csi('s') + at(3, 40) + cp('S') + csi('u') + cp('u') + ESC + b'7' + at(3, 50)
    b += cp('7') + ESC + b'8' + cp('8')
    # rows 5-6: backgrounds (domain 1), 90-97 and 100-107, reverse
    b += at(5, 1) + csi('0;37;40m') + cp('0')
    for g in range(1, 8):
        b += csi('1;37;%dm' % (40 + g)) + cp('%d' % g)
    b += csi('0m') + at(6, 1)
    for g in range(8):
        b += csi('30;%dm' % (100 + g)) + cp('%d' % g)
    b += csi('0m')
    # rows 9-12: erase (domain 2)
    for r in (9, 10, 11):
        b += at(r, 1) + cp('erase-ABCDEFGHIJKLMNOPQRSTUVWXYZ')
    b += at(9, 10) + csi('K') + at(10, 10) + csi('1K') + at(11, 10) + csi('2K')
    b += at(12, 1) + cp('ech-ABCDEFGHIJ') + at(12, 6) + csi('3X')
    b += at(12, 30) + csi('7;32m') + cp('rev') + csi('27m') + cp('n') + csi('0m')
    # rows 13-16: insert / delete characters (domain 3)
    b += at(13, 1) + cp('ich-abcdefghij') + at(13, 6) + csi('34;2@') + cp('++') + csi('0m')
    b += at(14, 1) + cp('dch-abcdefghij') + at(14, 6) + csi('3P')
    b += at(15, 1) + cp('tab\tA\tB\x08\x08x') + at(16, 1) + cp('glyphs \x01\x02\x03\x04\x05\x06\x0e\x0f\x10\x11\x7f')
    # rows 17-20: wrap (domain 4)
    b += at(17, 1) + cp(''.join(chr(48 + i % 10) for i in range(80))) + b'\r\n' + cp('after a full line')
    b += at(19, 1) + csi('?7l') + cp(''.join(chr(65 + i % 26) for i in range(85))) + csi('?7h')
    b += at(20, 75) + cp('wrap-on')
    # rows 21-24: scroll region, insert / delete lines, unknown sequences (domains 5 and 6)
    b += at(21, 1) + cp('line 21') + at(22, 1) + cp('line 22') + at(23, 1) + cp('line 23') + at(24, 1) + cp('line 24')
    b += at(25, 1) + cp('line 25')
    b += csi('22;24r') + at(24, 1) + b'\n' + csi('35m') + cp('scrolled in the region') + csi('0m')
    b += at(22, 1) + csi('L') + cp('inserted') + at(23, 1) + csi('M') + csi('S') + csi('T') + csi('r')
    b += csi('=255h') + csi('1;2;3t') + csi('?1049h') + csi('38;5;196m') + csi('48;2;1;2;3m') + ESC + b'(B'
    b += at(25, 10) + cp('end') + csi('0m')
    b += csi('?25l')
    return b


def sunset():
    """80x50 'pixels' (a cell = upper half foreground, lower half background), iCE: bright backgrounds."""
    W, H = 80, 50
    px = [[0] * W for _ in range(H)]
    sky = [1, 1, 9, 9, 5, 13, 12, 12, 4, 6, 14, 14]
    for y in range(H):
        for x in range(W):
            if y < 24:
                px[y][x] = sky[min(len(sky) - 1, y // 2)]
            else:
                px[y][x] = 1 if (x + y) % 7 else 9
    cx, cy = 40, 15
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - cx) / 2.0, y - cy)
            if y < 24 and d < 8:
                px[y][x] = 14 if d < 6 else 6
    for y in range(24, H):                      # reflection of the sun
        for x in range(34, 47):
            if (x + 2 * y) % 5 == 0 and abs(x - 40) < 8 - (y - 24) // 4:
                px[y][x] = 14
    for x in range(W):                          # hills
        top = 21 + int(1.5 * math.sin(x / 7.0) + 1.2 * math.sin(x / 3.1))
        if 30 <= x < 51:
            top = 23                            # a valley under the sun
        for y in range(max(top, 0), 24):
            px[y][x] = 2 if (x // 3 + y) % 4 else 10
    b = csi('0m') + csi('2J')
    last = None
    for r in range(25):
        b += at(r + 1, 1)
        for x in range(W):
            fg, bg = px[2 * r][x], px[2 * r + 1][x]
            if (fg, bg) != last:
                b += sgr_cga(fg, bg)
                last = (fg, bg)
            if r == 24 and x == W - 1:
                b += csi('?7l')                 # the last cell without scrolling
            b += b'\xdf'
    b += csi('0m') + csi('?25l')
    return b + b'\x1a' + sauce('Sunset', 80, 25, ice=True)


def sgr_cga(fg, bg):
    """SGR for CGA colours (bright background through blink = iCE)."""
    c2a = [0, 4, 2, 6, 1, 5, 3, 7]
    return csi('0;%s%s3%d;4%dm' % ('1;' if fg & 8 else '', '5;' if bg & 8 else '', c2a[fg & 7], c2a[bg & 7]))


def sauce(title, w, h, ice):
    rec = bytearray(128)
    rec[0:7] = b'SAUCE00'
    rec[7:42] = title.encode('ascii').ljust(35)
    rec[42:62] = b'SAPI-Term'.ljust(20)
    rec[62:82] = b'SAPI-Term'.ljust(20)
    rec[82:90] = b'20261030'
    rec[94] = 1                                 # character
    rec[95] = 1                                 # ANSi
    rec[96:98] = w.to_bytes(2, 'little')
    rec[98:100] = h.to_bytes(2, 'little')
    rec[105] = 1 if ice else 0
    return bytes(rec)


def menu():
    b = csi('0m') + csi('2J')
    b += csi('1;37;44m') + cp(' SAPI-Term BBS ' + ' ' * 50 + 'Node 1 ') + csi('0m')
    b += at(3, 10) + csi('1;36m') + cp('╔' + '═' * 58 + '╗')
    for r in range(4, 18):
        b += at(r, 10) + cp('║') + at(r, 69) + cp('║')
    b += at(18, 10) + cp('╚' + '═' * 58 + '╝')
    items = [('M', 'Message areas', 'Zprávy'), ('F', 'File areas', 'Soubory'), ('D', 'Door games', 'Hry'),
             ('W', "Who's online", 'Kdo je tu'), ('B', 'Bulletins', 'Oznámení'), ('G', 'Goodbye', 'Konec')]
    for i, (k, en, cz) in enumerate(items):
        b += at(5 + 2 * i, 14) + csi('0;37m') + cp('[') + csi('1;33m') + cp(k) + csi('0;37m') + cp(']')
        b += csi('1;37m') + cp(' %-20s' % en) + csi('0;36m') + cz.encode('cp437', 'replace')
    b += at(20, 1) + csi('0;32m') + cp('─' * 80)
    b += at(21, 2) + csi('1;32m') + cp('Time left: ') + csi('1;37m') + cp('59 min') + csi('0;32m')
    b += cp('   Calls today: ') + csi('1;37m') + cp('42')
    b += at(23, 2) + csi('0;37m') + cp('Your choice: ') + csi('1;33;41m') + cp(' ') + csi('0m') + csi('D')
    return b


def scroll():
    b = csi('0m') + csi('2J')
    for n in range(1, 76):
        fg = 30 + n % 8
        bold = '1;' if n % 3 == 0 else ''
        b += csi('0;%s%dm' % (bold, fg)) + cp('Line %2d: ' % n) + csi('0m')
        b += cp('the quick brown fox jumps over the lazy dog ') + csi('4%dm' % (n % 8)) + cp('%02d' % n)
        b += csi('0m') + b'\r\n'
    return b


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, make in (('ANSITEST', ansitest), ('SUNSET', sunset), ('MENU', menu), ('SCROLL', scroll)):
        data = make()
        t = ansiref.run(data)
        worst = max(t.max_pairs)
        if worst > 16:
            sys.exit('%s.ANS: a domain has %d attributes at once (%s)' % (name, worst, t.max_pairs))
        open(os.path.join(OUT, name + '.ANS'), 'wb').write(data)
        print('build/art/%s.ANS %d B, pairs per domain at most %s' % (name, len(data), t.max_pairs))


if __name__ == '__main__':
    main()
