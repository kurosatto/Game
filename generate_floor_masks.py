"""Floor masks for the art styles (data/ArtStyles.gd).

For each era this writes assets/eras/<era>/floor_mask.png: white where the
room art is open floor, black on the walls and rocks around it. Room.gd uses
it in the colour art styles to repaint just the floor in the style's own
backdrop, so the style filter never has to guess what is floor.

The floor is found as the region joined to the middle of the room whose
(smoothed) colour stays close to the floor's own, with its specks filled in.

Run from the project root:  python generate_floor_masks.py
"""
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ERAS = ["ediacaran", "cambrian", "ordovician", "carboniferous", "permian"]

for era in ERAS:
    src = Image.open(f"assets/eras/{era}/room.png").convert("RGB")
    w, h = src.size
    smooth = np.asarray(src.filter(ImageFilter.GaussianBlur(3)), dtype=np.float32) / 255.0
    centre = smooth[h // 2 - 250:h // 2 + 250, w // 2 - 500:w // 2 + 500].reshape(-1, 3)
    ref = np.median(centre, axis=0)
    spread = np.percentile(np.linalg.norm(centre - ref, axis=1), 99)
    dist = np.linalg.norm(smooth - ref, axis=2)
    close = dist < max(spread * 1.35, 0.08)
    # Walls are 128px thick: the floor never reaches past them, even where
    # the wall art is close to the floor's colour
    inside = np.zeros_like(close)
    inside[112:h - 112, 112:w - 112] = True
    close &= inside
    labels, _ = ndimage.label(close)
    floor = labels == labels[h // 2, w // 2]
    floor = ndimage.binary_fill_holes(floor)
    # Smooth the outline and keep a little clear of the rocks' ink edges
    floor = ndimage.binary_opening(floor, iterations=4)
    floor = ndimage.binary_erosion(floor, iterations=3)
    mask = Image.fromarray((floor * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))
    mask.save(f"assets/eras/{era}/floor_mask.png")
    print(era, "floor", round(float(floor.mean()) * 100, 1), "%")
