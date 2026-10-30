# Made module/images/undo*.png and redo*.png (normal, _hover, _off): the arrows of the map
# editor's undo and redo buttons. Only used while building the module.
import math
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'module', 'images')
SIZE, SS = 28, 8
COLOURS = {'': (226, 204, 150), '_hover': (255, 244, 200), '_off': (120, 112, 98)}
OUTLINE = (40, 30, 18)


def shape(s):
    """The arrow as a mask: an arc from the left over the top round to the lower right, head on the left."""
    mask = Image.new('L', (s, s), 0)
    d = ImageDraw.Draw(mask)
    r, w = s * 0.25, s * 0.10
    c, cy = s * 0.55, s * 0.50
    start, end = 180, 420                        # degrees, y down: 180 = left, 270 = top
    pts = [(c + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in range(start, end + 1, 2)]
    d.line(pts, fill=255, width=int(w), joint='curve')
    ex, ey = pts[-1]
    d.ellipse([ex - w / 2, ey - w / 2, ex + w / 2, ey + w / 2], fill=255)
    # head at the left end, pointing down (the arc runs up from there)
    tx, ty = pts[0]
    head = s * 0.18
    d.polygon([(tx, ty + head * 1.1), (tx - head, ty - head * 0.1), (tx + head, ty - head * 0.1)], fill=255)
    return mask


s = SIZE * SS
fill = shape(s)
outline = fill.filter(ImageFilter.MaxFilter(2 * SS + 1))
for suffix, colour in COLOURS.items():
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    img.paste(OUTLINE + (255,), (0, 0), outline)
    img.paste(colour + (255,), (0, 0), fill)
    small = img.resize((SIZE, SIZE), Image.LANCZOS)
    px = small.load()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= 110 else 0)   # the blit is all or nothing per pixel
    small.save(os.path.join(OUT, 'undo%s.png' % suffix))
    small.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(OUT, 'redo%s.png' % suffix))
print('ok')
