"""The zip of a release (docs/vyvoj.md, "Vydani"): build/release/SAPI-Term-VERSION.zip with SAPITERM.COM, the
Intel HEX, the default SAPITERM.CFG, the test files *.ANS (not AQUA.ANS: not ours), README, CHANGELOG and LICENSE.
Checks that the program built (build.cmd) has the version in its header and that CHANGELOG has it.
  python tools/release.py VERSION
"""
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = [('build/sapiterm.com', 'SAPITERM.COM'), ('build/sapiterm.hex', 'sapiterm.hex'),
         ('src/sapiterm.cfg', 'SAPITERM.CFG'), ('build/art/ANSITEST.ANS', 'ANSITEST.ANS'),
         ('build/art/SUNSET.ANS', 'SUNSET.ANS'), ('build/art/MENU.ANS', 'MENU.ANS'),
         ('build/art/SCROLL.ANS', 'SCROLL.ANS'), ('README.md', 'README.md'), ('CHANGELOG.md', 'CHANGELOG.md'),
         ('LICENSE', 'LICENSE')]


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    version = sys.argv[1]
    com = open(os.path.join(ROOT, 'build', 'sapiterm.com'), 'rb').read()
    if ('SAPI-Term %s\r\n' % version).encode() not in com[:64]:
        sys.exit('build/sapiterm.com is not %s: %r' % (version, com[3:24]))
    if '## %s ' % version not in open(os.path.join(ROOT, 'CHANGELOG.md'), encoding='utf-8').read():
        sys.exit('CHANGELOG.md has no "## %s"' % version)
    out = os.path.join(ROOT, 'build', 'release', 'SAPI-Term-%s.zip' % version)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for src, name in FILES:
            z.write(os.path.join(ROOT, src), name)
    print('%s: %d files, %d bytes' % (out, len(FILES), os.path.getsize(out)))


if __name__ == '__main__':
    main()
