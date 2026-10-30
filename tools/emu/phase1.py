"""Phase 1 check: SAPITERM from the RAM disk, the status screen, the 60 Hz counters, keys, the return to CP/M.

Needs the emulator with MCP (tools/emu/sapiemu.cmd) and build.cmd done. Loads machines/sapi1v_term.sapi (with
--consul machines/sapi1v_term_consul.sapi) and so also the fresh build/ramdisk.bin. Prints the results and
saves build/phase1_cga.png. Exit code 1 when a check fails.
  python tools/emu/phase1.py [--consul]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import emu  # noqa: E402
from emu import mcp  # noqa: E402

failed = []


def check(ok, what):
    print(('ok    ' if ok else 'FAIL  ') + what)
    if not ok:
        failed.append(what)


def main():
    consul = '--consul' in sys.argv
    sym = emu.symbols()
    emu.use_machine('sapi1v_term_consul' if consul else 'sapi1v_term')
    emu.checkpoint()
    screen = emu.command('SAPITERM', wait='Ctrl+] = konec')
    check('SAPI-Term 0.1' in screen, 'status screen on the AND-1V')
    check('CGA-1V  ano' in screen, 'CGA-1V detected')
    check(('MPH-1V  neni' if consul else 'MPH-1V  ano') in screen, 'MPH-1V detection')
    check('DPI-1L  ano firmware 0.5' in screen, 'DPI-1L detected, firmware 0.5')

    def counts():
        b = emu.read(sym['vbi_count'], 4)
        return b[0] | b[1] << 8, b[2] | b[3] << 8

    v0, t0 = counts()
    mcp.call('run_for', ms=1000)
    v1, t1 = counts()
    print('      in 1 s: VBI %d, tick %d' % (v1 - v0, t1 - t0))
    check(59 <= v1 - v0 <= 61, 'VBI of the CGA-1V at 60 Hz')
    if not consul:
        check(59 <= t1 - t0 <= 61, 'tick of the MPH-1V at 60 Hz')

    mcp.call('type_text', text='a', run_ms=100)
    check('Posledni klavesa: 61 a' in mcp.call('screen_text'), 'key a = 61h')
    mcp.call('press_key', key='up', run_ms=100)
    up = 'C1' if consul else '05'
    check(('Posledni klavesa: ' + up) in mcp.call('screen_text'), 'arrow up = %sh' % up)
    mcp.call('pause')
    emu.screenshot(os.path.join(emu.REPO, 'build', 'phase1_cga.png'))
    print('      build/phase1_cga.png')

    mcp.call('type_text', text='\x1d', run_ms=1500)
    res = mcp.call('run_until', screen_text='A>', timeout_ms=5000)
    check(res.get('stopped') != 'timeout', 'Ctrl+] returns to CP/M')
    mcp.call('pause')
    screen = emu.command('DIR SAPITERM.COM')
    check('SAPITERM.COM' in screen, 'CP/M and the RAM disk work after the return')
    mcp.call('pause')
    if failed:
        sys.exit('%d check(s) failed' % len(failed))
    print('all checks passed')


if __name__ == '__main__':
    main()
