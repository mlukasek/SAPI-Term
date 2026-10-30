"""A small local telnet BBS for testing SAPI-Term (standard library only).

Listens on 127.0.0.1 (one client at a time), negotiates like a usual BBS (DO TTYPE, DO NAWS, WILL ECHO,
WILL SGA, then TTYPE SEND), and offers pages. Everything the client sends is logged to a JSON file after every
event, for tools/emu/phase4.py:
  ttype, naws (every size received), client_will / client_do / client_wont / client_dont, keys (data bytes in
  hex), cpr (the answer to ESC [ 6 n), da (to ESC [ c), sent (pages), menu (times the menu was sent), closed.
Keys of the menu:
  1 ANSITEST, 2 SUNSET (with ESC [ ? 33 h for iCE), 3 MENU, 4 SCROLL: the test files of tools/mkart.py
  E echo (everything typed comes back, ! ends it), C position report test, D device attributes test,
  M the menu again, Q goodbye and close, X close at once;
  text in a character set (CHARSET_TEXT, the screen cleared first): U UTF-8 (with more Unicode), L Latin-2,
  W CP1250, P CP852, K Kamenicky, O KOI-8cs2.
  python tools/testbbs.py [--port 6023] [--log build/testbbs.json]
"""
import argparse
import json
import os
import socket
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IAC, DONT, DO, WONT, WILL, SB, SE = 255, 254, 253, 252, 251, 250, 240
BINARY, ECHO, SGA, TTYPE, NAWS = 0, 1, 3, 24, 31
PAGES = {'1': ('ANSITEST', False), '2': ('SUNSET', True), '3': ('MENU', False), '4': ('SCROLL', False)}
CHARSET_PAGES = {'U': 'UTF-8', 'L': 'LATIN2', 'W': 'CP1250', 'P': 'CP852', 'K': 'KAMENICKY', 'O': 'KOI8'}
CHARSET_TEXT = ['Příliš žluťoučký kůň úpěl ďábelské ódy.', 'PŘÍLIŠ ŽLUŤOUČKÝ KŮŇ ÚPĚL ĎÁBELSKÉ ÓDY.',
                'Ľudovít Štúr: ä ô ĺ ŕ Ĺ Ŕ Ä Ô']
UTF8_MORE = ['┌─┬─┐ ┏━┓ ╭─╮ ╔═╗ ░▒▓█ ▀▄▌▐ ▁▃▅▇ ■▲►▼◄', '“uvozovky” ‘a’ – — … € ½ ° ± µ ß ł',
             'emoji 🙂 zero​width é Ω α π Σ √ ∞ ≤ ≥']
KAMENICKY = 'ČüéďäĎŤčěĚĹÍľĺÄÁÉžŽôöÓůÚýÖÜŠĽÝŘťáíóúňŇŮÔšřŕŔ¼§«»'
KOI = {'á': 0xC1, 'č': 0xC3, 'ď': 0xC4, 'ě': 0xC5, 'ŕ': 0xC6, 'ü': 0xC8, 'í': 0xC9, 'ů': 0xCA, 'ĺ': 0xCB,
       'ľ': 0xCC, 'ö': 0xCD, 'ň': 0xCE, 'ó': 0xCF, 'ô': 0xD0, 'ä': 0xD1, 'ř': 0xD2, 'š': 0xD3, 'ť': 0xD4,
       'ú': 0xD5, 'é': 0xD7, 'à': 0xD8, 'ý': 0xD9, 'ž': 0xDA, 'Á': 0xE1, 'Č': 0xE3, 'Ď': 0xE4, 'Ě': 0xE5,
       'Ŕ': 0xE6, 'Ü': 0xE8, 'Í': 0xE9, 'Ů': 0xEA, 'Ĺ': 0xEB, 'Ľ': 0xEC, 'Ö': 0xED, 'Ň': 0xEE, 'Ó': 0xEF,
       'Ô': 0xF0, 'Ä': 0xF1, 'Ř': 0xF2, 'Š': 0xF3, 'Ť': 0xF4, 'Ú': 0xF5, 'É': 0xF7, 'À': 0xF8, 'Ý': 0xF9,
       'Ž': 0xFA}


def charset_lines(key):
    """The lines of the text page of a character set (Unicode)."""
    return CHARSET_TEXT + (UTF8_MORE if key == 'U' else [])


def encode(text, name):
    """text in the character set name (as SAPI-Term calls them)."""
    if name == 'UTF-8':
        return text.encode('utf-8')
    if name == 'KAMENICKY':
        return bytes(0x80 + KAMENICKY.index(c) if c in KAMENICKY else ord(c) for c in text)
    if name == 'KOI8':
        return bytes(KOI.get(c, ord(c)) for c in text)
    return text.encode({'LATIN2': 'iso8859_2', 'CP1250': 'cp1250', 'CP852': 'cp852'}[name])


def charset_bytes(key):
    """The bytes the server sends for the text page of a character set."""
    lines = [encode(t, CHARSET_PAGES[key]) for t in charset_lines(key)]
    return b'\x1b[0m\x1b[2J' + b'\r\n'.join(lines) + b'\r\n'


def page_bytes(key):
    """The bytes the server sends for a page (the art up to 1Ah, iCE switched as the page needs)."""
    name, ice = PAGES[key]
    data = open(os.path.join(ROOT, 'build', 'art', name + '.ANS'), 'rb').read()
    end = data.find(b'\x1a')
    if end >= 0:
        data = data[:end]
    return (b'\x1b[?33h' if ice else b'\x1b[?33l') + data


MENU = (b'\x1b[0m\x1b[2J\x1b[1;37;44m SAPI-Term test BBS \x1b[0m\r\n\r\n'
        b'  \x1b[1;33m1\x1b[0m ANSITEST   \x1b[1;33m2\x1b[0m SUNSET (iCE)   \x1b[1;33m3\x1b[0m MENU   '
        b'\x1b[1;33m4\x1b[0m SCROLL\r\n'
        b'  \x1b[1;33mE\x1b[0m echo   \x1b[1;33mC\x1b[0m position report   \x1b[1;33mD\x1b[0m attributes   '
        b'\x1b[1;33mQ\x1b[0m goodbye   \x1b[1;33mX\x1b[0m close\r\n\r\n  Choice: ')


class Session:
    def __init__(self, conn, log):
        self.conn = conn
        self.logpath = log
        self.log = log_data = {}
        if os.path.exists(log):
            with open(log) as f:
                log_data.update(json.load(f))
        log_data.setdefault('connects', 0)
        log_data['connects'] += 1
        for k in ('client_will', 'client_do', 'client_wont', 'client_dont', 'naws', 'sent'):
            log_data[k] = []
        log_data.update(ttype=None, keys='', cpr=None, da=None, menu=0, closed=False)
        self.state = 0
        self.verb = 0
        self.sb = bytearray()
        self.echo = False
        self.wait_reply = None
        self.reply = bytearray()
        self.save()

    def save(self):
        """The log through a temporary file; on Windows the reader may hold the file a moment: try again."""
        tmp = self.logpath + '.tmp'
        with open(tmp, 'w') as f:
            json.dump(self.log, f, indent=1)
        for _ in range(100):
            try:
                os.replace(tmp, self.logpath)
                return
            except PermissionError:
                time.sleep(0.01)

    def send(self, data):
        self.conn.sendall(data.replace(b'\xff', b'\xff\xff'))

    def cmd(self, *b):
        self.conn.sendall(bytes(b))

    def run(self):
        self.cmd(IAC, DO, TTYPE, IAC, DO, NAWS, IAC, WILL, ECHO, IAC, WILL, SGA)
        t0 = time.time()
        self.conn.settimeout(0.1)
        menu_sent = False
        while True:
            try:
                data = self.conn.recv(4096)
                if not data:
                    break
                for b in data:
                    if self.byte(b) == 'close':
                        return
            except socket.timeout:
                pass
            if not menu_sent and (self.log['ttype'] and self.log['naws'] or time.time() - t0 > 3):
                self.menu()
                menu_sent = True

    def menu(self):
        self.send(MENU)
        self.log['menu'] += 1
        self.save()

    def byte(self, b):
        if self.state == 0:
            if b == IAC:
                self.state = 1
            else:
                return self.data(b)
        elif self.state == 1:
            if b == IAC:
                self.state = 0
                return self.data(b)
            if b == SB:
                self.state = 3
                self.sb = bytearray()
            elif b in (WILL, WONT, DO, DONT):
                self.verb = b
                self.state = 2
            else:
                self.state = 0
        elif self.state == 2:
            self.state = 0
            self.option(self.verb, b)
        elif self.state == 3:
            if b == IAC:
                self.state = 4
            else:
                self.sb.append(b)
        elif self.state == 4:
            if b == SE:
                self.state = 0
                self.subneg(bytes(self.sb))
            else:
                self.sb.append(b)
                self.state = 3
        return None

    def option(self, verb, opt):
        name = {WILL: 'client_will', WONT: 'client_wont', DO: 'client_do', DONT: 'client_dont'}[verb]
        self.log[name].append(opt)
        if verb == WILL and opt == TTYPE:
            self.cmd(IAC, SB, TTYPE, 1, IAC, SE)
        self.save()

    def subneg(self, sb):
        if sb[:2] == bytes([TTYPE, 0]):
            self.log['ttype'] = sb[2:].decode('ascii', 'replace')
        elif sb[:1] == bytes([NAWS]) and len(sb) >= 5:
            self.log['naws'].append([sb[1] << 8 | sb[2], sb[3] << 8 | sb[4]])
        self.save()

    def data(self, b):
        self.log['keys'] += '%02X' % b
        self.save()
        if self.wait_reply:
            self.reply.append(b)
            if 0x40 <= b <= 0x7E and len(self.reply) > 2:
                self.log[self.wait_reply] = self.reply.decode('ascii', 'replace')
                self.wait_reply = None
                self.save()
            return None
        if self.echo:
            if b == ord('!'):
                self.echo = False
                self.menu()
            elif b == 0x0D:
                self.send(b'\r\n')
            elif b != 0:
                self.send(bytes([b]))
            return None
        c = chr(b).upper()
        if c in CHARSET_PAGES:
            data = charset_bytes(c)
            self.send(data)
            self.log['sent'].append({'page': CHARSET_PAGES[c], 'bytes': len(data)})
            self.save()
        elif c in PAGES:
            data = page_bytes(c)
            self.send(data)
            self.log['sent'].append({'page': PAGES[c][0], 'bytes': len(data)})
            self.save()
        elif c == 'E':
            self.echo = True
            self.send(b'\x1b[0m\x1b[2JEcho, ! = back\r\n')
        elif c == 'C':
            self.reply = bytearray()
            self.wait_reply = 'cpr'
            self.send(b'\x1b[10;20H\x1b[6n')
        elif c == 'D':
            self.reply = bytearray()
            self.wait_reply = 'da'
            self.send(b'\x1b[c')
        elif c == 'M':
            self.menu()
        elif c == 'Q':
            self.send(b'\r\n\r\nGoodbye.\r\n')
            return 'close'
        elif c == 'X':
            return 'close'
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, default=6023)
    ap.add_argument('--log', default=os.path.join(ROOT, 'build', 'testbbs.json'))
    ap.add_argument('--once', action='store_true', help='end after the first client')
    a = ap.parse_args()
    if os.path.exists(a.log):
        os.remove(a.log)
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(('127.0.0.1', a.port))
    srv.listen(1)
    print('test BBS on 127.0.0.1:%d, log %s' % (a.port, a.log), flush=True)
    while True:
        conn, addr = srv.accept()
        s = Session(conn, a.log)
        try:
            s.run()
        except OSError:
            pass
        s.log['closed'] = True
        s.save()
        try:
            conn.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        conn.close()
        if a.once:
            break


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
