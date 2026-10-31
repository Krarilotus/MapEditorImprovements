# Made module/images/pipette.png, pipette_hover.png and pipette_selected.png: the pipette button
# in the style of the map editor's buttons (mapedit_buttons.gm1). The parchment comes from the
# eraser button (pictures 51-53, read from the game's gm folder): its drawing is painted over
# with the parchment around it, then a pipette is drawn in the same dark brown lines, raised
# (hover) or pressed (selected) the way the game's buttons are. Only used while building the module.
import math
import os
import struct
import sys
from PIL import Image, ImageDraw, ImageFilter

GAME = sys.argv[1] if len(sys.argv) > 1 else r"H:\steam\steamapps\common\Stronghold Crusader Extreme UCP3 new"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'module', 'images')
SS = 8
INK = (52, 34, 18)


def gm_pictures(path, wanted):
    d = open(path, 'rb').read()
    num = struct.unpack('<22I', d[:88])[3]
    pos = 88 + 5120
    offs = struct.unpack('<%dI' % num, d[pos:pos + 4 * num]); pos += 4 * num
    sizes = struct.unpack('<%dI' % num, d[pos:pos + 4 * num]); pos += 4 * num
    heads = [struct.unpack('<HH', d[pos + 16 * i:pos + 16 * i + 4]) for i in range(num)]
    base = pos + 16 * num
    out = {}
    for i in wanted:
        w, h = heads[i]
        img = Image.new('RGBA', (w, h), (0, 0, 0, 0)); px = img.load()
        buf = d[base + offs[i]:base + offs[i] + sizes[i]]; k = x = y = 0
        while k < len(buf):
            b = buf[k]; k += 1; n = (b & 0x1f) + 1; f = b >> 5
            def colour(p): return (((p >> 10) & 31) << 3, ((p >> 5) & 31) << 3, (p & 31) << 3, 255)
            if f == 0:
                for _ in range(n):
                    p = struct.unpack_from('<H', buf, k)[0]; k += 2
                    if x < w and y < h: px[x, y] = colour(p)
                    x += 1
            elif f == 4: y += 1; x = 0
            elif f == 2:
                p = struct.unpack_from('<H', buf, k)[0]; k += 2
                for _ in range(n):
                    if x < w and y < h: px[x, y] = colour(p)
                    x += 1
            elif f == 1: x += n
            else: break
        out[i] = img
    return out


def parchment(img):
    """The picture with its dark drawing replaced by the light parchment around it."""
    rgb = img.convert('RGB')
    w, h = rgb.size
    light = Image.new('RGB', (w, h)); mask = Image.new('L', (w, h), 0)
    pr, pl, pm = rgb.load(), light.load(), mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b = pr[x, y]
            if r + g + b > 470:
                pl[x, y] = (r, g, b); pm[x, y] = 255
    filled = light.copy()
    for radius in (2, 3, 5, 8, 12):
        blur = light.filter(ImageFilter.BoxBlur(radius)); weight = mask.filter(ImageFilter.BoxBlur(radius))
        pb, pw, pf = blur.load(), weight.load(), filled.load()
        for y in range(h):
            for x in range(w):
                if pm[x, y] == 0 and pw[x, y] > 8:
                    s = 255.0 / pw[x, y]
                    pf[x, y] = tuple(min(255, int(c * s)) for c in pb[x, y])
                    pm[x, y] = 255
        light = filled.copy()
    return filled


def pipette_mask(w, h):
    """The pipette outline (lines) and its inside, at SS times the size: rubber bulb at the top
    right, a glass tube down to a fine tip at the bottom left."""
    W, H = w * SS, h * SS
    lines = Image.new('L', (W, H), 0); inside = Image.new('L', (W, H), 0)
    dl, di = ImageDraw.Draw(lines), ImageDraw.Draw(inside)
    a = math.radians(45)
    ux, uy = math.cos(a), -math.sin(a)          # along the pipette, from the tip up to the bulb
    vx, vy = -uy, ux                            # across
    tipx, tipy = 7.0 * SS, 29.5 * SS
    def at(s, t): return (tipx + ux * s * SS + vx * t * SS, tipy + uy * s * SS + vy * t * SS)
    lw = int(1.25 * SS)
    tube = [at(1.5, -0.6), at(6.5, -2.0), at(17.5, -2.0), at(17.5, 2.0), at(6.5, 2.0), at(1.5, 0.6)]
    di.polygon(tube, fill=255)
    dl.line(tube + [tube[0]], fill=255, width=lw, joint='curve')
    dl.line([at(0, 0), at(1.5, 0)], fill=255, width=lw)
    collar = [at(17.5, -3.0), at(19.5, -3.0), at(19.5, 3.0), at(17.5, 3.0)]
    di.polygon(collar, fill=255); dl.line(collar + [collar[0]], fill=255, width=lw, joint='curve')
    cx, cy = at(24.0, 0); r = 4.6 * SS
    di.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    dl.ellipse([cx - r, cy - r, cx + r, cy + r], outline=255, width=lw)
    di.polygon([at(19.5, -2.6), at(21.0, -3.6), at(21.0, 3.6), at(19.5, 2.6)], fill=255)
    dl.line([at(10.0, -0.8), at(15.5, -0.8)], fill=255, width=int(0.9 * SS))   # the liquid level glint
    return lines, inside


def make(background, state):
    w, h = background.size
    lines, inside = pipette_mask(w, h)
    big = background.resize((w * SS, h * SS), Image.BICUBIC).convert('RGBA')
    shape = Image.composite(Image.new('L', big.size, 255), inside, lines)
    if state != 'normal':
        off = 1 * SS
        light, dark = (255, 248, 214), (70, 50, 26)
        first, second = (light, dark) if state == 'hover' else (dark, light)
        glow = shape.filter(ImageFilter.MaxFilter(2 * SS + 1)).filter(ImageFilter.GaussianBlur(SS))
        for colour, dx, dy, strength in ((first, -off, -off, 0.55), (second, off, off, 0.55)):
            layer = Image.new('RGBA', big.size, colour + (0,))
            alpha = Image.new('L', big.size, 0); alpha.paste(glow, (dx, dy))
            layer.putalpha(alpha.point(lambda v: int(v * strength)))
            big.alpha_composite(layer)
    tube = Image.new('RGBA', big.size, (226, 214, 176, 255))
    big.paste(tube, (0, 0), inside.point(lambda v: int(v * 0.35)))
    ink = Image.new('RGBA', big.size, INK + (255,))
    big.paste(ink, (0, 0), lines)
    return big.resize((w, h), Image.LANCZOS).convert('RGBA')


pictures = gm_pictures(os.path.join(GAME, 'gm', 'mapedit_buttons.gm1'), (51, 52, 53))
for index, state, name in ((51, 'normal', 'pipette'), (52, 'hover', 'pipette_hover'), (53, 'selected', 'pipette_selected')):
    make(parchment(pictures[index]), state).save(os.path.join(OUT, name + '.png'))
print('ok')
