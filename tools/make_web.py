#!/usr/bin/env python3
"""Generate index.html (browser patcher) and DoDonPachi SaiDaiOuJou Platinum Label.mra
from sdoj_patch_data.py. Needs your original ddpsdoj.zip and your Xbox 360 GOD zip
only to compute the CRCs (no ROM or game data is written anywhere).

Usage: python3 tools/make_web.py path/to/ddpsdoj.zip path/to/GOD.zip path/to/dfkbl.zip [build-number]
The build number defaults to the one in tools/BUILD.
PATCHED_CRC = patch code only (checked first), FINAL_CRC = with the health bar graphics.
"""
import base64, json, os, re, subprocess, sys, zipfile, zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
from sdoj_patch_data import CHANGES  # noqa: E402
import sdoj_patch  # noqa: E402
from sdoj_god import build_bar_gfx, BAR_GFX_OFFSET  # noqa: E402
from sdoj_dfk import build_dfk_gfx, read_dfk_files, DFK_GFX_OFFSET, read_dfk_sound, build_dfk_sound  # noqa: E402

ORIG_CRC = 0xE2A4411C


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    u4 = zipfile.ZipFile(sys.argv[1]).read('u4')
    if zlib.crc32(u4) & 0xFFFFFFFF != ORIG_CRC:
        sys.exit('not the original ddpsdoj u4')
    patched = sdoj_patch.patch_u4(u4)
    pcrc = zlib.crc32(patched) & 0xFFFFFFFF
    gfx = build_bar_gfx(sys.argv[2])
    be = sdoj_patch.swap16(patched)
    be[BAR_GFX_OFFSET:BAR_GFX_OFFSET + len(gfx)] = gfx
    dg = build_dfk_gfx(read_dfk_files([sys.argv[3]]))
    be[DFK_GFX_OFFSET:DFK_GFX_OFFSET + len(dg)] = dg
    fcrc = zlib.crc32(bytes(sdoj_patch.swap16(be))) & 0xFFFFFFFF
    zs = zipfile.ZipFile(sys.argv[1])
    s23, s24 = build_dfk_sound(zs.read('u23'), zs.read('u24'), read_dfk_sound(sys.argv[3]))
    scrc = (zlib.crc32(s23) & 0xFFFFFFFF, zlib.crc32(s24) & 0xFFFFFFFF)
    # build number: argument, else tools/BUILD (raised by one for each new build), else git commit count
    build_file = os.path.join(ROOT, 'tools', 'BUILD')
    if len(sys.argv) > 4:
        build = sys.argv[4]
    elif os.path.exists(build_file):
        build = open(build_file).read().strip()
    else:
        build = subprocess.check_output(['git', '-C', ROOT, 'rev-list', '--count', 'HEAD']).decode().strip()

    # file-coordinate (word-swapped) patches: same offsets, byte pairs swapped
    patch = []
    for off, data in CHANGES:
        assert off % 2 == 0 and len(data) % 2 == 0
        sw = bytearray(data)
        sw[0::2], sw[1::2] = data[1::2], data[0::2]
        patch.append([off, base64.b64encode(bytes(sw)).decode()])
    test = bytearray(u4)
    for off, b64 in patch:
        d = base64.b64decode(b64)
        test[off:off + len(d)] = d
    assert bytes(test) == patched, 'web patch table does not reproduce the Python patcher'

    mra_path = os.path.join(ROOT, 'mister', 'DoDonPachi SaiDaiOuJou Platinum Label.mra')
    mra = open(mra_path, encoding='utf-8-sig').read()
    mra = re.sub(r'(<part name="plat_u4" crc=")[0-9a-fA-F]{8}', lambda m: m.group(1) + '%08x' % fcrc, mra)
    for nm, c in (('plat_u23', scrc[0]), ('plat_u24', scrc[1])):   # dfkbl's switch sound in the sound ROMs
        mra = re.sub(r'(<part name="%s" crc=")[0-9a-fA-F]{8}' % nm, lambda m, c=c: m.group(1) + '%08x' % c, mra)
    mra = re.sub(r'(\(\d{4}/\d{2}/\d{2} B)\d+\)', lambda m: m.group(1) + build + ')', mra)  # build number in the title
    open(mra_path, 'w').write(mra)

    # update the published page in place (no separate template)
    ip = os.path.join(ROOT, 'index.html')
    html = open(ip).read()
    def sub(pat, rep, h):
        h2, n = re.subn(pat, rep, h, count=1, flags=re.S)
        if n != 1:
            sys.exit('index.html: pattern not found: ' + pat)
        return h2
    html = sub(r'const ORIG_CRC = 0x[0-9a-f]+, PATCHED_CRC = 0x[0-9a-f]+, FINAL_CRC = 0x[0-9a-f]+',
               'const ORIG_CRC = 0x%08x, PATCHED_CRC = 0x%08x, FINAL_CRC = 0x%08x' % (ORIG_CRC, pcrc, fcrc), html)
    html = sub(r'const PATCH = \[.*?\];\n', lambda m: 'const PATCH = ' + json.dumps(patch) + ';\n', html)
    html = sub(r'const MRA = ".*?";\n', lambda m: 'const MRA = ' + json.dumps(mra) + ';\n', html)
    html = sub(r'<td class="mono" id="expcrc">[0-9a-f]{8}</td>', '<td class="mono" id="expcrc">%08x</td>' % fcrc, html)
    html = sub(r'const SND_CRC = \[0x[0-9a-f]+, 0x[0-9a-f]+\]', 'const SND_CRC = [0x%08x, 0x%08x]' % scrc, html)
    html = re.sub(r'build \d+', 'build ' + build, html)
    open(os.path.join(ROOT, 'index.html'), 'w').write(html)

    p = os.path.join(ROOT, 'sdoj_patch.py')
    s = open(p).read()
    s = re.sub(r'PATCHED_CRC = 0x[0-9A-Fa-f]{8}', 'PATCHED_CRC = 0x%08X' % pcrc, s)
    s = re.sub(r'FINAL_CRC = 0x[0-9A-Fa-f]{8}', 'FINAL_CRC = 0x%08X' % fcrc, s)
    open(p, 'w').write(s)
    rp = os.path.join(ROOT, 'README.md')
    rd = open(rp).read()
    rd = re.sub(r'(the patched program ROM \(CRC `)[0-9a-f]{8}', lambda m: m.group(1) + '%08x' % fcrc, rd)
    open(rp, 'w').write(rd)
    print('patched u4 CRC %08x (with health bars %08x), build %s -> index.html, DoDonPachi SaiDaiOuJou Platinum Label.mra'
          % (pcrc, fcrc, build))


if __name__ == '__main__':
    main()
