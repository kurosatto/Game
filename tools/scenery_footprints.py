# Measures each painted scenery sprite (assets/eras/<era>/<slot>.png) and
# prints the collision ellipse that matches what you see, for Obstacle.gd's
# FOOTPRINT table: [centre x, centre y, half width, half height] in world px
# (sprite scale and the -20 px offset applied, before any mirroring).
# Low, compact things (rocks, fossils, mounds) are solid over their whole
# drawn body; tall things (fronds, stems, trees) only at the base, since the
# player can pass in front of their tops.
# Run: python3 tools/scenery_footprints.py
from PIL import Image
import glob, os
SHRINK = 0.88   # a little inside the ink line, so near misses slide past
BASE_BAND = 40  # texture px of a tall thing's base that is solid
MIN_BLOB = 40  # px; smaller loose bits (the pebbles at the foot) aren't solid


def keep_body(a):
    """Opaque pixels, minus small loose specks such as the drawn pebbles."""
    on = {(x, y) for y in range(a.height) for x in range(a.width) if a.getpixel((x, y)) > 60}
    keep, seen = set(), set()
    for p in on:
        if p in seen:
            continue
        blob, stack = [], [p]
        seen.add(p)
        while stack:
            x, y = stack.pop()
            blob.append((x, y))
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if q in on and q not in seen:
                    seen.add(q)
                    stack.append(q)
        if len(blob) >= MIN_BLOB:
            keep.update(blob)
    return keep


out = []
for f in sorted(glob.glob('assets/eras/*/*.png')):
    era, name = f.split('/')[-2], os.path.basename(f)[:-4]
    if name.split('_')[0] not in ('rock', 'tall', 'mound', 'glow', 'fossil'):
        continue
    im = Image.open(f).convert('RGBA')
    if im.width != 160:
        continue
    s = 1.4 if name.startswith('tall') else 1.2
    a = im.split()[3]
    solid = keep_body(a)
    rows = {}
    for y in range(im.height):
        xs = [x for x in range(im.width) if (x, y) in solid]
        if xs:
            rows[y] = (min(xs), max(xs))
    top, bot = min(rows), max(rows)
    w = max(r[1] - r[0] for r in rows.values())
    if bot - top > 1.15 * w:
        top = bot - BASE_BAND
    band = [rows[y] for y in range(top, bot + 1) if y in rows]
    # widest part of the band, ignoring thin wisps (trimmed 10%)
    lefts = sorted(r[0] for r in band)
    rights = sorted(r[1] for r in band)
    k = len(band) // 10
    x0, x1 = lefts[k], rights[-1 - k]
    cx = ((x0 + x1) / 2 - 80) * s
    cy = ((top + bot) / 2 - 100) * s
    hw = max(10.0, (x1 - x0) / 2 * s * SHRINK)
    hh = max(10.0, (bot - top) / 2 * s * SHRINK)
    out.append('    "%s/%s": [%.0f, %.0f, %.0f, %.0f],' % (era, name, cx, cy, hw, hh))
print('const FOOTPRINT = {')
print('\n'.join(out))
print('}')
