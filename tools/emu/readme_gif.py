"""The aquarium of telehack.com as an animated GIF for the README (docs/img/telehack.gif).
  python tools/emu/readme_gif.py capture [SECONDS]   SAPITERM 16, aquarium, after it fills a CGA-1V screenshot
                                                     every ~100 ms to build/preview/aqua/NNN.png (times.json)
  python tools/emu/readme_gif.py gif [OUT.gif]       the frames as a GIF89a: the first whole, then the rectangle
                                                     that changed; each frame shown as long as it took to capture
Needs the emulator with MCP (tools/emu/sapiemu.cmd), build.cmd and the internet (capture).
"""
import base64
import json
import os
import struct
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..'))
import emu  # noqa: E402
from emu import mcp  # noqa: E402
import ansiref  # noqa: E402

FRAMES = os.path.join(emu.REPO, 'build', 'preview', 'aqua')
FILL_SECS = 25          # the aquarium starts empty


def capture(secs):
    import realbbs
    from phase4 import row_koi
    os.makedirs(FRAMES, exist_ok=True)
    for f in os.listdir(FRAMES):
        os.remove(os.path.join(FRAMES, f))
    sym = emu.symbols()
    emu.use_machine('sapi1v_term')
    emu.checkpoint()
    mcp.call('resume')
    mcp.call('type_text', text='SAPITERM 16\r')
    realbbs.run_wall(25, lambda: emu.read(sym['mode'], 1)[0] == realbbs.MODE_ONLINE)
    realbbs.run_wall(20, lambda: any(row_koi(sym, r).rstrip() == '.' for r in range(25)))
    mcp.call('resume')
    mcp.call('type_text', text='aquarium\r', run_ms=300)
    realbbs.run_wall(FILL_SECS)
    times = []
    end = time.time() + secs
    while time.time() < end:
        mcp.call('run_for', ms=100)
        mcp.call('pause')
        emu.cga_blank()
        res = mcp.call('screenshot', display='CGA-1V')
        img = next(c for c in (res if isinstance(res, list) else [res]) if isinstance(c, dict) and c.get('data'))
        times.append(time.time())
        open(os.path.join(FRAMES, '%03d.png' % len(times)), 'wb').write(base64.b64decode(img['data']))
    json.dump(times, open(os.path.join(FRAMES, 'times.json'), 'w'))
    print('%d frames in %.1f s' % (len(times), times[-1] - times[0]))
    mcp.call('resume')
    mcp.call('type_text', text='\x03', run_ms=500)
    mcp.call('type_text', text='\x1d', run_ms=500)
    mcp.call('type_text', text='o', run_ms=500)
    realbbs.run_wall(10, lambda: row_koi(sym, 18).startswith('BBS:'))
    mcp.call('pause')


def lzw(pixels, min_size):
    """GIF LZW of the colour indices, as the data sub-blocks (after the minimum code size byte)."""
    clear, eoi = 1 << min_size, (1 << min_size) + 1
    out = bytearray()
    acc = bits = 0

    def put(code, size):
        nonlocal acc, bits
        acc |= code << bits
        bits += size
        while bits >= 8:
            out.append(acc & 0xFF)
            acc >>= 8
            bits -= 8
    size, nxt, table = min_size + 1, eoi + 1, {}
    put(clear, size)
    prefix = pixels[0]
    for k in pixels[1:]:
        key = prefix << 8 | k
        code = table.get(key)
        if code is not None:
            prefix = code
            continue
        put(prefix, size)
        if nxt < 4096:
            table[key] = nxt
            nxt += 1
            if nxt > 1 << size and size < 12:
                size += 1
        else:
            put(clear, size)
            size, nxt, table = min_size + 1, eoi + 1, {}
        prefix = k
    put(prefix, size)
    put(eoi, size)
    if bits:
        out.append(acc & 0xFF)
    return b''.join(bytes([len(out[i:i + 255])]) + out[i:i + 255] for i in range(0, len(out), 255)) + b'\0'


def gif(out_path):
    names = sorted(f for f in os.listdir(FRAMES) if f.endswith('.png'))
    times = json.load(open(os.path.join(FRAMES, 'times.json')))
    index, frames = {}, []                          # each frame as bytes of colour indices
    for n in names:
        w, h, rgb = ansiref.png_rgb(os.path.join(FRAMES, n))
        pix = bytearray(w * h)
        for p in range(w * h):
            c = rgb[3 * p:3 * p + 3]
            i = index.get(c)
            if i is None:
                i = index[c] = len(index)
            pix[p] = i
        frames.append(bytes(pix))
    assert len(index) <= 256, len(index)
    bits = max(1, (len(index) - 1).bit_length())
    table = b''.join(sorted(index, key=index.get)) + b'\0\0\0' * ((1 << bits) - len(index))
    data = bytearray(b'GIF89a' + struct.pack('<HHBBB', w, h, 0x80 | 0x70 | (bits - 1), 0, 0) + table)
    data += b'\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00'         # loop for ever
    prev = None
    kept = 0
    for i, pix in enumerate(frames):
        if prev is None:
            x0, y0, x1, y1 = 0, 0, w - 1, h - 1
        else:
            rows = [y for y in range(h) if pix[y * w:(y + 1) * w] != prev[y * w:(y + 1) * w]]
            if not rows:
                continue                                        # the delay of the frame before grows
            y0, y1 = rows[0], rows[-1]
            xs = [x for y in rows for x in range(w) if pix[y * w + x] != prev[y * w + x]]
            x0, x1 = min(xs), max(xs)
        nxt = next((j for j in range(i + 1, len(frames)) if frames[j] != pix), len(frames) - 1)
        delay = max(2, round(100 * (times[nxt] - times[i]))) if nxt > i else 10
        sub = b''.join(pix[y * w + x0:y * w + x1 + 1] for y in range(y0, y1 + 1))
        data += b'\x21\xF9\x04' + struct.pack('<BHBB', 1 << 2, delay, 0, 0)     # disposal: keep
        data += b'\x2C' + struct.pack('<HHHHB', x0, y0, x1 - x0 + 1, y1 - y0 + 1, 0)
        data += bytes([max(2, bits)]) + lzw(sub, max(2, bits))
        prev = pix
        kept += 1
    data += b'\x3B'
    open(out_path, 'wb').write(data)
    print('%s: %d frames of %d, %d colours, %d bytes' % (out_path, kept, len(frames), len(index), len(data)))


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    if sys.argv[1:2] == ['capture']:
        capture(float(sys.argv[2]) if len(sys.argv) > 2 else 15)
    elif sys.argv[1:2] == ['gif']:
        gif(sys.argv[2] if len(sys.argv) > 2 else os.path.join(emu.REPO, 'docs', 'img', 'telehack.gif'))
    else:
        sys.exit(__doc__)
