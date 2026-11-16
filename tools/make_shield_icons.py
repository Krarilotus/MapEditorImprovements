"""Player 0's crest for the player shields (feature 33.2): the game's red crest from
interface_icons2.gm1 (424 normal, 432 selected) with its coloured quarters turned into the white
quarters' stone texture. Writes module/images/shield0.png, shield0_hover.png, shield0_selected.png.

    python tools/make_shield_icons.py [path to interface_icons2.gm1]
"""
import colorsys, os, struct, sys
from PIL import Image

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GM = sys.argv[1] if len(sys.argv) > 1 else \
    r'H:\steam\steamapps\common\Stronghold Crusader Extreme UCP3 new\gm\interface_icons2.gm1'
NORMAL, SELECTED = 424, 432


def pictures(path):
    d = open(path, 'rb').read()
    num = struct.unpack('<22I', d[:88])[3]
    pos = 88 + 5120
    offs = struct.unpack('<%dI' % num, d[pos:pos + 4 * num]); pos += 4 * num
    sizes = struct.unpack('<%dI' % num, d[pos:pos + 4 * num]); pos += 4 * num
    heads = []
    for _ in range(num):
        heads.append(struct.unpack('<HH', d[pos:pos + 4])); pos += 16
    return d, offs, sizes, heads, pos


def decode(d, off, size, w, h, base):
    """A compressed (type 1) gm1 picture."""
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = img.load()
    buf = d[base + off:base + off + size]
    i = x = y = 0
    while i < len(buf):
        b = buf[i]; i += 1
        n, f = (b & 0x1F) + 1, b >> 5
        if f == 0:
            for _ in range(n):
                p = struct.unpack_from('<H', buf, i)[0]; i += 2
                if x < w and y < h:
                    px[x, y] = (((p >> 10) & 31) << 3, ((p >> 5) & 31) << 3, (p & 31) << 3, 255)
                x += 1
        elif f == 4:
            y += 1; x = 0
        elif f == 2:
            p = struct.unpack_from('<H', buf, i)[0]; i += 2
            for _ in range(n):
                if x < w and y < h:
                    px[x, y] = (((p >> 10) & 31) << 3, ((p >> 5) & 31) << 3, (p & 31) << 3, 255)
                x += 1
        elif f == 1:
            x += n
        else:
            break
    return img


def whiten(img):
    """Coloured pixels (the player's quarters) become the white quarters' light stone."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            red = h < 0.08 or h > 0.85             # the red crest's colour, frame (yellow) kept
            if red and s > 0.12 and v > 0.12:
                grey = int(150 + 105 * v)          # shade kept, lifted to the white quarters' range
                grey = min(255, grey)
                px[x, y] = (grey, grey, grey, a)
    return out


def main():
    d, offs, sizes, heads, base = pictures(GM)
    out = os.path.join(HERE, 'module', 'images')
    normal = whiten(decode(d, offs[NORMAL], sizes[NORMAL], *heads[NORMAL], base))
    selected = whiten(decode(d, offs[SELECTED], sizes[SELECTED], *heads[SELECTED], base))
    normal.save(os.path.join(out, 'shield0.png'))
    normal.save(os.path.join(out, 'shield0_hover.png'))
    selected.save(os.path.join(out, 'shield0_selected.png'))
    print('wrote shield0.png, shield0_hover.png, shield0_selected.png', normal.size)


if __name__ == '__main__':
    main()
