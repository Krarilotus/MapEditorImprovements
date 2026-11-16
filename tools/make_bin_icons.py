# Made module/images/bin.png, bin_hover.png and bin_selected.png: the red wastebin of the
# Animals menu's "erase all" buttons, on the map editor's parchment. Hover is lighter; selected
# has a golden frame (not used by the buttons, which never stay chosen). Only used while
# building the module.
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'module', 'images')
W, H = 24, 26
SS = 8
INK = (52, 34, 18, 255)
STATES = {
    'bin': ((214, 190, 140, 255), INK, (178, 30, 24, 255)),
    'bin_hover': ((236, 216, 170, 255), (88, 60, 30, 255), (214, 48, 36, 255)),
    'bin_selected': ((176, 150, 104, 255), (232, 184, 64, 255), (178, 30, 24, 255)),
}


def icon(parchment, frame, red):
    img = Image.new('RGBA', (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = 3 * SS
    d.rounded_rectangle((0, 0, W * SS - 1, H * SS - 1), r, fill=frame)
    b = 2 * SS
    d.rounded_rectangle((b, b, W * SS - 1 - b, H * SS - 1 - b), r - b // 2, fill=parchment)
    dark = tuple(max(0, c - 70) for c in red[:3]) + (255,)
    # handle, lid, body (wider at the top), three grooves
    cx = W * SS // 2
    d.rounded_rectangle((cx - 3 * SS, 4 * SS, cx + 3 * SS, 6 * SS), SS, fill=red, outline=dark, width=SS // 2)
    d.rounded_rectangle((5 * SS, 6 * SS, W * SS - 5 * SS, 8 * SS), SS // 2, fill=red, outline=dark, width=SS // 2)
    d.polygon([(6 * SS, 9 * SS), (W * SS - 6 * SS, 9 * SS), (W * SS - 7 * SS, H * SS - 5 * SS),
               (7 * SS, H * SS - 5 * SS)], fill=red, outline=dark)
    for gx in (cx - 3 * SS, cx, cx + 3 * SS):
        d.line((gx, 11 * SS, gx, H * SS - 7 * SS), fill=dark, width=SS)
    return img.resize((W, H), Image.LANCZOS)


for name, (parchment, frame, red) in STATES.items():
    icon(parchment, frame, red).save(os.path.join(OUT, name + '.png'))
print('written to', os.path.normpath(OUT))
