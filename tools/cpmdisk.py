"""Put files into a copy of the ZRD-1V / ZRMD-1 RAM disk image (CP/M 2.2), standard library only.

Taken unchanged from SAPI-Bad-Apple (tools/cpmdisk.py, the same as in SAPI-Prince-of-Persia), same author, GPLv3.

Usage: python tools/cpmdisk.py [--empty] SRC_IMAGE OUT_IMAGE FILE[=CPMNAME[@BLOCK]] ...
       python tools/cpmdisk.py --dir IMAGE
       python tools/cpmdisk.py --get IMAGE CPMNAME OUT   (a file of user 0 out of the image)
--empty: only the system area of SRC_IMAGE (first 32 KB: the 4 x 8 KB systems ECMON boots from) is kept, the
directory and the data area are E5 (an empty disk), then the files are added.
@BLOCK: the file must lie contiguously from block BLOCK (physical 8000h + BLOCK * 4096), else an error
(POP.DAT@8: the program reads it at 10000h without the directory).

Disk parameters of the RAM disk (SAPIemu docs/desky/ZRMD-1.md, DPB): 4 MB linear, track = 256 B,
OFF = 128 tracks (32 KB system), blocks of 4 KB (BSH 5), DSM 1015, DRM 1023, EXM 1, AL0/AL1 = FF00h
(directory = blocks 0-7, 1024 entries of 32 B at offset 8000h), block n at 8000h + n * 4096.
Block numbers in a directory entry are 16-bit (DSM > 255), 8 per entry = 32 KB = 2 logical extents.
An existing file of the same name is replaced. The source image is not changed.
"""
import sys

DIR_OFF = 0x8000
BLOCK = 4096
DSM = 1015
DRM = 1023
DIR_BLOCKS = 8


def entries(img):
    for i in range(DRM + 1):
        a = DIR_OFF + 32 * i
        yield i, a, img[a:a + 32]


def entry_name(e):
    name = bytes(b & 0x7F for b in e[1:9]).decode('ascii', 'replace').rstrip()
    ext = bytes(b & 0x7F for b in e[9:12]).decode('ascii', 'replace').rstrip()
    return f'{name}.{ext}' if ext else name


def used_blocks(img):
    used = set(range(DIR_BLOCKS))
    for _, _, e in entries(img):
        if e[0] <= 15:
            for k in range(8):
                b = e[16 + 2 * k] | e[17 + 2 * k] << 8
                if b:
                    used.add(b)
    return used


def delete(img, cpmname):
    for _, a, e in entries(img):
        if e[0] == 0 and entry_name(e) == cpmname:
            img[a] = 0xE5


def fcb_name(cpmname):
    name, _, ext = cpmname.upper().partition('.')
    return name.ljust(8)[:8].encode() + ext.ljust(3)[:3].encode()


def add(img, data, cpmname, at=None):
    delete(img, cpmname)
    used = used_blocks(img)
    free = [b for b in range(DIR_BLOCKS, DSM + 1) if b not in used]
    nblocks = (len(data) + BLOCK - 1) // BLOCK
    if nblocks > len(free):
        raise SystemExit(f'{cpmname}: needs {nblocks} blocks, {len(free)} free')
    blocks = free[:nblocks]
    if at is not None:
        blocks = list(range(at, at + nblocks))
        if blocks[-1] > DSM or any(b in used for b in blocks):
            raise SystemExit(f'{cpmname}: blocks {at}-{at + nblocks - 1} are not free')
    for i, b in enumerate(blocks):
        chunk = data[i * BLOCK:(i + 1) * BLOCK]
        a = DIR_OFF + b * BLOCK
        img[a:a + BLOCK] = chunk + bytes([0x1A]) * (BLOCK - len(chunk))
    records = (len(data) + 127) // 128
    free_entries = [a for _, a, e in entries(img) if e[0] == 0xE5]
    nent = max(1, (nblocks + 7) // 8)
    if nent > len(free_entries):
        raise SystemExit('directory full')
    for j in range(nent):
        a = free_entries[j]
        recs = min(256, records - j * 256)  # records in this entry (32 KB = 256 records)
        ext_used = max(1, (recs + 127) // 128)
        ex = 2 * j + ext_used - 1
        rc = recs - (ext_used - 1) * 128
        e = bytearray(32)
        e[0] = 0
        e[1:12] = fcb_name(cpmname)
        e[12] = ex & 0x1F
        e[13] = 0
        e[14] = ex >> 5
        e[15] = rc
        for k, b in enumerate(blocks[j * 8:(j + 1) * 8]):
            e[16 + 2 * k] = b & 0xFF
            e[17 + 2 * k] = b >> 8
        img[a:a + 32] = e
    return blocks


def get(img, cpmname):
    """Contents of a file of user 0 (whole records; CP/M does not know the exact length)."""
    ents = sorted((e[12] | e[14] << 5, e) for _, _, e in entries(img) if e[0] == 0 and entry_name(e) == cpmname)
    if not ents:
        raise SystemExit(f'{cpmname}: not on the disk')
    data = bytearray()
    for _, e in ents:
        for k in range(8):
            b = e[16 + 2 * k] | e[17 + 2 * k] << 8
            if b:
                data += img[DIR_OFF + b * BLOCK:DIR_OFF + (b + 1) * BLOCK]
    ex, last = ents[-1]
    return bytes(data[:(ex * 128 + last[15]) * 128])


def show_dir(img):
    files = {}
    for _, _, e in entries(img):
        if e[0] <= 15:
            files.setdefault((e[0], entry_name(e)), 0)
            files[(e[0], entry_name(e))] += sum(1 for k in range(8) if e[16 + 2 * k] | e[17 + 2 * k])
    for (u, n), b in sorted(files.items()):
        print(f'{u:2} {n:12} {b * 4:6} KB')
    print(f'free {(DSM + 1 - len(used_blocks(img))) * 4} KB')


def main():
    if sys.argv[1] == '--dir':
        show_dir(bytearray(open(sys.argv[2], 'rb').read()))
        return
    if sys.argv[1] == '--get':
        data = get(bytearray(open(sys.argv[2], 'rb').read()), sys.argv[3].upper())
        open(sys.argv[4], 'wb').write(data)
        print(f'{sys.argv[3].upper()}: {len(data)} B')
        return
    args = sys.argv[1:]
    empty = args[0] == '--empty'
    if empty:
        args = args[1:]
    img = bytearray(open(args[0], 'rb').read())
    if empty:
        img[DIR_OFF:] = bytes([0xE5]) * (len(img) - DIR_OFF)
    for spec in args[2:]:
        path, _, name = spec.partition('=')
        name, _, at = name.partition('@')
        if not name:
            name = path.replace('\\', '/').split('/')[-1]
        blocks = add(img, open(path, 'rb').read(), name.upper(), int(at) if at else None)
        print(f'{name.upper()}: {len(blocks)} blocks, first {blocks[0]}')
    open(args[1], 'wb').write(img)


if __name__ == '__main__':
    main()
