# Made module/images/mask.png, mask_hover.png and mask_selected.png: the texture mask button, a
# small square split corner to corner, the lower right half filled, in the map editor's dark
# brown ink on parchment. Hover is lighter; chosen has a golden frame and darker parchment, like
# a pressed button. Only used while building the module.
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'module', 'images')
W, H = 26, 22
SS = 8
INK = (52, 34, 18, 255)
STATES = {
    'mask': ((214, 190, 140, 255), INK),
    'mask_hover': ((236, 216, 170, 255), (88, 60, 30, 255)),
    'mask_selected': ((176, 150, 104, 255), (232, 184, 64, 255)),
}


def icon(parchment, frame):
    img = Image.new('RGBA', (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = 3 * SS
    d.rounded_rectangle((0, 0, W * SS - 1, H * SS - 1), r, fill=frame)
    b = 2 * SS
    d.rounded_rectangle((b, b, W * SS - 1 - b, H * SS - 1 - b), r - b // 2, fill=parchment)
    # the filled half: below the diagonal from the inner top right to the inner bottom left
    x0, y0, x1, y1 = b + SS, b + SS, W * SS - 1 - b - SS, H * SS - 1 - b - SS
    d.polygon([(x1, y0), (x1, y1), (x0, y1)], fill=INK)
    d.rectangle((x0, y0, x1, y1), outline=INK, width=SS)
    return img.resize((W, H), Image.LANCZOS)


for name, (parchment, frame) in STATES.items():
    icon(parchment, frame).save(os.path.join(OUT, name + '.png'))
print('written to', os.path.normpath(OUT))
