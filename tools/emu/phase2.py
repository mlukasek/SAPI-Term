"""Phase 2 check: the terminal screen on the CGA-1V and the AND-1V, the status on the other card, typing,
scrolling, swapping the cards, clearing, the return to CP/M.

Needs the emulator with MCP (tools/emu/sapiemu.cmd) and build.cmd done. Loads machines/sapi1v_term.sapi (with
--consul machines/sapi1v_term_consul.sapi: Consul 262.3 strict, no MPH-1V). Checks the shadow screen in the
memory (exact) and the text of the AND-1V; saves screenshots to build/preview/f2_*.png (not with --consul).
  python tools/emu/phase2.py [--consul]
"""
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import emu  # noqa: E402
from emu import mcp  # noqa: E402

failed = []
PREVIEW = os.path.join(emu.REPO, 'build', 'preview')


def check(ok, what):
    print(('ok    ' if ok else 'FAIL  ') + what)
    if not ok:
        failed.append(what)


class Shadow:
    def __init__(self, sym):
        self.sym = sym

    def row(self, r):
        """Text of screen row r from the shadow (CP437, KOI letters as '?')."""
        off = emu.read(self.sym['row_off'] + 2 * r, 2)
        off = off[0] | off[1] << 8
        chars = emu.read(self.sym['scr_chr'] + off, 80)
        ext = emu.read(self.sym['scr_ext'] + off, 80)
        return ''.join('?' if e & 1 else bytes([c]).decode('cp437') for c, e in zip(chars, ext))

    def raw(self, r):
        """Character codes of screen row r."""
        off = emu.read(self.sym['row_off'] + 2 * r, 2)
        return emu.read(self.sym['scr_chr'] + (off[0] | off[1] << 8), 80)

    def byte(self, name):
        return emu.read(self.sym[name], 1)[0]


def keys(text, ms=600):
    mcp.call('resume')
    mcp.call('type_text', text=text, run_ms=ms)
    mcp.call('pause')


def main():
    os.makedirs(PREVIEW, exist_ok=True)
    consul = '--consul' in sys.argv
    if consul:
        emu.screenshot = lambda *a, **k: None
    sh = Shadow(emu.symbols())
    emu.use_machine('sapi1v_term_consul' if consul else 'sapi1v_term')
    emu.checkpoint()
    mcp.call('resume')
    mcp.call('type_text', text='SAPITERM\r')
    res = mcp.call('run_until', screen_text='Ctrl+]  konec', timeout_ms=15000)
    check(res.get('stopped') != 'timeout', 'SAPITERM started, status on the AND-1V')
    mcp.call('run_for', ms=600)
    mcp.call('type_text', text='\r', run_ms=2500)   # the prompt for a BBS: empty Enter = the test screen
    mcp.call('pause')
    status = mcp.call('screen_text')
    check('Terminál na:  CGA-1V, 80x25 znaků' in status, 'status: terminal on the CGA-1V')
    check(('MPH-1V  není' if consul else 'MPH-1V  ano') in status, 'status: MPH-1V')
    check('- test v?stupu' in sh.row(0)[:30], 'shadow row 0: title (KOI letters)')
    check(sh.raw(2)[:35] == b'00 ' + bytes(range(32)), 'shadow row 2: CP437 table 00-1F')
    check(sh.byte('pal_dirty') == 0, 'palette written (no pairs waiting)')
    emu.screenshot(os.path.join(PREVIEW, 'f2_cga.png'), display='CGA-1V')
    emu.screenshot(os.path.join(PREVIEW, 'f2_and.png'), display='AND-1V')

    keys('Ahoj SAPI! ', 800)
    check(sh.row(19).startswith('Ahoj SAPI! '), 'typing on row 19')
    for i in range(7):
        keys('\rradek %d' % i)
    check(sh.row(0).startswith('00 '), 'scrolled by 2 rows (row 0 = the CP437 table)')
    check(sh.row(24).startswith('radek 6'), 'last row: radek 6')
    check((sh.byte('cur_row'), sh.byte('cur_col')) == (24, 7), 'cursor after radek 6')
    emu.screenshot(os.path.join(PREVIEW, 'f2_cga_typed.png'), display='CGA-1V')

    keys('\t', 3000)
    term = mcp.call('screen_text')
    check('radek 6' in term and 'radek 0' in term, 'Tab: terminal on the AND-1V keeps the rows up to the cursor')
    check(sh.byte('cur_row') == 19, 'cursor on the last row of 20')
    emu.screenshot(os.path.join(PREVIEW, 'f2_and_term.png'), display='AND-1V')
    emu.screenshot(os.path.join(PREVIEW, 'f2_cga_status.png'), display='CGA-1V')
    keys('ahoj z AND-1V', 1000)
    check('radek 6ahoj z AND-1V' in mcp.call('screen_text').replace('▒', ''), 'typing on the AND-1V')

    keys('\t', 4000)
    check('Terminál na:  CGA-1V' in mcp.call('screen_text'), 'Tab again: terminal back on the CGA-1V')
    check(sh.row(19).startswith('radek 6ahoj z AND-1V'), 'shadow kept while on the AND-1V')
    wav = os.path.join(PREVIEW, 'f2_bell.wav').replace('\\', '/')
    mcp.call('audio_record', start=True)
    keys('\x07', 400)
    bell = mcp.call('audio_record', file=wav)
    hz, ms = emu.tone(wav)
    what = 'peak %s, %.0f Hz, %.0f ms' % (bell.get('peak'), hz, ms)
    if consul:     # the buzzer of the keyboard: 2.4 kHz in SAPIemu, 4 ticks of the VBI
        check(bell.get('peak', 0) > 1000 and hz > 1500 and 40 < ms < 75,
              'Ctrl+G: no MPH-1V, the buzzer of the keyboard (%s)' % what)
    else:          # 880 Hz of the YM3812 (it fades after the key off), no buzzer in it
        check(bell.get('peak', 0) > 1000 and 840 < hz < 920 and ms < 200,
              'Ctrl+G: the bell, a tone on the MPH-1V (%s)' % what)
    keys('\x0c', 1500)
    check(all(sh.row(r).strip() == '' for r in (0, 12, 24)), 'Ctrl+L clears the screen')
    keys('\x14', 2000)
    check('- test v?stupu' in sh.row(0)[:30], 'Ctrl+T draws the test screen again')

    check('Ctrl+]  zpět na výběr BBS' in mcp.call('screen_text'), 'status: Ctrl+] back to the BBS')
    keys('\x1d', 2500)
    check(sh.row(18).startswith('BBS:'), 'Ctrl+] in the test screen: back at the prompt for a BBS')
    check('Ctrl+]  konec' in mcp.call('screen_text'), 'status at the prompt: Ctrl+] ends')
    keys('\x1d', 1500)
    res = mcp.call('run_until', screen_text='A>', timeout_ms=5000)
    check(res.get('stopped') != 'timeout', 'Ctrl+] at the prompt returns to CP/M')
    mcp.call('pause')
    check('SAPITERM.COM' in emu.command('DIR SAPITERM.COM'), 'CP/M and the RAM disk work after the return')
    mcp.call('pause')
    if failed:
        sys.exit('%d check(s) failed' % len(failed))
    print('all checks passed')


if __name__ == '__main__':
    main()
