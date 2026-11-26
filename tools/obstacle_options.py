"""Mock-up overlays for other border/obstacle designs (kuro, 2026-11-26).

Reads <dir>/room_era<N>.json (from tools/obstacleoptions.gd OPTS=dump) and
writes <dir>/overlays/<opt>_era<N>.png: a full 1920x1080 room (floor, border,
obstacles) in raw colours. The game's ink filter turns it into sepia ink.

    python3 tools/obstacle_options.py <dir> [eras...]
"""
import json
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

W, H = 1920, 1080
SS = 2  # drawn at 2x, scaled down
WALL = 128
THEMES = {
    "cambrian": ((0.38, 0.30, 0.22), (0.82, 0.73, 0.58)),
    "carboniferous": ((0.28, 0.31, 0.20), (0.68, 0.70, 0.52)),
    "ordovician": ((0.26, 0.30, 0.36), (0.69, 0.73, 0.78)),
    "ediacaran": ((0.29, 0.33, 0.29), (0.72, 0.75, 0.66)),
    "permian": ((0.40, 0.24, 0.18), (0.83, 0.67, 0.55)),
}

BASE = dict(THEMES)
INK_K = {"carboniferous": 0.45, "ediacaran": 0.7}


def rgb(c, k=1.0):
    return tuple(int(max(0, min(1, v * k)) * 255) for v in c)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def noise1(seed):
    """Smooth 1D periodic noise on [0, 1)."""
    r = random.Random(seed)
    waves = [(r.randint(2, 9), r.uniform(0, math.tau), r.uniform(0.3, 1.0)) for _ in range(5)]
    tot = sum(w[2] for w in waves)

    def f(t):
        return sum(a * math.sin(k * math.tau * t + p) for k, p, a in waves) / tot
    return f


def blob(cx, cy, a, b, seed, rough=0.18, n=48):
    f = noise1(seed)
    return [(cx + math.cos(t) * a * (1 + rough * f(i / n)), cy + math.sin(t) * b * (1 + rough * f(i / n)))
            for i in range(n) for t in [math.tau * i / n]]


def S(pts):
    return [(x * SS, y * SS) for x, y in pts]


def wobble_line(d, pts, fill, width, seed, amp=1.2, closed=False):
    r = random.Random(seed)
    out = []
    for i, (x, y) in enumerate(pts):
        out.append((x + r.uniform(-amp, amp), y + r.uniform(-amp, amp)))
    if closed:
        out.append(out[0])
    d.line(S(out), fill=fill, width=int(width * SS), joint="curve")


def floor_image(era):
    room = Image.open(f"assets/eras/{era}/room.png").convert("RGB")
    return room.crop((150, 120, 1770, 960)).resize((W, H), Image.BICUBIC)


def hatch(size, spacing, angle, width, color, seed=0, jitter=1.0):
    """A layer of slightly wobbly parallel strokes."""
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = random.Random(seed)
    w, h = size
    diag = math.hypot(w, h)
    ca, sa = math.cos(angle), math.sin(angle)
    k = -diag
    while k < diag:
        x0, y0 = w / 2 + (-sa) * k - ca * diag, h / 2 + ca * k - sa * diag
        x1, y1 = w / 2 + (-sa) * k + ca * diag, h / 2 + ca * k + sa * diag
        j = r.uniform(-jitter, jitter) * spacing * 0.2
        d.line([(x0 + -sa * j, y0 + ca * j), (x1 + -sa * j, y1 + ca * j)], fill=color, width=width)
        k += spacing * r.uniform(0.85, 1.15)
    return im


def paste_masked(base, layer, mask):
    a = ImageChops.multiply(layer.split()[3], mask)
    base.paste(layer, (0, 0), a)


def door_gap(doors, x, y, r=110):
    return any(math.hypot(x - dx, y - dy) < r for dx, dy in doors)


def edge_dist(x, y):
    return min(x - WALL, W - WALL - x, y - WALL, H - WALL - y)


# ---------------------------------------------------------------------------
# A. Living reef: the room is ringed by growing reef (stromatolite heads and
# sponge cups seen from above), and obstacles are reef patches of the same.
def dome(d, cx, cy, r, dark, pale, seed, rings=True):
    pts = blob(cx, cy, r, r * 0.92, seed, 0.12, 36)
    d.polygon(S(pts), fill=rgb(mix(dark, pale, 0.55)))
    # lit upper-left cap
    cap = blob(cx - r * 0.18, cy - r * 0.2, r * 0.68, r * 0.6, seed + 1, 0.1, 30)
    d.polygon(S(cap), fill=rgb(mix(dark, pale, 0.95)))
    if rings:
        for k in (0.72, 0.46, 0.22):
            ring = blob(cx - r * 0.06 * (1 - k), cy - r * 0.08 * (1 - k), r * k, r * k * 0.9, seed + int(k * 100), 0.15, 30)
            wobble_line(d, ring, rgb(dark, 0.95), 1.1, seed + 7, 0.5, True)
    wobble_line(d, pts, rgb(dark, 0.55), 2.4, seed + 3, 0.7, True)


def cup(d, cx, cy, r, dark, pale, seed):
    pts = blob(cx, cy, r, r, seed, 0.08, 28)
    d.polygon(S(pts), fill=rgb(mix(dark, pale, 0.85)))
    inner = blob(cx + r * 0.08, cy + r * 0.1, r * 0.55, r * 0.55, seed + 1, 0.1, 24)
    d.polygon(S(inner), fill=rgb(dark, 0.6))
    # radial septa of an archaeocyath cup
    for i in range(10):
        t = math.tau * i / 10
        d.line(S([(cx + math.cos(t) * r * 0.58, cy + math.sin(t) * r * 0.58),
                  (cx + math.cos(t) * r * 0.95, cy + math.sin(t) * r * 0.95)]), fill=rgb(dark, 0.8), width=SS)
    wobble_line(d, pts, rgb(dark, 0.55), 2.2, seed + 3, 0.6, True)


def reef_cluster(d, items, dark, pale):
    items.sort(key=lambda it: it[1])
    for kind, cx, cy, r, seed in items:
        if kind == "cup":
            cup(d, cx, cy, r, dark, pale, seed)
        else:
            dome(d, cx, cy, r, dark, pale, seed)


def option_reef(era, data, floor):
    dark, pale = THEMES[era]
    im = Image.new("RGB", (W * SS, H * SS))
    im.paste(floor.resize((W * SS, H * SS)))
    d = ImageDraw.Draw(im)
    r = random.Random(4)
    doors = data["doors"]
    # dark crevices behind the reef
    band = Image.new("L", (W * SS, H * SS), 0)
    bd = ImageDraw.Draw(band)
    bd.rectangle([0, 0, W * SS, H * SS], fill=255)
    f = noise1(9)
    inner = []
    n = 160
    for i in range(n):
        t = i / n
        # walk round the room's inner rectangle
        per = 2 * (W - 2 * WALL) + 2 * (H - 2 * WALL)
        s = t * per
        if s < W - 2 * WALL:
            x, y, nx, ny = WALL + s, WALL, 0, 1
        elif s < W - 2 * WALL + H - 2 * WALL:
            x, y, nx, ny = W - WALL, WALL + s - (W - 2 * WALL), -1, 0
        elif s < 2 * (W - 2 * WALL) + H - 2 * WALL:
            x, y, nx, ny = W - WALL - (s - (W - 2 * WALL) - (H - 2 * WALL)), H - WALL, 0, -1
        else:
            x, y, nx, ny = WALL, H - WALL - (s - 2 * (W - 2 * WALL) - (H - 2 * WALL)), 1, 0
        off = -10 + 22 * f(t)
        if door_gap(doors, x, y, 120):
            off = -70
        inner.append((x + nx * off, y + ny * off))
    bd.polygon(S(inner), fill=0)
    band = band.filter(ImageFilter.GaussianBlur(10 * SS))
    shade = Image.new("RGB", im.size, rgb(dark, 0.45))
    im.paste(shade, (0, 0), band)
    d = ImageDraw.Draw(im)
    # reef along the edges: back rows first, smaller toward the floor
    items = []
    for _ in range(9000):
        x, y = r.uniform(-20, W + 20), r.uniform(-20, H + 20)
        e = edge_dist(x, y) + 18 * f(math.atan2(y - H / 2, x - W / 2) / math.tau % 1)
        if e > 26 or e < -150 or door_gap(doors, x, y, 105):
            continue
        rad = r.uniform(22, 40) if e < -50 else r.uniform(12, 24)
        if any(math.hypot(x - ix, y - iy) < (rad + ir) * 0.8 for _, ix, iy, ir, _ in items):
            continue
        items.append(("cup" if r.random() < 0.3 else "dome", x, y, rad, r.randint(0, 9999)))
    reef_cluster(d, items, dark, pale)
    # door mouths: a few small heads flanking
    # obstacles become reef patches
    for o in data["obstacles"]:
        rr = random.Random(int(o["x"] * 7 + o["y"]))
        patch = []
        a, b = o["a"] + 10, o["b"] + 10
        for _ in range(60):
            t, k = rr.uniform(0, math.tau), math.sqrt(rr.random())
            x, y = o["x"] + math.cos(t) * a * k, o["y"] + math.sin(t) * b * k
            rad = rr.uniform(10, 22) * (1.25 - 0.5 * k)
            if any(math.hypot(x - ix, y - iy) < (rad + ir) * 0.75 for _, ix, iy, ir, _ in patch):
                continue
            patch.append(("cup" if rr.random() < 0.25 else "dome", x, y, rad, rr.randint(0, 9999)))
        reef_cluster(d, patch, dark, pale)
    return im.resize((W, H), Image.LANCZOS)


# ---------------------------------------------------------------------------
# B. Relief map: the floor is a basin. Its sides rise in contour lines and
# downhill hachures, and obstacles are knolls drawn the same way.
def rounded_ring(off, seed, doors):
    f = noise1(seed)
    pts = []
    n = 220
    x0, y0, x1, y1 = WALL - off, WALL - off, W - WALL + off, H - WALL + off
    rad = 60 + off * 0.3
    per = 2 * (x1 - x0) + 2 * (y1 - y0)
    for i in range(n):
        s = per * i / n
        if s < x1 - x0:
            x, y, nx, ny = x0 + s, y0, 0, -1
        elif s < (x1 - x0) + (y1 - y0):
            x, y, nx, ny = x1, y0 + s - (x1 - x0), 1, 0
        elif s < 2 * (x1 - x0) + (y1 - y0):
            x, y, nx, ny = x1 - (s - (x1 - x0) - (y1 - y0)), y1, 0, 1
        else:
            x, y, nx, ny = x0, y1 - (s - 2 * (x1 - x0) - (y1 - y0)), -1, 0
        # round the corners
        cx = min(max(x, x0 + rad), x1 - rad)
        cy = min(max(y, y0 + rad), y1 - rad)
        if (cx, cy) != (x, y) and abs(cx - x) > 0 and abs(cy - y) > 0:
            ang = math.atan2(y - cy, x - cx)
            x, y = cx + math.cos(ang) * rad, cy + math.sin(ang) * rad
        w = 14 * f(i / n)
        # valleys run out through the doors
        for dx, dy in doors:
            dd = math.hypot(x - dx, y - dy)
            if dd < 340:
                q = 1 - dd / 340
                w -= (off + 40) * (q * q * (3 - 2 * q)) * 1.1
        pts.append((x + nx * w, y + ny * w))
    return pts


def option_contour(era, data, floor):
    dark, pale = THEMES[era]
    im = Image.new("RGB", (W * SS, H * SS))
    im.paste(floor.resize((W * SS, H * SS)))
    doors = data["doors"]
    # tone deepens up the slope
    tone = Image.new("L", (W * SS, H * SS), 0)
    td = ImageDraw.Draw(tone)
    rings = [-20, 0, 18, 34, 48, 60, 72, 84, 96, 110, 126, 146, 170]
    for k, off in enumerate(rings):
        td.polygon(S(rounded_ring(off, 3, doors)), fill=0)
    td.rectangle([0, 0, W * SS, H * SS], fill=255)
    td.polygon(S(rounded_ring(-30, 3, doors)), fill=0)
    tone = tone.filter(ImageFilter.GaussianBlur(60 * SS))
    im.paste(Image.new("RGB", im.size, rgb(dark, 0.8)), (0, 0), tone.point(lambda v: int(v * 0.75)))
    d = ImageDraw.Draw(im)
    # hachures: short strokes running downhill between the contours
    r = random.Random(5)
    for k in range(len(rings) - 1):
        a_pts = rounded_ring(rings[k], 3, doors)
        b_pts = rounded_ring(rings[k + 1], 3, doors)
        for i in range(0, len(a_pts), 1):
            if r.random() < 0.15:
                continue
            ax, ay = a_pts[i]
            bx, by = b_pts[i]
            t0, t1 = r.uniform(0.0, 0.15), r.uniform(0.75, 1.0)
            d.line(S([(ax + (bx - ax) * t0, ay + (by - ay) * t0), (ax + (bx - ax) * t1, ay + (by - ay) * t1)]),
                   fill=rgb(dark, 0.7), width=int(1.2 * SS))
    for k, off in enumerate(rings):
        wobble_line(d, rounded_ring(off, 3, doors), rgb(dark, 0.5 if k % 4 == 1 else 0.75),
                    2.6 if k % 4 == 1 else 1.3, k, 0.6, True)
    # knolls
    for o in data["obstacles"]:
        seed = int(o["x"] * 3 + o["y"])
        a, b = o["a"] + 6, o["b"] + 6
        cx, cy = o["x"], o["y"]
        levels = [1.0, 0.68, 0.38]
        # soft shade on the lower-right flank
        sh = Image.new("L", im.size, 0)
        ImageDraw.Draw(sh).polygon(S(blob(cx + a * 0.25, cy + b * 0.25, a * 0.9, b * 0.9, seed, 0.15)), fill=150)
        sh = sh.filter(ImageFilter.GaussianBlur(8 * SS))
        cut = Image.new("L", im.size, 0)
        ImageDraw.Draw(cut).polygon(S(blob(cx, cy, a, b, seed, 0.15)), fill=255)
        im.paste(Image.new("RGB", im.size, rgb(dark, 0.8)), (0, 0), ImageChops.multiply(sh, cut))
        d = ImageDraw.Draw(im)
        prev = None
        for k, lv in enumerate(levels):
            pts = blob(cx - a * 0.12 * (1 - lv), cy - b * 0.15 * (1 - lv), a * lv, b * lv, seed, 0.15)
            if prev:
                for i in range(0, len(pts), 2):
                    px, py = prev[i]
                    qx, qy = pts[i]
                    d.line(S([(qx, qy), (qx + (px - qx) * 0.85, qy + (py - qy) * 0.85)]), fill=rgb(dark, 0.5), width=int(1.5 * SS))
            prev = pts
        for k, lv in enumerate(levels):
            pts = blob(cx - a * 0.12 * (1 - lv), cy - b * 0.15 * (1 - lv), a * lv, b * lv, seed, 0.15)
            wobble_line(d, pts, rgb(dark, 0.4 if k == 0 else 0.5), 2.6 if k == 0 else 1.8, seed + k, 0.5, True)
        # summit spot
        d.ellipse(S([(cx - a * 0.12 - 2, cy - b * 0.15 - 2), (cx - a * 0.12 + 2, cy - b * 0.15 + 2)]), fill=rgb(dark, 0.4))
    return im.resize((W, H), Image.LANCZOS)


# ---------------------------------------------------------------------------
# C. Into the dark: no wall is drawn. The floor thins into deep water/night
# at the edges, and obstacles are hollows (burrows, sink pits) you go round.
def option_dark(era, data, floor):
    dark, pale = THEMES[era]
    im = Image.new("RGB", (W * SS, H * SS))
    im.paste(floor.resize((W * SS, H * SS)))
    doors = data["doors"]
    f = noise1(21)
    g = noise1(22)
    # edge darkness, ragged and soft
    m = Image.new("L", (W, H), 0)
    px = m.load()
    for y in range(0, H):
        for x in range(0, W):
            e = edge_dist(x, y)
            t = math.atan2(y - H / 2, x - W / 2) / math.tau
            e += 26 * f(t) + 10 * g((x + y) / 900.0 % 1)
            for dx, dy in doors:
                dd = math.hypot(x - dx, y - dy)
                if dd < 150:
                    e += 90 * (1 - dd / 150)
            v = 1 - (e + 40) / 150.0
            px[x, y] = int(255 * max(0, min(1, v)) ** 1.3)
    m = m.filter(ImageFilter.GaussianBlur(6)).resize(im.size)
    im.paste(Image.new("RGB", im.size, rgb(dark, 0.12)), (0, 0), m)
    d = ImageDraw.Draw(im)
    # loose specks drifting at the edge of sight
    r = random.Random(3)
    for _ in range(900):
        x, y = r.uniform(0, W), r.uniform(0, H)
        e = edge_dist(x, y)
        if -40 < e < 90 and r.random() < 0.6:
            s = r.uniform(0.8, 2.2)
            d.ellipse(S([(x - s, y - s), (x + s, y + s)]), fill=rgb(dark, 0.4))
    # door mouths: a faint lit tongue of floor
    # hollows
    for o in data["obstacles"]:
        seed = int(o["x"] * 5 + o["y"])
        cx, cy, a, b = o["x"], o["y"], o["a"] + 8, o["b"] + 6
        rr = random.Random(seed)
        # lip of piled sediment, lit on top
        lip = blob(cx, cy - 2, a + 12, b + 10, seed, 0.14)
        d.polygon(S(lip), fill=rgb(mix(dark, pale, 1.05)))
        hole = Image.new("L", im.size, 0)
        hd = ImageDraw.Draw(hole)
        for k in range(10):
            s = 1 - k * 0.07
            hd.polygon(S(blob(cx + a * 0.08 * k / 10, cy + b * 0.12 * k / 10, a * s, b * s, seed, 0.14)), fill=110 + k * 14)
        hole = hole.filter(ImageFilter.GaussianBlur(3 * SS))
        im.paste(Image.new("RGB", im.size, rgb(dark, 0.04)), (0, 0), hole)
        d = ImageDraw.Draw(im)
        wobble_line(d, blob(cx, cy, a, b, seed, 0.14), rgb(dark, 0.35), 2.2, seed, 0.6, True)
        # radial scratch lines down the inner wall (upper lip only)
        for i in range(14):
            t = math.pi + rr.uniform(0.1, math.pi - 0.1)
            x0, y0 = cx + math.cos(t) * a * 0.98, cy + math.sin(t) * b * 0.98
            x1, y1 = cx + math.cos(t) * a * 0.7, cy + math.sin(t) * b * 0.62
            d.line(S([(x0, y0), (x1, y1)]), fill=rgb(dark, 0.3), width=SS)
        # a few grains on the lip
        for i in range(10):
            t = rr.uniform(0, math.tau)
            x, y = cx + math.cos(t) * (a + rr.uniform(4, 12)), cy + math.sin(t) * (b + rr.uniform(3, 10))
            s = rr.uniform(1.5, 3)
            d.ellipse(S([(x - s, y - s), (x + s, y + s)]), outline=rgb(dark, 0.5), width=SS)
    return im.resize((W, H), Image.LANCZOS)


# ---------------------------------------------------------------------------
# D. Field notebook plate: the room is a sheet with a ruled plate border;
# obstacles are light specimen sketches (fine line and stipple, no dark fill).
def stipple_blob(d, cx, cy, a, b, seed, dark, density=0.5):
    rr = random.Random(seed)
    n = int(a * b * density)
    for _ in range(n):
        t, k = rr.uniform(0, math.tau), math.sqrt(rr.random())
        x, y = math.cos(t) * k, math.sin(t) * k
        # denser on the shaded lower right
        if rr.random() > 0.15 + 0.85 * max(0, (x + y) * 0.7 + 0.3):
            continue
        s = rr.uniform(0.7, 1.4)
        px, py = cx + x * a, cy + y * b
        d.ellipse(S([(px - s, py - s), (px + s, py + s)]), fill=rgb(dark, 0.45))


def option_plate(era, data, floor):
    dark, pale = THEMES[era]
    im = Image.new("RGB", (W * SS, H * SS))
    # paper sheet, lighter than the sea floor, on a dark ground
    im.paste(Image.new("RGB", im.size, rgb(dark, 0.3)))
    fl = floor.resize((W * SS, H * SS))
    sheet = Image.new("L", im.size, 0)
    f = noise1(31)
    pts = []
    n = 400
    x0, y0, x1, y1 = 64, 60, W - 64, H - 60
    per = 2 * (x1 - x0) + 2 * (y1 - y0)
    r = random.Random(8)
    for i in range(n):
        s = per * i / n
        if s < x1 - x0:
            x, y = x0 + s, y0
        elif s < (x1 - x0) + (y1 - y0):
            x, y = x1, y0 + s - (x1 - x0)
        elif s < 2 * (x1 - x0) + (y1 - y0):
            x, y = x1 - (s - (x1 - x0) - (y1 - y0)), y1
        else:
            x, y = x0, y1 - (s - 2 * (x1 - x0) - (y1 - y0))
        pts.append((x + r.uniform(-3, 3) + 4 * f(i / n), y + r.uniform(-3, 3) + 4 * f(i / n + 0.3)))
    ImageDraw.Draw(sheet).polygon(S(pts), fill=255)
    im.paste(fl.point(lambda v: min(255, int(v * 1.12))), (0, 0), sheet)
    d = ImageDraw.Draw(im)
    wobble_line(d, pts, rgb(dark, 0.5), 1.6, 1, 0.4, True)
    doors = data["doors"]

    def framed(off, width, col, seed):
        x0, y0, x1, y1 = WALL - off, WALL - off, W - WALL + off, H - WALL + off
        segs = [((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))]
        for (ax, ay), (bx, by) in segs:
            # break the rule where a door opens
            steps = 120
            run = []
            for i in range(steps + 1):
                x, y = ax + (bx - ax) * i / steps, ay + (by - ay) * i / steps
                if door_gap(doors, x, y, 90):
                    if len(run) > 1:
                        wobble_line(d, run, col, width, seed + i, 0.5)
                    run = []
                else:
                    run.append((x, y))
            if len(run) > 1:
                wobble_line(d, run, col, width, seed + 99, 0.5)
    framed(8, 3.2, rgb(dark, 0.4), 1)
    framed(20, 1.2, rgb(dark, 0.55), 2)
    # corner fleurons: little ammonite-like spirals
    for cx, cy in [(WALL + 14, WALL + 14), (W - WALL - 14, WALL + 14), (WALL + 14, H - WALL - 14), (W - WALL - 14, H - WALL - 14)]:
        sp = [(cx + math.cos(t) * t * 1.4, cy + math.sin(t) * t * 1.4) for t in [i * 0.25 for i in range(40)]]
        wobble_line(d, sp, rgb(dark, 0.45), 1.6, 3, 0.2)
    # door mouths: small ruled notches
    for dx, dy in doors:
        horiz = abs(dy - 540) > 200
        for s in (-1, 1):
            if horiz:
                x = dx + s * 90
                d.line(S([(x, dy - 40), (x, dy + 40)]), fill=rgb(dark, 0.45), width=int(2.4 * SS))
            else:
                y = dy + s * 90
                d.line(S([(dx - 40, y), (dx + 40, y)]), fill=rgb(dark, 0.45), width=int(2.4 * SS))
    # specimens: outline + contour lines + stipple, no fill
    for o in data["obstacles"]:
        seed = int(o["x"] * 11 + o["y"])
        cx, cy, a, b = o["x"], o["y"], o["a"] + 6, o["b"] + 6
        stipple_blob(d, cx, cy, a, b, seed, dark, 0.35)
        rr = random.Random(seed)
        for k in range(4):
            lv = 0.85 - k * 0.2
            arc = [(cx + math.cos(t) * a * lv - a * 0.1, cy + math.sin(t) * b * lv - b * 0.1)
                   for t in [math.pi * 0.15 + i * 0.12 for i in range(int(rr.uniform(8, 16)))]]
            wobble_line(d, arc, rgb(dark, 0.6), 1.0, seed + k, 0.4)
        wobble_line(d, blob(cx, cy, a, b, seed, 0.16), rgb(dark, 0.4), 2.0, seed, 0.6, True)
        # a few base grains
        for i in range(6):
            t = rr.uniform(0.1, math.pi - 0.1)
            x, y = cx + math.cos(t) * (a + rr.uniform(6, 14)), cy + math.sin(t) * (b + rr.uniform(4, 10))
            s = rr.uniform(1.5, 3)
            d.ellipse(S([(x - s, y - s), (x + s, y + s)]), outline=rgb(dark, 0.5), width=SS)
    return im.resize((W, H), Image.LANCZOS)


OPTIONS = {"reef": option_reef, "contour": option_contour, "dark": option_dark, "plate": option_plate}

if __name__ == "__main__":
    base = sys.argv[1]
    eras = [int(e) for e in sys.argv[2:]] or [2, 4]
    os.makedirs(base + "/overlays", exist_ok=True)
    only = os.environ.get("OPTS", "").split(",") if os.environ.get("OPTS") else list(OPTIONS)
    for n in eras:
        data = json.load(open(f"{base}/room_era{n}.json"))
        era = data["era"].rstrip("/").split("/")[-1]
        # pale floors (Carboniferous) need darker ink to read through the filter
        k = INK_K.get(era, 1.0)
        THEMES[era] = (tuple(v * k for v in BASE[era][0]), BASE[era][1])
        floor = floor_image(era)
        # pebble banks between pieces become small pieces of the same kind
        for ax, ay, bx, by in data["rubble"]:
            data["obstacles"].append({"x": (ax + bx) / 2, "y": (ay + by) / 2, "a": math.hypot(bx - ax, by - ay) / 2 + 8,
                                      "b": 18, "type": "rubble"})
        for name in only:
            OPTIONS[name](era, data, floor).save(f"{base}/overlays/{name}_era{n}.png")
            print("wrote", name, n)
