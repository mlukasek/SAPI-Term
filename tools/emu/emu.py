"""Shared helpers of the emulator scripts: symbols of the build, the CP/M checkpoint, SAPITERM in memory.

SAPIemu release with MCP on 8595 (tools/emu/sapiemu.cmd), see docs/vyvoj.md. The program is build/sapiterm.com,
its symbols build/sapiterm.sym (build.cmd).
"""
import base64
import os
import re
import sys
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


def read(addr, n):
    """n bytes from addr (read_memory gives at most 4096 per call)."""
    out = b''
    while len(out) < n:
        k = min(4096, n - len(out))
        h = mcp.call('read_memory', address='%04X' % (addr + len(out)), length=k, format='hex')
        b = bytes.fromhex(re.sub(r'[^0-9A-Fa-f]', '', h))
        assert len(b) == k, ('read_memory', addr, k, h[:80])
        out += b
    return out


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


def screenshot(path, display='CGA-1V'):
    """PNG of a display, saved again with zlib (the emulator's PNG is not compressed)."""
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
