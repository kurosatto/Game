"""Pixel-art sprite sheets for the era animals in data/Fauna.gd.

Each animal is drawn top-down with its head facing up, in 4 animation
frames, at half resolution and scaled 2x for chunky pixels like the rest of
the game's art. Sheets go to assets/fauna/<name>_sheet.png and Enemy.gd
picks them up by name. Colours are mid-tones because Fauna.gd tints them.

Run from the project root:  python generate_fauna_art.py
"""
import math
import os

from PIL import Image, ImageDraw

OUT = "assets/fauna"
FRAMES = 4

OUTLINE = (14, 20, 34, 255)
SHADOW = (0, 0, 0, 70)


def lerp_color(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def shade(c, k):
    """k < 1 darkens, k > 1 lightens."""
    if k < 1:
        return tuple(int(v * k) for v in c[:3]) + (255,)
    return tuple(int(v + (255 - v) * (k - 1)) for v in c[:3]) + (255,)


class Canvas:
    def __init__(self, size):
        self.size = size
        self.img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    # Every shape is drawn twice: a 1px-bigger dark outline, then the fill
    def ellipse(self, cx, cy, rx, ry, fill, outline=True):
        if outline:
            self.d.ellipse((cx - rx - 1, cy - ry - 1, cx + rx + 1, cy + ry + 1), fill=OUTLINE)
        self.d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=fill)

    def poly(self, pts, fill, outline=True):
        if outline:
            self.d.polygon(pts, fill=OUTLINE, outline=OUTLINE)
            # Grow the outline by redrawing shifted copies
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                self.d.polygon([(x + dx, y + dy) for x, y in pts], fill=OUTLINE)
        self.d.polygon(pts, fill=fill)

    def line(self, pts, fill, width=1, outline=True):
        if outline:
            self.d.line(pts, fill=OUTLINE, width=width + 2, joint="curve")
        self.d.line(pts, fill=fill, width=width, joint="curve")

    def dot(self, x, y, c, r=1):
        self.d.ellipse((x - r, y - r, x + r, y + r), fill=c)

    def eye(self, x, y, glow=(120, 255, 240, 255), r=2):
        self.d.ellipse((x - r - 1, y - r - 1, x + r + 1, y + r + 1), fill=OUTLINE)
        self.d.ellipse((x - r, y - r, x + r, y + r), fill=glow)
        self.d.point((x - (r > 1), y - (r > 1)), fill=(255, 255, 255, 255))

    def shadow(self, cx, cy, rx, ry):
        layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=SHADOW)
        self.img = Image.alpha_composite(layer, self.img)
        self.d = ImageDraw.Draw(self.img)


def sheet(name, frame_px, draw_fn):
    half = frame_px // 2
    out = Image.new("RGBA", (frame_px * FRAMES, frame_px), (0, 0, 0, 0))
    for f in range(FRAMES):
        c = Canvas(half)
        draw_fn(c, f / FRAMES, half)
        out.paste(c.img.resize((frame_px, frame_px), Image.NEAREST), (f * frame_px, 0))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + "_sheet.png")
    out.save(path)
    print("  wrote", path)
    return out


# ───────────────────────────── floor 1 ─────────────────────────────

def spriggina(c, t, s):
    # Long segmented Ediacaran body, crescent head shield, chevron segments
    body = (214, 170, 140, 255)
    cx = s / 2
    c.shadow(cx, s * 0.56, s * 0.14, s * 0.42)
    n = 11
    top, length = s * 0.2, s * 0.72
    pts_l, pts_r, mids = [], [], []
    for i in range(n + 1):
        f = i / n
        y = top + f * length
        w = s * 0.1 * (1 - 0.7 * f) + 1
        sway = math.sin(t * 2 * math.pi + i * 0.7) * f * 3
        pts_l.append((cx - w + sway, y))
        pts_r.append((cx + w + sway, y))
        mids.append((cx + sway, y, w))
    c.poly(pts_l + pts_r[::-1], body)
    for x, y, w in mids[1:-1]:
        c.d.line([(x - w + 1, y - 1), (x, y + 1), (x + w - 1, y - 1)], fill=shade(body, 0.62))
    c.d.line([(m[0], m[1]) for m in mids], fill=shade(body, 1.3))
    # Crescent head shield
    c.ellipse(cx, top, s * 0.13, s * 0.07, shade(body, 1.12))
    c.d.arc((cx - s * 0.13, top - s * 0.05, cx + s * 0.13, top + s * 0.09), 200, 340, fill=shade(body, 0.65))


def kimberella(c, t, s):
    # Oval slug-like grazer with frilled margin and a proboscis
    body = (150, 190, 140, 255)
    cx, cy = s / 2, s * 0.55
    c.shadow(cx, cy + 3, s * 0.32, s * 0.36)
    frill = []
    for k in range(40):
        a = k / 40 * 2 * math.pi
        r = 1 + 0.08 * math.sin(a * 9 + t * 2 * math.pi)
        frill.append((cx + math.cos(a) * s * 0.33 * r, cy + math.sin(a) * s * 0.38 * r))
    c.poly(frill, shade(body, 0.85))
    c.ellipse(cx, cy, s * 0.24, s * 0.3, body)
    # Central hump with ridges
    c.ellipse(cx, cy, s * 0.11, s * 0.2, shade(body, 1.25), outline=False)
    for i in range(5):
        y = cy - s * 0.16 + i * s * 0.08
        c.d.line([(cx - s * 0.08, y), (cx + s * 0.08, y)], fill=shade(body, 0.8))
    # Proboscis with toothed tip, reaching forward
    reach = s * (0.12 + 0.05 * math.sin(t * 2 * math.pi))
    c.line([(cx, cy - s * 0.3), (cx, cy - s * 0.3 - reach)], shade(body, 1.1), 2)
    c.dot(cx, cy - s * 0.32 - reach, (230, 120, 110, 255), 2)


# ───────────────────────────── floor 2 ─────────────────────────────

def opabinia(c, t, s):
    # Five stalked eyes, frontal nozzle with claw, lateral flaps, tail fan
    body = (200, 120, 110, 255)
    cx = s / 2
    c.shadow(cx, s * 0.6, s * 0.18, s * 0.34)
    for i in range(7):
        y = s * 0.36 + i * s * 0.065
        flap = s * (0.17 + 0.04 * math.sin(t * 2 * math.pi + i * 0.9))
        for side in (-1, 1):
            c.poly([(cx + side * s * 0.08, y - 2), (cx + side * (s * 0.08 + flap), y + 1), (cx + side * s * 0.08, y + 3)], shade(body, 0.8 + 0.05 * (i % 2)))
    c.ellipse(cx, s * 0.56, s * 0.1, s * 0.26, body)
    for i in range(6):
        y = s * 0.4 + i * s * 0.065
        c.d.line([(cx - s * 0.08, y), (cx + s * 0.08, y)], fill=shade(body, 0.65))
    # Tail fan: three pairs of blades
    for k, ang in enumerate((-0.6, -0.25, 0.25, 0.6)):
        a = math.pi / 2 + ang + math.sin(t * 2 * math.pi) * 0.12
        c.line([(cx, s * 0.8), (cx + math.cos(a) * s * 0.14, s * 0.8 + math.sin(a) * s * 0.14)], (230, 160, 120, 255), 2)
    c.ellipse(cx, s * 0.3, s * 0.11, s * 0.08, shade(body, 1.1))
    # Nozzle with grasping claw
    sw = math.sin(t * 2 * math.pi) * 3
    c.line([(cx, s * 0.24), (cx + sw * 0.5, s * 0.12), (cx + sw, s * 0.04)], shade(body, 1.2), 1)
    c.d.line([(cx + sw - 2, s * 0.02), (cx + sw, s * 0.05), (cx + sw + 2, s * 0.02)], fill=(250, 220, 160, 255))
    # Five eyes on stalks
    for ex, ey in ((-6, 0.25), (-3, 0.22), (0, 0.21), (3, 0.22), (6, 0.25)):
        c.d.line([(cx, s * 0.3), (cx + ex, s * ey)], fill=OUTLINE)
        c.eye(cx + ex, s * ey, r=1)


def olenoides(c, t, s):
    # Spiny trilobite: cephalon with genal spines, thorax, pygidium, antennae
    body = (120, 110, 150, 255)
    cx = s / 2
    c.shadow(cx, s * 0.58, s * 0.3, s * 0.36)
    # Legs peeking out, stepping
    for i in range(7):
        y = s * 0.34 + i * s * 0.065
        step = math.sin(t * 2 * math.pi + i * 1.1) * 2
        for side in (-1, 1):
            c.d.line([(cx + side * s * 0.22, y), (cx + side * (s * 0.32), y + step)], fill=(220, 150, 120, 255), width=1)
    # Thorax with pleural spines
    for i in range(7):
        y = s * 0.34 + i * s * 0.065
        w = s * 0.24 - i * 0.6
        c.poly([(cx - w - 3, y + 3), (cx - w, y - 2), (cx + w, y - 2), (cx + w + 3, y + 3), (cx + w, y + 2), (cx - w, y + 2)], shade(body, 1.0 if i % 2 else 0.9))
    c.ellipse(cx, s * 0.55, s * 0.07, s * 0.24, shade(body, 1.25), outline=False)
    # Pygidium with spines
    c.poly([(cx - s * 0.16, s * 0.79), (cx + s * 0.16, s * 0.79), (cx + s * 0.1, s * 0.88), (cx - s * 0.1, s * 0.88)], shade(body, 0.85))
    for k in (-2, -1, 1, 2):
        c.d.line([(cx + k * 4, s * 0.86), (cx + k * 6, s * 0.95)], fill=OUTLINE)
    # Cephalon with genal spines
    c.poly([(cx - s * 0.26, s * 0.34), (cx - s * 0.36, s * 0.48), (cx - s * 0.22, s * 0.36), (cx + s * 0.22, s * 0.36), (cx + s * 0.36, s * 0.48), (cx + s * 0.26, s * 0.34)], shade(body, 0.8))
    c.ellipse(cx, s * 0.27, s * 0.26, s * 0.11, body)
    c.ellipse(cx, s * 0.25, s * 0.08, s * 0.08, shade(body, 1.3), outline=False)
    c.eye(cx - s * 0.15, s * 0.27, r=1)
    c.eye(cx + s * 0.15, s * 0.27, r=1)
    sw = math.sin(t * 2 * math.pi) * 2
    c.d.line([(cx - 3, s * 0.17), (cx - 9 - sw, s * 0.03)], fill=(140, 230, 220, 255))
    c.d.line([(cx + 3, s * 0.17), (cx + 9 + sw, s * 0.03)], fill=(140, 230, 220, 255))


# ───────────────────────────── floor 3 ─────────────────────────────

def sacabambaspis(c, t, s):
    # Armoured jawless fish: broad head shield, eyes at the very front, fin tail
    body = (130, 160, 200, 255)
    cx = s / 2
    c.shadow(cx, s * 0.6, s * 0.2, s * 0.38)
    sweep = math.sin(t * 2 * math.pi)
    # Scaled trunk tapering into a swept tail fin
    trunk = [(cx - s * 0.13, s * 0.5), (cx + s * 0.13, s * 0.5), (cx + 3 + sweep * 3, s * 0.78), (cx - 3 + sweep * 3, s * 0.78)]
    c.poly(trunk, shade(body, 0.9))
    fin = [(cx - 2 + sweep * 3, s * 0.76), (cx + 2 + sweep * 3, s * 0.76), (cx + sweep * 8 + s * 0.14, s * 0.96), (cx + sweep * 6, s * 0.88), (cx + sweep * 8 - s * 0.14, s * 0.96)]
    c.poly(fin, shade(body, 1.1))
    for i in range(4):
        y = s * 0.55 + i * s * 0.055
        w = s * 0.11 - i * 1.5
        c.d.line([(cx - w + sweep * i * 0.7, y), (cx + w + sweep * i * 0.7, y)], fill=shade(body, 0.7))
    # Head shield, wide and flat, with sensory grooves
    c.ellipse(cx, s * 0.34, s * 0.21, s * 0.2, shade(body, 1.05))
    c.ellipse(cx, s * 0.37, s * 0.13, s * 0.12, shade(body, 1.22), outline=False)
    for k in range(-2, 3):
        c.d.point((cx + k * 3, s * 0.4 + abs(k)), fill=shade(body, 0.7))
    c.d.arc((cx - s * 0.17, s * 0.2, cx + s * 0.17, s * 0.5), 20, 160, fill=shade(body, 0.7))
    # Small forward eyes and mouth slit at the very front
    c.eye(cx - 3, s * 0.16, (255, 240, 140, 255), 0)
    c.eye(cx + 3, s * 0.16, (255, 240, 140, 255), 0)
    c.d.line([(cx - 2, s * 0.13), (cx + 2, s * 0.13)], fill=OUTLINE)


def megalograptus(c, t, s):
    # Sea scorpion: carapace, big spiny grasping limbs, tapering tail, paddles
    body = (190, 120, 90, 255)
    cx = s / 2
    c.shadow(cx, s * 0.6, s * 0.24, s * 0.38)
    # Swimming paddles
    pad = math.sin(t * 2 * math.pi) * 0.35
    for side in (-1, 1):
        a = math.pi / 2 + side * (1.1 + pad)
        c.line([(cx + side * s * 0.12, s * 0.36), (cx + side * s * 0.12 + math.cos(a) * -side * s * 0.0 + side * s * 0.16, s * 0.42 + pad * side * 4)], shade(body, 0.85), 3)
    # Abdomen segments
    for i in range(8):
        y = s * 0.42 + i * s * 0.05
        w = s * 0.15 - i * 1.0
        c.ellipse(cx, y, max(2, w), 3, shade(body, 0.95 if i % 2 else 0.85))
    # Telson with fork
    c.line([(cx, s * 0.8), (cx, s * 0.9)], shade(body, 1.1), 2)
    c.d.line([(cx - 3, s * 0.95), (cx, s * 0.9), (cx + 3, s * 0.95)], fill=OUTLINE)
    # Grasping limbs with spines, opening and closing
    open_ = 0.35 + 0.25 * math.sin(t * 2 * math.pi)
    for side in (-1, 1):
        base = (cx + side * s * 0.1, s * 0.26)
        elbow = (cx + side * s * 0.26, s * 0.16)
        tip = (cx + side * (s * 0.26 - open_ * 8), s * 0.02)
        c.line([base, elbow, tip], (220, 150, 110, 255), 2)
        for k in range(3):
            px = elbow[0] + (tip[0] - elbow[0]) * (k + 1) / 4
            py = elbow[1] + (tip[1] - elbow[1]) * (k + 1) / 4
            c.d.line([(px, py), (px - side * 3, py + 1)], fill=OUTLINE)
    # Carapace
    c.ellipse(cx, s * 0.3, s * 0.15, s * 0.11, body)
    c.eye(cx - 5, s * 0.27, r=1)
    c.eye(cx + 5, s * 0.27, r=1)


# ───────────────────────────── floor 4 ─────────────────────────────

def meganeura(c, t, s):
    # Griffinfly from above: four long wings beating, long abdomen, big eyes
    body = (110, 170, 120, 255)
    cx = s / 2
    c.shadow(cx, s * 0.62, s * 0.4, s * 0.12)
    beat = math.sin(t * 2 * math.pi)
    for row, y0 in enumerate((s * 0.3, s * 0.38)):
        span = s * (0.46 - row * 0.03) * (0.75 + 0.25 * beat)
        lift = beat * 3
        for side in (-1, 1):
            wing = [(cx + side * 2, y0), (cx + side * span, y0 - 3 - lift), (cx + side * (span + 1), y0 + 2 - lift), (cx + side * 2, y0 + 4)]
            layer = Image.new("RGBA", c.img.size, (0, 0, 0, 0))
            ld = ImageDraw.Draw(layer)
            ld.polygon(wing, fill=(200, 240, 255, 120), outline=(60, 90, 110, 255))
            for k in range(1, 4):
                ld.line([(cx + side * 2, y0 + 2), (cx + side * span * k / 4, y0 - lift * k / 4)], fill=(80, 120, 140, 160))
            c.img = Image.alpha_composite(c.img, layer)
            c.d = ImageDraw.Draw(c.img)
    # Abdomen
    for i in range(9):
        y = s * 0.42 + i * s * 0.055
        c.ellipse(cx, y, 2, 3, shade(body, 0.9 if i % 2 else 1.0))
    c.d.line([(cx - 2, s * 0.94), (cx - 3, s * 0.99)], fill=OUTLINE)
    c.d.line([(cx + 2, s * 0.94), (cx + 3, s * 0.99)], fill=OUTLINE)
    # Thorax and head
    c.ellipse(cx, s * 0.33, s * 0.07, s * 0.09, body)
    c.ellipse(cx, s * 0.21, s * 0.08, s * 0.06, shade(body, 0.9))
    c.eye(cx - 4, s * 0.2, (120, 255, 200, 255), 2)
    c.eye(cx + 4, s * 0.2, (120, 255, 200, 255), 2)


def pulmonoscorpius(c, t, s):
    # Giant scorpion: pincers, eight walking legs, tail curling to a stinger
    body = (170, 130, 80, 255)
    cx = s / 2
    c.shadow(cx, s * 0.58, s * 0.3, s * 0.36)
    for i in range(4):
        y = s * 0.34 + i * s * 0.06
        step = math.sin(t * 2 * math.pi + i * 1.5) * 3
        for side in (-1, 1):
            kx = cx + side * s * 0.24
            c.line([(cx + side * s * 0.08, y), (kx, y - 3 + step * side * 0.3), (cx + side * s * 0.34, y + 4 + step)], shade(body, 0.8), 1)
    # Mesosoma
    c.ellipse(cx, s * 0.46, s * 0.12, s * 0.18, body)
    for i in range(5):
        y = s * 0.35 + i * s * 0.05
        c.d.line([(cx - s * 0.1, y), (cx + s * 0.1, y)], fill=shade(body, 0.7))
    # Tail: five segments curling, stinger at the end
    curl = math.sin(t * 2 * math.pi) * 0.25
    x, y, ang = cx, s * 0.63, math.pi / 2
    for k in range(5):
        ang -= 0.32 + curl * 0.2
        nx, ny = x + math.cos(ang) * 4.5, y + math.sin(ang) * 4.5
        c.ellipse((x + nx) / 2, (y + ny) / 2, 2, 2, shade(body, 1.0 if k % 2 else 0.9))
        x, y = nx, ny
    c.ellipse(x, y, 2, 2, (230, 90, 70, 255))
    # Pincers
    snap = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 2)
    for side in (-1, 1):
        arm = [(cx + side * s * 0.08, s * 0.3), (cx + side * s * 0.22, s * 0.2), (cx + side * s * 0.2, s * 0.1)]
        c.line(arm, shade(body, 1.05), 2)
        c.ellipse(cx + side * s * 0.2, s * 0.08, 3, 3, shade(body, 1.15))
        c.d.line([(cx + side * s * 0.2, s * 0.06), (cx + side * (s * 0.2 - 2 - snap * 2), s * 0.0)], fill=OUTLINE, width=1)
        c.d.line([(cx + side * s * 0.21, s * 0.06), (cx + side * (s * 0.21 + 2 + snap), s * 0.0)], fill=OUTLINE, width=1)
    c.ellipse(cx, s * 0.28, s * 0.09, s * 0.07, shade(body, 0.9))
    c.eye(cx - 2, s * 0.26, (255, 120, 90, 255), 1)
    c.eye(cx + 2, s * 0.26, (255, 120, 90, 255), 1)


# ───────────────────────────── floor 5 ─────────────────────────────

def quadruped(c, t, s, body, head_len, head_w, body_len, body_w, tail_len, leg_len, tusks=None, fangs=None, stripes=False):
    cx = s / 2
    c.shadow(cx, s * 0.58, body_w * 1.2, body_len * 0.7)
    top = s * 0.3
    # Legs in a walk cycle (diagonal pairs move together)
    phase = t * 2 * math.pi
    for (fy, side, ph) in ((top + body_len * 0.15, -1, 0), (top + body_len * 0.15, 1, math.pi),
                           (top + body_len * 0.8, -1, math.pi), (top + body_len * 0.8, 1, 0)):
        swing = math.sin(phase + ph) * 3
        hip = (cx + side * body_w * 0.8, fy)
        foot = (cx + side * (body_w + leg_len), fy + swing)
        knee = ((hip[0] + foot[0]) / 2, (hip[1] + foot[1]) / 2 - 2)
        c.line([hip, knee, foot], shade(body, 0.8), 3)
        c.dot(foot[0], foot[1], shade(body, 0.55), 1)
    # Tail swaying
    sway = math.sin(phase) * 3
    c.line([(cx, top + body_len), (cx + sway, top + body_len + tail_len)], shade(body, 0.9), 3)
    # Body
    c.ellipse(cx, top + body_len / 2, body_w, body_len / 2, body)
    c.ellipse(cx, top + body_len / 2 - 1, body_w * 0.45, body_len * 0.38, shade(body, 1.18), outline=False)
    if stripes:
        for i in range(4):
            y = top + body_len * (0.2 + i * 0.18)
            c.d.line([(cx - body_w * 0.8, y), (cx - body_w * 0.3, y + 2)], fill=shade(body, 0.6))
            c.d.line([(cx + body_w * 0.8, y), (cx + body_w * 0.3, y + 2)], fill=shade(body, 0.6))
    # Head
    hy = top - head_len * 0.35
    c.ellipse(cx, hy, head_w, head_len / 2, shade(body, 1.05))
    if tusks:
        for side in (-1, 1):
            c.line([(cx + side * head_w * 0.6, hy - head_len * 0.2), (cx + side * head_w * 0.9, hy - head_len * 0.6)], (245, 235, 200, 255), 1)
    if fangs:
        for side in (-1, 1):
            c.line([(cx + side * 2, hy - head_len * 0.45), (cx + side * 2, hy - head_len * 0.85)], (250, 245, 230, 255), 1)
    # Snout taper and small side eyes
    c.poly([(cx - head_w * 0.6, hy - head_len * 0.15), (cx + head_w * 0.6, hy - head_len * 0.15), (cx + head_w * 0.35, hy - head_len * 0.55), (cx - head_w * 0.35, hy - head_len * 0.55)], shade(body, 1.05), outline=False)
    c.d.point((cx - 1, hy - head_len * 0.45), fill=OUTLINE)
    c.d.point((cx + 1, hy - head_len * 0.45), fill=OUTLINE)
    c.eye(cx - head_w * 0.75, hy + head_len * 0.05, (255, 210, 120, 255), 0)
    c.eye(cx + head_w * 0.75, hy + head_len * 0.05, (255, 210, 120, 255), 0)


def lystrosaurus(c, t, s):
    # Stocky, barrel-bodied, short-tailed, beaked head with two tusks
    quadruped(c, t, s, (180, 150, 110, 255), head_len=s * 0.22, head_w=s * 0.12, body_len=s * 0.42,
              body_w=s * 0.18, tail_len=s * 0.06, leg_len=s * 0.11, tusks=True)


def inostrancevia(c, t, s):
    # Long-skulled sabre-toothed predator, lean body, longer tail
    quadruped(c, t, s, (170, 110, 100, 255), head_len=s * 0.28, head_w=s * 0.1, body_len=s * 0.4,
              body_w=s * 0.14, tail_len=s * 0.2, leg_len=s * 0.13, fangs=True, stripes=True)


# ─────────────── third animal per era (special behaviours) ───────────────

def dickinsonia(c, t, s):
    # Flat oval quilted into many segments either side of a midline
    body = (200, 165, 130, 255)
    cx, cy = s / 2, s / 2
    c.shadow(cx, cy + 3, s * 0.38, s * 0.44)
    breathe = 1 + 0.03 * math.sin(t * 2 * math.pi)
    rx, ry = s * 0.36 * breathe, s * 0.43
    c.ellipse(cx, cy, rx, ry, body)
    n = 16
    for i in range(1, n):
        y = cy - ry + i * 2 * ry / n
        half = rx * math.sqrt(max(0.0, 1 - ((y - cy) / ry) ** 2))
        # Segments curve slightly toward the narrow end, like the fossils
        c.d.line([(cx, y), (cx - half + 1, y + 2)], fill=shade(body, 0.7))
        c.d.line([(cx, y), (cx + half - 1, y + 2)], fill=shade(body, 0.7))
    c.d.line([(cx, cy - ry + 2), (cx, cy + ry - 2)], fill=shade(body, 0.6), width=1)
    c.ellipse(cx, cy - ry * 0.55, rx * 0.25, ry * 0.12, shade(body, 1.15), outline=False)


def wiwaxia(c, t, s):
    # Oval body covered in overlapping scale-like sclerites, two rows of spines
    body = (120, 140, 120, 255)
    cx, cy = s / 2, s * 0.54
    c.shadow(cx, cy + 3, s * 0.28, s * 0.36)
    c.ellipse(cx, cy, s * 0.24, s * 0.34, body)
    for row in range(7):
        y = cy - s * 0.26 + row * s * 0.08
        for col in range(-2, 3):
            x = cx + col * s * 0.08 + (s * 0.04 if row % 2 else 0)
            if abs(x - cx) < s * 0.2:
                c.ellipse(x, y, 3, 2, shade(body, 1.15 if (row + col) % 2 else 0.95), outline=False)
                c.d.arc((x - 3, y - 2, x + 3, y + 2), 0, 180, fill=shade(body, 0.6))
    # Two rows of tall spines, swaying
    sway = math.sin(t * 2 * math.pi) * 1.5
    for i in range(6):
        y = cy - s * 0.22 + i * s * 0.09
        for side in (-1, 1):
            base = (cx + side * s * 0.1, y)
            tip = (cx + side * (s * 0.3 + i % 2 * 3) + sway, y - s * 0.12)
            c.line([base, tip], (200, 210, 170, 255), 1)


def orthoceras(c, t, s):
    # Straight cone-shaped shell, tentacles at the front (head up)
    shell = (200, 175, 140, 255)
    cx = s / 2
    c.shadow(cx, s * 0.6, s * 0.12, s * 0.42)
    top, bottom = s * 0.26, s * 0.95
    c.poly([(cx - s * 0.11, top), (cx + s * 0.11, top), (cx + 1.5, bottom), (cx - 1.5, bottom)], shell)
    # Growth bands and chambers
    for i in range(9):
        y = top + (bottom - top) * (i + 1) / 10
        w = s * 0.11 * (1 - (y - top) / (bottom - top)) + 1
        c.d.line([(cx - w, y), (cx + w, y)], fill=shade(shell, 0.65))
    for i in range(4):
        y = top + (bottom - top) * (0.1 + i * 0.22)
        c.d.line([(cx - 2, y), (cx + 2, y)], fill=(160, 80, 70, 255))
    # Head and wriggling tentacles
    c.ellipse(cx, top - 2, s * 0.09, s * 0.06, (190, 120, 120, 255))
    c.eye(cx - s * 0.06, top - 3, (255, 220, 120, 255), 1)
    c.eye(cx + s * 0.06, top - 3, (255, 220, 120, 255), 1)
    for k in range(-3, 4):
        wig = math.sin(t * 2 * math.pi + k) * 2
        c.d.line([(cx + k * 2, top - 6), (cx + k * 3 + wig, top - s * 0.2)], fill=(210, 140, 140, 255), width=1)


def archimylacris(c, t, s):
    # Carboniferous roachoid: flat oval wings, shield over the head, antennae
    body = (150, 105, 70, 255)
    cx = s / 2
    c.shadow(cx, s * 0.58, s * 0.22, s * 0.34)
    for i in range(3):
        y = s * 0.42 + i * s * 0.1
        step = math.sin(t * 2 * math.pi * 2 + i * 2) * 3
        for side in (-1, 1):
            c.line([(cx + side * s * 0.12, y), (cx + side * s * 0.3, y + 3 + step * side)], shade(body, 0.7), 1)
    c.ellipse(cx, s * 0.58, s * 0.2, s * 0.32, body)
    c.d.line([(cx, s * 0.36), (cx, s * 0.88)], fill=shade(body, 0.6))
    for i in range(4):
        y = s * 0.45 + i * s * 0.1
        c.d.line([(cx - s * 0.16, y), (cx - 2, y - 3)], fill=shade(body, 0.8))
        c.d.line([(cx + s * 0.16, y), (cx + 2, y - 3)], fill=shade(body, 0.8))
    c.ellipse(cx, s * 0.3, s * 0.15, s * 0.08, shade(body, 1.2))
    sw = math.sin(t * 2 * math.pi * 2) * 3
    c.d.line([(cx - 2, s * 0.25), (cx - 10 - sw, s * 0.04)], fill=shade(body, 1.3))
    c.d.line([(cx + 2, s * 0.25), (cx + 10 + sw, s * 0.04)], fill=shade(body, 1.3))


def diictodon(c, t, s):
    # Small burrowing dicynodont: stubby body, short tail, a pair of tusks
    quadruped(c, t, s, (175, 140, 105, 255), head_len=s * 0.2, head_w=s * 0.11, body_len=s * 0.36,
              body_w=s * 0.15, tail_len=s * 0.04, leg_len=s * 0.1, tusks=True)


# Fly-type sheets use 88px frames, pacer-type 104px, matching the originals
SPECIES = {
    "spriggina": (88, spriggina),
    "kimberella": (104, kimberella),
    "opabinia": (88, opabinia),
    "olenoides": (104, olenoides),
    "sacabambaspis": (88, sacabambaspis),
    "megalograptus": (104, megalograptus),
    "meganeura": (88, meganeura),
    "pulmonoscorpius": (104, pulmonoscorpius),
    "lystrosaurus": (88, lystrosaurus),
    "inostrancevia": (104, inostrancevia),
    "dickinsonia": (120, dickinsonia),
    "wiwaxia": (104, wiwaxia),
    "orthoceras": (104, orthoceras),
    "archimylacris": (72, archimylacris),
    "diictodon": (96, diictodon),
}


def main():
    import sys
    only = sys.argv[1:]
    for name, (px, fn) in SPECIES.items():
        if only and name not in only:
            continue
        sheet(name, px, fn)


if __name__ == "__main__":
    main()
