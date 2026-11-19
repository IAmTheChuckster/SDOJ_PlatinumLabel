#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DFK Black Label bottom bar for Power Mode (NORMAL / BOOST, MAXIMUM scroll), taken from your own dfkbl.zip.

Nothing from DFK is stored in this repository. The graphics are read from u2 (the NAND) inside your MAME
dfkbl.zip: two of DFK's LZ-compressed 256 x 256 textures, decompressed the same way the game does it:
  u2 0x4D678F  HUD sheet: bar background (x 0-15), bar frame (x 16-31), the NORMAL / BOOST words
               (dimmed when not selected); black outlines made transparent
  u2 0x4C22F4  MAXIMUM strips (x 16-31)

build_dfk_gfx() returns the bytes sdoj_patch.py writes to u4 at DFK_GFX_OFFSET: 'DFKB', w 48, h 240, 8 spare,
then 48 x 240 ARGB1555 pixels in the game's native orientation:
  columns  0-15 rows   0-239  the bar (background darkened + frame)
  columns 16-31 rows 0 / 39 NORMAL glowing / dimmed, 74 / 108 BOOST glowing / dimmed,
                rows 138 / 186 the box around a word, not selected / selected
  columns 32-47 rows   0-239  the MAXIMUM strip
"""
import struct, zipfile

DFK_GFX_OFFSET = 0x3B0000          # u4 offset (big-endian view); the patch reads it at 0xA03B0000
U2_CRC = 0x29F9D73A                # dfkbl u2
HUD_BLOB, MAX_BLOB = 0x4D678F, 0x4C22F4
GAUGE_BLOB = 0x5373D7              # the gauge under INSERT COIN: frame / background, red and blue fills
LABEL_BLOB = 0x527C5B             # the 烈怒 label shown on the gauge once it is red
GAUGE_AT = 0x8000                  # offset of the gauge data from DFK_GFX_OFFSET
NEED = 0x580000                    # u2 bytes needed (both blobs end before this)
BG_KEEP = 150                      # background brightness kept (of 255), like DFK's half-transparent strip
BLACK = 6                          # r + g + b (5-bit) below this = black outline, made transparent
# HUD sheet pieces copied to atlas columns 16-31: (x, y, w, h) -> first atlas row; each is centered in the 16 columns
DIM = 0.4                          # brightness of the word that is not selected
BOX_LENS = (58, 50)                # box lengths (screen pixels) around NORMAL / BOOST written in SDOJ's font
GLOW = (0.55, 0.25)                # halo around the selected word: 1 and 2 pixels out, share of its colour
# (x, y, w, h) in the HUD sheet, first atlas row, brightness, glow; the glowing ones get 2 rows of room each side
PIECES = (((36, 7, 8, 35), 2, 1.0, True),       # NORMAL (selected), rows 0-38
          ((36, 7, 8, 35), 39, DIM, False),     # NORMAL dimmed, rows 39-73
          ((53, 34, 6, 30), 76, 1.0, True),     # BOOST (selected), rows 74-107
          ((53, 34, 6, 30), 108, DIM, False),   # BOOST dimmed, rows 108-137
          ((48, 160, 16, 48), 138, 1.0, False),  # box, not selected
          ((48, 208, 16, 48), 186, 1.0, False))  # box, selected


def unlz(d, p):
    """DFK's texture LZ: header size, token count, data offset (BE u32); 32-bit flag words, MSB first;
    flag 0 = literal byte, 1 = BE u16 match (distance = v >> 5, length = (v & 31) + 3)."""
    size, cnt, off = struct.unpack_from('>III', d, p)
    if size != 0x20014 or off != 12 + (cnt + 7) // 8:
        raise ValueError('not the expected DFK texture - is this dfkbl?')
    fl, dp, out, bits, w = p + 12, p + off, bytearray(), 0, 0
    for _ in range(cnt):
        if not bits:
            w = struct.unpack_from('>I', d, fl)[0]; fl += 4; bits = 32
        if w & 0x80000000:
            v = d[dp] << 8 | d[dp + 1]; dp += 2
            s = len(out) - (v >> 5)
            for k in range((v & 31) + 3):
                out.append(out[s + k])
        else:
            out.append(d[dp]); dp += 1
        w = (w << 1) & 0xFFFFFFFF; bits -= 1
    return struct.unpack('>65536H', bytes(out[16:16 + 0x20000]))


def read_dfk_files(paths):
    """paths: dfkbl.zip (or a raw u2). Returns the first NEED bytes of u2."""
    for path in paths:
        if zipfile.is_zipfile(path):
            z = zipfile.ZipFile(path)
            for i in z.infolist():
                if i.filename.split('/')[-1].lower() == 'u2':
                    if i.CRC != U2_CRC:
                        raise ValueError('u2 in %s is not the dfkbl dump (CRC %08X)' % (path, i.CRC))
                    with z.open(i) as f:
                        return f.read(NEED)
        else:
            return open(path, 'rb').read(NEED)
    raise ValueError('dfkbl.zip (with u2) is needed')


def build_dfk_gfx(u2):
    hud, mx = unlz(u2, HUD_BLOB), unlz(u2, MAX_BLOB)
    W, H = 48, 240
    pix = [[0] * W for _ in range(H)]
    for r in range(H):
        for c in range(16):
            v = hud[r * 256 + 16 + c]
            if not v & 0x8000:
                v = hud[r * 256 + c]
                if v & 0x8000:
                    v = 0x8000 | sum(((v >> s & 31) * BG_KEEP // 255) << s for s in (10, 5, 0))
            pix[r][c] = v if v & 0x8000 else 0
            v = mx[r * 256 + 16 + c]
            pix[r][32 + c] = v if v & 0x8000 else 0
    for (bx, by, bw, bh), row, f, glow in PIECES:
        oc = 16 + (16 - bw) // 2
        for y in range(bh):
            for x in range(bw):
                v = hud[(by + y) * 256 + bx + x]
                if v & 0x8000 and (v >> 10 & 31) + (v >> 5 & 31) + (v & 31) >= BLACK:
                    if f != 1.0:
                        v = 0x8000 | sum(int((v >> s & 31) * f) << s for s in (10, 5, 0))
                    pix[row + y][oc + x] = v
        if glow:
            word = [(r, c) for r in range(row, row + bh) for c in range(16, 32) if pix[r][c]]
            avg = [sum(pix[r][c] >> sh & 31 for r, c in word) / len(word) for sh in (10, 5, 0)]
            for r in range(row - 2, row + bh + 2):
                for c in range(16, 32):
                    if pix[r][c]:
                        continue
                    d = min(max(abs(r - wr), abs(c - wc)) for wr, wc in word)
                    if d <= 2:
                        g = GLOW[d - 1]
                        pix[r][c] = 0x8000 | int(avg[0] * g) << 10 | int(avg[1] * g) << 5 | int(avg[2] * g)
    # after the atlas: the boxes stretched to the words (BOX_LENS), not selected / selected each, 16 x 216
    box = []
    for L in BOX_LENS:
        for by in (160, 208):
            for r in range(L):
                sr = r if r < 6 else 48 - (L - r) if r >= L - 6 else 24
                row = []
                for c in range(16):
                    v = hud[(by + sr) * 256 + 48 + c]
                    row.append(v if v & 0x8000 and (v >> 10 & 31) + (v >> 5 & 31) + (v & 31) >= BLACK else 0)
                box.append(row)
    for r, row in enumerate(box):           # also in the atlas, columns 16-31 (the words are not used)
        pix[r][16:32] = row
    g = unlz(u2, GAUGE_BLOB)
    gpix = [g[r * 256 + 96 + c] for r in range(128) for c in range(32)]      # cols 96-111 background, 112-127 frame
    gpix += [g[r * 256 + c] for r in range(128, 256) for c in range(64)]     # rows 128-191 red, 192-255 blue (64 columns)
    lb = unlz(u2, LABEL_BLOB)                                                  # 烈怒: 4 frames of 32, 16 thick
    gpix += [lb[r * 256 + c] for r in range(128) for c in range(16)]
    gauge = b'GAUG' + b'\0' * 12 + struct.pack('>%dH' % len(gpix), *gpix)
    main = (b'DFKB' + struct.pack('>HH', W, H) + b'\0' * 8 + b''.join(struct.pack('>%dH' % W, *r) for r in pix)
            + b''.join(struct.pack('>16H', *r) for r in box))
    return main + b'\0' * (GAUGE_AT - len(main)) + gauge


if __name__ == '__main__':
    import sys
    data = build_dfk_gfx(read_dfk_files(sys.argv[1:]))
    print('DFK bar graphics: %d bytes' % len(data))


# ---------------------------------------------------------------- the NORMAL / BOOST switch sound
# dfkbl's switch sound is its YMZ770 phrase 78. It is copied (still compressed) into free space at the end of
# SDOJ's sound ROM and phrase slot 248 (one of the unused slots 248-255) points at it. u23 + u24 form one 8 MB
# image with byte pairs swapped; each file has 256 spare bytes after its 4 MB, kept as they are.
SND_PHRASE, SND_SLOT, SND_DST = 78, 248, 0x7FC000
# also the coin chime (phrase 64), played when Power Mode is picked: (dfkbl phrase, SDOJ slot, address)
SNDS = [(78, 248, 0x7FC000), (64, 249, 0x7FCC00)]


def _snd_image(a, b):
    d = bytearray(a[:0x400000] + b[:0x400000])
    d[0::2], d[1::2] = d[1::2], d[0::2]
    return d


def read_dfk_sound(path):
    """the dfkbl phrase: (table byte 0, compressed data)"""
    z = zipfile.ZipFile(path)
    files = {i.filename.split('/')[-1].lower(): i for i in z.infolist()}
    k = _snd_image(z.read(files['u23']), z.read(files['u24']))
    ent = lambda i: (k[i * 4], int.from_bytes(k[i * 4 + 1:i * 4 + 4], 'big'))
    out = []
    for ph, _, _ in SNDS:
        b, o = ent(ph)
        nxt = min(oo for _, oo in (ent(i) for i in range(256)) if oo > o)
        out.append((b, bytes(k[o:nxt])))
    return out


def build_dfk_sound(u23, u24, snd):
    """SDOJ's u23 / u24 with the dfkbl phrase added as phrase SND_SLOT"""
    s = _snd_image(u23, u24)
    for (b, data), (_, slot, dst) in zip(snd, SNDS):
        if any(x != 0xFF for x in s[dst:dst + len(data)]):
            raise ValueError('sound ROM free space at %06X is not empty - unexpected dump' % dst)
        s[dst:dst + len(data)] = data
        s[slot * 4:slot * 4 + 4] = bytes([b]) + dst.to_bytes(3, 'big')
    s[0::2], s[1::2] = s[1::2], s[0::2]
    return bytes(s[:0x400000]) + bytes(u23[0x400000:]), bytes(s[0x400000:]) + bytes(u24[0x400000:])
