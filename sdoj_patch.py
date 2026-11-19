#!/usr/bin/env python3
"""SaiDaiOuJou 2.0 patcher (Python 3, standard library only).

Usage:
    python3 sdoj_patch.py ddpsdoj.zip --god GOD.zip [--zip] [--mra] [-o FILE]

Reads your own ddpsdoj (DoDonPachi SaiDaiOuJou) ROM set (or a loose u4 file) and
writes the patched program ROM plat_u4 (or -o FILE).
  --god   required: your Xbox 360 DoDonPachi SaiDaiOuJou Games-on-Demand package as a zip
          (containing B699E3A8BDFD9BB5BE92 and B699E3A8BDFD9BB5BE92.data/, any folder).
          The stage 1 boss pod health bars are cut from it (needs sdoj_god.py next to this script).
  --zip   also write ddpsdojplat.zip: your set with u4 replaced by plat_u4, u23 / u24 by plat_u23 / plat_u24
          (with dfkbl's NORMAL / BOOST switch sound)
  --mra   also write "DoDonPachi SaiDaiOuJou Platinum Label.mra" (MiSTer), with the patched CRC
The original files are not modified.
"""
import os, re, sys, zipfile, zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdoj_patch_data import CHANGES, ORIG_BOOT_LITERAL

U4_SIZE = 4194560
U4_CRC = 0xE2A4411C  # original ddpsdoj u4
OUT_U4 = 'plat_u4'
PATCHED_CRC = 0x545A55D7  # patch code only; set by tools/make_web.py
FINAL_CRC = 0x0E8599A9    # with the health bar graphics; set by tools/make_web.py


def swap16(b):
    b = bytearray(b)
    b[0::2], b[1::2] = b[1::2], b[0::2]
    return b


def patch_u4(u4):
    if len(u4) != U4_SIZE:
        sys.exit('u4 has the wrong size (%d), expected %d' % (len(u4), U4_SIZE))
    be = swap16(u4)
    lit = int.from_bytes(be[0x1D8:0x1DC], 'big')
    if lit != ORIG_BOOT_LITERAL:
        sys.exit('u4 is not an unpatched ddpsdoj program ROM (boot literal %08X)' % lit)
    for off, data in CHANGES:
        if off != 0x1D8 and any(x != 0xFF for x in be[off:off + len(data)]):
            sys.exit('u4 free space at %06X is not empty - unexpected dump' % off)
        be[off:off + len(data)] = data
    return bytes(swap16(be))


def main():
    args = sys.argv[1:]
    if not args or args[0] in ('-h', '--help'):
        sys.exit(__doc__)
    want_zip = '--zip' in args
    want_mra = '--mra' in args
    out = None
    god = None
    if '--god' in args:
        i = args.index('--god')
        if i + 1 >= len(args):
            sys.exit('--god needs the GOD zip file')
        god = args[i + 1]
        del args[i:i + 2]
    else:
        sys.exit('--god GOD.zip is required: your Xbox 360 DoDonPachi SaiDaiOuJou Games-on-Demand zip\n'
                 '(the boss pod health bars are taken from it).\n\n' + __doc__)
    if '--dfk' in args:
        i = args.index('--dfk')
        if i + 1 >= len(args):
            sys.exit('--dfk needs your MAME dfkbl.zip (DoDonPachi DaiFukkatsu Black Label)')
        dfk = args[i + 1]
        del args[i:i + 2]
    else:
        sys.exit('--dfk dfkbl.zip is required: your MAME DoDonPachi DaiFukkatsu Black Label set\n'
                 '(the Power Mode bottom bar is taken from it).\n\n' + __doc__)
    if '-o' in args:
        i = args.index('-o')
        if i + 1 >= len(args):
            sys.exit('-o needs a file name')
        out = args[i + 1]
        del args[i:i + 2]
    src = next((a for a in args if not a.startswith('-')), None)
    if not src:
        sys.exit(__doc__)
    names = None
    zin = None
    if zipfile.is_zipfile(src):
        zin = zipfile.ZipFile(src)
        names = zin.namelist()
        u4name = next((n for n in names if os.path.basename(n).lower() == 'u4'), None)
        if not u4name:
            sys.exit('no u4 in %s' % src)
        u4 = zin.read(u4name)
    else:
        u4 = open(src, 'rb').read()
    crc = zlib.crc32(u4) & 0xFFFFFFFF
    if crc != U4_CRC:
        print('warning: u4 CRC %08X differs from the known dump %08X' % (crc, U4_CRC))
    new = patch_u4(u4)
    nc = zlib.crc32(new) & 0xFFFFFFFF
    if nc != PATCHED_CRC:
        print('warning: patch code CRC %08X does not match the release %08X' % (nc, PATCHED_CRC))
    if god:
        from sdoj_god import build_bar_gfx, BAR_GFX_OFFSET
        gfx = build_bar_gfx(god)
        be = swap16(new)
        if any(x != 0xFF for x in be[BAR_GFX_OFFSET:BAR_GFX_OFFSET + len(gfx)]):
            sys.exit('u4 free space at %06X is not empty - unexpected dump' % BAR_GFX_OFFSET)
        be[BAR_GFX_OFFSET:BAR_GFX_OFFSET + len(gfx)] = gfx
        new = bytes(swap16(be))
        nc = zlib.crc32(new) & 0xFFFFFFFF
        print('added pod health bars from %s' % god)
    from sdoj_dfk import build_dfk_gfx, read_dfk_files, DFK_GFX_OFFSET
    dg = build_dfk_gfx(read_dfk_files([dfk]))
    be = swap16(new)
    if any(x != 0xFF for x in be[DFK_GFX_OFFSET:DFK_GFX_OFFSET + len(dg)]):
        sys.exit('u4 free space at %06X is not empty - unexpected dump' % DFK_GFX_OFFSET)
    be[DFK_GFX_OFFSET:DFK_GFX_OFFSET + len(dg)] = dg
    new = bytes(swap16(be))
    nc = zlib.crc32(new) & 0xFFFFFFFF
    print('added the Power Mode bar from %s' % dfk)
    print('patched u4 CRC %08X%s' % (nc, '' if nc == FINAL_CRC else ' (does not match release %08X!)' % FINAL_CRC))
    out = out or OUT_U4
    open(out, 'wb').write(new)
    print('wrote', out)
    if want_zip:
        if zin is None:
            sys.exit('--zip needs the ddpsdoj.zip set as input, not a loose u4')
        from sdoj_dfk import read_dfk_sound, build_dfk_sound
        base = {n.split('/')[-1].lower(): n for n in names}
        s23, s24 = build_dfk_sound(zin.read(base['u23']), zin.read(base['u24']), read_dfk_sound(dfk))
        snd_crc = (zlib.crc32(s23) & 0xFFFFFFFF, zlib.crc32(s24) & 0xFFFFFFFF)
        with zipfile.ZipFile('ddpsdojplat.zip', 'w', zipfile.ZIP_DEFLATED) as zout:
            for n in names:
                b = n.split('/')[-1].lower()
                if n == u4name:
                    zout.writestr(os.path.join(os.path.dirname(n), OUT_U4), new)
                elif b in ('u23', 'u24'):   # with dfkbl's NORMAL / BOOST switch sound
                    zout.writestr(os.path.join(os.path.dirname(n), 'plat_' + b), s23 if b == 'u23' else s24)
                else:
                    zout.writestr(n, zin.read(n))
        print('wrote ddpsdojplat.zip')
    if want_mra:
        here = os.path.dirname(os.path.abspath(__file__))
        src = os.path.join(here, 'mister', 'DoDonPachi SaiDaiOuJou Platinum Label.mra')
        if not os.path.exists(src):
            src = os.path.join(here, 'DoDonPachi SaiDaiOuJou Platinum Label.mra')
        mra = open(src, encoding='utf-8-sig').read()
        mra = re.sub(r'(<part name="plat_u4" crc=")[0-9a-fA-F]{8}', lambda m: m.group(1) + '%08x' % nc, mra)
        if want_zip:
            for nm, c in (('plat_u23', snd_crc[0]), ('plat_u24', snd_crc[1])):
                mra = re.sub(r'(<part name="%s" crc=")[0-9a-fA-F]{8}' % nm, lambda m: m.group(1) + '%08x' % c, mra)
        open('DoDonPachi SaiDaiOuJou Platinum Label.mra', 'w').write(mra)
        print('wrote DoDonPachi SaiDaiOuJou Platinum Label.mra')


if __name__ == '__main__':
    main()
