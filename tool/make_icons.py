"""Build Android adaptive-icon layers from the single square source art.

The source has its own rounded plate with white corners baked in. Adaptive
icons need the opposite: a full-bleed background layer and a transparent
foreground the launcher masks itself.
"""
import sys
from PIL import Image, ImageDraw

SRC, OUT = sys.argv[1], sys.argv[2]

im = Image.open(SRC).convert("RGBA")
w, h = im.size
px = im.load()

# Plate colour, sampled well inside the dark rounded square.
plate = im.getpixel((w // 2, int(h * 0.06)))[:3]
plate_lum = sum(plate) / 3
print("plate colour: #%02X%02X%02X" % plate)


def saturated(p):
    r, g, b, _a = p
    return max(r, g, b) - min(r, g, b) > 45


# The mark's true extent comes from its saturated pixels (the teal and orange
# panels). Flood-fill bboxes are unreliable here: the anti-aliased ring where
# the white corners meet the dark plate survives both fills and stretches the
# box back out to the full frame.
xs, ys = [], []
for y in range(0, h, 2):
    for x in range(0, w, 2):
        if saturated(px[x, y]):
            xs.append(x)
            ys.append(y)
pad = 10
box = (
    max(min(xs) - pad, 0),
    max(min(ys) - pad, 0),
    min(max(xs) + pad, w),
    min(max(ys) + pad, h),
)
print("mark box:", box)

# Inside that box, drop the plate. Flood fill keeps the dark outlines that sit
# *inside* the artwork, which a plain colour threshold would punch out.
cut = im.crop(box)
cw, ch = cut.size
for pt in ((1, 1), (cw - 2, 1), (1, ch - 2), (cw - 2, ch - 2)):
    ImageDraw.floodfill(cut, pt, (0, 0, 0, 0), thresh=80)
mark = cut.crop(cut.getbbox() or (0, 0, cw, ch))
print("mark size:", mark.size)


def canvas(size, bg=None):
    return Image.new("RGBA", (size, size), bg or (0, 0, 0, 0))


def place(art, size, fraction):
    """Centre the art on a square canvas at the given fraction of its width."""
    target = int(size * fraction)
    scaled = art.copy()
    scaled.thumbnail((target, target), Image.LANCZOS)
    layer = canvas(size)
    layer.paste(
        scaled, ((size - scaled.width) // 2, (size - scaled.height) // 2), scaled
    )
    return layer


# Foreground. flutter_launcher_icons wraps this drawable in a 16% inset, so
# only 68% of the adaptive canvas is left. Filling 88% of the PNG puts the
# mark at 0.88 * 0.68 = 60% of the 108dp canvas — comfortably inside the
# 66dp safe circle, and large enough to fill the visible 72dp mask. Sizing it
# to 60% *here* would compound with the inset and land at 41%, which is the
# shrunken-icon look this is meant to fix.
FOREGROUND_FILL = 0.88
place(mark, 1024, FOREGROUND_FILL).save(f"{OUT}/app_icon_foreground.png")

# Background: flat colour, full bleed, no shape of its own.
canvas(1024, plate + (255,)).save(f"{OUT}/app_icon_background.png")

# Legacy square for pre-adaptive launchers: same art, no white corners.
legacy = canvas(1024, plate + (255,))
legacy.alpha_composite(place(mark, 1024, 0.72))
legacy.save(f"{OUT}/app_icon_legacy.png")

# Monochrome for Android 13 themed icons: the coloured panels go solid and the
# dark gutter stays a gap, so it still reads as an open book.
shape = Image.new("RGBA", mark.size, (0, 0, 0, 0))
sp, mp = shape.load(), mark.load()
for y in range(mark.height):
    for x in range(mark.width):
        r, g, b, a = mp[x, y]
        if a >= 128 and (r + g + b) / 3 > plate_lum + 40:
            sp[x, y] = (0, 0, 0, 255)
place(shape, 1024, FOREGROUND_FILL).save(f"{OUT}/app_icon_monochrome.png")
print("wrote foreground, background, legacy, monochrome")
