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
    if s['BSS_END'] > 0xC000:
        errors.append(f'buffers and stack up to {s["BSS_END"]:04X}h, over C000h')
    if errors:
        sys.exit('\n'.join(errors))
    pages = (size + 255) // 256
    print(f'layout ok: program 0100-{s["PROGRAM_END"] - 1:04X}h ({size} B), buffers and stack to '
          f'{s["BSS_END"] - 1:04X}h; in CP/M: SAVE {pages} SAPITERM.COM')


if __name__ == '__main__':
    main()
