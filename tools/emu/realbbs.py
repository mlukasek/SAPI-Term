"""Real BBS from the address book: for each entry "SAPITERM n" in CP/M (or "SAPITERM host:port" for an address),
the first screen of the BBS for a while (no login, no keys), a screenshot of the CGA-1V (build/preview/bbs_NN.png
or bbs_HOST.png), the menu disconnects. Prints how the connection went, the telnet options agreed and the text
rows of the screen. Needs the emulator with MCP (tools/emu/sapiemu.cmd), build.cmd and the internet.
  python tools/emu/realbbs.py [NUMBER | HOST[:PORT] ...] [--secs N] [--set SET] [--keys TEXT] [--shot NAME]
--set: menu Z to the set SET (CP437 ... VIEWDATA) right after the connection; --keys: then these keys (\r for
Enter); --shot: the screenshot build/preview/NAME.png (for one BBS).
"""
import os
import sys
import time

sys.stdout.reconfigure(encoding='utf-8')
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..'))
import emu  # noqa: E402
from emu import mcp  # noqa: E402
from phase4 import row_koi  # noqa: E402

PREVIEW = os.path.join(emu.REPO, 'build', 'preview')
MODE_ONLINE = 2
OPTS = {0: 'BINARY', 1: 'ECHO', 3: 'SGA', 24: 'TTYPE', 31: 'NAWS'}
SETS = ['CP437', 'UTF-8', 'LATIN2', 'CP1250', 'CP852', 'KAMENICKY', 'KOI8', 'PETSCII', 'ATASCII', 'VIEWDATA']


def run_wall(secs, cond=None):
    """Run the emulator for secs of real time (the network is real), or until cond() is true."""
    mcp.call('resume')
    end = time.time() + secs
    while time.time() < end:
        mcp.call('run_for', ms=250)
        if cond and cond():
            break
    mcp.call('pause')


def one(sym, n, secs, cs=None, keys='', shot=None):
    emu.checkpoint()
    mcp.call('resume')
    mcp.call('type_text', text='SAPITERM %s\r' % n)
    run_wall(25, lambda: emu.read(sym['mode'], 1)[0] == MODE_ONLINE)
    host = emu.read(sym['ui_line'], 64).split(b'\0')[0].decode('ascii', 'replace')
    if emu.read(sym['mode'], 1)[0] != MODE_ONLINE:
        run_wall(1)
        print('%2s %-36s FAIL: %s' % (n, host, row_koi(sym, 6).strip()))
        return False
    if cs is not None:
        mcp.call('resume')
        mcp.call('type_text', text='\x1d', run_ms=300)
        for _ in range(len(SETS)):
            if emu.read(sym['cs_type'], 1)[0] == cs:
                break
            mcp.call('type_text', text='z', run_ms=600)
        mcp.call('type_text', text='\x1b', run_ms=500)
        run_wall(4)
    if keys:
        mcp.call('resume')
        mcp.call('type_text', text=keys, run_ms=300)
    run_wall(secs)
    us = emu.read(sym['tn_us'], 32)
    them = emu.read(sym['tn_them'], 32)
    agreed = ['%s%s' % ('us ' if us[o] else 'them ', name) for o, name in OPTS.items() if us[o] or them[o]]
    print('%2s %-36s on line, telnet: %s' % (n, host, ', '.join(agreed) or '-'))
    name = '%02d' % n if isinstance(n, int) else n.split(':')[0].replace('.', '_')
    emu.screenshot(os.path.join(PREVIEW, '%s.png' % (shot or 'bbs_' + name)), display='CGA-1V')
    for r in range(25):
        t = row_koi(sym, r).rstrip()
        if t.strip():
            print('     |%s' % t)
    mcp.call('resume')
    mcp.call('type_text', text='\x1d', run_ms=500)
    mcp.call('type_text', text='o', run_ms=500)
    run_wall(10, lambda: row_koi(sym, 18).startswith('BBS:'))
    return True


def main():
    os.makedirs(PREVIEW, exist_ok=True)
    args = sys.argv[1:]
    secs = 15
    if '--secs' in args:
        i = args.index('--secs')
        secs = int(args[i + 1])
        del args[i:i + 2]
    opt = {}
    for name in ('--set', '--keys', '--shot'):
        if name in args:
            i = args.index(name)
            opt[name] = args[i + 1]
            del args[i:i + 2]
    cs = SETS.index(opt['--set'].upper()) if '--set' in opt else None
    keys = opt.get('--keys', '').replace('\\r', '\r')
    sym = emu.symbols()
    emu.use_machine('sapi1v_term')
    nums = [int(a) if a.isdigit() else a for a in args] or range(1, 17)
    ok = [n for n in nums if one(sym, n, secs, cs, keys, opt.get('--shot'))]
    print('on line: %d of %d' % (len(ok), len(nums)))


if __name__ == '__main__':
    main()
