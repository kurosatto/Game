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
PERIOD = W - 2 * WALL    # (old layout; see TILE below)

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


# ───────────────────────────── era looks ─────────────────────────────
# One palette per era, shared by the floor, the rim of the room and the
# doors, so every room reads as one painted place. Data/EraLook.gd holds
# the matching in-game colours (light, motes, tint).

SIDE = 96                 # half-res nine-patch side margin (192px in game)
TILE = W - 2 * SIDE       # the floor between the side patches tiles with this period

ERA_LOOK = {
    "ediacaran": {   # quiet teal shallows, pink microbial mats
        "floor": [(0.0, (44, 88, 92)), (0.5, (76, 124, 118)), (1.0, (118, 156, 138))],
        "deep": (10, 28, 38), "outline": (12, 30, 36),
        "rim": [(96, 132, 116), (78, 116, 112), (176, 132, 140)],
        "accent": (222, 140, 152),
    },
    "cambrian": {    # sunlit sand under turquoise water, colourful sponges
        "floor": [(0.0, (70, 110, 116)), (0.5, (128, 150, 136)), (1.0, (196, 188, 150))],
        "deep": (18, 34, 54), "outline": (24, 26, 40),
        "rim": [(190, 150, 108), (150, 96, 140), (212, 128, 84)],
        "accent": (210, 236, 240),
    },
    "ordovician": {  # deep blue reef, pink and cream corals
        "floor": [(0.0, (34, 62, 104)), (0.5, (70, 104, 142)), (1.0, (134, 162, 186))],
        "deep": (10, 16, 42), "outline": (12, 14, 36),
        "rim": [(214, 128, 158), (228, 206, 168), (148, 128, 204)],
        "accent": (236, 150, 180),
    },
    "carboniferous": {  # peat swamp under ferns, golden light
        "floor": [(0.0, (30, 36, 22)), (0.5, (54, 60, 34)), (1.0, (88, 86, 50))],
        "deep": (12, 18, 10), "outline": (14, 18, 10),
        "rim": [(76, 128, 58), (112, 82, 54), (122, 158, 66)],
        "accent": (110, 170, 60),
    },
    "permian": {     # red beds, ash and far-off volcanic glow
        "floor": [(0.0, (84, 50, 44)), (0.5, (132, 86, 66)), (1.0, (178, 136, 102))],
        "deep": (34, 14, 14), "outline": (34, 12, 12),
        "rim": [(172, 92, 62), (110, 92, 90), (214, 150, 96)],
        "accent": (240, 226, 196),
    },
}


def shade_rgb(c, k):
    """k < 1 darkens, k > 1 lightens toward white."""
    if k < 1:
        return tuple(int(v * k) for v in c[:3])
    return tuple(int(v + (255 - v) * (k - 1)) for v in c[:3])


def wrap_x(fn, x, *a):
    """Draw at x and one tile either side, so the tiling floor has no seam."""
    for dx in (-TILE, 0, TILE):
        fn(x + dx, *a)


def voronoi_edges(w, h, n, rng):
    """Distance to the nearest cell edge of a horizontally wrapping Voronoi."""
    pts = np.stack([rng.uniform(0, TILE, n), rng.uniform(0, h, n)], 1)
    pts = np.concatenate([pts + [dx, 0] for dx in (-TILE, 0, TILE, 2 * TILE)]) + [SIDE, 0]
    yy, xx = np.mgrid[0:h, 0:w]
    out = np.zeros((h, w))
    for y0 in range(0, h, 60):
        sub = np.stack([xx[y0:y0 + 60], yy[y0:y0 + 60]], -1).reshape(-1, 1, 2)
        d = np.sqrt(((sub - pts[None]) ** 2).sum(-1))
        d.sort(axis=1)
        out[y0:y0 + 60] = (d[:, 1] - d[:, 0]).reshape(-1, w)
    return out


def paint_floor(era, rng):
    look = ERA_LOOK[era]
    big = fbm(W, H, rng, 150, 4, TILE)
    grain = fbm(W, H, rng, 5, 2, TILE)
    v = big * 0.88 + grain * 0.12
    rgb = palette_map(v, look["floor"])
    yy, xx = np.mgrid[0:H, 0:W]

    if era == "ediacaran":
        # Wrinkled microbial mats ("elephant skin") in pink patches
        patch = np.clip((fbm(W, H, rng, 90, 3, TILE) - 0.5) * 6, 0, 1)
        wr = fbm(W, H, rng, 9, 2, TILE)
        ridge = 1 - np.abs(wr * 2 - 1)
        mat = np.array(look["accent"]) * (0.72 + 0.28 * ridge[..., None])
        rgb = rgb * (1 - patch[..., None] * 0.55) + mat * patch[..., None] * 0.55
    elif era == "cambrian":
        # Ripple marks in the sand
        warp = fbm(W, H, rng, 70, 2, TILE)
        k = 2 * np.pi * round(TILE / 15) / TILE
        rip = np.sin(xx * k + warp * 9 + yy * 0.05)
        rgb *= (1 + 0.045 * rip)[..., None]
    elif era == "ordovician":
        # Soft carbonate mud with lighter shell-sand drifts
        drift = np.clip((fbm(W, H, rng, 60, 3, TILE) - 0.55) * 5, 0, 1)
        rgb = rgb * (1 - drift[..., None] * 0.3) + np.array((176, 196, 210)) * drift[..., None] * 0.3
    elif era == "carboniferous":
        # Dark peat with still puddles that catch the light
        pud = fbm(W, H, rng, 80, 3, TILE)
        water = np.clip((pud - 0.64) * 14, 0, 1)
        edge = np.clip(1 - np.abs(pud - 0.64) * 60, 0, 1)
        rgb = rgb * (1 - water[..., None]) + np.array((40, 70, 64)) * water[..., None]
        rgb += np.array((150, 170, 90)) * (edge * 0.25)[..., None]
        moss = np.clip((fbm(W, H, rng, 40, 3, TILE) - 0.58) * 6, 0, 1) * (1 - water)
        rgb = rgb * (1 - moss[..., None] * 0.4) + np.array((96, 132, 48)) * moss[..., None] * 0.4
    elif era == "permian":
        # Sun-cracked red mud
        e = voronoi_edges(W, H, 70, rng)
        crack = np.clip(1 - e / 1.6, 0, 1)
        curl = np.clip(1 - np.abs(e - 3.0) / 1.5, 0, 1)
        rgb *= (1 - 0.55 * crack)[..., None]
        rgb += np.array((60, 40, 26)) * (curl * 0.35)[..., None]
        ash = np.clip((fbm(W, H, rng, 50, 3, TILE) - 0.55) * 4, 0, 1)
        rgb = rgb * (1 - ash[..., None] * 0.35) + np.array((120, 112, 112)) * ash[..., None] * 0.35

    # A little less saturated than the animals, so they stand out
    lum = rgb.mean(axis=2, keepdims=True)
    rgb = rgb * 0.85 + lum * 0.15
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    floor_marks(era, img, rng)
    return img


def floor_marks(era, img, rng):
    """A few hand-placed details per room: imprints, shells, tracks, litter."""
    d = ImageDraw.Draw(img, "RGBA")
    look = ERA_LOOK[era]
    lo, hi = SIDE, W - SIDE
    top, bot = WALL + 12, H - WALL - 12

    def spot():
        return rng.uniform(lo, hi), rng.uniform(top, bot)

    if era == "ediacaran":
        for _ in range(5):
            x, y = spot()
            rx, ry = rng.uniform(9, 15), rng.uniform(6, 10)

            def dick(x, y, rx=rx, ry=ry):
                d.ellipse((x - rx, y - ry, x + rx, y + ry), fill=(0, 0, 0, 22), outline=(20, 50, 50, 90))
                for k in range(-int(rx) + 2, int(rx) - 1, 3):
                    h = ry * math.sqrt(max(0, 1 - (k / rx) ** 2))
                    d.line((x + k, y - h + 1, x + k, y + h - 1), fill=(20, 50, 50, 70))
                d.line((x - rx + 2, y, x + rx - 2, y), fill=(20, 50, 50, 90))
            wrap_x(dick, x, y)
        for _ in range(3):
            x, y = spot()
            ang = rng.uniform(0, math.tau)

            def frond(x, y, ang=ang):
                for k in range(12):
                    px, py = x + math.cos(ang) * k * 2.2, y + math.sin(ang) * k * 2.2
                    w = 6 * math.sin((k + 1) / 13 * math.pi)
                    for s in (-1, 1):
                        a2 = ang + s * 1.2
                        d.line((px, py, px + math.cos(a2) * w, py + math.sin(a2) * w), fill=(20, 50, 50, 70))
            wrap_x(frond, x, y)
    elif era == "cambrian":
        for _ in range(4):
            # Trilobite trackways (Cruziana): paired chevrons along a curve
            x, y = spot()
            ang = rng.uniform(0, math.tau)
            turn = rng.uniform(-0.04, 0.04)

            def track(x, y, ang=ang, turn=turn):
                a = ang
                for k in range(16):
                    nx, ny = math.cos(a), math.sin(a)
                    px, py = -ny, nx
                    for s in (-1, 1):
                        bx, by = x + px * 3 * s, y + py * 3 * s
                        d.line((bx, by, bx - nx * 2 + px * 2 * s, by - ny * 2 + py * 2 * s), fill=(60, 60, 50, 80))
                    x, y = x + nx * 4, y + ny * 4
                    a += turn
            wrap_x(track, x, y)
        for _ in range(26):
            x, y = spot()
            r = rng.uniform(1.2, 2.6)
            wrap_x(lambda x, y, r=r: d.ellipse((x - r, y - r * 0.7, x + r, y + r * 0.7), fill=(236, 226, 196, 120)), x, y)
    elif era == "ordovician":
        for _ in range(14):
            # Brachiopod valves: ribbed fans
            x, y = spot()
            r = rng.uniform(3, 5.5)
            ang = rng.uniform(0, math.tau)

            def brach(x, y, r=r, ang=ang):
                d.pieslice((x - r, y - r, x + r, y + r), math.degrees(ang), math.degrees(ang) + 180,
                           fill=(200, 210, 220, 110), outline=(40, 60, 90, 120))
                for k in range(1, 6):
                    a = ang + math.pi * k / 6
                    d.line((x, y, x + math.cos(a) * r, y + math.sin(a) * r), fill=(60, 80, 110, 90))
            wrap_x(brach, x, y)
        for _ in range(20):
            # Crinoid ossicles: little discs with a hole
            x, y = spot()
            wrap_x(lambda x, y: (d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(196, 206, 220, 110)),
                                 d.point((x, y), fill=(40, 60, 90, 160))), x, y)
    elif era == "carboniferous":
        for _ in range(8):
            # Fallen fern fronds
            x, y = spot()
            ang = rng.uniform(0, math.tau)
            col = (72 + rng.integers(0, 30), 96 + rng.integers(0, 40), 40, 150)

            def frond(x, y, ang=ang, col=col):
                for k in range(14):
                    px, py = x + math.cos(ang) * k * 2.4, y + math.sin(ang) * k * 2.4
                    w = 5 * math.sin((k + 1) / 15 * math.pi)
                    for s in (-1, 1):
                        a2 = ang + s * 1.1
                        d.line((px, py, px + math.cos(a2) * w, py + math.sin(a2) * w), fill=col)
                d.line((x, y, x + math.cos(ang) * 33, y + math.sin(ang) * 33), fill=(50, 44, 24, 160))
            wrap_x(frond, x, y)
    elif era == "permian":
        for _ in range(3):
            # Weathered bone fragments
            x, y = spot()
            ang = rng.uniform(0, math.tau)
            ln = rng.uniform(7, 12)

            def bone(x, y, ang=ang, ln=ln):
                dx, dy = math.cos(ang) * ln, math.sin(ang) * ln
                d.line((x - dx, y - dy, x + dx, y + dy), fill=(214, 200, 170, 150), width=3)
                for s in (-1, 1):
                    d.ellipse((x + s * dx - 2.5, y + s * dy - 2.5, x + s * dx + 2.5, y + s * dy + 2.5), fill=(214, 200, 170, 150))
            wrap_x(bone, x, y)


# ───────────────────────────── room rim ─────────────────────────────
# The walls are no longer bricks: each era is ringed by what grew or lay
# there, drawn like the animals (dark outline, flat colours, lit top-left).

def irregular(cx, cy, r, rng, squash=0.85, n=11, wobble=0.18):
    pts = []
    ph = rng.uniform(0, math.tau)
    for k in range(n):
        a = ph + k / n * math.tau
        rr = r * (1 + rng.uniform(-wobble, wobble))
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * squash))
    return pts


def scaled(pts, cx, cy, k, dx=0.0, dy=0.0):
    return [(cx + (x - cx) * k + dx, cy + (y - cy) * k + dy) for x, y in pts]


def toon_blob(d, pts, cx, cy, r, col, outline):
    """Outlined shape with a shadowed rim, a lit body and a small highlight."""
    d.polygon(pts, fill=outline + (255,), outline=outline + (255,), width=2)
    d.polygon(scaled(pts, cx, cy, 0.92), fill=shade_rgb(col, 0.68) + (255,))
    d.polygon(scaled(pts, cx, cy, 0.8, -r * 0.1, -r * 0.12), fill=col + (255,))
    d.polygon(scaled(pts, cx, cy, 0.34, -r * 0.3, -r * 0.34), fill=shade_rgb(col, 1.22) + (255,))


def rim_piece(era, d, cx, cy, r, rng, row):
    look = ERA_LOOK[era]
    ol = look["outline"]
    main, second, accent = look["rim"]
    dim = (0.62, 0.8, 1.0)[row]

    def c(col):
        return shade_rgb(col, dim)

    roll = rng.random()
    if era == "ediacaran":
        # Stromatolite domes: layered, some with a pink mat on top
        pts = irregular(cx, cy, r, rng, 0.82, 12, 0.08)
        toon_blob(d, pts, cx, cy, r, c(main if roll < 0.6 else second), ol)
        for k in (0.75, 0.52, 0.3):
            d.arc((cx - r * k, cy - r * k * 0.8, cx + r * k, cy + r * k * 0.8), 200, 340,
                  fill=shade_rgb(c(main), 0.6) + (200,), width=1)
        if roll > 0.55:
            d.ellipse((cx - r * 0.45, cy - r * 0.55, cx + r * 0.25, cy - r * 0.1), fill=c(accent) + (230,))
    elif era == "cambrian":
        if roll < 0.45:
            pts = irregular(cx, cy, r, rng, 0.8, 9, 0.2)
            toon_blob(d, pts, cx, cy, r, c(main), ol)
        else:
            # Sponge tubes seen from above: rings with dark oscula
            col = second if roll < 0.75 else accent
            for k in range(rng.integers(2, 4)):
                tx, ty = cx + rng.uniform(-r * 0.5, r * 0.5), cy + rng.uniform(-r * 0.4, r * 0.4)
                tr = r * rng.uniform(0.45, 0.65)
                pts = irregular(tx, ty, tr, rng, 0.9, 10, 0.06)
                toon_blob(d, pts, tx, ty, tr, c(col), ol)
                d.ellipse((tx - tr * 0.42, ty - tr * 0.42, tx + tr * 0.42, ty + tr * 0.36), fill=ol + (255,))
    elif era == "ordovician":
        col = (main, second, accent)[int(roll * 3)]
        pts = irregular(cx, cy, r, rng, 0.85, 12, 0.1)
        toon_blob(d, pts, cx, cy, r, c(col), ol)
        if col == second:
            # Tabulate coral: honeycomb of corallites
            for _ in range(int(r)):
                a, rr = rng.uniform(0, math.tau), rng.uniform(0, r * 0.7)
                px, py = cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.8
                d.ellipse((px - 1.2, py - 1.2, px + 1.2, py + 1.2), fill=shade_rgb(c(col), 0.7) + (255,))
        else:
            # Brain-like meanders
            for k in range(3):
                yy = cy - r * 0.4 + k * r * 0.35
                d.arc((cx - r * 0.6, yy - r * 0.2, cx + r * 0.6, yy + r * 0.2), 180 + k * 20, 360 - k * 15,
                      fill=shade_rgb(c(col), 0.72) + (255,))
    elif era == "carboniferous":
        if roll < 0.2:
            # Fallen lycopsid log with diamond leaf scars
            ang = rng.uniform(-0.4, 0.4)
            ln = r * 1.5
            dx, dy = math.cos(ang) * ln, math.sin(ang) * ln
            d.line((cx - dx, cy - dy, cx + dx, cy + dy), fill=ol + (255,), width=int(r * 1.1) + 3)
            d.line((cx - dx, cy - dy, cx + dx, cy + dy), fill=c(second) + (255,), width=int(r * 1.1))
            d.line((cx - dx, cy - dy - r * 0.25, cx + dx, cy + dy - r * 0.25), fill=shade_rgb(c(second), 1.2) + (255,), width=max(1, int(r * 0.3)))
            for k in np.linspace(-0.85, 0.85, 7):
                px, py = cx + dx * k, cy + dy * k
                d.polygon([(px, py - 2), (px + 1.5, py), (px, py + 2), (px - 1.5, py)], fill=shade_rgb(c(second), 0.6) + (255,))
        else:
            # Fern clump: fronds fanning out from a crown
            col = main if roll < 0.75 else accent
            n = rng.integers(6, 9)
            for k in range(n):
                a = k / n * math.tau + rng.uniform(-0.2, 0.2)
                ex, ey = cx + math.cos(a) * r * 1.15, cy + math.sin(a) * r * 0.95
                d.line((cx, cy, ex, ey), fill=ol + (255,), width=4)
            for k in range(n):
                a = k / n * math.tau + rng.uniform(-0.2, 0.2)
                ex, ey = cx + math.cos(a) * r * 1.1, cy + math.sin(a) * r * 0.9
                for j in range(1, 8):
                    px, py = cx + (ex - cx) * j / 8, cy + (ey - cy) * j / 8
                    w = r * 0.32 * math.sin(j / 8 * math.pi)
                    for s in (-1, 1):
                        d.line((px, py, px + math.cos(a + s * 1.3) * w, py + math.sin(a + s * 1.3) * w),
                               fill=c(col) + (255,), width=2)
                d.line((cx, cy, ex, ey), fill=shade_rgb(c(col), 1.25) + (255,), width=1)
            d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=c(second) + (255,), outline=ol + (255,))
    elif era == "permian":
        col = main if roll < 0.7 else second
        pts = irregular(cx, cy, r, rng, 0.78, 7, 0.22)
        toon_blob(d, pts, cx, cy, r, c(col), ol)
        # Bedding lines across the red sandstone
        for k in (-0.25, 0.1):
            d.line((cx - r * 0.6, cy + r * k, cx + r * 0.5, cy + r * k + r * 0.08), fill=shade_rgb(c(col), 0.75) + (255,))
        if roll > 0.9:
            d.line((cx - r * 0.3, cy - r * 0.2, cx + r * 0.1, cy + r * 0.25), fill=(255, 140, 60, 255), width=1)


def paint_rim(era, rng):
    """RGBA layer: the ring of rocks/reef/ferns along every wall."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    look = ERA_LOOK[era]
    deep = look["deep"]
    # Solid dark behind the pieces, so gaps read as deep crevices
    d.rectangle((0, 0, W, WALL - 20), fill=deep + (255,))
    d.rectangle((0, H - WALL + 20, W, H), fill=deep + (255,))
    d.rectangle((0, 0, WALL - 20, H), fill=deep + (255,))
    d.rectangle((W - WALL + 20, 0, W, H), fill=deep + (255,))

    pieces = []
    # Rows: back (dim, outer edge) to front (bright, inner edge)
    rows = [(14, (14, 24)), (34, (12, 21)), (54, (8, 15))]
    for row, (depth, (rmin, rmax)) in enumerate(rows):
        # Top and bottom bands run across the tiling middle, so they wrap
        x = SIDE + rng.uniform(0, 10)
        while x < SIDE + TILE:
            r = rng.uniform(rmin, rmax)
            jitter = rng.uniform(-4, 4)
            for band in (0, 1):
                if row == 2 and rng.random() < 0.3:
                    continue
                y = depth + jitter if band == 0 else H - depth - jitter
                if row == 2:
                    y = min(y, WALL + 2 - r * 0.6) if band == 0 else max(y, H - WALL - 2 + r * 0.6)
                seed = int(rng.integers(0, 1 << 30))
                for dx in (-TILE, 0, TILE):
                    if -rmax < x + dx < W + rmax:
                        pieces.append((row, y, x + dx, r, seed))
            x += r * rng.uniform(1.15, 1.45)
        # Left and right bands, the full height
        y = rng.uniform(0, 10)
        while y < H:
            r = rng.uniform(rmin, rmax)
            jitter = rng.uniform(-4, 4)
            for band in (0, 1):
                if row == 2 and rng.random() < 0.3:
                    continue
                x2 = depth + jitter if band == 0 else W - depth - jitter
                if row == 2:
                    x2 = min(x2, WALL + 2 - r * 0.6) if band == 0 else max(x2, W - WALL - 2 + r * 0.6)
                pieces.append((row, y, x2, r, int(rng.integers(0, 1 << 30))))
            y += r * rng.uniform(1.1, 1.4)

    for row, y, x, r, seed in sorted(pieces, key=lambda p: (p[0], p[1])):
        rim_piece(era, d, x, y, r, np.random.default_rng(seed), row)
    return layer


def make_room(era, seed):
    rng = np.random.default_rng(seed)
    look = ERA_LOOK[era]
    floor = paint_floor(era, rng).convert("RGBA")
    rim = paint_rim(era, rng)
    # Soft shadow the rim casts onto the floor (down and to the right)
    alpha = rim.getchannel("A")
    sh = Image.new("L", (W, H), 0)
    sh.paste(alpha, (3, 5))
    sh = sh.filter(ImageFilter.GaussianBlur(7))
    shade = Image.new("RGBA", (W, H), look["deep"] + (0,))
    shade.putalpha(sh.point(lambda v: int(v * 0.7)))
    out = Image.alpha_composite(floor, shade)
    out = Image.alpha_composite(out, rim)
    arr = np.array(out.convert("RGB")).astype(np.float64)
    # The game lights rooms (CanvasModulate, glow), so keep the art a bit low
    arr = (arr / 255.0) ** 1.08 * 255.0 * 0.72
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).resize((W * 2, H * 2), Image.NEAREST)


# ───────────────────────────── doors ─────────────────────────────
# 64px half-res, up = out of the room. A gap in the rim with rocks either
# side; closed doors are grown over, locked ones carry a golden shell seal.

def door_frame(era, rng, state):
    look = ERA_LOOK[era]
    ol = look["outline"]
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    floor_mid = look["floor"][1][1]
    # Passage: lit floor at the room edge, deep in the middle, a glimmer beyond
    for y in range(64):
        t = y / 63
        k = np.clip((t - 0.25) / 0.75, 0, 1)
        col = np.array(look["deep"]) * (1 - k) + np.array(floor_mid) * k * 0.9
        if state == "open" and y < 14:
            col = col + np.array(shade_rgb(floor_mid, 1.3)) * (1 - y / 14) * 0.5
        d.line((14, y, 50, y), fill=tuple(int(v) for v in col) + (255,))
    if state != "open":
        barrier(era, d, rng, look)
    # Flanking pieces, back to front
    for (x, y, r) in ((8, 14, 13), (56, 14, 13), (6, 38, 14), (58, 38, 14), (10, 58, 9), (54, 58, 9)):
        rim_piece(era, d, x, y, r, np.random.default_rng(int(x * 31 + y)), 2 if y > 30 else 1)
    if state == "locked":
        seal(d)
    return img.resize((128, 128), Image.NEAREST)


def barrier(era, d, rng, look):
    ol = look["outline"]
    if era in ("ediacaran", "cambrian", "ordovician"):
        # Living lattice across the gap: mat, glass sponge or bryozoan mesh
        col = {"ediacaran": look["rim"][2], "cambrian": look["accent"], "ordovician": look["rim"][0]}[era]
        d.rectangle((14, 16, 50, 52), fill=shade_rgb(col, 0.45) + (220,))
        for k in range(-40, 60, 6):
            d.line((14 + k, 16, 14 + k + 36, 52), fill=ol + (255,), width=3)
            d.line((50 - k, 16, 50 - k - 36, 52), fill=ol + (255,), width=3)
        for k in range(-40, 60, 6):
            d.line((14 + k, 16, 14 + k + 36, 52), fill=col + (255,), width=1)
            d.line((50 - k, 16, 50 - k - 36, 52), fill=col + (255,), width=1)
        d.rectangle((0, 0, 13, 64), fill=(0, 0, 0, 0))
        d.rectangle((51, 0, 64, 64), fill=(0, 0, 0, 0))
    elif era == "carboniferous":
        # Fern fronds grown across
        for k, y in enumerate((20, 30, 40, 50)):
            sgn = 1 if k % 2 else -1
            x0, x1 = (12, 52) if sgn > 0 else (52, 12)
            d.line((x0, y, x1, y + 3), fill=ol + (255,), width=4)
            for j in range(1, 10):
                px = x0 + (x1 - x0) * j / 10
                py = y + 3 * j / 10
                for s in (-1, 1):
                    d.line((px, py, px - sgn * 3, py + s * 5), fill=look["rim"][0] + (255,), width=2)
            d.line((x0, y, x1, y + 3), fill=shade_rgb(look["rim"][0], 1.25) + (255,), width=1)
    else:
        # Rockfall
        for (x, y, r) in ((22, 24, 9), (40, 22, 10), (31, 36, 11), (20, 48, 9), (44, 46, 9)):
            rim_piece(era, d, x, y, r, np.random.default_rng(x * 7 + y), 2)


def seal(d):
    """Golden nautiloid shell set into the barrier."""
    gold, dark = (240, 196, 80), (90, 56, 10)
    d.ellipse((20, 22, 44, 46), fill=dark + (255,))
    d.ellipse((22, 24, 42, 44), fill=gold + (255,))
    d.ellipse((24, 25, 34, 33), fill=(255, 236, 160, 255))
    pts = [(32 + math.cos(a) * (9 - a * 0.7), 34 + math.sin(a) * (9 - a * 0.7)) for a in np.linspace(0, 11, 40)]
    d.line(pts, fill=dark + (255,), width=1)


# ───────────────────────── drifting shadows ─────────────────────────
# Something big passing overhead, cast on the floor (Room.gd moves it).

def silhouette(era, rng, size):
    """Top-down outline of the era's big passer-by, head pointing up."""
    a = Image.new("L", (size, size), 0)
    dd = ImageDraw.Draw(a)
    c = size / 2
    if era == "cambrian":
        # Anomalocaris: flap-lined body, frontal appendages, tail fan
        for k in range(11):
            y = c - 44 + k * 7
            w = 26 - abs(k - 3) * 1.6
            dd.ellipse((c - w, y - 4, c + w, y + 5), fill=255)
            dd.ellipse((c - 10, y - 5, c + 10, y + 6), fill=255)
        dd.ellipse((c - 12, c - 58, c + 12, c - 36), fill=255)
        for s in (-1, 1):
            pts = [(c + s * 6, c - 54), (c + s * 16, c - 70), (c + s * 12, c - 80), (c + s * 4, c - 76)]
            dd.line(pts, fill=255, width=5)
            for side in (-1, 1):
                dd.polygon([(c, c + 30), (c + side * 22, c + 52), (c + side * 8, c + 56)], fill=255)
    elif era == "ordovician":
        # Orthocone nautiloid: long straight shell, tentacles forward
        dd.polygon([(c - 13, c - 40), (c + 13, c - 40), (c + 3, c + 70), (c - 3, c + 70)], fill=255)
        dd.ellipse((c - 13, c - 50, c + 13, c - 30), fill=255)
        for k in range(8):
            ang = -math.pi / 2 + (k - 3.5) * 0.12
            dd.line((c, c - 44, c + math.cos(ang) * 34, c - 44 + math.sin(ang) * 30), fill=255, width=3)
    elif era == "carboniferous":
        # Meganeura: griffinfly with two pairs of long wings
        dd.line((c, c - 30, c, c + 60), fill=255, width=6)
        dd.ellipse((c - 9, c - 44, c + 9, c - 26), fill=255)
        dd.ellipse((c - 7, c - 30, c + 7, c - 4), fill=255)
        for s in (-1, 1):
            dd.ellipse((c + s * 4 - (64 if s < 0 else 0), c - 26, c + s * 4 + (64 if s > 0 else 0), c - 12), fill=255)
            dd.ellipse((c + s * 4 - (58 if s < 0 else 0), c - 8, c + s * 4 + (58 if s > 0 else 0), c + 6), fill=255)
    else:
        # Clouds (Permian sky) or a drifting raft of plankton (Ediacaran)
        for _ in range(9):
            x, y = rng.uniform(c - 40, c + 40), rng.uniform(c - 25, c + 25)
            r = rng.uniform(16, 30)
            dd.ellipse((x - r, y - r * 0.7, x + r, y + r * 0.7), fill=255)
    return a


def make_shadow(era, rng):
    size = 180
    a = silhouette(era, rng, size)
    a = a.filter(ImageFilter.GaussianBlur(5))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.putalpha(a)
    return out

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
        for state in ("open", "closed", "locked"):
            door_frame(era, np.random.default_rng(300 + i), state).save(os.path.join(out, "door_%s.png" % state))
        make_shadow(era, np.random.default_rng(400 + i)).save(os.path.join(out, "shadow.png"))
        print("  wrote", out)


if __name__ == "__main__":
    main()
