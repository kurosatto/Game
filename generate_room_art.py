"""Per-era room backgrounds and obstacle sprites.

For each of the five eras (floors) this writes
  assets/eras/<era>/room.png       1920x1080 room: floor plus 128px walls
  assets/eras/<era>/<slot>.png     128x128 obstacles: rock, tall, mound, glow, fossil

Everything is painted at half resolution and scaled 2x for the same chunky
pixels as the sprites. The room image tiles horizontally between the side
walls (period = 1664px), so Room.gd can stretch it with a NinePatchRect to
any screen width without visible seams.

Run from the project root:  python generate_room_art.py
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 960, 540          # half-res room
WALL = 64                # half-res wall thickness (128px in game)
PERIOD = W - 2 * WALL    # floor tiles horizontally with this period

ERAS = ["ediacaran", "cambrian", "ordovician", "carboniferous", "permian"]


# ─────────────────────────────── noise ───────────────────────────────

def value_noise(w, h, cell, rng, period_x=None):
    """Smooth value noise; wraps horizontally when period_x is given."""
    gx = int(math.ceil((period_x or w) / cell))
    gy = int(math.ceil(h / cell)) + 2
    grid = rng.random((gy, gx))
    ys = np.arange(h) / cell
    xs = np.arange(w) / cell
    x0 = np.floor(xs).astype(int)
    y0 = np.floor(ys).astype(int)
    fx = xs - x0
    fy = ys - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    x0w, x1w = x0 % gx, (x0 + 1) % gx
    a = grid[y0][:, x0w]
    b = grid[y0][:, x1w]
    c = grid[y0 + 1][:, x0w]
    d = grid[y0 + 1][:, x1w]
    top = a + (b - a) * fx
    bot = c + (d - c) * fx
    return top + (bot - top) * fy[:, None]


def fbm(w, h, rng, base=64, octaves=4, period_x=None):
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    cell = base
    for _ in range(octaves):
        # Each octave's cell size divides the period so the sum still wraps
        c = cell
        if period_x:
            c = period_x / max(1, round(period_x / cell))
        out += value_noise(w, h, c, rng, period_x) * amp
        total += amp
        amp *= 0.5
        cell = max(2, cell / 2)
    return out / total


def caustics(w, h, rng, period_x, scale=80):
    """Bright wavy network like sunlight focused through ripples."""
    n1 = fbm(w, h, rng, scale, 2, period_x)
    n2 = fbm(w, h, rng, scale * 0.7, 2, period_x)
    v = np.abs(np.sin(n1 * 9.0)) * np.abs(np.sin(n2 * 8.0))
    return np.clip(1.0 - v * 6.0, 0, 1) ** 2


def palette_map(v, stops):
    """Map 0..1 values through colour stops [(pos, (r,g,b)), ...]."""
    v = np.clip(v, 0, 1)
    out = np.zeros(v.shape + (3,))
    for (p0, c0), (p1, c1) in zip(stops[:-1], stops[1:]):
        m = (v >= p0) & (v <= p1)
        t = ((v - p0) / max(1e-6, p1 - p0))[m][:, None]
        out[m] = np.array(c0) + (np.array(c1) - np.array(c0)) * t
    return out


def quantize(rgb, levels=20):
    """Slight posterisation for a painted-pixel look."""
    return np.round(rgb / 255 * levels) / levels * 255


# ───────────────────────────── era recipes ─────────────────────────────

ERA_STYLE = {
    "ediacaran": {
        "floor": [(0.0, (22, 52, 58)), (0.45, (46, 92, 88)), (0.7, (88, 128, 108)), (1.0, (150, 170, 130))],
        "wall": [(0.0, (14, 30, 40)), (0.5, (40, 70, 70)), (1.0, (90, 120, 100))],
        "caustic": (150, 230, 210), "rim": (90, 220, 200),
    },
    "cambrian": {
        "floor": [(0.0, (40, 60, 80)), (0.45, (92, 118, 128)), (0.75, (150, 160, 150)), (1.0, (210, 205, 170))],
        "wall": [(0.0, (40, 30, 40)), (0.5, (120, 80, 70)), (1.0, (200, 150, 110))],
        "caustic": (200, 240, 255), "rim": (255, 190, 140),
    },
    "ordovician": {
        "floor": [(0.0, (18, 34, 66)), (0.45, (52, 82, 120)), (0.75, (98, 128, 160)), (1.0, (170, 190, 205))],
        "wall": [(0.0, (16, 22, 40)), (0.5, (70, 84, 110)), (1.0, (150, 160, 175))],
        "caustic": (170, 220, 255), "rim": (140, 200, 255),
    },
    "carboniferous": {
        "floor": [(0.0, (16, 26, 14)), (0.4, (40, 58, 28)), (0.7, (74, 84, 40)), (1.0, (120, 118, 60))],
        "wall": [(0.0, (16, 14, 10)), (0.5, (64, 50, 34)), (1.0, (120, 98, 64))],
        "caustic": (200, 230, 140), "rim": (170, 220, 90),
    },
    "permian": {
        "floor": [(0.0, (16, 12, 16)), (0.45, (46, 36, 40)), (0.75, (80, 62, 58)), (1.0, (130, 100, 86))],
        "wall": [(0.0, (10, 8, 10)), (0.5, (40, 34, 36)), (1.0, (90, 76, 72))],
        "caustic": (255, 150, 90), "rim": (255, 110, 50),
    },
}


def floor_details(era, img, rng):
    """Era-specific marks painted onto the floor (half-res, PERIOD-wrapped)."""
    d = ImageDraw.Draw(img, "RGBA")

    def wrap_draw(fn, x, y, *a):
        # Draw at x and at x +/- PERIOD so details crossing the seam wrap
        for dx in (-PERIOD, 0, PERIOD):
            fn(x + dx, y, *a)

    if era == "ediacaran":
        # Dickinsonia-like ribbed ovals and Charnia frond imprints on the mat
        for _ in range(9):
            x, y = rng.uniform(WALL, W - WALL), rng.uniform(WALL + 10, H - WALL - 10)
            rx, ry = rng.uniform(10, 18), rng.uniform(7, 12)
            def dick(x, y, rx=rx, ry=ry):
                d.ellipse((x - rx, y - ry, x + rx, y + ry), outline=(30, 70, 66, 150))
                for k in range(-int(rx) + 2, int(rx) - 1, 3):
                    h = ry * math.sqrt(max(0, 1 - (k / rx) ** 2))
                    d.line((x + k, y - h + 1, x + k, y + h - 1), fill=(30, 70, 66, 90))
                d.line((x - rx + 2, y, x + rx - 2, y), fill=(30, 70, 66, 140))
            wrap_draw(dick, x, y)
        for _ in range(6):
            x, y = rng.uniform(WALL, W - WALL), rng.uniform(WALL + 20, H - WALL - 20)
            ang = rng.uniform(0, math.pi)
            def frond(x, y, ang=ang):
                L = 26
                ex, ey = x + math.cos(ang) * L, y + math.sin(ang) * L
                d.line((x, y, ex, ey), fill=(160, 190, 150, 110))
                for k in range(1, 9):
                    px, py = x + math.cos(ang) * L * k / 9, y + math.sin(ang) * L * k / 9
                    for s in (-1, 1):
                        d.line((px, py, px + math.cos(ang + s * 1.1) * 5, py + math.sin(ang + s * 1.1) * 5), fill=(160, 190, 150, 80))
            wrap_draw(frond, x, y)
    elif era == "cambrian":
        # Cruziana trilobite trackways and scattered small shells
        for _ in range(5):
            x, y = rng.uniform(WALL, W - WALL), rng.uniform(WALL + 20, H - WALL - 20)
            ang = rng.uniform(0, math.pi * 2)
            def track(x, y, ang=ang):
                for k in range(14):
                    px = x + math.cos(ang) * k * 4 + math.sin(k * 0.5) * 2
                    py = y + math.sin(ang) * k * 4
                    for s in (-1, 1):
                        ox, oy = -math.sin(ang) * 3 * s, math.cos(ang) * 3 * s
                        d.line((px + ox, py + oy, px + ox * 1.8 + math.cos(ang) * 2, py + oy * 1.8 + math.sin(ang) * 2), fill=(60, 70, 80, 120))
            wrap_draw(track, x, y)
        for _ in range(40):
            x, y = rng.uniform(WALL, W - WALL), rng.uniform(WALL + 4, H - WALL - 4)
            def shell(x, y):
                d.ellipse((x - 2, y - 1, x + 2, y + 1), fill=(225, 215, 190, 170))
            wrap_draw(shell, x, y)
    elif era == "ordovician":
        # Crinoid stem discs and straight orthocone shell fossils
        for _ in range(60):
            x, y = rng.uniform(WALL, W - WALL), rng.uniform(WALL + 4, H - WALL - 4)
            def disc(x, y):
                d.ellipse((x - 1.5, y - 1.5, x + 1.5, y + 1.5), fill=(200, 210, 220, 140))
                d.point((x, y), fill=(80, 100, 130, 200))
            wrap_draw(disc, x, y)
        for _ in range(6):
            x, y = rng.uniform(WALL, W - WALL), rng.uniform(WALL + 20, H - WALL - 20)
            ang = rng.uniform(0, math.pi * 2)
            def ortho(x, y, ang=ang):
                L = rng.uniform(22, 34)
                ex, ey = x + math.cos(ang) * L, y + math.sin(ang) * L
                d.polygon([(x - math.sin(ang) * 4, y + math.cos(ang) * 4), (x + math.sin(ang) * 4, y - math.cos(ang) * 4), (ex, ey)], fill=(170, 180, 190, 120))
                for k in range(1, 7):
                    px, py = x + math.cos(ang) * L * k / 7, y + math.sin(ang) * L * k / 7
                    w = 4 * (1 - k / 7)
                    d.line((px - math.sin(ang) * w, py + math.cos(ang) * w, px + math.sin(ang) * w, py - math.cos(ang) * w), fill=(90, 100, 120, 140))
            wrap_draw(ortho, x, y)
    elif era == "carboniferous":
        # Fern leaf litter and fallen lycopsid bark with diamond leaf scars
        for _ in range(4):
            x, y = rng.uniform(WALL, W - WALL), rng.uniform(WALL + 30, H - WALL - 30)
            ang = rng.uniform(-0.4, 0.4)
            def bark(x, y, ang=ang):
                L, wd = 70, 9
                pts = [(x - math.sin(ang) * wd, y + math.cos(ang) * wd), (x + math.sin(ang) * wd, y - math.cos(ang) * wd)]
                pts += [(pts[1][0] + math.cos(ang) * L, pts[1][1] + math.sin(ang) * L), (pts[0][0] + math.cos(ang) * L, pts[0][1] + math.sin(ang) * L)]
                d.polygon(pts, fill=(70, 56, 36, 200))
                for i in range(2, 34, 4):
                    for j in (-4, 0, 4):
                        cx = x + math.cos(ang) * i * 2 - math.sin(ang) * j + (2 if (i // 4) % 2 else 0)
                        cy = y + math.sin(ang) * i * 2 + math.cos(ang) * j
                        d.polygon([(cx, cy - 2), (cx + 1.5, cy), (cx, cy + 2), (cx - 1.5, cy)], outline=(40, 30, 20, 200))
            wrap_draw(bark, x, y)
        for _ in range(26):
            x, y = rng.uniform(WALL, W - WALL), rng.uniform(WALL + 10, H - WALL - 10)
            ang = rng.uniform(0, math.pi * 2)
            col = (int(rng.uniform(70, 120)), int(rng.uniform(100, 140)), 40, 150)
            def fern(x, y, ang=ang, col=col):
                L = 16
                d.line((x, y, x + math.cos(ang) * L, y + math.sin(ang) * L), fill=col)
                for k in range(1, 8):
                    px, py = x + math.cos(ang) * L * k / 8, y + math.sin(ang) * L * k / 8
                    lw = 4 * (1 - k / 9)
                    for s in (-1, 1):
                        d.line((px, py, px + math.cos(ang + s * 1.3) * lw, py + math.sin(ang + s * 1.3) * lw), fill=col)
            wrap_draw(fern, x, y)
    elif era == "permian":
        # Cooled lava crust split by glowing cracks, plus ash flecks
        for _ in range(16):
            x, y = rng.uniform(WALL, W - WALL), rng.uniform(WALL + 10, H - WALL - 10)
            segs = int(rng.integers(4, 9))
            pts = [(x, y)]
            ang = rng.uniform(0, math.pi * 2)
            for _ in range(segs):
                ang += rng.uniform(-0.9, 0.9)
                L = rng.uniform(6, 16)
                pts.append((pts[-1][0] + math.cos(ang) * L, pts[-1][1] + math.sin(ang) * L))
            def crack(x, y, pts=pts):
                dx = x - pts[0][0]
                sh = [(px + dx, py) for px, py in pts]
                d.line(sh, fill=(255, 120, 40, 90), width=3)
                d.line(sh, fill=(255, 200, 110, 220), width=1)
            wrap_draw(crack, x, y)
        for _ in range(200):
            x, y = rng.uniform(WALL, W - WALL), rng.uniform(WALL, H - WALL)
            def ash(x, y):
                d.point((x, y), fill=(170, 160, 160, 110))
            wrap_draw(ash, x, y)


def wall_texture(era, rng):
    """Half-res wall material, 64px thick, as an RGB array of the whole room."""
    st = ERA_STYLE[era]
    n = fbm(W, H, rng, 20, 3, PERIOD)
    base = palette_map(n * 0.6 + 0.2, st["wall"])
    img = Image.fromarray(base.astype(np.uint8))
    d = ImageDraw.Draw(img, "RGBA")
    lit, dark = (255, 255, 255, 50), (0, 0, 0, 90)
    if era == "ediacaran":
        # Stacked stromatolite domes
        for y in range(0, H, 14):
            for x in range(-8, W + 8, 18):
                ox = x + (9 if (y // 14) % 2 else 0)
                d.chord((ox - 10, y - 4, ox + 10, y + 14), 180, 360, fill=None, outline=(120, 160, 130, 160))
                d.arc((ox - 6, y, ox + 6, y + 10), 180, 360, fill=(30, 60, 60, 160))
    elif era == "cambrian":
        # Archaeocyath reef: rows of porous cups
        for y in range(4, H, 16):
            for x in range(0, W, 14):
                ox = x + (7 if (y // 16) % 2 else 0)
                d.polygon([(ox - 6, y), (ox + 6, y), (ox + 3, y + 13), (ox - 3, y + 13)], fill=(170, 110, 90, 200), outline=(60, 35, 35, 220))
                d.ellipse((ox - 4, y - 1, ox + 4, y + 2), fill=(70, 40, 40, 230))
                for k in (-2, 0, 2):
                    d.point((ox + k, y + 6), fill=(230, 190, 150, 200))
    elif era == "ordovician":
        # Cut limestone blocks with crinoid stems embedded
        for y in range(0, H, 16):
            for x in range(0, W, 32):
                ox = x + (16 if (y // 16) % 2 else 0)
                d.rectangle((ox, y, ox + 31, y + 15), outline=(20, 26, 44, 200))
                d.line((ox + 1, y + 1, ox + 30, y + 1), fill=lit)
                if rng.random() < 0.3:
                    for k in range(5):
                        d.ellipse((ox + 6 + k * 3, y + 6, ox + 8 + k * 3, y + 9), fill=(190, 200, 215, 170))
    elif era == "carboniferous":
        # Lycopsid trunks (Lepidodendron) packed side by side, diamond scars
        for x in range(-6, W + 6, 12):
            d.rectangle((x, 0, x + 10, H), fill=(60 + (x % 24), 48, 30, 255), outline=(20, 16, 10, 255))
            for y in range(0, H, 6):
                cx = x + 5 + (2 if (y // 6) % 2 else -2)
                d.polygon([(cx, y), (cx + 2, y + 3), (cx, y + 6), (cx - 2, y + 3)], outline=(30, 24, 14, 220), fill=(90, 74, 44, 255))
    elif era == "permian":
        # Basalt columns seen end-on (hexagons) with lava glow in the joints
        r = 8
        for row, y in enumerate(range(0, H + r, int(r * 1.5))):
            for x in range(0, W + r * 2, int(r * 1.75)):
                ox = x + (r * 0.87 if row % 2 else 0)
                hexp = [(ox + r * math.cos(a), y + r * math.sin(a)) for a in [math.pi / 3 * k + math.pi / 6 for k in range(6)]]
                d.polygon(hexp, fill=(int(40 + rng.integers(0, 20)), 34, 36, 255), outline=(255, 110, 40, 140))
                d.line(hexp[3:6], fill=lit)
    arr = np.array(img).astype(np.float64)
    return arr


def make_room(era, seed):
    rng = np.random.default_rng(seed)
    st = ERA_STYLE[era]
    # Floor: fbm through the era palette, plus fine grain
    n = fbm(W, H, rng, 96, 5, PERIOD)
    grain = fbm(W, H, rng, 6, 2, PERIOD)
    floor = palette_map(n * 0.92 + grain * 0.08, st["floor"])
    img = Image.fromarray(quantize(floor).astype(np.uint8))
    floor_details(era, img, rng)
    floor = np.array(img).astype(np.float64)
    # Caustic light network, stronger near the room centre
    yy, xx = np.mgrid[0:H, 0:W]
    centre = 1 - np.clip(np.hypot((xx - W / 2) / (W * 0.65), (yy - H / 2) / (H * 0.7)), 0, 1)
    cau = caustics(W, H, rng, PERIOD)
    floor += np.array(st["caustic"]) * (cau * (0.06 + 0.12 * centre))[..., None]
    # Walls: top/bottom bands across the whole width, sides at the edges
    wall = wall_texture(era, rng)
    mask = np.zeros((H, W))
    mask[:WALL, :] = 1
    mask[H - WALL:, :] = 1
    mask[:, :WALL] = 1
    mask[:, W - WALL:] = 1
    out = floor * (1 - mask[..., None]) + wall * mask[..., None]
    # Inner shadow where floor meets wall, and a lit rim on the wall edge
    dist = np.minimum.reduce([yy - WALL, H - WALL - 1 - yy, xx - WALL, W - WALL - 1 - xx]).astype(np.float64)
    shadow = np.clip(1 - dist / 22, 0, 1) * (dist >= 0)
    out *= (1 - 0.55 * shadow[..., None])
    rim = (dist >= -2) & (dist < 0)
    out[rim] = out[rim] * 0.4 + np.array(st["rim"]) * 0.6
    # Darken the outer half of the walls for depth
    outer = np.clip((-dist - 2) / 50, 0, 1) * (dist < 0)
    out *= (1 - 0.45 * outer[..., None])
    # The game brightens rooms (CanvasModulate x brightness, plus glow), so
    # the art is kept dark and slightly contrasty to land at the right level
    out = (out / 255.0) ** 1.15 * 255.0 * 0.58
    out = np.clip(out, 0, 255).astype(np.uint8)
    room = Image.fromarray(out).resize((W * 2, H * 2), Image.NEAREST)
    return room


# ───────────────────────────── obstacles ─────────────────────────────

OUTLINE = (10, 14, 24, 255)


def obstacle_canvas():
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def shade(c, k):
    if k < 1:
        return tuple(int(v * k) for v in c[:3]) + (255,)
    return tuple(int(v + (255 - v) * (k - 1)) for v in c[:3]) + (255,)


def blob(d, cx, cy, rx, ry, col, light=True):
    d.ellipse((cx - rx - 1, cy - ry - 1, cx + rx + 1, cy + ry + 1), fill=OUTLINE)
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=col)
    if light:
        d.ellipse((cx - rx * 0.6, cy - ry * 0.75, cx + rx * 0.1, cy - ry * 0.1), fill=shade(col, 1.25))


def shadow(img, cx, cy, rx, ry):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(0, 0, 0, 90))
    return Image.alpha_composite(layer, img)


def rock(era, rng):
    cols = {"ediacaran": (90, 110, 100), "cambrian": (150, 130, 110), "ordovician": (120, 130, 150),
            "carboniferous": (90, 80, 60), "permian": (60, 52, 56)}
    col = cols[era] + (255,)
    img, d = obstacle_canvas()
    img = shadow(img, 32, 46, 24, 9)
    d = ImageDraw.Draw(img)
    pts = []
    for k in range(9):
        a = k / 9 * math.tau
        r = rng.uniform(17, 24)
        pts.append((32 + math.cos(a) * r * 1.1, 34 + math.sin(a) * r * 0.85))
    d.polygon([(x, y + 1) for x, y in pts], fill=OUTLINE)
    d.polygon(pts, fill=col, outline=OUTLINE)
    d.polygon([pts[4], pts[5], pts[6], (32, 30)], fill=shade(col, 1.2))
    d.line([pts[1], (34, 36), pts[7]], fill=shade(col, 0.7))
    if era == "permian":
        d.line([(24, 30), (30, 38), (40, 34)], fill=(255, 140, 60, 255))
    if era == "carboniferous":
        for k in range(5):
            d.point((22 + k * 4, 26 + (k % 2) * 2), fill=(90, 140, 50, 255))
    return img


def tall(era, rng):
    img, d = obstacle_canvas()
    img = shadow(img, 32, 52, 14, 6)
    d = ImageDraw.Draw(img)
    if era == "ediacaran":
        # Charnia frond on a holdfast disc
        blob(d, 32, 50, 7, 4, (90, 120, 100, 255))
        d.line((32, 50, 32, 10), fill=OUTLINE, width=3)
        for k in range(10):
            y = 46 - k * 3.6
            w = 12 * math.sin((k + 1) / 11 * math.pi)
            for s in (-1, 1):
                d.line((32, y, 32 + s * w, y - 3), fill=(120, 180, 150, 255), width=2)
        d.line((32, 50, 32, 10), fill=(160, 210, 170, 255))
    elif era == "cambrian":
        # Archaeocyath cup: double-walled porous cone
        d.polygon([(18, 12), (46, 12), (38, 54), (26, 54)], fill=OUTLINE)
        d.polygon([(20, 13), (44, 13), (37, 53), (27, 53)], fill=(200, 140, 100, 255))
        d.ellipse((19, 9, 45, 17), fill=OUTLINE)
        d.ellipse((21, 10, 43, 16), fill=(90, 50, 40, 255))
        for y in range(20, 52, 5):
            for x in range(24, 41, 4):
                d.point((x + (y % 2), y), fill=(110, 60, 45, 255))
    elif era == "ordovician":
        # Crinoid: segmented stalk with a feathery crown
        for y in range(54, 22, -3):
            d.ellipse((30, y - 2, 34, y + 1), fill=(200, 190, 210, 255), outline=OUTLINE)
        for k in range(10):
            a = -math.pi / 2 + (k - 4.5) * 0.28
            ex, ey = 32 + math.cos(a) * 20, 20 + math.sin(a) * 16
            d.line((32, 22, ex, ey), fill=OUTLINE, width=3)
            d.line((32, 22, ex, ey), fill=(220, 120, 170, 255))
        blob(d, 32, 22, 5, 4, (200, 110, 150, 255))
    elif era == "carboniferous":
        # Broken lycopsid stump with diamond leaf-scar bark
        d.rectangle((22, 14, 42, 54), fill=OUTLINE)
        d.rectangle((23, 15, 41, 53), fill=(90, 72, 46, 255))
        for y in range(16, 52, 5):
            for x in range(25, 40, 5):
                cx = x + (2 if (y // 5) % 2 else 0)
                d.polygon([(cx, y), (cx + 2, y + 2), (cx, y + 4), (cx - 2, y + 2)], fill=(60, 46, 28, 255))
        d.polygon([(22, 14), (28, 8), (33, 14), (38, 9), (42, 14)], fill=(140, 110, 70, 255), outline=OUTLINE)
        for s in (-1, 1):
            d.line((32 + s * 10, 52, 32 + s * 18, 58), fill=(70, 56, 36, 255), width=3)
    else:
        # Basalt column cluster with a glowing fissure
        for x, h in ((22, 30), (32, 40), (42, 26)):
            d.rectangle((x - 5, 54 - h, x + 5, 54), fill=OUTLINE)
            d.rectangle((x - 4, 55 - h, x + 4, 53), fill=(56, 48, 52, 255))
            d.polygon([(x - 4, 55 - h), (x, 52 - h), (x + 4, 55 - h)], fill=(90, 80, 84, 255))
        d.line((26, 50, 28, 30), fill=(255, 140, 60, 255))
        d.line((38, 52, 37, 36), fill=(255, 110, 40, 255))
    return img


def mound(era, rng):
    img, d = obstacle_canvas()
    img = shadow(img, 32, 48, 22, 8)
    d = ImageDraw.Draw(img)
    if era == "ediacaran":
        # Stromatolite: layered microbial dome
        blob(d, 32, 38, 22, 14, (80, 120, 100, 255), light=False)
        for k in range(5):
            d.arc((14 + k * 3, 26 + k * 3, 50 - k * 3, 52 - k * 2), 180, 360, fill=(140, 180, 150, 255))
    elif era == "cambrian":
        # Sponge cluster (Vauxia-like branching tubes)
        for x, h in ((22, 22), (32, 30), (42, 18)):
            d.rounded_rectangle((x - 6, 50 - h, x + 6, 50), 4, fill=OUTLINE)
            d.rounded_rectangle((x - 5, 51 - h, x + 5, 49), 4, fill=(220, 180, 90, 255))
            d.ellipse((x - 3, 51 - h, x + 3, 55 - h), fill=(120, 80, 40, 255))
    elif era == "ordovician":
        # Bryozoan colony: lacy fan of branches
        blob(d, 32, 48, 10, 4, (90, 110, 140, 255), light=False)
        for k in range(9):
            a = -math.pi / 2 + (k - 4) * 0.3
            d.line((32, 48, 32 + math.cos(a) * 22, 48 + math.sin(a) * 24), fill=OUTLINE, width=3)
            d.line((32, 48, 32 + math.cos(a) * 22, 48 + math.sin(a) * 24), fill=(170, 210, 230, 255))
    elif era == "carboniferous":
        # Fern clump (Psaronius-style tree-fern fronds from a low crown)
        for k in range(7):
            a = -math.pi / 2 + (k - 3) * 0.45
            ex, ey = 32 + math.cos(a) * 26, 46 + math.sin(a) * 22
            d.line((32, 46, ex, ey), fill=OUTLINE, width=3)
            for j in range(1, 7):
                px, py = 32 + (ex - 32) * j / 7, 46 + (ey - 46) * j / 7
                for s in (-1, 1):
                    d.line((px, py, px + math.cos(a + s * 1.4) * 4, py + math.sin(a + s * 1.4) * 4), fill=(80, 140, 50, 255))
            d.line((32, 46, ex, ey), fill=(110, 170, 60, 255))
    else:
        # Ash heap with a smouldering core
        blob(d, 32, 40, 22, 12, (70, 64, 66, 255), light=False)
        blob(d, 32, 36, 12, 6, (90, 84, 86, 255))
        d.ellipse((28, 38, 36, 42), fill=(255, 120, 50, 255))
    return img


def glow(era, rng):
    """The light-emitting obstacle of each era (gets a PointLight in game)."""
    img, d = obstacle_canvas()
    img = shadow(img, 32, 48, 18, 7)
    d = ImageDraw.Draw(img)
    if era == "ediacaran":
        # Bioluminescent mat bubble cluster
        for x, y, r in ((26, 40, 9), (38, 38, 8), (32, 30, 7), (40, 46, 5)):
            blob(d, x, y, r, r, (80, 230, 200, 255))
    elif era == "cambrian":
        # Glassy hexactinellid sponge vase
        d.polygon([(22, 16), (42, 16), (38, 52), (26, 52)], fill=OUTLINE)
        d.polygon([(23, 17), (41, 17), (37, 51), (27, 51)], fill=(180, 240, 255, 255))
        for y in range(20, 50, 4):
            d.line((25, y, 39, y + 2), fill=(120, 200, 230, 255))
            d.line((25, y + 2, 39, y), fill=(120, 200, 230, 255))
    elif era == "ordovician":
        # Glowing calcite crystals
        for x, h, w in ((24, 26, 6), (33, 36, 7), (42, 22, 5)):
            d.polygon([(x - w, 52), (x - w, 52 - h + w), (x, 52 - h), (x + w, 52 - h + w), (x + w, 52)], fill=OUTLINE)
            d.polygon([(x - w + 1, 51), (x - w + 1, 52 - h + w), (x, 53 - h), (x + w - 1, 52 - h + w), (x + w - 1, 51)], fill=(150, 210, 255, 255))
            d.line((x, 53 - h, x, 51), fill=(230, 250, 255, 255))
    elif era == "carboniferous":
        # Glowing fungus shelf on a root
        d.line((20, 54, 44, 40), fill=OUTLINE, width=6)
        d.line((20, 54, 44, 40), fill=(80, 60, 40, 255), width=4)
        for x, y, r in ((26, 44, 8), (36, 38, 9), (44, 32, 6)):
            d.chord((x - r - 1, y - r - 1, x + r + 1, y + r), 180, 360, fill=OUTLINE)
            d.chord((x - r, y - r, x + r, y + r - 1), 180, 360, fill=(190, 240, 120, 255))
    else:
        # Lava vent: cone with a glowing mouth
        d.polygon([(12, 54), (26, 26), (38, 26), (52, 54)], fill=OUTLINE)
        d.polygon([(14, 53), (27, 27), (37, 27), (50, 53)], fill=(60, 50, 54, 255))
        d.ellipse((25, 23, 39, 31), fill=OUTLINE)
        d.ellipse((26, 24, 38, 30), fill=(255, 150, 60, 255))
        d.line((32, 30, 30, 50), fill=(255, 110, 40, 255))
    return img


def fossil(era, rng):
    """A fossil of an animal from an EARLIER era, half buried."""
    img, d = obstacle_canvas()
    img = shadow(img, 32, 46, 22, 8)
    d = ImageDraw.Draw(img)
    blob(d, 32, 38, 23, 14, {"ediacaran": (80, 100, 90, 255), "cambrian": (150, 130, 110, 255),
                             "ordovician": (120, 130, 150, 255), "carboniferous": (90, 80, 60, 255),
                             "permian": (70, 62, 64, 255)}[era], light=False)
    bone = (230, 220, 190, 255)
    if era in ("ediacaran", "cambrian"):
        # Dickinsonia impression
        d.ellipse((20, 30, 44, 46), outline=bone)
        for k in range(22, 43, 3):
            d.line((k, 32, k, 44), fill=bone)
    elif era == "ordovician":
        # Trilobite
        d.ellipse((26, 26, 38, 34), outline=bone)
        for k in range(6):
            d.line((25, 35 + k * 2, 39, 35 + k * 2), fill=bone)
    else:
        # Ammonoid / nautiloid spiral
        pts = [(32 + math.cos(a) * (10 - a * 0.9), 38 + math.sin(a) * (10 - a * 0.9) * 0.75) for a in np.linspace(0, 10, 50)]
        d.line(pts, fill=bone, width=2)
    return img


SLOTS = {"rock": rock, "tall": tall, "mound": mound, "glow": glow, "fossil": fossil}


def main():
    for i, era in enumerate(ERAS):
        out = os.path.join("assets", "eras", era)
        os.makedirs(out, exist_ok=True)
        make_room(era, 100 + i).save(os.path.join(out, "room.png"))
        rng = np.random.default_rng(200 + i)
        for slot, fn in SLOTS.items():
            fn(era, rng).resize((128, 128), Image.NEAREST).save(os.path.join(out, slot + ".png"))
        print("  wrote", out)


if __name__ == "__main__":
    main()
