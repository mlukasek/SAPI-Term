"""Shared helpers of the emulator scripts: symbols of the build, the CP/M checkpoint, SAPITERM in memory.

SAPIemu release with MCP on 8595 (tools/emu/sapiemu.cmd), see docs/vyvoj.md. The program is build/sapiterm.com,
its symbols build/sapiterm.sym (build.cmd).
"""
import array
import base64
import os
import re
import sys
import wave
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sapimcp as mcp  # noqa: E402

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
HZ = 4000   # emulator 'cycles' per ms: they count the 4 MHz clock also when the CPU runs at 2 MHz


def symbols(path=os.path.join(REPO, 'build', 'sapiterm.sym')):
    out = {}
    for line in open(path):
        m = re.match(r'(\S+)\s+EQU\s+0*([0-9A-F]+)H', line)
        if m:
            out[m.group(1)] = int(m.group(2), 16)
    return out


def map_latch():
    """(MAP1, MAP2) of port 63h as machine_info shows them (the card with map_port)."""
    def find(o):
        if isinstance(o, dict):
            if 'map_port' in o:
                return o
            o = list(o.values())
        if isinstance(o, list):
            for v in o:
                r = find(v)
                if r:
                    return r
        return None
    d = find(mcp.call('machine_info'))
    return d['map1'], d['map2']


def ram_view():
    """Paused with MAP_CPM: read_memory shows the CPU view, so above C000h with the CGA-1V mapped (SAPI-Term
    drawing at the moment of the pause) it would read the card, not the RAM. Runs on by 1 ms until it is not."""
    for _ in range(200):
        if not any(map_latch()):
            return
        mcp.call('run_for', ms=1)
        mcp.call('pause')
    raise RuntimeError('the CGA-1V stays mapped')


def read(addr, n):
    """n bytes from addr (read_memory gives at most 4096 per call); above C000h from the RAM (ram_view)."""
    if addr + n > 0xC000:
        ram_view()
    out = b''
    while len(out) < n:
        k = min(4096, n - len(out))
        h = mcp.call('read_memory', address='%04X' % (addr + len(out)), length=k, format='hex')
        b = bytes.fromhex(re.sub(r'[^0-9A-Fa-f]', '', h))
        assert len(b) == k, ('read_memory', addr, k, h[:80])
        out += b
    return out


def tone(path):
    """(Hz, ms) of the loud part of a WAV of audio_record (mono, 16 bits), from the first to the last sample above
    a tenth of the peak; Hz from the zero crossings around its mean. (0, 0) when it is silent."""
    with wave.open(path) as w:
        assert w.getsampwidth() == 2 and w.getnchannels() == 1, path
        rate = w.getframerate()
        s = array.array('h', w.readframes(w.getnframes()))
    peak = max((abs(v) for v in s), default=0)
    loud = [i for i, v in enumerate(s) if abs(v) > peak / 10]
    if not peak or len(loud) < 2:
        return 0, 0
    part = s[loud[0]:loud[-1] + 1]
    mean = sum(part) / len(part)
    cross = sum(1 for a, b in zip(part, part[1:]) if (a - mean) * (b - mean) < 0)
    return cross / 2 * rate / len(part), 1000 * len(part) / rate


def use_machine(name):
    """Load machines/<name>.sapi of SAPI-Term into the running emulator (also reloads build/ramdisk.bin)."""
    path = os.path.join(REPO, 'machines', name + '.sapi').replace('\\', '/')
    mcp.call('load_machine', path=path)
    mcp.call('pause')


def checkpoint():
    """The emulator state 'cpm-<machine>-<time of build/ramdisk.bin>' (CP/M on the A> prompt); booted and saved
    when missing. The state lives in the emulator's memory and is lost when it ends; it carries the machine and
    the RAM disk, so it is kept per machine file and build. ECMON choice 3: CP/M from the RAM disk (choices 0-2
    wait for a floppy controller that the set V does not have)."""
    mcp.call('pause')
    machine = os.path.splitext(os.path.basename(mcp.call('machine_info').get('machine_file', '')))[0]
    disk = os.path.join(REPO, 'build', 'ramdisk.bin')
    name = 'cpm-%s-%d' % (machine, int(os.path.getmtime(disk)) if os.path.exists(disk) else 0)
    try:
        mcp.call('load_state', name=name)
    except RuntimeError:
        mcp.call('power', state='cycle')
        mcp.call('resume')
        res = mcp.call('run_until', screen_text='Zadej 0-3', timeout_ms=20000)
        assert res.get('stopped') != 'timeout', 'ECMON menu did not appear'
        mcp.call('type_text', text='3')
        res = mcp.call('run_until', screen_text='A>', timeout_ms=30000)
        assert res.get('stopped') != 'timeout', 'CP/M did not start'
        mcp.call('pause')
        mcp.call('save_state', name=name)
    mcp.call('pause')


def command(text, wait='A>', timeout_ms=30000):
    """Type a CP/M command line, run until the screen shows wait; returns the screen text (AND-1V). The run
    before the wait covers the typing: the Consul 262.3 without the 7474 latch gets 20 ms per key."""
    mcp.call('resume')
    mcp.call('type_text', text=text + '\r')
    mcp.call('run_for', ms=200 + 25 * (len(text) + 1))
    res = mcp.call('run_until', screen_text=wait, timeout_ms=timeout_ms)
    mcp.call('pause')
    assert res.get('stopped') != 'timeout', ('command', text, 'no', wait)
    return mcp.call('screen_text')


def command_lines(text, timeout_ms=15000):
    """Type a CP/M command, run until the prompt A> is on the last line again; returns every line seen on the
    console meanwhile (read every 50 ms of emulation, so lines that scrolled away are there too). The console of
    ECMON waits for a key when the output has filled the screen: after 1 s without a change Enter goes on."""
    before = mcp.call('screen_text').replace('▒', ' ').rstrip()     # the cursor blinks
    mcp.call('resume')
    mcp.call('type_text', text=text + '\r')
    mcp.call('run_for', ms=200 + 25 * (len(text) + 1))
    seen = []
    started = False                             # the screen changed since the typing began
    last, still = None, 0
    t = 0
    while t < timeout_ms:
        mcp.call('run_for', ms=50)
        t += 50
        screen = mcp.call('screen_text')
        lines = screen.rstrip().split('\n')
        seen += [ln for ln in lines if ln not in seen]
        screen = screen.replace('▒', ' ').rstrip()
        started = started or screen != before
        at = [i for i, ln in enumerate(lines) if text in ln]
        if started and lines[-1].strip('▒ ') == 'A>' and (not at or at[-1] < len(lines) - 1):
            break
        still = still + 50 if screen == last else 0
        last = screen
        if started and still >= 1000:
            mcp.call('type_text', text='\r')
            still = 0
    mcp.call('pause')
    return '\n'.join(seen)


class Term:
    """SAPITERM loaded from build/sapiterm.com straight into memory (no disk) and started at 0100h."""

    def __init__(self, root=REPO):
        self.root = root
        self.sym = symbols(os.path.join(root, 'build', 'sapiterm.sym'))

    def start(self, turbo=True):
        checkpoint()
        mcp.call('cpu_turbo', on=turbo)
        mcp.call('load_binary', address='0100', path=os.path.join(self.root, 'build', 'sapiterm.com'))
        mcp.call('set_registers', pc='0100')

    def run_to(self, name, timeout=3000):
        """Run to the address (symbol or number), return the emulator cycles."""
        addr = self.sym[name] if isinstance(name, str) else name
        res = mcp.call('run_until', address='%04X' % addr, timeout_ms=timeout)
        assert res.get('stopped') != 'timeout', ('run_until', name, res)
        return res['cycles']

    def byte(self, name):
        return read(self.sym[name], 1)[0]


def cga_blank():
    """When paused: on by 1 ms until the beam of the CGA-1V is below the picture (line 400 on). SAPIemu 0.7.0-beta:
    a screenshot with the beam at the top of a frame may show rows below it older than the last frame
    (docs/vyvoj.md). A running emulator is left as it is."""
    for _ in range(40):
        info = mcp.call('machine_info')
        cga = next((c.get('details', {}) for c in info.get('cards', []) if c.get('type') == 'CGA-1V'), None)
        if info.get('state') != 'paused' or not cga or cga.get('beam_line', 400) >= 400:
            return
        mcp.call('run_for', ms=1)
        mcp.call('pause')


def screenshot(path, display='CGA-1V'):
    """PNG of a display, saved again with zlib (the emulator's PNG is not compressed); the CGA-1V with its beam
    below the picture (cga_blank)."""
    if display == 'CGA-1V':
        cga_blank()
    res = mcp.call('screenshot', display=display)
    img = next(c for c in (res if isinstance(res, list) else [res]) if isinstance(c, dict) and c.get('data'))
    data = base64.b64decode(img['data'])
    open(path, 'wb').write(recompress(data))
    return path


def recompress(png):
    """Re-deflate the IDAT data of a PNG (level 9)."""
    out, pos, idat = png[:8], 8, b''
    chunks = []
    while pos < len(png):
        n = int.from_bytes(png[pos:pos + 4], 'big')
        kind = png[pos + 4:pos + 8]
        body = png[pos + 8:pos + 8 + n]
        pos += 12 + n
        if kind == b'IDAT':
            idat += body
        else:
            chunks.append((kind, body))
    raw = zlib.decompress(idat)
    for kind, body in chunks:
        if kind == b'IEND':
            out += chunk(b'IDAT', zlib.compress(raw, 9))
        out += chunk(kind, body)
    return out


def chunk(kind, body):
    return len(body).to_bytes(4, 'big') + kind + body + zlib.crc32(kind + body).to_bytes(4, 'big')
