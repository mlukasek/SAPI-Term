"""Statistical profile of SAPI-Term in the emulator: the PC is read every emulated millisecond while a command
runs, each sample counts for the routine (the nearest label below the PC in build/sapiterm.sym, labels with a
digit or local names folded into the routine above them is not done: every label counts). Prints the labels
with most samples. Needs the emulator with MCP (tools/emu/sapiemu.cmd) and build.cmd.
  python tools/emu/profile.py "SAPITERM SUNSET.ANS" [--until view_state] [--ms 1] [--top 40]
"""
import bisect
import collections
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import emu  # noqa: E402
from emu import mcp  # noqa: E402


def main():
    args = sys.argv[1:]
    opt = {'--until': 'view_state', '--ms': '1', '--top': '40'}
    for k in list(opt):
        if k in args:
            i = args.index(k)
            opt[k] = args[i + 1]
            del args[i:i + 2]
    command = args[0] if args else 'SAPITERM SUNSET.ANS'
    sym = emu.symbols()
    labels = sorted((v, k) for k, v in sym.items() if 0x100 <= v < 0x6000 and not k.isupper())
    addrs = [a for a, _ in labels]
    emu.use_machine('sapi1v_term')
    emu.checkpoint()
    mcp.call('resume')
    mcp.call('type_text', text=command + '\r')
    mcp.call('run_for', ms=600)
    mcp.call('pause')
    hits = collections.Counter()
    n = 0
    while emu.read(sym[opt['--until']], 1)[0] == 0 and n < 20000:
        mcp.call('run_for', ms=float(opt['--ms']))
        pc = int(mcp.call('get_registers')['pc'], 16)
        i = bisect.bisect_right(addrs, pc) - 1
        hits[labels[i][1] if pc < 0x6000 and i >= 0 else 'outside %04X' % (pc & 0xF000)] += 1
        n += 1
    print('%d samples (%s ms each)' % (n, opt['--ms']))
    for name, c in hits.most_common(int(opt['--top'])):
        print('%6.1f %%  %5d  %s' % (100.0 * c / n, c, name))


if __name__ == '__main__':
    main()
