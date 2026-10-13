"""Pixel-art sprite sheets for the player's lineages (data/Lineages.gd ids).

Same chunky style as generate_fauna_art.py: drawn top-down, head facing up,
4 animation frames, at half resolution then scaled 2x into 128px frames.
Each sheet gets a faint cyan halo so the player always reads as the player.
Player.update_creature_visuals loads assets/lineages/<id>_sheet.png.

Anatomy notes are kept next to each drawing (segment, limb and arm counts,
symmetry) because players who know their taxonomy will check.

Run from the project root:  python generate_lineage_art.py [id ...]
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

from generate_fauna_art import OUTLINE, Canvas, shade

OUT = "assets/lineages"
FRAME = 128
FRAMES = 4
HALO = (60, 230, 255)
TAU = 2 * math.pi


# Drawings use a unit box of DRAW_S half-res pixels; long animals poke out of
# it a little, so it is inset by MARGIN inside the 64px half-res frame.
DRAW_S = 50
MARGIN = 7


class Shift:
    """ImageDraw wrapper that offsets every coordinate by `off`."""
    def __init__(self, draw, off):
        self._d, self._o = draw, off

    def _xy(self, xy):
        o = self._o
        if isinstance(xy, tuple) and len(xy) == 4 and all(isinstance(v, (int, float)) for v in xy):
            return (xy[0] + o, xy[1] + o, xy[2] + o, xy[3] + o)
        if isinstance(xy, tuple) and len(xy) == 2 and all(isinstance(v, (int, float)) for v in xy):
            return (xy[0] + o, xy[1] + o)
        return [(x + o, y + o) for x, y in xy]

    def __getattr__(self, name):
        fn = getattr(self._d, name)
        def call(xy, *a, **k):
            return fn(self._xy(xy), *a, **k)
        return call


class ShiftedCanvas(Canvas):
    def __init__(self, size, off):
        self.off = off
        super().__init__(size)

    @property
    def d(self):
        return self._d

    @d.setter
    def d(self, raw):
        self._d = Shift(raw, self.off)

    def shadow(self, cx, cy, rx, ry):
        super().shadow(cx + self.off, cy + self.off, rx, ry)

    def layer_draw(self, layer):
        return Shift(ImageDraw.Draw(layer), self.off)


def save_sheet(name, draw_fn):
    half = FRAME // 2
    out = Image.new("RGBA", (FRAME * FRAMES, FRAME), (0, 0, 0, 0))
    for f in range(FRAMES):
        c = ShiftedCanvas(half, MARGIN)
        draw_fn(c, f / FRAMES, DRAW_S)
        img = add_halo(c.img)
        out.paste(img.resize((FRAME, FRAME), Image.NEAREST), (f * FRAME, 0))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + "_sheet.png")
    out.save(path)
    print("  wrote", path)


def add_halo(img):
    """Soft cyan glow around the silhouette, drawn underneath it."""
    alpha = img.getchannel("A").point(lambda a: 255 if a > 160 else 0)
    glow = alpha.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.5))
    halo = Image.new("RGBA", img.size, HALO + (0,))
    halo.putalpha(glow.point(lambda a: int(a * 0.45)))
    return Image.alpha_composite(halo, img)


def wave(t, k=0.0):
    return math.sin(t * TAU + k)


# ───────────────────────── shared body plans ─────────────────────────

def legs_pair(c, x, y, side, length, color, t, k, segments=2, width=1, rake=0.0):
    """One jointed leg from (x, y) outwards on `side` (-1 left, +1 right)."""
    step = wave(t, k) * 2.5
    knee = (x + side * length * 0.55, y - 2 + rake * 0.5 + step * 0.4)
    foot = (x + side * length, y + 2 + rake + step)
    pts = [(x, y), knee, foot] if segments >= 2 else [(x, y), foot]
    c.line(pts, color, width)


def arthropod_trunk(c, cx, top, n, seg_h, w0, w1, color, t, sway=0.0, alt=0.9):
    """Stack of n overlapping tergites from `top`, width tapering w0 -> w1.
    Returns the list of (x, y, half_width) per segment."""
    segs = []
    for i in range(n):
        f = i / max(1, n - 1)
        y = top + i * seg_h
        w = w0 + (w1 - w0) * f
        x = cx + wave(t, i * 0.6) * sway * f
        segs.append((x, y, w))
    for i, (x, y, w) in reversed(list(enumerate(segs))):
        c.ellipse(x, y, w, seg_h * 0.75, shade(color, 1.0 if i % 2 else alt))
    return segs


def antenna(c, x, y, side, length, t, color=(150, 230, 220, 255), bend=0.4):
    sw = wave(t) * 1.5
    c.d.line([(x, y), (x + side * length * 0.4 + sw, y - length * 0.6), (x + side * length * (0.6 + bend) + sw, y - length)], fill=color)


def eye_pair(c, cx, y, dx, color=(120, 255, 240, 255), r=0):
    c.eye(cx - dx, y, color, r)
    c.eye(cx + dx, y, color, r)


def fish(c, t, s, body, length=0.66, width=0.13, head=0.28, tail="fork", pectoral=0.14, pelvic=0.0,
         eyes=0.08, gill_slits=0, scales=True, armour=False, jaw=True, barbels=0, scutes=False, eye_color=(255, 240, 160, 255),
         spine=False, whip=False, fin_color=None):
    """Top-down fish facing up. Anatomy switches cover sharks, bony fish, placoderms, sturgeons."""
    cx = s / 2
    top = s * (0.5 - length / 2)
    bottom = top + s * length
    fin_color = fin_color or shade(body, 1.15)
    sweep = wave(t)
    c.shadow(cx, s * 0.58, s * width * 1.4, s * length * 0.5)
    # Spine of the body bends with the swim stroke, more towards the tail
    def mid(f):
        return cx + sweep * 3.5 * f * f, top + f * s * length
    # Tail
    tx, ty = mid(1.0)
    if tail == "fork":
        c.poly([(tx - 2, ty - 4), (tx + 2, ty - 4), (tx + sweep * 3 + s * 0.11, ty + s * 0.1), (tx + sweep * 2, ty + 1), (tx + sweep * 3 - s * 0.11, ty + s * 0.1)], fin_color)
    elif tail == "hetero":
        # Heterocercal: upper lobe longer (seen from above, one lobe swept further)
        c.poly([(tx - 2, ty - 4), (tx + 2, ty - 4), (tx + sweep * 3 + s * 0.06, ty + s * 0.07), (tx + sweep * 3 - s * 0.03, ty + s * 0.15)], fin_color)
    elif tail == "round":
        c.ellipse(tx + sweep * 2, ty + s * 0.04, s * 0.06, s * 0.07, fin_color)
    elif tail == "whip":
        c.line([(tx, ty - 3), (tx + sweep * 4, ty + s * 0.12), (tx - sweep * 3, ty + s * 0.22)], fin_color, 1)
    # Paired fins
    if pectoral:
        for side in (-1, 1):
            px, py = mid(head * 1.05)
            flap = wave(t, 1.0) * 0.15 * side
            c.poly([(px + side * s * width * 0.7, py - 2), (px + side * (s * width + s * pectoral), py + s * pectoral * (0.5 + flap)), (px + side * s * width * 0.6, py + s * pectoral * 0.8)], fin_color)
    if pelvic:
        for side in (-1, 1):
            px, py = mid(0.62)
            c.poly([(px + side * s * width * 0.5, py), (px + side * (s * width * 0.5 + s * pelvic), py + s * pelvic), (px + side * s * width * 0.3, py + s * pelvic * 0.9)], fin_color)
    # Body outline as a smooth taper
    left, right = [], []
    for i in range(13):
        f = i / 12
        x, y = mid(f)
        # Fusiform: pointed snout, widest about a third back, slim tail stalk
        w = s * width * (max(0.16, math.sin(math.pi * (f * 0.9 + 0.05) ** 0.7)) ** 0.9 * (1 - 0.3 * f))
        left.append((x - w, y))
        right.append((x + w, y))
    c.poly(left + right[::-1], body)
    hx, hy = mid(0.0)
    # Belly-light dorsal stripe and scales
    c.d.line([mid(f) for f in (0.12, 0.4, 0.7, 0.9)], fill=shade(body, 1.25))
    if scales:
        for i in range(3, 11):
            x, y = mid(i / 12)
            w = s * width * 0.55 * (1 - 0.6 * i / 12)
            c.d.point((x - w, y), fill=shade(body, 0.7))
            c.d.point((x + w, y), fill=shade(body, 0.7))
    if scutes:
        # Sturgeon: one dorsal and two lateral rows of bony scutes
        for i in range(2, 11):
            x, y = mid(i / 12)
            w = s * width * 0.75 * (1 - 0.6 * i / 12)
            for dx in (-w, 0, w):
                c.d.point((x + dx, y), fill=(235, 225, 200, 255))
    if armour:
        # Placoderm head and trunk shields
        c.poly([(hx - s * width * 0.95, hy + s * 0.06), (hx + s * width * 0.95, hy + s * 0.06), (hx + s * width * 0.9, hy + s * head * 0.95), (hx - s * width * 0.9, hy + s * head * 0.95)], shade(body, 1.2))
        c.d.line([(hx, hy + s * 0.06), (hx, hy + s * head * 0.95)], fill=shade(body, 0.7))
    if gill_slits:
        for k in range(gill_slits):
            x, y = mid(head * 0.55 + k * 0.035)
            for side in (-1, 1):
                c.d.line([(x + side * (s * width * 0.55), y), (x + side * (s * width * 0.85), y + 1)], fill=shade(body, 0.55))
    if spine:
        x, y = mid(0.25)
        c.d.line([(x, y), (x, y - 4)], fill=(240, 230, 200, 255))
    if barbels:
        for k in range(barbels):
            off = (k - (barbels - 1) / 2) * 2.2
            c.d.line([(hx + off, hy + 3), (hx + off * 1.4, hy - 2)], fill=(230, 210, 170, 255))
    if jaw:
        c.d.line([(hx - 2, hy + 2), (hx, hy + 3), (hx + 2, hy + 2)], fill=OUTLINE)
    ex, ey = mid(head * 0.32)
    c.eye(ex - s * eyes, ey, eye_color, 0)
    c.eye(ex + s * eyes, ey, eye_color, 0)


def eel(c, t, s, body, width=0.07, length=0.8, head_w=None, mouth="jaw", gill_pores=0, barbels=0, eyes=True, fin=True, pores=False):
    """Long undulating body (lancelet, lamprey, hagfish)."""
    cx = s / 2
    top = s * (0.5 - length / 2)
    head_w = head_w or width
    c.shadow(cx, s * 0.55, s * width * 1.6, s * length * 0.5)
    pts_l, pts_r, mids = [], [], []
    n = 16
    for i in range(n + 1):
        f = i / n
        x = cx + wave(t, -f * 4.5) * 4.0 * (0.25 + f)
        y = top + f * s * length
        w = s * (head_w + (width - head_w) * min(1, f * 3)) * (1 - 0.8 * max(0, f - 0.6) / 0.4)
        mids.append((x, y, w))
        pts_l.append((x - w - 0.5, y))
        pts_r.append((x + w + 0.5, y))
    if fin:
        # Low median fin fringe around the tail
        fringe_l = [(x - w - 2, y) for x, y, w in mids[n // 2:]]
        fringe_r = [(x + w + 2, y) for x, y, w in mids[n // 2:]]
        c.poly(fringe_l + fringe_r[::-1], shade(body, 1.2))
    c.poly(pts_l + pts_r[::-1], body)
    c.d.line([(x, y) for x, y, _ in mids[1:]], fill=shade(body, 1.25))
    hx, hy, hw = mids[0]
    if gill_pores:
        for k in range(gill_pores):
            x, y, w = mids[2 + k // 2] if 2 + k // 2 < len(mids) else mids[-1]
            yy = y + (k % 2) * 1.5
            c.d.point((x - w + 1, yy), fill=OUTLINE)
            c.d.point((x + w - 1, yy), fill=OUTLINE)
    if pores:
        for x, y, w in mids[3:-3:2]:
            c.d.point((x - w, y), fill=(250, 250, 230, 255))
            c.d.point((x + w, y), fill=(250, 250, 230, 255))
    if mouth == "disc":
        # Lamprey oral disc with rasping teeth
        c.ellipse(hx, hy - 1, hw + 2, 3, shade(body, 0.8))
        for k in range(6):
            a = k / 6 * TAU
            c.d.point((hx + math.cos(a) * 2, hy - 1 + math.sin(a) * 1.5), fill=(250, 240, 200, 255))
    if barbels:
        for k in range(barbels):
            off = (k - (barbels - 1) / 2) * 2
            c.d.line([(hx + off * 0.6, hy), (hx + off, hy - 4)], fill=shade(body, 1.3))
    if eyes:
        c.eye(hx - hw * 0.6, hy + 3, (255, 240, 160, 255), 0)
        c.eye(hx + hw * 0.6, hy + 3, (255, 240, 160, 255), 0)


def tetrapod(c, t, s, body, head_len, head_w, body_len, body_w, tail_len, tail_w, leg_len, toes=5, snout=0.0,
             skin="smooth", spots=False, sail=False, whiskers=False, flat_head=False, fin_legs=False):
    """Sprawling four-legged animal from above. Legs move in diagonal pairs."""
    cx = s / 2
    top = s * 0.5 - (body_len + head_len * 0.6) * s / 2 + head_len * s * 0.6
    phase = t * TAU
    c.shadow(cx, s * 0.58, s * body_w * 1.6, s * (body_len + tail_len) * 0.55)
    # Tail
    tail_pts_l, tail_pts_r = [], []
    for i in range(7):
        f = i / 6
        x = cx + wave(t, -f * 2.5) * 3 * f
        y = top + s * body_len * 0.9 + f * s * tail_len
        w = s * tail_w * (1 - f) + 0.5
        tail_pts_l.append((x - w, y))
        tail_pts_r.append((x + w, y))
    c.poly(tail_pts_l + tail_pts_r[::-1], shade(body, 0.92))
    # Legs: front pair and hind pair, diagonal gait
    for fy, side, ph in ((0.2, -1, 0), (0.2, 1, math.pi), (0.82, -1, math.pi), (0.82, 1, 0)):
        y = top + s * body_len * fy
        swing = math.sin(phase + ph) * 3
        hip = (cx + side * s * body_w * 0.75, y)
        knee = (cx + side * (s * body_w + s * leg_len * 0.55), y - 2 + swing * 0.3)
        foot = (cx + side * (s * body_w + s * leg_len), y + (-3 if fy < 0.5 else 3) + swing)
        if fin_legs:
            c.poly([hip, (foot[0], foot[1] - 2), (foot[0] + side * 1, foot[1] + 3), (hip[0], hip[1] + 4)], shade(body, 1.1))
            for k in range(3):
                c.d.line([(hip[0] + side * (k + 2), hip[1] + 1), (foot[0], foot[1] + k - 1)], fill=shade(body, 0.75))
        else:
            c.line([hip, knee, foot], shade(body, 0.85), 2)
            for k in range(toes):
                a = (k - (toes - 1) / 2) * 0.45 + (-math.pi / 2 if fy < 0.5 else math.pi / 2) * 0.35
                c.d.point((foot[0] + side * math.cos(a) * 2, foot[1] + math.sin(a) * 2), fill=shade(body, 0.6))
    # Body
    c.ellipse(cx, top + s * body_len / 2, s * body_w, s * body_len / 2, body)
    c.ellipse(cx, top + s * body_len / 2 - 1, s * body_w * 0.45, s * body_len * 0.38, shade(body, 1.15), outline=False)
    if skin == "scaly":
        for i in range(6):
            y = top + s * body_len * (0.12 + i * 0.15)
            for k in (-2, 0, 2):
                c.d.point((cx + k * 2 + (i % 2), y), fill=shade(body, 0.72))
    if spots:
        for (dx, fy) in ((-0.5, 0.25), (0.45, 0.4), (-0.3, 0.65), (0.5, 0.8), (0.1, 0.5)):
            c.dot(cx + dx * s * body_w, top + s * body_len * fy, (240, 200, 60, 255), 1)
    if sail:
        # Dimetrodon-style sail: a tall crest of neural spines along the back
        for i in range(9):
            y = top + s * body_len * (0.1 + i * 0.1)
            h = math.sin((i + 1) / 10 * math.pi) * 4
            c.d.line([(cx - h * 0.5, y), (cx + h * 0.5, y)], fill=(230, 120, 90, 255))
        c.d.line([(cx, top + s * body_len * 0.08), (cx, top + s * body_len * 0.95)], fill=OUTLINE)
    # Head
    hy = top - s * head_len * 0.3
    c.ellipse(cx, hy, s * head_w, s * head_len / 2, shade(body, 1.05))
    if snout:
        c.poly([(cx - s * head_w * 0.7, hy - s * head_len * 0.15), (cx + s * head_w * 0.7, hy - s * head_len * 0.15),
                (cx + s * head_w * 0.3, hy - s * head_len * (0.5 + snout)), (cx - s * head_w * 0.3, hy - s * head_len * (0.5 + snout))], shade(body, 1.05), outline=False)
    if whiskers:
        for side in (-1, 1):
            for k in range(2):
                c.d.line([(cx + side * 2, hy - s * head_len * 0.35), (cx + side * 7, hy - s * head_len * 0.4 + k * 2)], fill=(240, 240, 230, 255))
    ey = hy - s * head_len * (0.05 if not flat_head else 0.1)
    ex = s * head_w * (0.7 if not flat_head else 0.45)
    c.eye(cx - ex, ey, (255, 210, 120, 255), 0)
    c.eye(cx + ex, ey, (255, 210, 120, 255), 0)


def star(c, t, s, body, arms=5, arm_len=0.36, arm_w=0.085, disc=0.12, thin=False, bumps=True, groove=True, wiggle=0.25, branch=0, feathers=False):
    """Pentaradial echinoderm seen from above (one arm points forward)."""
    cx, cy = s / 2, s / 2
    c.shadow(cx, cy + 2, s * (disc + arm_len * 0.45), s * (disc + arm_len * 0.45))
    for k in range(arms):
        base_a = -math.pi / 2 + k * TAU / arms
        pts_l, pts_r, spine = [], [], []
        n = 8
        for i in range(n + 1):
            f = i / n
            a = base_a + wave(t, k * 1.3) * wiggle * f * (1.6 if thin else 1.0)
            r = s * (disc * 0.6 + arm_len * f)
            w = s * arm_w * (1 - f * (0.85 if not thin else 0.6)) + (0.6 if thin else 1.0)
            x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
            nx, ny = -math.sin(a), math.cos(a)
            spine.append((x, y))
            pts_l.append((x + nx * w, y + ny * w))
            pts_r.append((x - nx * w, y - ny * w))
        if branch:
            # Crinoid arms fork, giving 10 feathery arms from 5
            for side in (-1, 1):
                fx, fy = spine[3]
                a2 = base_a + side * 0.35 + wave(t, k) * wiggle
                ex, ey = fx + math.cos(a2) * s * arm_len * 0.7, fy + math.sin(a2) * s * arm_len * 0.7
                c.line([(fx, fy), (ex, ey)], body, 1)
                if feathers:
                    for j in range(1, 5):
                        px = fx + (ex - fx) * j / 5
                        py = fy + (ey - fy) * j / 5
                        nx, ny = -math.sin(a2), math.cos(a2)
                        c.d.line([(px - nx * 2, py - ny * 2), (px + nx * 2, py + ny * 2)], fill=shade(body, 1.3))
            c.line(spine[:4], body, 2)
            continue
        c.poly(pts_l + pts_r[::-1], body)
        if groove:
            c.d.line(spine[1:], fill=shade(body, 0.68))
        if bumps:
            for x, y in spine[1:-1:2]:
                c.d.point((x, y), fill=shade(body, 1.35))
    c.ellipse(cx, cy, s * disc, s * disc, shade(body, 1.08))
    if bumps:
        for k in range(arms):
            a = -math.pi / 2 + k * TAU / arms
            c.d.point((cx + math.cos(a) * s * disc * 0.5, cy + math.sin(a) * s * disc * 0.5), fill=shade(body, 1.35))


# ─────────────────────────── tier 1 and 2 ───────────────────────────

def ancestral_collar_cell(c, t, s):
    # Choanoflagellate: ovoid cell body in front; behind it a collar of
    # microvilli and one long flagellum. The flagellum beats behind the cell
    # and pushes it forward, so collar and flagellum trail (they point down).
    cx, cy = s / 2, s * 0.36
    body = (90, 200, 220, 255)
    c.shadow(cx, cy + 4, s * 0.17, s * 0.2)
    # Flagellum: a travelling wave that grows towards its tip
    pts = [(cx + wave(t, -k * 0.7) * 3.5 * (k / 10), cy + s * 0.26 + k * s * 0.035) for k in range(11)]
    c.line([(cx, cy + s * 0.2)] + pts, (180, 255, 245, 255), 1)
    # Collar of microvilli flaring backwards around the flagellum base
    for k in range(-5, 6):
        x0 = cx + k * 1.6
        c.d.line([(x0, cy + s * 0.15), (x0 + k * 1.1, cy + s * 0.33)], fill=(170, 250, 240, 255))
    c.ellipse(cx, cy, s * 0.16, s * 0.2, body)
    c.ellipse(cx, cy - 2, s * 0.07, s * 0.07, (60, 90, 170, 255))
    c.dot(cx + 3, cy - 3, (255, 255, 255, 255), 0)
    c.dot(cx - 4, cy + 4, shade(body, 1.4), 1)
    c.dot(cx + 5, cy - 6, (120, 220, 140, 255), 1)


def early_arthropod(c, t, s):
    # Stem arthropod (Fuxianhuia-like): head shield, ONE pair of antennae,
    # 11 trunk segments each with a pair of biramous limbs, tail fan.
    cx, body = s / 2, (90, 150, 190, 255)
    c.shadow(cx, s * 0.56, s * 0.18, s * 0.38)
    segs = []
    for i in range(11):
        y = s * 0.3 + i * s * 0.05
        w = s * (0.15 - i * 0.008)
        segs.append((y, w))
        for side in (-1, 1):
            legs_pair(c, cx + side * w * 0.6, y, side, s * 0.1, (200, 160, 130, 255), t, i * 0.8, 1)
    arthropod_trunk(c, cx, s * 0.3, 11, s * 0.05, s * 0.15, s * 0.07, body, t)
    for side in (-1, 1):
        c.poly([(cx, s * 0.84), (cx + side * s * 0.09, s * 0.93 + wave(t) * 1.5), (cx + side * s * 0.02, s * 0.95)], shade(body, 1.2))
    c.ellipse(cx, s * 0.24, s * 0.16, s * 0.09, shade(body, 1.1))
    eye_pair(c, cx, s * 0.22, 6)
    for side in (-1, 1):
        antenna(c, cx + side * 3, s * 0.17, side, s * 0.16, t)


def chelicerate(c, t, s):
    # Early chelicerate: NO antennae; chelicerae (small pincers) in front,
    # prosoma shield carrying 6 appendage pairs (chelicerae, pedipalps and
    # 4 walking legs), segmented opisthosoma and a spine-like telson.
    cx, body = s / 2, (150, 110, 170, 255)
    c.shadow(cx, s * 0.56, s * 0.2, s * 0.38)
    for i in range(4):
        y = s * 0.3 + i * s * 0.045
        for side in (-1, 1):
            legs_pair(c, cx + side * s * 0.1, y, side, s * 0.2 + i * 1.5, shade(body, 0.85), t, i * 1.4 + (side > 0) * math.pi, 2, 1, rake=i * 1.0)
    for side in (-1, 1):
        c.line([(cx + side * s * 0.08, s * 0.24), (cx + side * s * 0.16, s * 0.16), (cx + side * s * 0.14, s * 0.1)], shade(body, 1.1), 1)
    arthropod_trunk(c, cx, s * 0.48, 8, s * 0.04, s * 0.12, s * 0.04, body, t, sway=1.5)
    c.line([(cx, s * 0.78), (cx + wave(t) * 2, s * 0.94)], shade(body, 1.15), 1)
    c.ellipse(cx, s * 0.33, s * 0.15, s * 0.13, shade(body, 1.05))
    eye_pair(c, cx, s * 0.29, 5, (255, 140, 200, 255))
    snap = 1 + wave(t, 2) * 1
    for side in (-1, 1):
        c.d.line([(cx + side * 2, s * 0.22), (cx + side * (2 + snap), s * 0.16)], fill=OUTLINE)


def mandibulate(c, t, s):
    # Early mandibulate: one pair of long antennae, visible mandibles,
    # head then a long trunk of 12 segments, one leg pair per segment.
    cx, body = s / 2, (110, 160, 110, 255)
    c.shadow(cx, s * 0.56, s * 0.16, s * 0.4)
    for i in range(12):
        y = s * 0.28 + i * s * 0.05
        for side in (-1, 1):
            legs_pair(c, cx + side * s * 0.08, y, side, s * 0.12, (210, 190, 140, 255), t, i * 0.9 + (side > 0) * math.pi, 2)
    arthropod_trunk(c, cx, s * 0.28, 12, s * 0.05, s * 0.11, s * 0.07, body, t, sway=1.0)
    c.ellipse(cx, s * 0.21, s * 0.1, s * 0.07, shade(body, 1.1))
    eye_pair(c, cx, s * 0.2, 4)
    for side in (-1, 1):
        c.d.line([(cx + side * 2, s * 0.15), (cx + side * 1, s * 0.12)], fill=(250, 220, 150, 255))
        antenna(c, cx + side * 3, s * 0.16, side, s * 0.18, t)


# ──────────────────────────── tier 4 ────────────────────────────────

def arachnid(c, t, s):
    # Early arachnid (trigonotarbid-like): chelicerae, short pedipalps,
    # FOUR pairs of walking legs (8 legs), prosoma + segmented opisthosoma.
    cx, body = s / 2, (140, 100, 80, 255)
    c.shadow(cx, s * 0.55, s * 0.26, s * 0.3)
    for i, (ang, ln) in enumerate(((-0.9, 0.24), (-0.3, 0.26), (0.3, 0.25), (0.85, 0.27))):
        y = s * 0.36 + i * s * 0.04
        for side in (-1, 1):
            legs_pair(c, cx + side * s * 0.08, y, side, s * ln, shade(body, 0.85), t, i * 1.6 + (side > 0) * math.pi, 2, 1, rake=ang * 6)
    arthropod_trunk(c, cx, s * 0.52, 6, s * 0.05, s * 0.13, s * 0.06, body, t)
    c.ellipse(cx, s * 0.36, s * 0.11, s * 0.1, shade(body, 1.1))
    for side in (-1, 1):
        c.line([(cx + side * 4, s * 0.28), (cx + side * 7, s * 0.2)], shade(body, 1.2), 1)
    eye_pair(c, cx, s * 0.31, 2, (255, 120, 90, 255))


def horseshoe_crab(c, t, s):
    # Xiphosuran: broad horseshoe prosoma with lateral compound eyes,
    # hinged opisthosoma with movable marginal spines, long tail spine.
    cx, body = s / 2, (120, 110, 80, 255)
    c.shadow(cx, s * 0.5, s * 0.3, s * 0.3)
    c.line([(cx, s * 0.62), (cx + wave(t) * 3, s * 0.97)], shade(body, 0.9), 2)
    # Opisthosoma: hexagonal plate with six movable spines per side
    op = [(cx - s * 0.2, s * 0.44), (cx + s * 0.2, s * 0.44), (cx + s * 0.16, s * 0.62), (cx, s * 0.68), (cx - s * 0.16, s * 0.62)]
    c.poly(op, shade(body, 0.92))
    for k in range(6):
        y = s * 0.46 + k * s * 0.027
        for side in (-1, 1):
            x = cx + side * (s * 0.2 - k * 0.8)
            c.d.line([(x, y), (x + side * 3, y + 1 + wave(t, k) * 0.8)], fill=OUTLINE)
    c.d.line([(cx, s * 0.46), (cx, s * 0.64)], fill=shade(body, 1.25))
    # Prosoma: half-disc shield, front edge rounded
    r = s * 0.31
    c.d.pieslice((cx - r - 1, s * 0.44 - r - 1, cx + r + 1, s * 0.44 + r + 1), 180, 360, fill=OUTLINE)
    c.d.pieslice((cx - r, s * 0.44 - r, cx + r, s * 0.44 + r), 180, 360, fill=body)
    c.d.line([(cx - r, s * 0.44), (cx + r, s * 0.44)], fill=OUTLINE)
    c.d.arc((cx - s * 0.17, s * 0.27, cx + s * 0.17, s * 0.61), 200, 340, fill=shade(body, 0.7))
    c.d.line([(cx, s * 0.15), (cx, s * 0.43)], fill=shade(body, 1.3))
    eye_pair(c, cx, s * 0.3, 11, (180, 230, 255, 255))
    c.d.point((cx - 1, s * 0.2), fill=(180, 230, 255, 255))
    c.d.point((cx + 1, s * 0.2), fill=(180, 230, 255, 255))


def myriapod(c, t, s):
    # Early myriapod: one pair of antennae, head, 16 trunk segments,
    # one leg pair per segment, rippling in a metachronal wave.
    cx, body = s / 2, (170, 120, 70, 255)
    c.shadow(cx, s * 0.56, s * 0.12, s * 0.42)
    n = 16
    for i in range(n):
        y = s * 0.2 + i * s * 0.045
        x = cx + wave(t, i * 0.5) * 2.5 * (i / n)
        for side in (-1, 1):
            legs_pair(c, x + side * s * 0.05, y, side, s * 0.08, shade(body, 0.75), t, i * 0.7, 1)
    arthropod_trunk(c, cx, s * 0.2, n, s * 0.045, s * 0.065, s * 0.05, body, t, sway=2.5)
    c.ellipse(cx, s * 0.15, s * 0.07, s * 0.05, shade(body, 1.15))
    eye_pair(c, cx, s * 0.15, 3)
    for side in (-1, 1):
        antenna(c, cx + side * 2, s * 0.11, side, s * 0.1, t)


def malacostracan(c, t, s):
    # Malacostracan (shrimp-like) body plan: TWO pairs of antennae (antennules + antennae),
    # stalked eyes, carapace, 5 walking leg pairs, abdomen and tail fan.
    cx, body = s / 2, (200, 120, 90, 255)
    c.shadow(cx, s * 0.56, s * 0.17, s * 0.4)
    for i in range(5):
        y = s * 0.32 + i * s * 0.035
        for side in (-1, 1):
            legs_pair(c, cx + side * s * 0.09, y, side, s * 0.14, shade(body, 0.85), t, i * 1.3 + (side > 0) * math.pi, 2)
    arthropod_trunk(c, cx, s * 0.52, 6, s * 0.05, s * 0.1, s * 0.06, body, t, sway=1.5)
    for k, ang in enumerate((-0.5, -0.17, 0.17, 0.5)):
        c.poly([(cx, s * 0.8), (cx + math.sin(ang) * s * 0.12, s * 0.93), (cx + math.sin(ang) * s * 0.06, s * 0.94)], shade(body, 1.15))
    c.ellipse(cx, s * 0.36, s * 0.12, s * 0.14, body)
    c.d.line([(cx, s * 0.25), (cx, s * 0.47)], fill=shade(body, 1.3))
    for side in (-1, 1):
        c.d.line([(cx + side * 3, s * 0.23), (cx + side * 5, s * 0.19)], fill=OUTLINE)
        c.eye(cx + side * 5, s * 0.19, (40, 40, 40, 255), 0)
        antenna(c, cx + side * 1, s * 0.22, side, s * 0.1, t, (250, 200, 160, 255), 0.1)
        antenna(c, cx + side * 2, s * 0.23, side, s * 0.22, t, (250, 200, 160, 255), 0.6)


def hexapod(c, t, s):
    # Early wingless hexapod (silverfish-like): head with ONE pair of long
    # antennae, 3 thorax segments each with one pair of legs (6 legs),
    # 11-segment tapering abdomen ending in three tail filaments.
    cx, body = s / 2, (200, 175, 110, 255)
    c.shadow(cx, s * 0.55, s * 0.14, s * 0.38)
    for i in range(3):
        y = s * 0.33 + i * s * 0.07
        for side in (-1, 1):
            legs_pair(c, cx + side * s * 0.07, y, side, s * 0.15, shade(body, 0.8), t, i * 2.1 + (side > 0) * math.pi, 2, 1, rake=(i - 1) * 5)
    trunk = arthropod_trunk(c, cx, s * 0.45, 9, s * 0.04, s * 0.09, s * 0.03, body, t, sway=1.5)
    tx, ty, _ = trunk[-1]
    for ang in (-0.35, 0.0, 0.35):
        c.d.line([(tx, ty), (tx + math.sin(ang + wave(t) * 0.1) * s * 0.18, ty + s * 0.16)], fill=shade(body, 1.2))
    for i in range(3):
        c.ellipse(cx, s * 0.33 + i * s * 0.07, s * 0.1, s * 0.04, shade(body, 1.0 if i % 2 else 0.9))
    c.ellipse(cx, s * 0.24, s * 0.07, s * 0.05, shade(body, 1.1))
    eye_pair(c, cx, s * 0.23, 4, (60, 40, 20, 255))
    for side in (-1, 1):
        antenna(c, cx + side * 2, s * 0.2, side, s * 0.2, t, (230, 210, 150, 255), 0.3)


def decapod(c, t, s):
    # Lobster-like decapod: stalked eyes, two pairs of antennae (long
    # second pair), first leg pair as big claws (crusher bigger than
    # cutter), 4 more walking leg pairs (10 legs), 6-segment abdomen, tail fan.
    cx, body = s / 2, (190, 60, 45, 255)
    c.shadow(cx, s * 0.56, s * 0.2, s * 0.4)
    for i in range(4):
        y = s * 0.38 + i * s * 0.04
        for side in (-1, 1):
            legs_pair(c, cx + side * s * 0.08, y, side, s * 0.13, shade(body, 0.85), t, i * 1.3 + (side > 0) * math.pi, 2)
    arthropod_trunk(c, cx, s * 0.55, 6, s * 0.05, s * 0.09, s * 0.06, body, t, sway=1.0)
    for ang in (-0.5, -0.17, 0.17, 0.5):
        c.poly([(cx, s * 0.82), (cx + math.sin(ang) * s * 0.12, s * 0.95), (cx + math.sin(ang) * s * 0.06, s * 0.96)], shade(body, 1.15))
    c.ellipse(cx, s * 0.4, s * 0.11, s * 0.15, body)
    c.d.line([(cx, s * 0.28), (cx, s * 0.52)], fill=shade(body, 1.3))
    pinch = max(0.0, math.sin(t * TAU)) * 0.4
    for side, big in ((-1, 1.25), (1, 0.95)):
        ax, ay = cx + side * s * 0.09, s * 0.3
        ex, ey = cx + side * s * 0.2, s * 0.2
        c.line([(ax, ay), (ex, ey)], shade(body, 0.9), 2)
        c.ellipse(ex, ey - s * 0.06 * big, s * 0.05 * big, s * 0.08 * big, shade(body, 1.1))
        c.line([(ex - side * s * 0.02, ey - s * 0.13 * big), (ex - side * s * (0.02 + 0.03 * pinch), ey - s * 0.2 * big)], shade(body, 1.2), 1)
        c.line([(ex + side * s * 0.02, ey - s * 0.13 * big), (ex + side * s * (0.02 + 0.03 * pinch), ey - s * 0.2 * big)], shade(body, 1.2), 1)
    for side in (-1, 1):
        c.d.line([(cx + side * 3, s * 0.26), (cx + side * 5, s * 0.22)], fill=OUTLINE)
        c.eye(cx + side * 5, s * 0.22, (40, 40, 40, 255), 0)
        antenna(c, cx + side * 1, s * 0.25, side, s * 0.08, t, (250, 180, 140, 255), 0.1)
        antenna(c, cx + side * 2, s * 0.26, side, s * 0.3, t, (250, 180, 140, 255), 0.7)


# ──────────────────────────── tier 5 ────────────────────────────────

def scorpion(c, t, s):
    # Scorpion: pedipalps with big claws, 4 pairs of legs, 7-segment
    # mesosoma, 5-segment tail (metasoma) and a telson with stinger.
    cx, body = s / 2, (60, 60, 70, 255)
    c.shadow(cx, s * 0.55, s * 0.26, s * 0.34)
    for i in range(4):
        y = s * 0.36 + i * s * 0.05
        for side in (-1, 1):
            legs_pair(c, cx + side * s * 0.08, y, side, s * 0.22, shade(body, 1.4), t, i * 1.5 + (side > 0) * math.pi, 2, 1, rake=(i - 1.5) * 3)
    arthropod_trunk(c, cx, s * 0.36, 7, s * 0.045, s * 0.12, s * 0.09, shade(body, 1.2), t)
    curl = wave(t) * 0.15
    x, y, ang = cx, s * 0.66, math.pi / 2
    for k in range(5):
        ang -= 0.38 + curl * 0.3
        nx, ny = x + math.cos(ang) * 4.2, y + math.sin(ang) * 4.2
        c.ellipse((x + nx) / 2, (y + ny) / 2, 2, 2, shade(body, 1.3 if k % 2 else 1.15))
        x, y = nx, ny
    c.ellipse(x, y, 2, 2, (220, 180, 60, 255))
    snap = 0.5 + 0.5 * wave(t, 1)
    for side in (-1, 1):
        c.line([(cx + side * s * 0.07, s * 0.3), (cx + side * s * 0.2, s * 0.22), (cx + side * s * 0.18, s * 0.12)], shade(body, 1.3), 2)
        c.ellipse(cx + side * s * 0.18, s * 0.1, 3, 3, shade(body, 1.45))
        c.d.line([(cx + side * s * 0.18, s * 0.08), (cx + side * (s * 0.18 - 1 - snap * 2), s * 0.02)], fill=OUTLINE)
        c.d.line([(cx + side * s * 0.19, s * 0.08), (cx + side * (s * 0.19 + 1 + snap), s * 0.02)], fill=OUTLINE)
    c.ellipse(cx, s * 0.3, s * 0.09, s * 0.07, shade(body, 1.25))
    eye_pair(c, cx, s * 0.28, 1, (120, 255, 200, 255))


def spider(c, t, s):
    # Spider: TWO body parts (cephalothorax + unsegmented abdomen with
    # spinnerets), 8 legs, short pedipalps, chelicerae with fangs, 8 eyes.
    cx, body = s / 2, (90, 70, 110, 255)
    c.shadow(cx, s * 0.52, s * 0.3, s * 0.3)
    for i, (ang, ln) in enumerate(((-1.1, 0.3), (-0.4, 0.3), (0.35, 0.28), (1.0, 0.32))):
        y = s * 0.38 + i * s * 0.035
        for side in (-1, 1):
            legs_pair(c, cx + side * s * 0.06, y, side, s * ln, shade(body, 0.85), t, i * 1.7 + (side > 0) * math.pi, 2, 1, rake=ang * 8)
    c.ellipse(cx, s * 0.62, s * 0.14, s * 0.17, body)
    c.d.line([(cx - 3, s * 0.6), (cx, s * 0.56), (cx + 3, s * 0.6)], fill=(240, 200, 80, 255))
    c.d.line([(cx - 3, s * 0.66), (cx, s * 0.63), (cx + 3, s * 0.66)], fill=(240, 200, 80, 255))
    c.d.point((cx - 1, s * 0.79), fill=OUTLINE)
    c.d.point((cx + 1, s * 0.79), fill=OUTLINE)
    c.ellipse(cx, s * 0.39, s * 0.1, s * 0.09, shade(body, 1.15))
    for side in (-1, 1):
        c.line([(cx + side * 3, s * 0.32), (cx + side * 6, s * 0.26)], shade(body, 1.2), 1)
        c.d.line([(cx + side * 1, s * 0.31), (cx + side * 1, s * 0.27)], fill=(240, 240, 240, 255))
    for k, (dx, dy) in enumerate(((-3, 0), (-1, -1), (1, -1), (3, 0), (-2, 1.5), (-0.7, 1.5), (0.7, 1.5), (2, 1.5))):
        c.d.point((cx + dx, s * 0.355 + dy), fill=(120, 255, 240, 255))


def centipede(c, t, s):
    # Centipede (Chilopoda): flattened, ONE leg pair per segment (here 15
    # pairs), forcipules (venom claws) under the head, long antennae and
    # long backward-pointing last legs.
    cx, body = s / 2, (200, 90, 50, 255)
    c.shadow(cx, s * 0.55, s * 0.14, s * 0.42)
    n = 15
    for i in range(n):
        y = s * 0.2 + i * s * 0.046
        x = cx + wave(t, i * 0.55) * 3 * (i / n)
        for side in (-1, 1):
            legs_pair(c, x + side * s * 0.06, y, side, s * 0.1, (240, 190, 90, 255), t, i * 0.8, 1, rake=1.5)
    segs = arthropod_trunk(c, cx, s * 0.2, n, s * 0.046, s * 0.075, s * 0.06, body, t, sway=3.0, alt=0.75)
    lx, ly, _ = segs[-1]
    for side in (-1, 1):
        c.d.line([(lx + side * 2, ly), (lx + side * 6, ly + 8)], fill=(240, 190, 90, 255))
        c.d.line([(cx + side * 2, s * 0.14), (cx + side * 4, s * 0.1), (cx + side * 2, s * 0.08)], fill=(30, 20, 20, 255))
        antenna(c, cx + side * 2, s * 0.12, side, s * 0.14, t, (240, 190, 90, 255))
    c.ellipse(cx, s * 0.14, s * 0.07, s * 0.05, shade(body, 1.1))


def millipede(c, t, s):
    # Millipede (Diplopoda): rounded body, TWO leg pairs per segment
    # (diplosegments), short elbowed antennae, slow leg ripple.
    cx, body = s / 2, (80, 70, 90, 255)
    c.shadow(cx, s * 0.55, s * 0.12, s * 0.42)
    n = 14
    for i in range(n):
        y = s * 0.2 + i * s * 0.048
        x = cx + wave(t, i * 0.4) * 1.5 * (i / n)
        for k in (0, 1):
            for side in (-1, 1):
                legs_pair(c, x + side * s * 0.06, y + k * 2 - 1, side, s * 0.06, (230, 200, 160, 255), t, i * 0.6 + k * 0.3, 1)
    arthropod_trunk(c, cx, s * 0.2, n, s * 0.048, s * 0.075, s * 0.07, body, t, sway=1.5, alt=0.8)
    for i in range(n):
        y = s * 0.2 + i * s * 0.048
        c.d.point((cx + wave(t, i * 0.4) * 1.5 * (i / n), y), fill=(230, 140, 70, 255))
    c.ellipse(cx, s * 0.15, s * 0.07, s * 0.05, shade(body, 1.15))
    for side in (-1, 1):
        c.d.line([(cx + side * 2, s * 0.11), (cx + side * 4, s * 0.07), (cx + side * 3, s * 0.04)], fill=(230, 200, 160, 255))


def dragonfly_line(c, t, s):
    # Odonata: FOUR wings (two pairs, held flat and beating out of phase),
    # huge compound eyes, 3 pairs of legs tucked under the thorax, a
    # 10-segment abdomen ending in small claspers.
    cx, body = s / 2, (60, 140, 200, 255)
    c.shadow(cx, s * 0.6, s * 0.42, s * 0.1)
    for row, (y0, ph) in enumerate(((s * 0.3, 0.0), (s * 0.38, math.pi / 2))):
        beat = math.sin(t * TAU + ph)
        span = s * (0.44 - row * 0.03) * (0.78 + 0.22 * beat)
        for side in (-1, 1):
            wing = [(cx + side * 2, y0), (cx + side * span, y0 - 3 - beat * 2), (cx + side * (span + 1), y0 + 2 - beat * 2), (cx + side * 2, y0 + 4)]
            layer = Image.new("RGBA", c.img.size, (0, 0, 0, 0))
            ld = c.layer_draw(layer)
            ld.polygon(wing, fill=(210, 240, 255, 110), outline=(70, 110, 140, 255))
            ld.point((cx + side * span * 0.85, y0 - 1 - beat * 2), fill=(40, 60, 90, 255))
            c.img = Image.alpha_composite(c.img, layer)
            c.d = ImageDraw.Draw(c.img)
    for i in range(10):
        c.ellipse(cx, s * 0.43 + i * s * 0.05, 1.5, 2, shade(body, 1.0 if i % 2 else 0.8))
    c.d.line([(cx - 1, s * 0.93), (cx - 2, s * 0.97)], fill=OUTLINE)
    c.d.line([(cx + 1, s * 0.93), (cx + 2, s * 0.97)], fill=OUTLINE)
    c.ellipse(cx, s * 0.34, s * 0.06, s * 0.08, shade(body, 0.9))
    c.ellipse(cx, s * 0.23, s * 0.075, s * 0.05, body)
    eye_pair(c, cx, s * 0.22, 3, (90, 230, 160, 255), 1)


def beetle(c, t, s):
    # Coleoptera: hardened elytra meeting in a straight midline, pronotum,
    # head with one pair of clubbed antennae, 3 pairs of legs (6 legs).
    cx, body = s / 2, (40, 120, 90, 255)
    c.shadow(cx, s * 0.55, s * 0.22, s * 0.3)
    for i, ang in enumerate((-0.8, 0.0, 0.8)):
        y = s * 0.38 + i * s * 0.1
        for side in (-1, 1):
            legs_pair(c, cx + side * s * 0.12, y, side, s * 0.14, (30, 40, 40, 255), t, i * 2.1 + (side > 0) * math.pi, 2, 1, rake=ang * 6)
    c.ellipse(cx, s * 0.58, s * 0.17, s * 0.22, body)
    c.d.line([(cx, s * 0.38), (cx, s * 0.8)], fill=OUTLINE)
    for side in (-1, 1):
        c.d.arc((cx + side * 2 - 6, s * 0.42, cx + side * 2 + 6, s * 0.72), 100 if side < 0 else 260, 260 if side < 0 else 100, fill=shade(body, 1.5))
    c.ellipse(cx, s * 0.33, s * 0.12, s * 0.06, shade(body, 0.85))
    c.ellipse(cx, s * 0.25, s * 0.07, s * 0.04, shade(body, 0.75))
    for side in (-1, 1):
        antenna(c, cx + side * 2, s * 0.22, side, s * 0.1, t, (60, 60, 50, 255), 0.2)
        c.dot(cx + side * (2 + s * 0.06), s * 0.12, (60, 60, 50, 255), 0)
    eye_pair(c, cx, s * 0.24, 3, (200, 255, 120, 255))


def mantis_shrimp_line(c, t, s):
    # Stomatopod: stalked compound eyes, a pair of raptorial "smashers"
    # folded under the head, short carapace, 6 abdominal segments with
    # swimmerets, broad telson flanked by uropods.
    cx, body = s / 2, (70, 170, 120, 255)
    c.shadow(cx, s * 0.56, s * 0.16, s * 0.4)
    for i in range(5):
        y = s * 0.5 + i * s * 0.05
        for side in (-1, 1):
            legs_pair(c, cx + side * s * 0.09, y, side, s * 0.06, (240, 120, 160, 255), t, i * 1.0, 1)
    arthropod_trunk(c, cx, s * 0.44, 7, s * 0.055, s * 0.13, s * 0.11, body, t, sway=1.0)
    c.ellipse(cx, s * 0.85, s * 0.08, s * 0.06, shade(body, 1.2))
    for side in (-1, 1):
        c.poly([(cx + side * s * 0.06, s * 0.82), (cx + side * s * 0.16, s * 0.9), (cx + side * s * 0.08, s * 0.92)], (240, 120, 160, 255))
    c.ellipse(cx, s * 0.34, s * 0.12, s * 0.1, shade(body, 1.05))
    strike = max(0.0, math.sin(t * TAU)) ** 3
    for side in (-1, 1):
        reach = s * (0.1 + 0.12 * strike)
        c.line([(cx + side * s * 0.07, s * 0.3), (cx + side * s * 0.12, s * 0.3 - reach * 0.6)], (240, 120, 160, 255), 2)
        c.ellipse(cx + side * s * 0.12, s * 0.3 - reach * 0.6 - 2, 2, 2, (255, 160, 190, 255))
        c.d.line([(cx + side * 2, s * 0.25), (cx + side * 5, s * 0.17)], fill=OUTLINE)
        c.eye(cx + side * 5, s * 0.16, (120, 220, 255, 255), 1)
        antenna(c, cx + side * 1, s * 0.24, side, s * 0.09, t, (250, 200, 120, 255), 0.0)


# ──────────────────────────── tier 6 ────────────────────────────────

def pikaia_chordate(c, t, s):
    # Pikaia: laterally flattened ribbon with a notochord, V-shaped muscle
    # blocks (myomeres), small head with a pair of tentacles, fin fold tail.
    body = (220, 190, 160, 255)
    eel(c, t, s, body, width=0.055, length=0.78, head_w=0.04, mouth="none", eyes=False, fin=True)
    cx = s / 2
    top = s * 0.11
    for i in range(3, 15):
        f = i / 16
        x = cx + wave(t, -f * 4.5) * 4.0 * (0.25 + f)
        y = top + f * s * 0.78
        c.d.line([(x - 2, y - 1), (x, y + 1), (x + 2, y - 1)], fill=shade(body, 0.7))
    x0 = cx + wave(t, 0) * 1.0
    for side in (-1, 1):
        c.d.line([(x0 + side * 1, top), (x0 + side * 4, top - 4 + wave(t) * 1)], fill=shade(body, 1.3))


def early_echinoderm(c, t, s):
    # Edrioasteroid-style early echinoderm: a plated disc with FIVE curved
    # ambulacral grooves (pentaradial), each fringed with tube feet.
    cx, cy, body = s / 2, s / 2, (200, 150, 170, 255)
    c.shadow(cx, cy + 3, s * 0.3, s * 0.3)
    c.ellipse(cx, cy, s * 0.29, s * 0.29, body)
    for k in range(18):
        a = k / 18 * TAU
        c.d.point((cx + math.cos(a) * s * 0.25, cy + math.sin(a) * s * 0.25), fill=shade(body, 0.7))
    for k in range(5):
        a0 = -math.pi / 2 + k * TAU / 5
        pts = []
        for i in range(8):
            f = i / 7
            a = a0 + f * 0.9
            r = s * 0.04 + f * s * 0.19
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        c.d.line(pts, fill=shade(body, 0.6), width=2)
        for i, (x, y) in enumerate(pts[1:]):
            if (i + int(t * 4)) % 2 == 0:
                c.d.point((x + 1, y), fill=(255, 230, 240, 255))
    c.ellipse(cx, cy, s * 0.05, s * 0.05, shade(body, 1.25))


def early_mollusc(c, t, s):
    # Early mollusc: a single cap-shaped shell over a broad muscular foot,
    # a head with one pair of tentacles; mantle edge visible around it.
    cx, body = s / 2, (220, 190, 120, 255)
    c.shadow(cx, s * 0.56, s * 0.24, s * 0.3)
    foot = (230, 150, 140, 255)
    ripple = wave(t) * 1.5
    c.ellipse(cx, s * 0.55 + ripple * 0.3, s * 0.22, s * 0.3, foot)
    c.ellipse(cx, s * 0.24, s * 0.09, s * 0.06, foot)
    for side in (-1, 1):
        c.d.line([(cx + side * 3, s * 0.2), (cx + side * 6, s * 0.12 + wave(t, side) * 1)], fill=shade(foot, 1.2))
        c.eye(cx + side * 3, s * 0.22, (40, 40, 40, 255), 0)
    c.ellipse(cx, s * 0.55, s * 0.19, s * 0.26, body)
    for k in range(1, 4):
        c.d.ellipse((cx - s * 0.19 * k / 4, s * 0.55 - s * 0.26 * k / 4, cx + s * 0.19 * k / 4, s * 0.55 + s * 0.26 * k / 4), outline=shade(body, 0.8))
    c.dot(cx, s * 0.5, shade(body, 1.35), 1)


# ──────────────────────────── tier 7 ────────────────────────────────

def jawed_fish(c, t, s):
    # Placoderm (early gnathostome): armoured head and trunk shields,
    # bony jaws, paired pectoral AND pelvic fins, heterocercal tail.
    fish(c, t, s, (110, 120, 150, 255), width=0.15, head=0.3, tail="hetero", pectoral=0.12, pelvic=0.07, armour=True, scales=False)


def jawless_fish(c, t, s):
    # Osteostracan (Cephalaspis-like): horseshoe head shield with eyes on
    # top, pectoral flaps but NO jaws and no pelvic fins, tail.
    cx, body = s / 2, (150, 140, 110, 255)
    fish(c, t, s, body, width=0.12, head=0.15, tail="hetero", pectoral=0.0, scales=True, jaw=False)
    c.d.ellipse((cx - s * 0.25, s * 0.13, cx + s * 0.25, s * 0.5), fill=OUTLINE)
    c.d.ellipse((cx - s * 0.24, s * 0.14, cx + s * 0.24, s * 0.49), fill=shade(body, 1.1))
    c.d.rectangle((cx - s * 0.26, s * 0.38, cx + s * 0.26, s * 0.51), fill=(0, 0, 0, 0))
    for side in (-1, 1):
        c.poly([(cx + side * s * 0.2, s * 0.36), (cx + side * s * 0.27, s * 0.47), (cx + side * s * 0.14, s * 0.4)], shade(body, 1.0))
        c.d.line([(cx + side * s * 0.24, s * 0.3), (cx + side * s * 0.3, s * 0.42)], fill=OUTLINE)
    c.d.line([(cx, s * 0.36), (cx, s * 0.62)], fill=shade(body, 0.95), width=3)
    eye_pair(c, cx, s * 0.24, 3, (255, 240, 160, 255))
    c.d.point((cx, s * 0.27), fill=shade(body, 1.4))


def lobe_finned_shorewalker(c, t, s):
    # Tiktaalik-like: flat crocodile-like head with eyes on top, no gill
    # cover, robust lobed pectoral fins with internal bones, scaly body.
    tetrapod(c, t, s, (110, 130, 90, 255), head_len=0.2, head_w=0.12, body_len=0.42, body_w=0.12,
             tail_len=0.28, tail_w=0.06, leg_len=0.1, toes=0, snout=0.3, skin="scaly", flat_head=True, fin_legs=True)


def early_shark(c, t, s):
    # Cladoselache-like: torpedo body, big triangular pectoral fins,
    # 5 gill slits per side, nearly symmetrical forked tail.
    fish(c, t, s, (110, 130, 150, 255), width=0.13, head=0.3, tail="fork", pectoral=0.16, gill_slits=5, scales=False)


def ray_finned_fish(c, t, s):
    # Early actinopterygian: slim body with fans of fin rays, shiny scales.
    fish(c, t, s, (160, 170, 190, 255), width=0.11, head=0.25, tail="hetero", pectoral=0.1, pelvic=0.06, scales=True, fin_color=(220, 200, 150, 255))


def lamprey(c, t, s):
    # Lamprey: eel body, round sucking oral disc with teeth, SEVEN round
    # gill pores per side, no paired fins, no jaws.
    eel(c, t, s, (120, 110, 100, 255), width=0.06, length=0.82, mouth="disc", gill_pores=14, eyes=True)


def hagfish(c, t, s):
    # Hagfish: pink eel, three pairs of barbels (6) around the mouth,
    # eyes reduced to faint spots, a row of slime pores along each side.
    eel(c, t, s, (210, 140, 150, 255), width=0.06, length=0.82, mouth="none", barbels=6, eyes=False, pores=True)


def synapsid(c, t, s):
    # Sail-backed pelycosaur (Dimetrodon-like): sprawling legs, 5 toes,
    # tall sail of elongated neural spines, long tail.
    tetrapod(c, t, s, (150, 110, 90, 255), head_len=0.2, head_w=0.08, body_len=0.36, body_w=0.11,
             tail_len=0.3, tail_w=0.05, leg_len=0.11, toes=5, snout=0.25, sail=True)


def lissamphibian(c, t, s):
    # Salamander: smooth moist skin, broad flat head, 4 toes on the front
    # feet and 5 on the back (shown as 4/5 dots), long tail.
    tetrapod(c, t, s, (40, 50, 50, 255), head_len=0.16, head_w=0.11, body_len=0.36, body_w=0.09,
             tail_len=0.36, tail_w=0.05, leg_len=0.1, toes=4, spots=True, flat_head=True)


def sauropsid(c, t, s):
    # Early reptile: dry scaly skin, pointed snout, sprawling limbs with
    # 5 clawed toes, long tapering tail.
    tetrapod(c, t, s, (110, 150, 70, 255), head_len=0.18, head_w=0.08, body_len=0.32, body_w=0.09,
             tail_len=0.4, tail_w=0.05, leg_len=0.1, toes=5, snout=0.25, skin="scaly")


def shark_line(c, t, s):
    # Modern shark: heterocercal tail, pectoral fins, FIVE gill slits.
    fish(c, t, s, (100, 120, 140, 255), width=0.12, head=0.3, tail="hetero", pectoral=0.16, pelvic=0.05, gill_slits=5, scales=False)


def chimaera(c, t, s):
    # Chimaera (ratfish): big head with huge eyes, broad wing-like
    # pectoral fins, a venomous spine before the dorsal fin, whip tail.
    fish(c, t, s, (170, 160, 190, 255), width=0.12, head=0.32, tail="whip", pectoral=0.2, eyes=0.09, spine=True, scales=False, eye_color=(160, 255, 240, 255))


def sturgeon_line(c, t, s):
    # Sturgeon: long shovel snout with FOUR barbels underneath, five rows of
    # bony scutes (three visible from above), heterocercal tail.
    fish(c, t, s, (120, 130, 110, 255), length=0.78, width=0.1, head=0.22, tail="hetero", pectoral=0.1, pelvic=0.05, scales=False, scutes=True, barbels=4, jaw=False)


def teleost_line(c, t, s):
    # Teleost: compact body, symmetrical (homocercal) forked tail, fin rays.
    fish(c, t, s, (220, 160, 60, 255), length=0.6, width=0.15, head=0.3, tail="fork", pectoral=0.1, pelvic=0.06, scales=True, fin_color=(250, 220, 120, 255))


# ──────────────────────────── tier 8 ────────────────────────────────

def coiled_shell(c, cx, cy, r, color, turns=2.6, stripes=False):
    c.ellipse(cx, cy, r, r, color)
    pts = []
    for i in range(40):
        f = i / 39
        a = f * turns * TAU
        rr = r * (1 - f) * 0.95
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    c.d.line(pts, fill=shade(color, 0.6))
    if stripes:
        # Nautilus "tiger" bands: broad, wavy, from the rim towards the coil
        for k in range(9):
            a = k / 9 * TAU
            pts = [(cx + math.cos(a + g * 0.5) * r * (0.97 - g * 0.5), cy + math.sin(a + g * 0.5) * r * (0.97 - g * 0.5)) for g in (0, 0.25, 0.5, 0.75)]
            c.d.line(pts, fill=(160, 80, 40, 255), width=2)


def arms_fan(c, t, cx, y, n, length, color, spread=1.2, width=1, suckers=False, longest=None):
    for k in range(n):
        f = (k - (n - 1) / 2) / max(1, (n - 1) / 2)
        a = -math.pi / 2 + f * spread / 2
        ln = length * (1.5 if longest and k in longest else 1.0)
        pts = []
        for i in range(6):
            g = i / 5
            aa = a + wave(t, k * 0.9 + g * 2) * 0.35 * g
            pts.append((cx + math.cos(aa) * ln * g, y + math.sin(aa) * ln * g))
        c.line(pts, color, width)
        if suckers:
            for x, yy in pts[2::2]:
                c.d.point((x, yy), fill=(255, 230, 220, 255))


def cephalopod(c, t, s):
    # Earliest cephalopods (Plectronoceras-like): a straight, chambered
    # shell (orthocone) with septa, the soft head and arms in front.
    cx, shell = s / 2, (220, 200, 160, 255)
    c.shadow(cx, s * 0.56, s * 0.12, s * 0.38)
    c.poly([(cx - s * 0.11, s * 0.34), (cx + s * 0.11, s * 0.34), (cx + s * 0.03, s * 0.92), (cx - s * 0.03, s * 0.92)], shell)
    for k in range(7):
        y = s * 0.4 + k * s * 0.07
        w = s * 0.11 * (1 - (y - s * 0.34) / (s * 0.6)) + 1
        c.d.line([(cx - w, y), (cx + w, y)], fill=shade(shell, 0.7))
    arms_fan(c, t, cx, s * 0.3, 10, s * 0.18, (220, 140, 120, 255), 1.4)
    c.ellipse(cx, s * 0.31, s * 0.09, s * 0.06, (220, 140, 120, 255))
    eye_pair(c, cx, s * 0.31, 5, (40, 40, 40, 255))


def sea_snail(c, t, s):
    # Gastropod: coiled shell carried on a muscular foot, head with one pair
    # of tentacles with eyes at their bases.
    cx, foot = s / 2, (200, 180, 150, 255)
    c.shadow(cx, s * 0.58, s * 0.2, s * 0.3)
    c.ellipse(cx, s * 0.55 + wave(t) * 0.8, s * 0.13, s * 0.3, foot)
    for side in (-1, 1):
        c.d.line([(cx + side * 2, s * 0.28), (cx + side * 6, s * 0.16 + wave(t, side) * 1)], fill=shade(foot, 1.1))
        c.eye(cx + side * 3, s * 0.27, (30, 30, 30, 255), 0)
    coiled_shell(c, cx, s * 0.58, s * 0.2, (190, 120, 80, 255))


def bivalve(c, t, s):
    # Bivalve (clam) from above: two valves meeting at the hinge line down
    # the middle, concentric growth lines, siphons out the back, foot in front.
    cx, shell = s / 2, (200, 180, 160, 255)
    c.shadow(cx, s * 0.55, s * 0.25, s * 0.3)
    c.ellipse(cx, s * 0.2, s * 0.05, s * 0.05 + wave(t) * 1, (230, 160, 150, 255))
    for side in (-1, 1):
        c.d.line([(cx + side * 2, s * 0.78), (cx + side * 3, s * 0.88 + wave(t, side) * 1.5)], fill=(230, 160, 150, 255), width=2)
    gape = 1 + max(0.0, wave(t)) * 1.5
    for side in (-1, 1):
        x0 = cx + side * gape * 0.5
        c.d.pieslice((x0 - s * 0.24, s * 0.22, x0 + s * 0.24, s * 0.8), 90 if side < 0 else -90, 270 if side < 0 else 90, fill=OUTLINE)
        c.d.pieslice((x0 - s * 0.23, s * 0.23, x0 + s * 0.23, s * 0.79), 90 if side < 0 else -90, 270 if side < 0 else 90, fill=shell)
        for k in range(1, 4):
            r = k / 4
            c.d.arc((x0 - s * 0.23 * r, s * 0.51 - s * 0.28 * r, x0 + s * 0.23 * r, s * 0.51 + s * 0.28 * r), 90 if side < 0 else -90, 270 if side < 0 else 90, fill=shade(shell, 0.75))
    c.d.line([(cx, s * 0.22), (cx, s * 0.8)], fill=OUTLINE)


def nautilus(c, t, s):
    # Nautilus: coiled, chambered shell with tiger stripes, a leathery hood
    # and many (about 90) slender tentacles without suckers; pinhole eyes.
    cx, shell = s / 2, (240, 230, 210, 255)
    c.shadow(cx, s * 0.56, s * 0.25, s * 0.28)
    arms_fan(c, t, cx, s * 0.32, 14, s * 0.14, (220, 170, 150, 255), 1.5)
    c.ellipse(cx, s * 0.34, s * 0.12, s * 0.06, (200, 150, 130, 255))
    eye_pair(c, cx, s * 0.36, 8, (30, 30, 30, 255))
    coiled_shell(c, cx, s * 0.6, s * 0.23, shell, turns=1.5, stripes=True)


def coleoid(c, t, s):
    # Belemnite-style early coleoid: shell internal (a bullet-shaped guard
    # inside the mantle), side fins, TEN arms lined with hooks.
    cx, body = s / 2, (180, 120, 150, 255)
    c.shadow(cx, s * 0.55, s * 0.12, s * 0.4)
    arms_fan(c, t, cx, s * 0.32, 10, s * 0.2, shade(body, 1.1), 0.9)
    c.ellipse(cx, s * 0.6, s * 0.1, s * 0.3, body)
    flap = wave(t) * 0.2
    for side in (-1, 1):
        c.poly([(cx + side * s * 0.08, s * 0.72), (cx + side * s * (0.18 + flap * 0.05), s * 0.8), (cx + side * s * 0.06, s * 0.86)], shade(body, 1.15))
    c.poly([(cx - 2, s * 0.55), (cx + 2, s * 0.55), (cx, s * 0.86)], shade(body, 0.7), outline=False)
    eye_pair(c, cx, s * 0.34, 5, (255, 230, 120, 255), 1)


def predatory_sea_snail(c, t, s):
    # Cone snail: cone-shaped shell with a tented pattern, a long siphon and
    # an extendable proboscis carrying a venom harpoon.
    cx, shell = s / 2, (230, 200, 150, 255)
    c.shadow(cx, s * 0.58, s * 0.16, s * 0.34)
    reach = s * (0.08 + 0.08 * max(0.0, wave(t)))
    c.line([(cx, s * 0.24), (cx, s * 0.24 - reach)], (230, 120, 140, 255), 1)
    c.d.point((cx, s * 0.22 - reach), fill=(255, 255, 255, 255))
    c.line([(cx + 3, s * 0.26), (cx + 6, s * 0.14)], (230, 150, 140, 255), 1)
    c.poly([(cx - s * 0.16, s * 0.34), (cx + s * 0.16, s * 0.34), (cx + s * 0.03, s * 0.88), (cx - s * 0.03, s * 0.88)], shell)
    c.ellipse(cx, s * 0.32, s * 0.16, s * 0.05, shade(shell, 1.1))
    for k in range(6):
        y = s * 0.4 + k * s * 0.08
        w = s * 0.14 * (1 - (y - s * 0.34) / (s * 0.56))
        for j in range(-2, 3):
            c.d.point((cx + j * w / 2.5, y + (j % 2)), fill=(140, 70, 40, 255))


def sea_slug_line(c, t, s):
    # Nudibranch: shell-less, flattened body, two rhinophores in front and
    # rows of cerata (finger-like gills) down the back; very colourful.
    cx, body = s / 2, (120, 80, 200, 255)
    c.shadow(cx, s * 0.56, s * 0.17, s * 0.36)
    c.ellipse(cx, s * 0.55, s * 0.15 + wave(t) * 0.5, s * 0.35, body)
    for i in range(7):
        y = s * 0.35 + i * s * 0.065
        for side in (-1, 1):
            x = cx + side * (s * 0.08 + (i % 2) * 2)
            c.line([(x, y), (x + side * 3 + wave(t, i) * 0.8, y - 2)], (255, 160, 60, 255), 1)
            c.d.point((x + side * 3 + wave(t, i) * 0.8, y - 3), fill=(255, 240, 200, 255))
    c.d.line([(cx, s * 0.25), (cx, s * 0.88)], fill=(250, 220, 90, 255))
    for side in (-1, 1):
        c.line([(cx + side * 3, s * 0.24), (cx + side * 5, s * 0.15)], (250, 220, 90, 255), 1)


def scallop(c, t, s):
    # Scallop: fan-shaped valve with radiating ribs, two "ears" at the
    # hinge, and a row of many small blue eyes along the mantle edge.
    # Swims by clapping its valves (the frames pulse).
    cx, shell = s / 2, (230, 140, 100, 255)
    c.shadow(cx, s * 0.55, s * 0.28, s * 0.28)
    clap = 1 + 0.06 * wave(t)
    r = s * 0.3 * clap
    c.d.pieslice((cx - r - 1, s * 0.62 - r - 1, cx + r + 1, s * 0.62 + r + 1), 200, 340, fill=OUTLINE)
    c.d.pieslice((cx - r, s * 0.62 - r, cx + r, s * 0.62 + r), 200, 340, fill=shell)
    for k in range(9):
        a = math.radians(205 + k * 16.25)
        c.d.line([(cx, s * 0.62), (cx + math.cos(a) * r, s * 0.62 + math.sin(a) * r)], fill=shade(shell, 0.75))
    c.d.rectangle((cx - 5, s * 0.6, cx + 5, s * 0.68), fill=OUTLINE)
    c.d.rectangle((cx - 4, s * 0.61, cx + 4, s * 0.67), fill=shade(shell, 1.1))
    for k in range(10):
        a = math.radians(205 + k * 14.5)
        c.d.point((cx + math.cos(a) * (r + 1.5), s * 0.62 + math.sin(a) * (r + 1.5)), fill=(80, 170, 255, 255))


def burrowing_clam(c, t, s):
    # Razor clam: long narrow valves, a digging foot in front and a long
    # paired siphon at the back.
    cx, shell = s / 2, (210, 190, 140, 255)
    c.shadow(cx, s * 0.55, s * 0.1, s * 0.4)
    dig = wave(t) * 2
    c.ellipse(cx, s * 0.12 - dig, s * 0.05, s * 0.07, (230, 170, 150, 255))
    c.d.line([(cx - 1, s * 0.8), (cx - 1, s * 0.95 + dig)], fill=(230, 170, 150, 255), width=2)
    c.d.line([(cx + 1, s * 0.8), (cx + 1, s * 0.95 + dig)], fill=(230, 170, 150, 255), width=2)
    for side in (-1, 1):
        c.poly([(cx, s * 0.17), (cx + side * s * 0.09, s * 0.2), (cx + side * s * 0.09, s * 0.8), (cx, s * 0.83)], shade(shell, 1.0 if side < 0 else 0.92))
    for k in range(5):
        y = s * 0.25 + k * s * 0.12
        c.d.line([(cx - s * 0.08, y), (cx + s * 0.08, y + 2)], fill=shade(shell, 0.8))
    c.d.line([(cx, s * 0.17), (cx, s * 0.83)], fill=OUTLINE)


def squid_line(c, t, s):
    # Squid: torpedo mantle with two triangular fins at the rear, EIGHT
    # arms plus TWO longer feeding tentacles with clubs, big eyes.
    cx, body = s / 2, (230, 120, 110, 255)
    c.shadow(cx, s * 0.55, s * 0.13, s * 0.42)
    arms_fan(c, t, cx, s * 0.3, 8, s * 0.2, shade(body, 1.1), 1.0, suckers=True)
    for side in (-1, 1):
        c.line([(cx + side * 1, s * 0.34), (cx + side * 4 + wave(t) * 1, s * 0.06)], shade(body, 1.2), 1)
        c.ellipse(cx + side * 4 + wave(t) * 1, s * 0.05, 1.5, 2, shade(body, 1.3))
    c.ellipse(cx, s * 0.6, s * 0.09, s * 0.28, body)
    flap = wave(t) * 2
    for side in (-1, 1):
        c.poly([(cx + side * s * 0.05, s * 0.75), (cx + side * (s * 0.17 + flap), s * 0.84), (cx, s * 0.92)], shade(body, 1.15))
    for k in range(6):
        c.d.point((cx + (k % 3 - 1) * 3, s * 0.48 + k * s * 0.05), fill=shade(body, 0.7))
    eye_pair(c, cx, s * 0.36, 5, (255, 240, 140, 255), 1)


def octopus_line(c, t, s):
    # Octopus: rounded mantle, EIGHT arms with paired suckers, no fins,
    # no shell; arms curl in a slow wave.
    cx, body = s / 2, (200, 100, 70, 255)
    c.shadow(cx, s * 0.5, s * 0.3, s * 0.3)
    for k in range(8):
        a = -math.pi / 2 + (k - 3.5) / 3.5 * 1.25 + (math.pi if k in (0, 7) else 0) * 0
        pts = []
        for i in range(8):
            g = i / 7
            aa = a + wave(t, k * 0.8 + g * 2.5) * 0.5 * g
            r = s * (0.08 + 0.3 * g)
            pts.append((cx + math.cos(aa) * r, s * 0.48 + math.sin(aa) * r))
        c.line(pts, body, 2)
        for x, y in pts[2::2]:
            c.d.point((x, y), fill=(255, 220, 200, 255))
    c.ellipse(cx, s * 0.6, s * 0.14, s * 0.18, body)
    c.ellipse(cx, s * 0.64, s * 0.07, s * 0.09, shade(body, 1.2), outline=False)
    eye_pair(c, cx, s * 0.47, 6, (255, 230, 120, 255), 1)


# ──────────────────────────── tier 9 ────────────────────────────────

def sea_lily(c, t, s):
    # Crinoid: a cup (calyx) with FIVE arms that fork into ten feathery
    # arms with pinnules; a jointed stalk trailing behind.
    cx, body = s / 2, (190, 90, 120, 255)
    for i in range(10):
        y = s * 0.55 + i * s * 0.04
        c.ellipse(cx + wave(t, i * 0.3) * i * 0.2, y, 2, 1.5, shade(body, 0.9 if i % 2 else 0.8))
    star(c, t, s, body, arms=5, arm_len=0.36, disc=0.09, branch=1, feathers=True, wiggle=0.25, bumps=False, groove=False)


def free_moving_echinoderm(c, t, s):
    # Early free-living echinoderm: short, broad five-armed body that can
    # crawl on tube feet (between the edrioasteroids and true sea stars).
    star(c, t, s, (210, 140, 100, 255), arms=5, arm_len=0.26, arm_w=0.12, disc=0.15, wiggle=0.12)


def sea_star_line(c, t, s):
    # Asteroid lineage: five arms merging into a central disc, an ambulacral
    # groove with tube feet down each arm, madreporite plate on top.
    star(c, t, s, (230, 120, 70, 255), arms=5, arm_len=0.34, arm_w=0.1, disc=0.12, wiggle=0.15)
    c.d.point((s / 2 + 3, s / 2 - 2), fill=(250, 230, 120, 255))


def spiny_echinozoan(c, t, s):
    # Early echinozoan: globe-shaped test with short spines and five double
    # rows of tube-foot pores (pentaradial ambulacra).
    cx, cy, body = s / 2, s / 2, (150, 100, 160, 255)
    c.shadow(cx, cy + 3, s * 0.26, s * 0.26)
    for k in range(20):
        a = k / 20 * TAU + wave(t) * 0.05
        c.d.line([(cx + math.cos(a) * s * 0.2, cy + math.sin(a) * s * 0.2), (cx + math.cos(a) * s * 0.29, cy + math.sin(a) * s * 0.29)], fill=shade(body, 1.3))
    c.ellipse(cx, cy, s * 0.21, s * 0.21, body)
    for k in range(5):
        a = -math.pi / 2 + k * TAU / 5
        for r in (0.06, 0.1, 0.14, 0.18):
            c.d.point((cx + math.cos(a) * s * r, cy + math.sin(a) * s * r), fill=(240, 220, 250, 255))


def sea_star(c, t, s):
    # Sea star: five broad arms, knobbly upper surface, eyespot at each tip.
    star(c, t, s, (200, 60, 90, 255), arms=5, arm_len=0.33, arm_w=0.11, disc=0.13, wiggle=0.12)
    for k in range(5):
        a = -math.pi / 2 + k * TAU / 5
        c.d.point((s / 2 + math.cos(a) * s * 0.39, s / 2 + math.sin(a) * s * 0.39), fill=(255, 80, 60, 255))


def brittle_star(c, t, s):
    # Ophiuroid: small round central disc sharply set off from FIVE long,
    # thin, segmented arms that snake about to move.
    cx, body = s / 2, (150, 120, 100, 255)
    star(c, t, s, body, arms=5, arm_len=0.34, arm_w=0.03, disc=0.1, thin=True, wiggle=0.45, groove=False, bumps=False)
    for k in range(5):
        a = -math.pi / 2 + k * TAU / 5
        c.d.point((cx + math.cos(a) * s * 0.05, s / 2 + math.sin(a) * s * 0.05), fill=shade(body, 1.4))


def sea_urchin(c, t, s):
    # Echinoid: round test bristling with long movable spines, five paired
    # rows of tube feet, Aristotle's lantern mouth underneath (not visible).
    cx, cy, body = s / 2, s / 2, (90, 50, 110, 255)
    c.shadow(cx, cy + 3, s * 0.3, s * 0.3)
    for k in range(28):
        a = k / 28 * TAU + wave(t, k) * 0.05
        ln = s * (0.36 if k % 2 else 0.31)
        c.d.line([(cx + math.cos(a) * s * 0.15, cy + math.sin(a) * s * 0.15), (cx + math.cos(a) * ln, cy + math.sin(a) * ln)], fill=OUTLINE, width=2)
        c.d.line([(cx + math.cos(a) * s * 0.15, cy + math.sin(a) * s * 0.15), (cx + math.cos(a) * (ln - 1), cy + math.sin(a) * (ln - 1))], fill=(170, 110, 200, 255))
    c.ellipse(cx, cy, s * 0.17, s * 0.17, body)
    for k in range(5):
        a = -math.pi / 2 + k * TAU / 5
        for r in (0.05, 0.09, 0.13):
            c.d.point((cx + math.cos(a) * s * r, cy + math.sin(a) * s * r), fill=(220, 200, 240, 255))


def sea_cucumber(c, t, s):
    # Holothurian: soft sausage body lying on its side, rows of tube feet
    # (five ambulacra, three on the sole), a ring of branched feeding
    # tentacles around the mouth at the front, warty papillae on top.
    cx, body = s / 2, (110, 80, 60, 255)
    c.shadow(cx, s * 0.56, s * 0.16, s * 0.4)
    squash = wave(t) * 0.02
    for i in range(10):
        y = s * 0.28 + i * s * 0.06
        for side in (-1, 1):
            c.d.point((cx + side * s * (0.15 + squash), y + 1), fill=(240, 210, 180, 255))
    c.ellipse(cx, s * 0.56, s * (0.14 + squash), s * (0.34 - squash), body)
    for (dx, dy) in ((-0.06, 0.4), (0.05, 0.5), (-0.03, 0.62), (0.07, 0.7), (-0.06, 0.78), (0.02, 0.33)):
        c.dot(cx + dx * s, dy * s, shade(body, 1.35), 0)
    for k in range(10):
        a = -math.pi / 2 + (k - 4.5) / 4.5 * 1.3
        ln = s * (0.07 + 0.02 * wave(t, k))
        c.line([(cx, s * 0.24), (cx + math.cos(a) * ln, s * 0.24 + math.sin(a) * ln)], (240, 220, 200, 255), 1)


LINEAGES = {
    "ancestral_collar_cell": ancestral_collar_cell,
    "early_arthropod": early_arthropod,
    "chelicerate": chelicerate,
    "mandibulate": mandibulate,
    "arachnid": arachnid,
    "horseshoe_crab": horseshoe_crab,
    "myriapod": myriapod,
    "malacostracan": malacostracan,
    "hexapod": hexapod,
    "scorpion": scorpion,
    "spider": spider,
    "centipede": centipede,
    "millipede": millipede,
    "dragonfly_line": dragonfly_line,
    "beetle": beetle,
    "mantis_shrimp_line": mantis_shrimp_line,
    "decapod": decapod,
    "pikaia_chordate": pikaia_chordate,
    "early_echinoderm": early_echinoderm,
    "early_mollusc": early_mollusc,
    "jawed_fish": jawed_fish,
    "jawless_fish": jawless_fish,
    "lobe_finned_shorewalker": lobe_finned_shorewalker,
    "early_shark": early_shark,
    "ray_finned_fish": ray_finned_fish,
    "lamprey": lamprey,
    "hagfish": hagfish,
    "synapsid": synapsid,
    "lissamphibian": lissamphibian,
    "sauropsid": sauropsid,
    "shark_line": shark_line,
    "chimaera": chimaera,
    "sturgeon_line": sturgeon_line,
    "teleost_line": teleost_line,
    "cephalopod": cephalopod,
    "sea_snail": sea_snail,
    "bivalve": bivalve,
    "nautilus": nautilus,
    "coleoid": coleoid,
    "predatory_sea_snail": predatory_sea_snail,
    "sea_slug_line": sea_slug_line,
    "scallop": scallop,
    "burrowing_clam": burrowing_clam,
    "squid_line": squid_line,
    "octopus_line": octopus_line,
    "sea_lily": sea_lily,
    "free_moving_echinoderm": free_moving_echinoderm,
    "sea_star_line": sea_star_line,
    "spiny_echinozoan": spiny_echinozoan,
    "sea_star": sea_star,
    "brittle_star": brittle_star,
    "sea_urchin": sea_urchin,
    "sea_cucumber": sea_cucumber,
}


def main():
    names = sys.argv[1:] or list(LINEAGES)
    for name in names:
        save_sheet(name, LINEAGES[name])


if __name__ == "__main__":
    main()
