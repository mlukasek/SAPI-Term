"""Checks of the memory layout of build/sapiterm.com (symbols from build/sapiterm.sym), prints SAVE n."""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def symbols(path=os.path.join(ROOT, 'build', 'sapiterm.sym')):
    out = {}
    for line in open(path):
        m = re.match(r'(\S+)\s+EQU\s+0*([0-9A-F]+)H', line)
        if m:
            out[m.group(1)] = int(m.group(2), 16)
    return out


def main():
    s = symbols()
    size = os.path.getsize(os.path.join(ROOT, 'build', 'sapiterm.com'))
    errors = []
    if 0x100 + size != s['PROGRAM_END']:
        errors.append(f'sapiterm.com has {size} B, PROGRAM_END is {s["PROGRAM_END"]:04X}h')
    # everything must stay below C000h: MAP_CGA puts the CGA-1V there
    if s['BSS_END'] > s['att_slot']:
        errors.append(f'buffers and stack up to {s["BSS_END"]:04X}h, over att_slot {s["att_slot"]:04X}h')
    # pasmo: an EQU using a symbol defined after it gives the code before it the value of the first pass;
    # the first LD SP,nn of the program must be STACK_TOP
    com = open(os.path.join(ROOT, 'build', 'sapiterm.com'), 'rb').read()
    i = com.find(b'1', s['start'] - 0x100)
    if i < 0 or com[i + 1] | com[i + 2] << 8 != s['STACK_TOP']:
        errors.append('LD SP in the code is not STACK_TOP %04Xh (an EQU uses a symbol defined after it)'
                      % s['STACK_TOP'])
    # tables indexed by the low byte of the address
    for name in ('font_cp437', 'font_koi', 'and_map_cp437', 'col_dist', 'cga_rows', 'att_slot'):
        if name in s and s[name] & 0xFF:
            errors.append(f'{name} at {s[name]:04X}h is not page aligned')
    if s['font_cp437'] != 0x200:
        errors.append(f'font_cp437 at {s["font_cp437"]:04X}h, not 0200h: the buffers before it grew too much')
    if errors:
        sys.exit('\n'.join(errors))
    pages = (size + 255) // 256
    print(f'layout ok: program 0100-{s["PROGRAM_END"] - 1:04X}h ({size} B), buffers and stack to '
          f'{s["BSS_END"] - 1:04X}h, {s["att_slot"] - s["BSS_END"]} B free below att_slot; in CP/M: SAVE {pages} '
          'SAPITERM.COM')


if __name__ == '__main__':
    main()
