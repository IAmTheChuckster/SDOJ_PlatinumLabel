#!/usr/bin/env python3
"""Optional: build the pod health bar graphics from your own Xbox 360 DoDonPachi SaiDaiOuJou
Games-on-Demand package (a zip containing B699E3A8BDFD9BB5BE92 and B699E3A8BDFD9BB5BE92.data/,
at any folder depth). Nothing of the game is stored in this repository: the pieces are cut from
your copy at patch time.

Steps: zip -> GOD data files (hash blocks stripped) -> XDVDFS disc image -> CA022010.bin (Cave
archive) -> gamen_new_0/1 (Cave LZSS, 16-bit TGA, ARGB1555) -> outline, fill, digits 0-9, '%'
-> half size -> one atlas, returned as the bytes sdoj_patch.py writes to u4 at BAR_GFX_OFFSET.

Used by: python3 sdoj_patch.py ddpsdoj.zip --god 435A07E7.zip
"""
import re, struct, zipfile, zlib

BAR_GFX_OFFSET = 0x3C0000      # u4 offset (big-endian view); the patch reads it at 0xA03C0000
ARCHIVE = 'CA022010.bin'

# pieces in the decoded (top-down) 512x512 textures: (texture, x0, y0, x1, y1); order is fixed:
# outline, fill, '0'..'9', '%'
PIECES = [
    (1, 364, 302, 380, 444),                       # outline (capsule); from 302: rows 300-301 are a black edge
    (1, 353, 300, 365, 436),                       # fill (gradient)
    (0, 47, 483, 69, 503), (0, 349, 495, 369, 507), (0, 11, 315, 33, 335), (1, 491, 487, 512, 507),
    (1, 471, 0, 493, 20), (1, 471, 20, 493, 40), (1, 471, 40, 493, 60), (1, 473, 60, 493, 80),
    (1, 471, 80, 493, 100), (1, 471, 100, 493, 120), (1, 471, 120, 493, 140),
]
BLK = 0x1000
PER_FILE = 203 * 204           # data blocks per GOD DataNNNN file


class GodZip:
    """Random-access reads of the disc image inside a GOD package that is stored in a zip."""

    def __init__(self, path):
        self.z = zipfile.ZipFile(path)
        names = self.z.namelist()
        self.datas = sorted(n for n in names if re.search(r'B699E3A8BDFD9BB5BE92\.data/Data\d{4}$', n))
        if not self.datas:
            raise ValueError('no B699E3A8BDFD9BB5BE92.data/DataNNNN files in the zip')
        self.cur = None

    def _file_read(self, f, off, n):
        if self.cur is None or self.cur[0] != f or self.cur[2] > off:
            self.cur = [f, self.z.open(self.datas[f]), 0]
        fh = self.cur[1]
        while self.cur[2] < off:
            k = len(fh.read(min(off - self.cur[2], 1 << 20)))
            if not k:
                raise ValueError('GOD data file too short')
            self.cur[2] += k
        data = fh.read(n)
        self.cur[2] += len(data)
        return data

    def read(self, off, size):
        out = bytearray()
        while size > 0:
            block, inner = divmod(off, BLK)
            f, b = divmod(block, PER_FILE)
            group, k = divmod(b, 204)
            n = min(size, BLK - inner)
            out += self._file_read(f, (1 + group * 205 + 1 + k) * BLK + inner, n)
            off += n
            size -= n
        return bytes(out)

    def find_file(self, name):
        if self.read(0x10000, 20) != b'MICROSOFT*XBOX*MEDIA':
            raise ValueError('not an Xbox disc image (XDVDFS)')
        sec, size = struct.unpack('<II', self.read(0x10000 + 20, 8))
        return self._find(sec, size, name.lower())

    def _find(self, sector, size, name):
        data = self.read(sector * 0x800, size)
        stack = [0]
        while stack:
            o = stack.pop()
            if o * 4 + 14 > len(data):
                continue
            l, r, sec, sz, attr, nl = struct.unpack_from('<HHIIBB', data, o * 4)
            if l == 0xFFFF:
                continue
            ent = data[o * 4 + 14:o * 4 + 14 + nl].decode('latin-1').lower()
            if ent == name and not attr & 0x10:
                return sec, sz
            if l:
                stack.append(l)
            if r:
                stack.append(r)
        raise ValueError(name + ' not found on the disc image')


def cave_entries(arc):
    magic, total, dstart, count = struct.unpack_from('>IIII', arc, 0)
    if magic != 0xC0090117:
        raise ValueError('not a Cave CA archive')
    out = {}
    for k in range(count):
        o = 0x24 + k * 0x114
        size, off = struct.unpack_from('>II', arc, o + 8)
        name = re.match(rb'[\x20-\x7e]*', arc[o + 16:o + 16 + 256]).group(0).decode()
        out[name.replace('\\', '/').lstrip('./').lower()] = (off, size)
    return out


def cave_lzss(e):
    """+4 token count, +8 token data offset, flags from +12 (MSB first, 1 = copy: BE u16, len low 5 + 3, dist >> 5)."""
    n, t = struct.unpack_from('>II', e, 4)
    p = t
    out = bytearray()
    for i in range(n):
        if (e[12 + (i >> 3)] >> (7 - (i & 7))) & 1:
            v = (e[p] << 8) | e[p + 1]
            p += 2
            d = v >> 5
            for _ in range((v & 0x1F) + 3):
                out.append(out[-d])
        else:
            out.append(e[p])
            p += 1
    return bytes(out)


def tga16_rows(raw):
    """16-bit TGA -> list of rows (top first) of ARGB1555 ints."""
    w, h = struct.unpack_from('<HH', raw, 12)
    desc = raw[17]
    px = struct.unpack_from('<%dH' % (w * h), raw, 18)
    rows = [list(px[y * w:(y + 1) * w]) for y in range(h)]
    if not desc & 0x20:
        rows.reverse()
    return rows


def half(img, need=2):
    """2x2 box down-scale of an ARGB1555 image (list of rows); a pixel is opaque if `need`+ of 4 are
    (1 for the outline, so its 1-pixel lines survive)."""
    h, w = len(img), len(img[0])
    out = []
    for y in range(0, h - 1, 2):
        row = []
        for x in range(0, w - 1, 2):
            q = [img[y][x], img[y][x + 1], img[y + 1][x], img[y + 1][x + 1]]
            op = [v for v in q if v & 0x8000]
            if len(op) >= need:
                r = sum((v >> 10) & 31 for v in op) // len(op)
                g = sum((v >> 5) & 31 for v in op) // len(op)
                b = sum(v & 31 for v in op) // len(op)
                row.append(0x8000 | (r << 10) | (g << 5) | b)
            else:
                row.append(0)
        out.append(row)
    return out


def glyph_clean(img):
    """Digits are white with a blue outline: drop other colours (neighbouring icons in the texture)."""
    def keep(v):
        if not v & 0x8000:
            return False
        r, g, b = (v >> 10) & 31, (v >> 5) & 31, v & 31
        return b >= g + 4 or (r >= 20 and g >= 20 and b >= 20)
    return [[v if keep(v) else 0 for v in row] for row in img]


def trim(img):
    """Crop to the opaque bounding box."""
    ys = [y for y, row in enumerate(img) if any(v & 0x8000 for v in row)]
    xs = [x for x in range(len(img[0])) if any(row[x] & 0x8000 for row in img)]
    return [row[xs[0]:xs[-1] + 1] for row in img[ys[0]:ys[-1] + 1]]


def build_bar_gfx(god_zip_path):
    """Return the bytes to write at BAR_GFX_OFFSET: 'HPBR', atlas w, h, 13 x {x, y, w, h}, pixels at +0x80."""
    g = GodZip(god_zip_path)
    sec, size = g.find_file(ARCHIVE)
    arc = g.read(sec * 0x800, size)
    ents = cave_entries(arc)
    tex = {}
    for i in (0, 1):
        off, sz = ents['gamen/gamen_new_%d.tga' % i]
        tex[i] = tga16_rows(cave_lzss(arc[off:off + sz]))
    pieces = []
    for k, (t, x0, y0, x1, y1) in enumerate(PIECES):
        crop = [row[x0:x1] for row in tex[t][y0:y1]]
        if k < 2:
            # no black outline: near-black pixels (every channel <= 4 of 31) become transparent
            pieces.append([[0 if v & 0x8000 and max((v >> 10) & 31, (v >> 5) & 31, v & 31) <= 4 else v
                            for v in row] for row in half(crop, 1 if k == 0 else 2)])
        else:
            pieces.append(trim(half(trim(glyph_clean(crop)), 2)))
    # glyphs: same native width (= height on screen), padded on the far side so they share a baseline,
    # and one transparent row after each (a 1 pixel gap between characters)
    gw = max(len(p[0]) for p in pieces[2:])
    for k in range(2, len(pieces)):
        p = [row + [0] * (gw - len(row)) for row in pieces[k]]
        pieces[k] = p + [[0] * gw]
    # atlas: outline and fill side by side, glyphs stacked in a column on the right
    ow, fw = len(pieces[0][0]), len(pieces[1][0])
    gx = ow + fw + 2
    gw = max(len(p[0]) for p in pieces[2:])
    W = gx + gw
    W += W & 1
    boxes, y = [(0, 0), (ow + 1, 0)], 0
    for p in pieces[2:]:
        boxes.append((gx, y))
        y += len(p) + 1
    H = max(len(pieces[0]), len(pieces[1]), y)
    atlas = [[0] * W for _ in range(H)]
    hdr = bytearray(b'HPBR' + struct.pack('>HH', W, H))
    for (bx, by), p in zip(boxes, pieces):
        for yy, row in enumerate(p):
            atlas[by + yy][bx:bx + len(row)] = row
        hdr += struct.pack('>HHHH', bx, by, len(p[0]), len(p))
    hdr += b'\0' * (0x80 - len(hdr))
    pix = b''.join(struct.pack('>%dH' % W, *row) for row in atlas)
    return bytes(hdr) + pix


if __name__ == '__main__':
    import sys
    data = build_bar_gfx(sys.argv[1])
    w, h = struct.unpack_from('>HH', data, 4)
    print('bar graphics: atlas %dx%d, %d bytes' % (w, h, len(data)))
    if len(sys.argv) > 2:
        open(sys.argv[2], 'wb').write(data)
