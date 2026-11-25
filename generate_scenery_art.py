"""Room obstacles ("scenery") for each era, painted as real things that lived
or lay on that era's sea floor or forest floor.

Writes assets/eras/<era>/<slot>.png and <slot>_2.png (a second variant), at
160x160, for the five slots Obstacle.gd uses: rock, tall, mound, glow, fossil.
Each is drawn at 4x and scaled down for smooth edges, with a soft shadow, a
dark outline, a lit top and a shaded underside to match the room rims from
generate_room_art.py. The object's footprint is centred at (80, 100);
Obstacle.gd shifts the sprite up 20 px so that sits on the collision circle.
Tall slots ("tall", and "mound" in the fern and frond eras) sway in game.

Run from the project root:  python generate_scenery_art.py
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from generate_room_art import ERA_LOOK, ERAS, THEMES, shade_rgb

SIZE = 160
K = 4                      # supersampling
BX, BY = 80, 100           # footprint centre


def P(x, y):
    return (x * K, y * K)


def pts_k(pts):
    return [P(x, y) for x, y in pts]


# Each floor's quiet two-tone theme (keep in step with data/SceneryTheme.gd):
# [dark tone, pale tone, glow tint]. kuro (2026-11-25): obstacles were too
# loud and too crude, so every piece is now pen-and-ink (hatched shading,
# stipple, a wobbly ink line heavier on the shadow side, a hatched cast
# shadow) and recoloured into its floor's theme. Some of the drawing's own
# hue stays (HUE_KEEP) so a sponge still reads as a sponge.
HUE_KEEP = 0.22
HATCH = 15          # 4x px between hatch lines (about 3.7 px on screen)


def _grid():
    n = SIZE * K
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    return yy, xx


_YY, _XX = _grid()
# Diagonal hatching (down-right strokes), cross-hatching, and the flat
# hatching used for cast shadows; each line wobbles a little like a pen
_WOB = np.sin(_YY * 0.045) * 2.2 + np.sin(_XX * 0.031 + 1.3) * 1.6
_HATCH_A = (((_XX + _YY + _WOB) % HATCH) < 3.6).astype(np.float32)
_HATCH_B = (((_XX - _YY + _WOB * 0.7) % HATCH) < 3.2).astype(np.float32)
_HATCH_H = ((((_YY + _WOB * 0.6) % 13)) < 3.2).astype(np.float32)


def _shift(a, dx, dy):
    out = np.zeros_like(a)
    h, w = a.shape
    xs0, xs1 = max(0, dx), min(w, w + dx)
    ys0, ys1 = max(0, dy), min(h, h + dy)
    out[ys0:ys1, xs0:xs1] = a[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out


class Canvas:
    def __init__(self, era):
        self.era = era
        self.theme = THEMES[era]
        self.ink = tuple(int(v * 0.42) for v in self.theme[0])
        self.ol = self.ink
        self.img = Image.new("RGBA", (SIZE * K, SIZE * K), (0, 0, 0, 0))
        self.rng = np.random.default_rng(len(era) * 7)

    # ── building blocks ──
    def mask(self, fn):
        m = Image.new("L", self.img.size, 0)
        fn(ImageDraw.Draw(m))
        return m

    def _layer(self, rgb, alpha):
        out = np.dstack([np.clip(rgb, 0, 255) * np.ones(alpha.shape + (3,), np.float32),
                         np.clip(alpha, 0, 1) * 255]).astype(np.uint8)
        self.img = Image.alpha_composite(self.img, Image.fromarray(out, "RGBA"))

    def shadow(self, rx, ry, cx=BX, cy=BY + 4, alpha=95):
        """A cast shadow drawn the engraver's way: flat hatching, fading out."""
        m = self.mask(lambda d: d.ellipse((*P(cx - rx, cy - ry), *P(cx + rx, cy + ry)), fill=255))
        m = m.filter(ImageFilter.GaussianBlur(2 * K))
        a = np.asarray(m, np.float32) / 255
        ink = np.array(self.ink, np.float32)
        # (kept under the alpha tools/scenery_footprints.py counts as solid)
        self._layer(ink, a * _HATCH_H * 0.14 + a * 0.08)
        # A few pebbles and grit at the foot, so it sits on the ground
        d = ImageDraw.Draw(self.img)
        dk = tuple(self.theme[0])
        for _ in range(int(rx / 6)):
            ang = self.rng.uniform(0, math.tau)
            px = cx + math.cos(ang) * rx * self.rng.uniform(0.75, 1.0)
            py = cy + math.sin(ang) * ry * self.rng.uniform(0.6, 1.0) + 1
            r = self.rng.uniform(0.8, 2.2)
            d.ellipse((*P(px - r, py - r * 0.7), *P(px + r, py + r * 0.7)),
                      fill=tuple(int(v * 1.9) if v * 1.9 < 255 else 255 for v in dk) + (255,),
                      outline=self.ink + (255,), width=K)

    def solid(self, m, col, outline=True, light=1.25, dark=0.62, rim=True, tex=None):
        """Fill a mask as an ink drawing: a pale wash, hatched shade on the
        side away from the light, stipple, and a wobbly ink outline."""
        a = np.asarray(m, dtype=np.float32) / 255
        ys, xs = np.nonzero(a > 0.5)
        if len(xs) == 0:
            return
        x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
        # Light from the top left: a gradient over the shape...
        t = ((_YY - y0) / max(1, y1 - y0)) * 0.7 + ((_XX - x0) / max(1, x1 - x0)) * 0.3
        t = np.clip(t, 0, 1)
        # ...plus the turning-away edges on the shadow side
        inner = np.asarray(m.filter(ImageFilter.GaussianBlur(5 * K)), np.float32) / 255
        lit_edge = _shift(a, 3 * K, 3 * K)  # where the shape is, seen from the light
        away = np.clip(a - np.minimum(a, lit_edge * 0.0 + inner * 1.15), 0, 1)
        shade = np.clip(t * 0.75 + away * 0.9 - (dark - 0.62) * 0.8, 0, 1)
        # Wash: the colour, lightened, with paper grain
        base = np.array(col[:3], np.float32)
        wash = base + (255 - base) * 0.18
        rgb = np.ones(a.shape + (3,), np.float32) * wash
        if tex is not None:
            rgb = rgb * tex[..., None]
        rgb = rgb * (1.0 - 0.18 * shade[..., None])
        self._layer(rgb, a)
        # Hatching where it turns from the light, cross-hatching deeper in
        ink = np.array(self.ink, np.float32)
        h1 = np.clip((shade - 0.32) * 4.0, 0, 1) * _HATCH_A
        h2 = np.clip((shade - 0.62) * 4.0, 0, 1) * _HATCH_B
        self._layer(ink, a * np.clip(h1 * 0.72 + h2 * 0.6, 0, 0.9))
        # Stipple in the half-shade
        n = int(a.sum() / (K * K) * 0.05)
        if n:
            idx = self.rng.integers(0, len(xs), n)
            sx, sy = xs[idx], ys[idx]
            keep = shade[sy, sx] > self.rng.uniform(0.25, 0.9, n)
            d = ImageDraw.Draw(self.img)
            for x, y in zip(sx[keep], sy[keep]):
                d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=self.ink + (150,))
        if outline:
            # Ink line: thin on the lit side, heavier where the shadow falls,
            # with a faint second stroke slightly off, like a quick sketch
            grown = np.asarray(m.filter(ImageFilter.MaxFilter(K + 1)), np.float32) / 255
            heavy = _shift(grown, int(1.2 * K), int(1.2 * K))
            line = np.clip(np.maximum(grown, heavy) - a, 0, 1)
            self._layer(ink, line)
            ghost = np.clip(_shift(grown, -K, int(0.5 * K)) - np.maximum(a, grown), 0, 1)
            self._layer(ink, ghost * 0.35)

    def poly(self, pts, col, **kw):
        self.solid(self.mask(lambda d: d.polygon(pts_k(pts), fill=255)), col, **kw)

    def ellipse(self, cx, cy, rx, ry, col, **kw):
        self.solid(self.mask(lambda d: d.ellipse((*P(cx - rx, cy - ry), *P(cx + rx, cy + ry)), fill=255)), col, **kw)

    def lines(self, segs, col, width, outline=True, glow=False):
        """Thick strokes [(x0,y0,x1,y1)], outlined as one shape."""
        m = self.mask(lambda d: [d.line(P(*s[:2]) + P(*s[2:]), fill=255, width=int(width * K)) for s in segs])
        m = m.filter(ImageFilter.GaussianBlur(0.6 * K))
        self.solid(m, col, outline=outline, rim=False, light=1.15, dark=0.8)

    def draw(self):
        return ImageDraw.Draw(self.img)

    def detail(self, fn):
        """Thin details drawn straight onto the image (at 4x)."""
        fn(self.draw())

    def glow(self, cx, cy, r, col, alpha=150):
        # A faint halo only: the floor's glow tint, far softer than before
        m = self.mask(lambda d: d.ellipse((*P(cx - r, cy - r), *P(cx + r, cy + r)), fill=int(alpha * 0.35)))
        m = m.filter(ImageFilter.GaussianBlur(r * K * 0.5))
        layer = Image.new("RGBA", self.img.size, tuple(self.theme[2]) + (255,))
        layer.putalpha(m)
        self.img = Image.alpha_composite(self.img, layer)

    def done(self):
        """Recolour everything into the floor's theme, then scale down."""
        arr = np.asarray(self.img, np.float32)
        rgb, al = arr[..., :3], arr[..., 3:]
        lum = (rgb @ np.array([0.299, 0.587, 0.114], np.float32)) / 255
        dk, pl = np.array(self.theme[0], np.float32), np.array(self.theme[1], np.float32)
        ink = np.array(self.ink, np.float32)
        # ink-dark -> dark tone -> pale tone across the drawing's values
        v = np.clip((lum - 0.12) / 0.78, 0, 1)[..., None]
        low = ink + (dk - ink) * np.clip(lum[..., None] / 0.3, 0, 1)
        themed = np.where(lum[..., None] < 0.3, low, dk + (pl - dk) * v)
        out = themed * (1 - HUE_KEEP) + rgb * HUE_KEEP
        img = Image.fromarray(np.dstack([np.clip(out, 0, 255), al]).astype(np.uint8), "RGBA")
        return img.resize((SIZE, SIZE), Image.LANCZOS)


def blobby(cx, cy, rx, ry, rng, n=14, wob=0.12, flat_bottom=0.0):
    pts = []
    ph = rng.uniform(0, math.tau)
    for k in range(n):
        a = k / n * math.tau
        r = 1 + wob * math.sin(a * 3 + ph) * rng.uniform(0.5, 1.0)
        y = math.sin(a) * ry * r
        if y > 0:
            y *= 1 - flat_bottom
        pts.append((cx + math.cos(a) * rx * r, cy + y))
    return pts


def noise_tex(rng, scale=24, amount=0.18):
    """Multiplicative blotchy texture, about 1.0 on average."""
    n = SIZE * K
    small = rng.uniform(0, 1, (n // (scale * K) + 2, n // (scale * K) + 2))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)
    v = np.asarray(img, np.float32) / 255
    return 1 - amount / 2 + v * amount


def stipple(c, rng, cx, cy, rx, ry, col, n=40, r=0.8):
    def fn(d):
        for _ in range(n):
            a, rr = rng.uniform(0, math.tau), math.sqrt(rng.uniform(0, 1))
            x, y = cx + math.cos(a) * rx * rr, cy + math.sin(a) * ry * rr
            d.ellipse((*P(x - r, y - r), *P(x + r, y + r)), fill=col)
    c.detail(fn)


def arc(c, box, a0, a1, col, w=1.0):
    c.detail(lambda d: d.arc((*P(*box[:2]), *P(*box[2:])), a0, a1, fill=col, width=int(w * K)))


# ════════════════════════════ shared shapes ════════════════════════════

def boulder(c, rng, col, rx=42, ry=30, cy=BY - 6):
    c.shadow(rx + 4, ry * 0.45)
    pts = blobby(BX, cy, rx, ry, rng, 13, 0.1, flat_bottom=0.35)
    c.poly(pts, col, tex=noise_tex(rng, 10, 0.16))
    # A crack or two
    x = BX + rng.uniform(-12, 12)
    arc(c, (x - 14, cy - 10, x + 14, cy + 14), 200, 300, shade_rgb(col, 0.55) + (255,), 1.2)
    return pts


def slab(c, rng, col, rx=46, ry=26):
    """A flat bedding-plane slab, the bed a fossil lies in."""
    c.shadow(rx + 2, ry * 0.5)
    pts = blobby(BX, BY - 4, rx, ry, rng, 9, 0.08)
    c.poly(pts, col, tex=noise_tex(rng, 8, 0.12), light=1.15)
    # Bedding edge: a thinner, darker layer below
    c.detail(lambda d: d.line(pts_k([(BX - rx * 0.9, BY + ry * 0.45), (BX + rx * 0.85, BY + ry * 0.5)]),
                              fill=shade_rgb(col, 0.6) + (255,), width=K))


# ════════════════════════════ EDIACARAN ════════════════════════════
# Quiet teal shallows; everything sits on pink microbial mats

def ed_rock(c, rng):
    boulder(c, rng, (98, 128, 116))
    # Pink microbial mat draped over the top, wrinkled like elephant skin
    pts = blobby(BX - 4, BY - 22, 30, 14, rng, 12, 0.18)
    c.poly(pts, (214, 146, 156), light=1.2, dark=0.75)
    for k in range(5):
        x = BX - 26 + k * 11 + rng.uniform(-2, 2)
        arc(c, (x - 6, BY - 30, x + 6, BY - 18), 190, 330, (170, 100, 118, 255), 0.9)


def ed_tall(c, rng):
    # Charnia: a fern-like frond on a holdfast disc, built of fractal branches
    c.shadow(16, 6)
    c.ellipse(BX, BY - 2, 14, 7, (170, 132, 140), light=1.15)
    lean = rng.uniform(-6, 6)
    top = (BX + lean, 10)
    left, right = [], []
    for k in range(13):
        t = k / 12
        y = BY - 6 - t * (BY - 16)
        w = 22 * math.sin(min(1, t * 1.15) * math.pi) ** 0.8 + 2
        x = BX + lean * t
        left.append((x - w, y))
        right.append((x + w, y))
    c.poly([(BX - 3, BY - 4)] + left + [top] + right[::-1] + [(BX + 3, BY - 4)], (150, 198, 168), light=1.2, dark=0.7)
    # Primary branches, each split in zig-zag secondaries
    col = (96, 140, 116, 255)

    def fn(d):
        for k in range(1, 12):
            t = k / 12
            y = BY - 6 - t * (BY - 16)
            x = BX + lean * t
            w = 22 * math.sin(min(1, t * 1.15) * math.pi) ** 0.8
            for s in (-1, 1):
                d.line(pts_k([(x, y), (x + s * w * 0.95, y - 5)]), fill=col, width=int(1.2 * K))
                for j in range(1, 4):
                    px = x + s * w * j / 4
                    d.line(pts_k([(px, y - 1.2 * j), (px + s * 2, y + 2.5 - 1.2 * j)]), fill=col, width=int(0.7 * K))
        d.line(pts_k([(BX, BY - 4), top]), fill=(230, 245, 230, 255), width=int(1.4 * K))
    c.detail(fn)


def ed_mound(c, rng):
    # Stromatolites: a cluster of layered microbial domes
    c.shadow(44, 12)
    for dx, r, col in ((-20, 20, (88, 124, 110)), (18, 24, (104, 140, 120)), (-2, 16, (120, 150, 128))):
        cx, cy = BX + dx, BY - r * 0.7 + (6 if r == 16 else 0)
        c.ellipse(cx, cy, r, r * 0.8, col, tex=noise_tex(rng, 6, 0.1))
        for k in (0.8, 0.6, 0.4):
            arc(c, (cx - r * k, cy - r * k * 0.8, cx + r * k, cy + r * k * 0.8), 190, 350, shade_rgb(col, 0.68) + (255,), 1.0)
        c.ellipse(cx - r * 0.2, cy - r * 0.45, r * 0.4, r * 0.22, (218, 150, 160), outline=False, rim=False)


def ed_glow(c, rng):
    # Cyanobacterial mat pumping out oxygen bubbles in the sunlight
    c.shadow(40, 10)
    pts = blobby(BX, BY - 6, 40, 16, rng, 16, 0.2)
    c.poly(pts, (206, 120, 140), tex=noise_tex(rng, 6, 0.25), light=1.15)
    c.poly(blobby(BX - 4, BY - 10, 26, 9, rng, 12, 0.2), (232, 170, 120), outline=False, rim=False)
    for _ in range(9):
        x, y, r = BX + rng.uniform(-30, 30), BY - 10 + rng.uniform(-8, 6), rng.uniform(2.5, 6)
        c.glow(x, y - 2, r * 2.2, (200, 255, 230), 110)
        c.ellipse(x, y - r, r, r, (190, 245, 235), light=1.6, dark=0.85)
        c.detail(lambda d, x=x, y=y, r=r: d.ellipse((*P(x - r * 0.5, y - r * 1.6), *P(x - r * 0.1, y - r * 1.2)), fill=(255, 255, 255, 230)))


def ed_fossil(c, rng):
    # A Dickinsonia print left in the mat-bound sand
    slab(c, rng, (120, 140, 126))
    rx, ry = 26, 16
    m = c.mask(lambda d: d.ellipse((*P(BX - rx, BY - 6 - ry), *P(BX + rx, BY - 6 + ry)), fill=255))
    c.solid(m, (92, 112, 100), outline=False, light=0.9, dark=1.1, rim=False)

    def fn(d):
        d.ellipse((*P(BX - rx, BY - 6 - ry), *P(BX + rx, BY - 6 + ry)), outline=(226, 222, 190, 255), width=K)
        d.line(pts_k([(BX - rx + 3, BY - 6), (BX + rx - 3, BY - 6)]), fill=(226, 222, 190, 255), width=K)
        for k in range(-7, 8):
            x = BX + k * 3.3
            h = ry * math.sqrt(max(0, 1 - (k * 3.3 / rx) ** 2))
            d.line(pts_k([(x, BY - 6 - h + 1), (x, BY - 6 + h - 1)]), fill=(200, 196, 168, 255), width=int(0.8 * K))
    c.detail(fn)


# ════════════════════════════ CAMBRIAN ════════════════════════════
# Sunlit sand, colourful sponges and the first reefs

def cam_rock(c, rng):
    pts = boulder(c, rng, (176, 150, 120))
    # Brachiopod shells and a Chancelloria tuft clinging to it
    for _ in range(4):
        x, y = BX + rng.uniform(-28, 24), BY - 6 + rng.uniform(-16, 4)
        c.ellipse(x, y, 4.5, 3.5, (226, 214, 186), light=1.2)
        c.detail(lambda d, x=x, y=y: [d.line(pts_k([(x, y + 3), (x + dx, y - 3)]), fill=(150, 130, 100, 255), width=int(0.5 * K)) for dx in (-3, 0, 3)])
    x, y = BX + 16, BY - 30
    c.lines([(x, y + 6, x + math.cos(a) * 11, y + 6 + math.sin(a) * 11) for a in np.linspace(-2.8, -0.3, 7)], (230, 200, 140), 1.8)


def cam_tall(c, rng):
    # Archaeocyaths: porous, double-walled cups that built the first reefs
    c.shadow(36, 10)
    for dx, h, w in sorted(((-18, 46, 13), (16, 38, 12), (0, 62, 15)), key=lambda v: -v[1]):
        x = BX + dx
        base = BY - (2 if dx == 0 else 6)
        col = (214, 150, 104) if dx == 0 else (196, 132, 96)
        c.poly([(x - w, base - h), (x + w, base - h), (x + w * 0.4, base), (x - w * 0.4, base)], col, tex=noise_tex(rng, 4, 0.08))
        c.ellipse(x, base - h, w, w * 0.32, col, light=1.3)
        c.ellipse(x, base - h + 1, w * 0.72, w * 0.2, (84, 46, 40), outline=False, rim=False, light=1.0, dark=1.0)

        def fn(d, x=x, h=h, w=w, base=base):
            for j in range(1, 7):
                y = base - h + j * h / 7
                ww = w * (1 - 0.6 * j / 7)
                for i in range(-3, 4):
                    px = x + i * ww / 3.6
                    d.ellipse((*P(px - 0.8, y - 0.8), *P(px + 0.8, y + 0.8)), fill=(120, 70, 52, 255))
        c.detail(fn)


def cam_mound(c, rng):
    # Vauxia: an orange branching sponge
    c.shadow(30, 9)
    segs = []

    def branch(x, y, a, ln, depth):
        ex, ey = x + math.cos(a) * ln, y + math.sin(a) * ln
        segs.append((x, y, ex, ey, depth))
        if depth < 3:
            branch(ex, ey, a - rng.uniform(0.3, 0.55), ln * 0.75, depth + 1)
            branch(ex, ey, a + rng.uniform(0.3, 0.55), ln * 0.75, depth + 1)
    branch(BX, BY, -math.pi / 2, 24, 0)
    for depth, w in ((0, 9), (1, 7.5), (2, 6.5), (3, 5.5)):
        c.lines([s[:4] for s in segs if s[4] == depth], (232, 150, 70), w)
    for s in segs:
        if s[4] == 3:
            c.ellipse(s[2], s[3], 3.4, 2.6, (240, 170, 90), light=1.3)
            c.ellipse(s[2], s[3] - 0.4, 1.6, 1.0, (110, 50, 30), outline=False, rim=False)


def cam_glow(c, rng):
    # A glass sponge: a lattice vase of silica spicules that catches the light
    c.shadow(20, 7)
    c.glow(BX, BY - 40, 34, (190, 240, 255), 120)
    pts = [(BX - 8, BY), (BX - 20, BY - 40), (BX - 18, BY - 66), (BX + 18, BY - 66), (BX + 20, BY - 40), (BX + 8, BY)]
    c.poly(pts, (170, 226, 240), light=1.35, dark=0.8)
    c.ellipse(BX, BY - 66, 18, 5, (120, 180, 200), light=1.4)

    def fn(d):
        for k in range(-5, 6):
            d.line(pts_k([(BX + k * 3.6, BY - 66), (BX + k * 1.4, BY - 2)]), fill=(240, 255, 255, 200), width=int(0.6 * K))
        for j in range(1, 10):
            y = BY - 66 + j * 6.6
            w = 18 + 2 * math.sin(j / 10 * math.pi) - j * 0.9
            d.line(pts_k([(BX - w, y), (BX + w, y)]), fill=(240, 255, 255, 170), width=int(0.6 * K))
        for k in range(10):
            a = -math.pi / 2 + (k - 4.5) * 0.25
            d.line(pts_k([(BX + math.cos(a) * 16, BY - 66), (BX + math.cos(a) * 24, BY - 66 + math.sin(a) * 9)]), fill=(250, 255, 255, 230), width=int(0.5 * K))
    c.detail(fn)


def cam_fossil(c, rng):
    # An Ediacaran frond (Charnia) preserved in an older slab
    slab(c, rng, (176, 156, 126))
    col = (110, 90, 66, 255)
    a = rng.uniform(-0.4, 0.4)
    ax, ay = math.cos(a), math.sin(a)
    x0, y0 = BX - ax * 30, BY - 4 - ay * 8

    def fn(d):
        d.line(pts_k([(x0, y0), (x0 + ax * 60, y0 + ay * 60)]), fill=col, width=int(1.6 * K))
        d.ellipse((*P(x0 - 5, y0 - 3), *P(x0 + 1, y0 + 3)), outline=col, width=K)
        for k in range(1, 14):
            t = k / 14
            px, py = x0 + ax * 60 * t, y0 + ay * 60 * t
            w = 11 * math.sin(min(1, t * 1.2) * math.pi) ** 0.8
            for s in (-1, 1):
                d.line(pts_k([(px, py), (px - s * ay * w + ax * 3, py + s * ax * w * 0.7 + ay * 3)]), fill=col, width=int(1.1 * K))
    c.detail(fn)


# ════════════════════════════ ORDOVICIAN ════════════════════════════
# A deep blue reef of corals, crinoid meadows and bryozoans

def ord_rock(c, rng):
    boulder(c, rng, (124, 136, 160))
    # Crust of honeycomb tabulate coral (Favosites) on top
    pts = blobby(BX + 4, BY - 22, 26, 12, rng, 12, 0.15)
    c.poly(pts, (232, 210, 176), light=1.15)

    def fn(d):
        for i in range(-5, 6):
            for j in range(-2, 3):
                x, y = BX + 4 + i * 4.4 + (j % 2) * 2.2, BY - 22 + j * 3.6
                if ((x - BX - 4) / 24) ** 2 + ((y - BY + 22) / 10) ** 2 < 1:
                    d.regular_polygon((*P(x, y), 1.8 * K), 6, fill=(176, 146, 116, 255))
    c.detail(fn)


def ord_tall(c, rng):
    # Crinoid: a stalked "sea lily" spreading feathery arms to filter food
    c.shadow(14, 5)
    c.ellipse(BX, BY - 2, 9, 4, (150, 136, 170))
    lean = rng.uniform(-8, 8)
    stalk = [(BX + lean * (k / 10) ** 1.5, BY - 2 - k * 6.2) for k in range(11)]
    c.lines([(*stalk[k], *stalk[k + 1]) for k in range(10)], (214, 200, 222), 4.2)

    def disks(d):
        for x, y in stalk[1:]:
            d.line(pts_k([(x - 2.2, y), (x + 2.2, y)]), fill=(150, 130, 170, 255), width=int(0.7 * K))
    c.detail(disks)
    cx, cy = stalk[-1]
    arms = []
    for k in range(10):
        a = -math.pi / 2 + (k - 4.5) * 0.3
        mx, my = cx + math.cos(a) * 16, cy - 6 + math.sin(a) * 14
        ex, ey = cx + math.cos(a) * 26, cy + 4 + math.sin(a) * 14
        arms.append(((cx, cy), (mx, my), (ex, ey)))
    c.lines([(*a[0], *a[1]) for a in arms] + [(*a[1], *a[2]) for a in arms], (226, 120, 168), 3.2)

    def pinnules(d):
        for (x0, y0), (x1, y1), (x2, y2) in arms:
            for seg in (((x0, y0), (x1, y1)), ((x1, y1), (x2, y2))):
                (a0, b0), (a1, b1) = seg
                for t in np.linspace(0.15, 0.95, 5):
                    px, py = a0 + (a1 - a0) * t, b0 + (b1 - b0) * t
                    ang = math.atan2(b1 - b0, a1 - a0)
                    for s in (-1, 1):
                        d.line(pts_k([(px, py), (px + math.cos(ang + s * 1.2) * 3, py + math.sin(ang + s * 1.2) * 3)]),
                               fill=(250, 180, 210, 255), width=int(0.6 * K))
    c.detail(pinnules)
    c.ellipse(cx, cy, 6, 5, (200, 100, 150), light=1.3)


def ord_mound(c, rng):
    # Rugose "horn" corals around a lacy bryozoan fan
    c.shadow(38, 11)
    # Bryozoan fan behind
    fan = [(BX - 4, BY - 8)]
    for k in range(13):
        a = -math.pi / 2 + (k - 6) * 0.17
        fan.append((BX - 4 + math.cos(a) * 34, BY - 12 + math.sin(a) * 40))
    c.poly(fan, (160, 200, 226), light=1.2)

    def lace(d):
        for k in range(13):
            a = -math.pi / 2 + (k - 6) * 0.17
            d.line(pts_k([(BX - 4, BY - 8), (BX - 4 + math.cos(a) * 33, BY - 12 + math.sin(a) * 39)]), fill=(100, 140, 176, 255), width=int(0.6 * K))
        for r in (12, 20, 28, 35):
            d.arc((*P(BX - 4 - r, BY - 12 - r * 1.1), *P(BX - 4 + r, BY - 12 + r * 1.1)), 225, 315, fill=(100, 140, 176, 255), width=int(0.6 * K))
    c.detail(lace)
    for dx, h, a in ((-22, 22, -0.5), (20, 26, 0.45), (2, 18, 0.1)):
        x, y = BX + dx, BY + 2
        tip = (x + math.sin(a) * h, y - math.cos(a) * h)
        perp = (math.cos(a), math.sin(a))
        w = 8
        cup = [(x - 1.5, y), (tip[0] - perp[0] * w, tip[1] - perp[1] * w), (tip[0] + perp[0] * w, tip[1] + perp[1] * w), (x + 1.5, y)]
        c.poly(cup, (214, 170, 120), tex=noise_tex(rng, 3, 0.1))
        c.ellipse(tip[0], tip[1], w, 3.4, (236, 196, 150), light=1.2)
        c.ellipse(tip[0], tip[1], w * 0.65, 2.0, (130, 82, 60), outline=False, rim=False)


def ord_glow(c, rng):
    # A cracked geode: calcite crystals catching the light inside a nodule
    c.shadow(36, 9)
    c.glow(BX, BY - 18, 36, (170, 210, 255), 140)
    c.ellipse(BX, BY - 12, 34, 22, (116, 112, 132), tex=noise_tex(rng, 6, 0.15))
    c.ellipse(BX, BY - 16, 26, 15, (60, 56, 84), outline=False, rim=False, light=0.8, dark=1.2)
    for _ in range(14):
        x, y = BX + rng.uniform(-20, 20), BY - 16 + rng.uniform(-9, 9)
        h, w = rng.uniform(8, 16), rng.uniform(3, 5)
        c.poly([(x - w, y + 3), (x - w, y - h + w), (x, y - h), (x + w, y - h + w), (x + w, y + 3)], (176, 214, 255), light=1.5, dark=0.85)
        c.detail(lambda d, x=x, y=y, h=h: d.line(pts_k([(x, y - h + 1), (x, y + 2)]), fill=(240, 250, 255, 255), width=int(0.6 * K)))


def ord_fossil(c, rng):
    # A Cambrian trilobite (Olenoides) in an old grey slab
    slab(c, rng, (130, 138, 156))
    col = (232, 226, 206)
    cx, cy = BX, BY - 6
    c.ellipse(cx, cy - 10, 13, 7, shade_rgb(col, 0.85), light=1.2)                       # head shield
    c.poly([(cx - 10, cy - 6), (cx + 10, cy - 6), (cx + 6, cy + 12), (cx - 6, cy + 12)], shade_rgb(col, 0.8), light=1.15)

    def fn(d):
        for k in range(7):
            y = cy - 4 + k * 2.4
            w = 10 - k * 0.6
            d.line(pts_k([(cx - w, y), (cx + w, y)]), fill=(140, 136, 130, 255), width=int(0.7 * K))
        d.line(pts_k([(cx - 3.2, cy - 6), (cx - 2.4, cy + 12)]), fill=(140, 136, 130, 255), width=int(0.6 * K))
        d.line(pts_k([(cx + 3.2, cy - 6), (cx + 2.4, cy + 12)]), fill=(140, 136, 130, 255), width=int(0.6 * K))
        for s in (-1, 1):
            d.line(pts_k([(cx + s * 12, cy - 8), (cx + s * 16, cy + 2)]), fill=(226, 220, 200, 255), width=int(0.9 * K))
            d.ellipse((*P(cx + s * 5 - 1.6, cy - 13), *P(cx + s * 5 + 1.6, cy - 10)), fill=(110, 104, 100, 255))
    c.detail(fn)


# ════════════════════════════ CARBONIFEROUS ════════════════════════════
# Coal swamp: giant clubmosses, horsetails, tree ferns, fungus on logs

def carb_rock(c, rng):
    boulder(c, rng, (100, 92, 70))
    # Moss cushion and a sprig of Sphenophyllum
    c.poly(blobby(BX - 6, BY - 24, 28, 11, rng, 14, 0.25), (96, 150, 60), tex=noise_tex(rng, 3, 0.3), light=1.2)
    x, y = BX + 18, BY - 26
    c.lines([(x, y + 8, x + 2, y - 10)], (90, 140, 60), 1.4)
    for k in range(3):
        yy = y + 4 - k * 6
        c.lines([(x + 1, yy, x + 1 + math.cos(a) * 5, yy + math.sin(a) * 3) for a in np.linspace(0, math.tau, 6, endpoint=False)], (120, 176, 70), 1.6, outline=False)


def carb_tall(c, rng):
    # Lepidodendron: a broken clubmoss trunk with diamond leaf-cushion bark
    c.shadow(24, 8)
    roots = [(BX - 6, BY - 6, BX - 26, BY + 4), (BX + 6, BY - 6, BX + 26, BY + 5), (BX, BY - 4, BX + 4, BY + 8)]
    c.lines(roots, (96, 78, 52), 5)
    top = 14
    body = [(BX - 15, BY - 4), (BX - 13, top + 8), (BX - 9, top), (BX - 3, top + 7), (BX + 3, top - 2), (BX + 8, top + 6), (BX + 13, top + 2), (BX + 15, BY - 4)]
    c.poly(body, (104, 86, 56), tex=noise_tex(rng, 5, 0.1))

    def fn(d):
        for j in range(13):
            y = top + 10 + j * 6
            for i in range(-2, 3):
                x = BX + i * 6 + (3 if j % 2 else 0)
                if abs(x - BX) > 12:
                    continue
                d.polygon(pts_k([(x, y - 2.6), (x + 2.2, y), (x, y + 2.6), (x - 2.2, y)]), fill=(70, 56, 36, 255))
                d.point(P(x, y), fill=(150, 130, 90, 255))
    c.detail(fn)
    # Broken top: pale splintered wood
    c.poly([(BX - 9, top + 2), (BX - 3, top + 8), (BX + 3, top), (BX + 8, top + 7), (BX + 3, top + 10), (BX - 6, top + 10)], (200, 176, 130), outline=False, light=1.2)


def carb_tall2(c, rng):
    # Calamites: a giant horsetail, jointed with whorls of needle leaves
    c.shadow(18, 6)
    xs = [BX + rng.uniform(-3, 3) for _ in range(9)]
    segs = [(xs[k], BY - 4 - k * 11, xs[k + 1], BY - 4 - (k + 1) * 11) for k in range(8)]
    c.lines(segs, (120, 150, 70), 6.5)

    def ribs(d):
        for x0, y0, x1, y1 in segs:
            for s in (-1.6, 0, 1.6):
                d.line(pts_k([(x0 + s, y0 - 1), (x1 + s, y1 + 1)]), fill=(90, 120, 50, 255), width=int(0.5 * K))
            d.line(pts_k([(x0 - 3.6, y0), (x0 + 3.6, y0)]), fill=(60, 80, 30, 255), width=int(0.9 * K))
    c.detail(ribs)
    whorl = []
    for k in range(2, 9):
        x, y = xs[k], BY - 4 - k * 11
        ln = 16 - k
        for a in np.linspace(math.pi * 0.05, math.pi * 0.95, 7):
            whorl.append((x, y, x + math.cos(a + math.pi) * ln, y + math.sin(a + math.pi) * ln * 0.45 + 3))
    c.lines(whorl, (130, 190, 80), 1.3, outline=False)


def carb_mound(c, rng):
    # Tree-fern clump: big arching fronds from a low crown
    c.shadow(40, 10)
    for k in range(8):
        a = -math.pi / 2 + (k - 3.5) * 0.42 + rng.uniform(-0.08, 0.08)
        ln = rng.uniform(34, 44)
        ex, ey = BX + math.cos(a) * ln, BY - 10 + math.sin(a) * ln * 0.9
        mx, my = (BX + ex) / 2 + math.cos(a + math.pi / 2) * 3, (BY - 10 + ey) / 2 - 6
        pts_l, pts_r = [], []
        for j in range(12):
            t = j / 11
            px = (1 - t) ** 2 * BX + 2 * (1 - t) * t * mx + t * t * ex
            py = (1 - t) ** 2 * (BY - 10) + 2 * (1 - t) * t * my + t * t * ey
            w = 7 * math.sin(t * math.pi) ** 0.7
            pts_l.append((px - math.sin(a) * w, py + math.cos(a) * w * 0.6))
            pts_r.append((px + math.sin(a) * w, py - math.cos(a) * w * 0.6))
        col = (92, 150, 58) if k % 2 else (112, 170, 66)
        c.poly(pts_l + pts_r[::-1], col, light=1.25, dark=0.65)

        def veins(d, pl=pts_l, pr=pts_r):
            for (x0, y0), (x1, y1) in zip(pl[1:-1], pr[1:-1]):
                d.line(pts_k([(x0, y0), (x1, y1)]), fill=(64, 110, 40, 255), width=int(0.5 * K))
        c.detail(veins)
    c.ellipse(BX, BY - 8, 8, 5, (110, 84, 54))


def carb_glow(c, rng):
    # Glowing fungus shelves on a rotting log (living Mycena glow like this)
    c.shadow(42, 9)
    c.lines([(BX - 40, BY - 2, BX + 40, BY - 10)], (110, 84, 56), 16)

    def bark(d):
        for k in range(8):
            x = BX - 36 + k * 10
            d.line(pts_k([(x, BY - 12 + k * -0.8 + 6), (x + 6, BY - 12 - k * 0.8 + 4)]), fill=(76, 56, 36, 255), width=int(0.8 * K))
    c.detail(bark)
    c.ellipse(BX + 40, BY - 10, 4, 8, (180, 150, 100), light=1.1)
    for x, y, r in ((-20, -12, 10), (2, -18, 12), (22, -20, 8), (-6, -2, 7)):
        cx, cy = BX + x, BY + y
        c.glow(cx, cy, r * 2.4, (180, 255, 120), 120)
        m = c.mask(lambda d, cx=cx, cy=cy, r=r: d.chord((*P(cx - r, cy - r * 0.8), *P(cx + r, cy + r * 0.8)), 180, 360, fill=255))
        c.solid(m, (200, 246, 140), light=1.35, dark=0.8)
        arc(c, (cx - r * 0.7, cy - r * 0.5, cx + r * 0.7, cy + r * 0.5), 200, 340, (150, 210, 100, 255), 0.7)


def carb_fossil(c, rng):
    # An Ordovician orthocone (straight-shelled nautiloid) in a dark shale
    slab(c, rng, (88, 84, 72))
    a = rng.uniform(-0.3, 0.3)
    ax, ay = math.cos(a), math.sin(a)
    x0, y0 = BX - ax * 30, BY - 6 - ay * 10
    pts = [(x0, y0), (x0 + ax * 60 - ay * 7, y0 + ay * 60 + ax * 7 * 0.6), (x0 + ax * 60 + ay * 7, y0 + ay * 60 - ax * 7 * 0.6)]
    c.poly(pts, (220, 212, 186), light=1.15)

    def fn(d):
        for k in range(1, 12):
            t = k / 12
            px, py = x0 + ax * 60 * t, y0 + ay * 60 * t
            w = 7 * t
            d.arc((*P(px - 2, py - w * 0.6), *P(px + 2, py + w * 0.6)), 270, 90, fill=(150, 140, 120, 255), width=int(0.6 * K))
    c.detail(fn)


# ════════════════════════════ PERMIAN ════════════════════════════
# Red beds, dry uplands and the volcanic glow of the Siberian Traps

def perm_rock(c, rng):
    pts = boulder(c, rng, (176, 96, 66), rx=42, ry=28)
    # Cross-bedded red sandstone
    for k in range(4):
        y = BY - 26 + k * 7
        arc(c, (BX - 40, y - 4, BX + 30, y + 10), 190, 340, (140, 70, 50, 255), 0.9)
    c.ellipse(BX + 14, BY - 24, 9, 4, (210, 196, 170), light=1.2)  # a bleached reduction spot


def perm_tall(c, rng):
    # Glossopteris: a small tree with tongue-shaped leaves
    c.shadow(30, 8)
    c.lines([(BX, BY - 2, BX + 1, BY - 44), (BX + 1, BY - 36, BX - 14, BY - 52), (BX + 1, BY - 40, BX + 15, BY - 54)], (110, 76, 56), 5)
    for _ in range(26):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(4, 30)
        cx, cy = BX + math.cos(a) * r, BY - 58 + math.sin(a) * r * 0.55
        ang = math.atan2(cy - (BY - 44), cx - BX) + rng.uniform(-0.4, 0.4)
        ln, w = rng.uniform(9, 13), 3.4
        ux, uy = math.cos(ang), math.sin(ang)
        leaf = [(cx - ux * ln / 2, cy - uy * ln / 2), (cx - uy * w, cy + ux * w), (cx + ux * ln / 2, cy + uy * ln / 2), (cx + uy * w, cy - ux * w)]
        col = (110, 150, 70) if rng.random() < 0.6 else (140, 160, 76)
        c.poly(leaf, col, light=1.2, dark=0.7)
        c.detail(lambda d, leaf=leaf: d.line(pts_k([leaf[0], leaf[2]]), fill=(80, 110, 50, 255), width=int(0.5 * K)))


def perm_mound(c, rng):
    # Walchia: a low early conifer with bottlebrush branches
    c.shadow(34, 9)
    c.lines([(BX, BY - 2, BX, BY - 56)], (100, 70, 50), 4)
    tiers = []
    for k in range(6):
        y = BY - 14 - k * 8
        ln = 30 - k * 4
        for s in (-1, 1):
            tiers.append((BX, y, BX + s * ln, y + 6 - k * 0.5))
    c.lines(tiers, (70, 110, 70), 3.5)

    def needles(d):
        for x0, y0, x1, y1 in tiers:
            for t in np.linspace(0.1, 1, 9):
                px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                for s in (-1, 1):
                    d.line(pts_k([(px, py), (px + 1.6 * (1 if x1 > x0 else -1), py + s * 2.6)]), fill=(120, 170, 100, 255), width=int(0.6 * K))
    c.detail(needles)


def perm_glow(c, rng):
    # A lava-filled fissure in a basalt flow: the Siberian Traps erupting
    c.shadow(42, 11)
    c.glow(BX, BY - 12, 40, (255, 120, 40), 150)
    c.poly(blobby(BX, BY - 10, 42, 20, rng, 10, 0.12), (66, 56, 62), tex=noise_tex(rng, 5, 0.18))
    crack = [(BX - 34, BY - 8), (BX - 18, BY - 16), (BX - 6, BY - 8), (BX + 8, BY - 18), (BX + 20, BY - 10), (BX + 34, BY - 16)]
    m = c.mask(lambda d: d.line(pts_k(crack), fill=255, width=int(7 * K), joint="curve"))
    c.solid(m, (255, 150, 60), outline=False, light=1.5, dark=0.9, rim=False)
    c.detail(lambda d: d.line(pts_k(crack), fill=(255, 236, 170, 255), width=int(2.2 * K), joint="curve"))
    # Cooled ropy (pahoehoe) folds
    for k in range(4):
        x = BX - 26 + k * 16
        arc(c, (x - 8, BY - 4, x + 8, BY + 6), 20, 160, (40, 34, 38, 255), 1.0)


def perm_fossil(c, rng):
    # A Carboniferous seed-fern frond (Neuropteris) in grey shale
    slab(c, rng, (118, 108, 110))
    col = (60, 64, 50)
    a = rng.uniform(-0.3, 0.3)
    ax, ay = math.cos(a), math.sin(a)
    x0, y0 = BX - ax * 28, BY - 6 - ay * 8

    def fn(d):
        d.line(pts_k([(x0, y0), (x0 + ax * 56, y0 + ay * 56)]), fill=col + (255,), width=K)
        for k in range(1, 10):
            t = k / 10
            px, py = x0 + ax * 56 * t, y0 + ay * 56 * t
            for s in (-1, 1):
                ex, ey = px - s * ay * 9 + ax * 3, py + s * ax * 6
                d.ellipse((*P(min(px, ex) - 1, min(py, ey) - 1), *P(max(px, ex) + 1, max(py, ey) + 1)), fill=col + (200,))
    c.detail(fn)


# ════════════════════════════ CARBONIFEROUS SEAS ════════════════════════════
# The Bear Gulch bay and the crinoid meadows: the Age of Crinoids, with
# brachiopod banks, screw-shaped Archimedes bryozoans and Keokuk geodes

def crinoid(c, rng, stalk_col, arm_col, pin_col, cup_col, height=10):
    c.shadow(14, 5)
    c.ellipse(BX, BY - 2, 9, 4, shade_rgb(stalk_col, 0.8))
    lean = rng.uniform(-9, 9)
    stalk = [(BX + lean * (k / height) ** 1.5, BY - 2 - k * 6.2) for k in range(height + 1)]
    c.lines([(*stalk[k], *stalk[k + 1]) for k in range(height)], stalk_col, 4.2)

    def disks(d):
        for x, y in stalk[1:]:
            d.line(pts_k([(x - 2.2, y), (x + 2.2, y)]), fill=shade_rgb(stalk_col, 0.65) + (255,), width=int(0.7 * K))
    c.detail(disks)
    cx, cy = stalk[-1]
    arms = []
    n = 10
    for k in range(n):
        a = -math.pi / 2 + (k - (n - 1) / 2) * 0.32
        mx, my = cx + math.cos(a) * 15, cy - 7 + math.sin(a) * 15
        ex, ey = cx + math.cos(a) * 25, cy + 3 + math.sin(a) * 15
        arms.append(((cx, cy), (mx, my), (ex, ey)))
    c.lines([(*a[0], *a[1]) for a in arms] + [(*a[1], *a[2]) for a in arms], arm_col, 3.0)

    def pinnules(d):
        for (x0, y0), (x1, y1), (x2, y2) in arms:
            for (a0, b0), (a1, b1) in (((x0, y0), (x1, y1)), ((x1, y1), (x2, y2))):
                for t in np.linspace(0.15, 0.95, 5):
                    px, py = a0 + (a1 - a0) * t, b0 + (b1 - b0) * t
                    ang = math.atan2(b1 - b0, a1 - a0)
                    for sg in (-1, 1):
                        d.line(pts_k([(px, py), (px + math.cos(ang + sg * 1.2) * 3, py + math.sin(ang + sg * 1.2) * 3)]),
                               fill=pin_col + (255,), width=int(0.6 * K))
    c.detail(pinnules)
    c.ellipse(cx, cy, 6, 5, cup_col, light=1.3)


def brachiopods(c, rng, n, cx, cy, sx, sy, col):
    """Productid brachiopods: ribbed, rounded shells lying in a bank."""
    for _ in range(n):
        x, y = cx + rng.uniform(-sx, sx), cy + rng.uniform(-sy, sy)
        r = rng.uniform(4.5, 6.5)
        c.ellipse(x, y, r, r * 0.8, col, light=1.25)

        def fn(d, x=x, y=y, r=r):
            for k in range(-2, 3):
                d.line(pts_k([(x + k * r * 0.18, y + r * 0.75), (x + k * r * 0.32, y - r * 0.6)]), fill=shade_rgb(col, 0.6) + (255,), width=int(0.5 * K))
            d.arc((*P(x - r * 0.9, y - r * 0.9), *P(x + r * 0.9, y + r * 0.4)), 200, 340, fill=shade_rgb(col, 0.55) + (255,), width=int(0.5 * K))
        c.detail(fn)


def cs_rock(c, rng):
    boulder(c, rng, (176, 172, 150))
    # A bank of productid brachiopods settled on the limestone
    brachiopods(c, rng, 6, BX, BY - 18, 22, 7, (228, 214, 176))


def cs_rock2(c, rng):
    boulder(c, rng, (150, 160, 150), rx=40, ry=28)
    # Loose crinoid stem pieces lying across it
    for _ in range(3):
        a = rng.uniform(-0.6, 0.6)
        x, y = BX + rng.uniform(-18, 14), BY - 14 + rng.uniform(-8, 6)
        ln = rng.uniform(12, 20)
        c.lines([(x, y, x + math.cos(a) * ln, y + math.sin(a) * ln)], (218, 200, 214), 3.2)
        c.detail(lambda d, x=x, y=y, a=a, ln=ln: [d.line(pts_k([(x + math.cos(a) * t - math.sin(a) * 1.6, y + math.sin(a) * t + math.cos(a) * 1.6),
                                                                      (x + math.cos(a) * t + math.sin(a) * 1.6, y + math.sin(a) * t - math.cos(a) * 1.6)]),
                                                               fill=(140, 120, 140, 255), width=int(0.5 * K)) for t in np.arange(2, ln, 2.4)])


def cs_tall(c, rng):
    # A crinoid, cream stalk and plum arms: the Carboniferous was their heyday
    crinoid(c, rng, (226, 214, 196), (156, 96, 150), (226, 170, 214), (130, 80, 130))


def cs_tall2(c, rng):
    # A second kind, ochre-armed and shorter
    crinoid(c, rng, (212, 196, 170), (214, 150, 80), (250, 206, 140), (180, 110, 60), height=8)


def cs_mound(c, rng):
    # Archimedes: a bryozoan colony with a corkscrew axis and lacy whorls
    c.shadow(26, 8)
    turns = 7
    for k in range(turns):
        y = BY - 6 - k * 9
        w = 22 - k * 1.6
        ph = k * 0.9
        # Each whorl seen edge-on: a tilted lacy disc
        c.ellipse(BX + math.sin(ph) * 2, y, w, 4.2, (176, 206, 186), light=1.25)

        def fn(d, y=y, w=w, ph=ph):
            for i in range(-6, 7):
                x = BX + math.sin(ph) * 2 + i * w / 7
                d.line(pts_k([(x, y - 3), (x + 1, y + 3)]), fill=(100, 140, 120, 255), width=int(0.5 * K))
        c.detail(fn)
    c.lines([(BX, BY, BX + 1, BY - 6 - (turns - 1) * 9 - 4)], (210, 200, 170), 3.6)


def cs_glow(c, rng):
    # A Keokuk geode cracked open: quartz crystals in a limestone nodule
    c.shadow(36, 9)
    c.glow(BX, BY - 18, 36, (190, 255, 230), 140)
    c.ellipse(BX, BY - 12, 34, 22, (160, 150, 130), tex=noise_tex(rng, 6, 0.15))
    c.ellipse(BX, BY - 16, 26, 15, (70, 90, 84), outline=False, rim=False, light=0.8, dark=1.2)
    for _ in range(14):
        x, y = BX + rng.uniform(-20, 20), BY - 16 + rng.uniform(-9, 9)
        h, w = rng.uniform(8, 16), rng.uniform(3, 5)
        c.poly([(x - w, y + 3), (x - w, y - h + w), (x, y - h), (x + w, y - h + w), (x + w, y + 3)], (190, 250, 226), light=1.5, dark=0.85)
        c.detail(lambda d, x=x, y=y, h=h: d.line(pts_k([(x, y - h + 1), (x, y + 2)]), fill=(240, 255, 250, 255), width=int(0.6 * K)))


def cs_fossil(c, rng):
    # The armoured head of a Devonian placoderm (Dunkleosteus) in an old slab
    slab(c, rng, (120, 128, 128))
    col = (226, 218, 196)
    cx, cy = BX, BY - 6
    shield = [(cx - 20, cy + 6), (cx - 22, cy - 6), (cx - 10, cy - 14), (cx + 8, cy - 14), (cx + 22, cy - 6), (cx + 18, cy + 4), (cx + 4, cy + 10)]
    c.poly(shield, shade_rgb(col, 0.88), light=1.15)

    def fn(d):
        ink = (120, 112, 100, 255)
        d.ellipse((*P(cx + 6, cy - 9), *P(cx + 12, cy - 4)), outline=ink, width=int(0.8 * K))   # orbit
        d.line(pts_k([(cx - 14, cy - 2), (cx + 2, cy - 10), (cx + 18, cy - 4)]), fill=ink, width=int(0.6 * K))
        d.line(pts_k([(cx - 4, cy + 8), (cx - 6, cy - 12)]), fill=ink, width=int(0.6 * K))
        # Bony jaw blades with their fang tips
        d.line(pts_k([(cx + 4, cy + 10), (cx + 24, cy + 8), (cx + 27, cy + 3)]), fill=(236, 230, 214, 255), width=int(1.6 * K))
        d.line(pts_k([(cx + 4, cy + 10), (cx + 24, cy + 8), (cx + 27, cy + 3)]), fill=ink, width=int(0.5 * K))
    c.detail(fn)


# ════════════════════════════ PERMIAN SEAS ════════════════════════════
# Sponge and algae reefs like the Capitan Reef of Texas, fusulinid sand

def fusulinids(c, rng, n, cx, cy, sx, sy):
    def fn(d):
        for _ in range(n):
            x, y = cx + rng.uniform(-sx, sx), cy + rng.uniform(-sy, sy)
            a = rng.uniform(0, math.pi)
            dx, dy = math.cos(a) * 2.4, math.sin(a) * 2.4
            d.line(pts_k([(x - dx, y - dy), (x + dx, y + dy)]), fill=(236, 220, 180, 255), width=int(1.4 * K))
            d.line(pts_k([(x - dx * 0.4, y - dy * 0.4), (x + dx * 0.4, y + dy * 0.4)]), fill=(150, 120, 90, 255), width=int(0.4 * K))
    c.detail(fn)


def ps_rock(c, rng):
    # Pale reef limestone studded with rice-grain fusulinids
    boulder(c, rng, (206, 190, 156))
    fusulinids(c, rng, 22, BX, BY - 12, 28, 12)


def ps_rock2(c, rng):
    boulder(c, rng, (190, 160, 130), rx=40, ry=27)
    brachiopods(c, rng, 4, BX - 2, BY - 16, 18, 6, (232, 206, 170))
    fusulinids(c, rng, 10, BX, BY - 8, 26, 8)


def ps_tall(c, rng):
    # A sphinctozoan sponge: a column of hollow, bead-like chambers
    c.shadow(16, 6)
    x, y = BX, BY - 2
    lean = rng.uniform(-0.18, 0.18)
    for k in range(6):
        r = 10 - k * 0.5 + rng.uniform(-0.6, 0.6)
        cx, cy = x + math.sin(lean) * k * 10, y - 6 - k * 11
        c.ellipse(cx, cy, r, 7.5, (218, 150, 96), light=1.25, tex=noise_tex(rng, 3, 0.1))

        def fn(d, cx=cx, cy=cy, r=r):
            for i in range(-2, 3):
                d.ellipse((*P(cx + i * r * 0.32 - 0.9, cy - 1.4), *P(cx + i * r * 0.32 + 0.9, cy + 0.4)), fill=(130, 70, 50, 255))
        c.detail(fn)
    top = (x + math.sin(lean) * 50, y - 6 - 5 * 11 - 6)
    c.ellipse(top[0], top[1], 5, 2.2, (110, 56, 40), outline=False, rim=False)


def ps_tall2(c, rng):
    # A tall vase sponge with a wide mouth
    c.shadow(18, 6)
    h = rng.uniform(56, 66)
    pts = [(BX - 7, BY), (BX - 14, BY - h * 0.5), (BX - 16, BY - h), (BX + 16, BY - h), (BX + 14, BY - h * 0.5), (BX + 7, BY)]
    c.poly(pts, (226, 176, 110), tex=noise_tex(rng, 4, 0.1))
    c.ellipse(BX, BY - h, 16, 5, (236, 196, 130), light=1.3)
    c.ellipse(BX, BY - h + 0.5, 11, 3, (110, 60, 40), outline=False, rim=False)
    stipple(c, rng, BX, BY - h * 0.5, 11, h * 0.4, (150, 96, 60, 255), 36, 0.9)


def ps_mound(c, rng):
    # A thicket of red calcareous algae and Tubiphytes crusts
    c.shadow(30, 9)
    segs = []

    def branch(x, y, a, ln, depth):
        ex, ey = x + math.cos(a) * ln, y + math.sin(a) * ln
        segs.append((x, y, ex, ey, depth))
        if depth < 3:
            branch(ex, ey, a - rng.uniform(0.35, 0.6), ln * 0.72, depth + 1)
            branch(ex, ey, a + rng.uniform(0.35, 0.6), ln * 0.72, depth + 1)
    branch(BX - 8, BY, -math.pi / 2 - 0.2, 22, 0)
    branch(BX + 10, BY, -math.pi / 2 + 0.25, 18, 1)
    for depth, w in ((0, 8), (1, 6.5), (2, 5.5), (3, 4.5)):
        c.lines([sg[:4] for sg in segs if sg[4] == depth], (190, 86, 78), w)
    for sg in segs:
        if sg[4] == 3:
            c.ellipse(sg[2], sg[3], 3.0, 2.4, (226, 130, 120), light=1.3)


def ps_glow(c, rng):
    # A glass sponge vase, its silica lattice catching the light
    c.shadow(20, 7)
    c.glow(BX, BY - 40, 34, (255, 236, 190), 120)
    pts = [(BX - 8, BY), (BX - 20, BY - 40), (BX - 18, BY - 66), (BX + 18, BY - 66), (BX + 20, BY - 40), (BX + 8, BY)]
    c.poly(pts, (240, 226, 190), light=1.35, dark=0.8)
    c.ellipse(BX, BY - 66, 18, 5, (200, 180, 140), light=1.4)

    def fn(d):
        for k in range(-5, 6):
            d.line(pts_k([(BX + k * 3.6, BY - 66), (BX + k * 1.4, BY - 2)]), fill=(255, 250, 235, 200), width=int(0.6 * K))
        for j in range(1, 10):
            y = BY - 66 + j * 6.6
            w = 18 + 2 * math.sin(j / 10 * math.pi) - j * 0.9
            d.line(pts_k([(BX - w, y), (BX + w, y)]), fill=(255, 250, 235, 170), width=int(0.6 * K))
    c.detail(fn)


def ps_fossil(c, rng):
    # A Carboniferous goniatite: an ammonoid with zig-zag chamber seams
    slab(c, rng, (176, 160, 132))
    cx, cy = BX + rng.uniform(-4, 4), BY - 6
    c.ellipse(cx, cy, 17, 14, (230, 216, 184), light=1.2)

    def fn(d):
        ink = (140, 116, 90, 255)
        pts = [(cx + math.cos(a) * (15 - a * 1.1), cy + math.sin(a) * (12 - a * 0.9)) for a in np.linspace(0, 11.5, 60)]
        d.line(pts_k(pts), fill=ink, width=int(0.8 * K))
        for k in range(10):
            a = k / 10 * math.tau
            r0, r1 = 7, 15
            mx, my = cx + math.cos(a + 0.15) * 11, cy + math.sin(a + 0.15) * 9
            d.line(pts_k([(cx + math.cos(a) * r0, cy + math.sin(a) * r0 * 0.8), (mx, my),
                          (cx + math.cos(a) * r1, cy + math.sin(a) * r1 * 0.8)]), fill=ink, width=int(0.5 * K))
    c.detail(fn)


SLOTS = {
    "ediacaran": {"rock": ed_rock, "tall": ed_tall, "mound": ed_mound, "glow": ed_glow, "fossil": ed_fossil},
    "cambrian": {"rock": cam_rock, "tall": cam_tall, "mound": cam_mound, "glow": cam_glow, "fossil": cam_fossil},
    "ordovician": {"rock": ord_rock, "tall": ord_tall, "mound": ord_mound, "glow": ord_glow, "fossil": ord_fossil},
    "carboniferous": {"rock": carb_rock, "tall": carb_tall, "mound": carb_mound, "glow": carb_glow, "fossil": carb_fossil},
    "permian": {"rock": perm_rock, "tall": perm_tall, "mound": perm_mound, "glow": perm_glow, "fossil": perm_fossil},
    "carboniferous_sea": {"rock": cs_rock, "tall": cs_tall, "mound": cs_mound, "glow": cs_glow, "fossil": cs_fossil},
    "permian_sea": {"rock": ps_rock, "tall": ps_tall, "mound": ps_mound, "glow": ps_glow, "fossil": ps_fossil},
}
# Second variants that are a different plant, not just a reshuffle
VARIANT_2 = {("carboniferous", "tall"): carb_tall2,
             ("carboniferous_sea", "tall"): cs_tall2, ("carboniferous_sea", "rock"): cs_rock2,
             ("permian_sea", "tall"): ps_tall2, ("permian_sea", "rock"): ps_rock2}


def main():
    # ONLY=carboniferous_sea,permian_sea redraws just those eras
    only = [e for e in os.environ.get("ONLY", "").split(",") if e]
    for i, era in enumerate(ERAS):
        if only and era not in only:
            continue
        out = os.path.join("assets", "eras", era)
        os.makedirs(out, exist_ok=True)
        for slot, fn in SLOTS[era].items():
            for v in (1, 2):
                rng = np.random.default_rng(1000 + i * 50 + list(SLOTS[era]).index(slot) * 5 + v)
                c = Canvas(era)
                VARIANT_2.get((era, slot), fn)(c, rng) if v == 2 else fn(c, rng)
                name = slot + ("" if v == 1 else "_2") + ".png"
                c.done().save(os.path.join(out, name))
        print("  wrote", out)
    if not only or "ediacaran" in only:
        charnia_sheet()


def charnia_sheet():
    # The Ediacaran Charnia fronds are animals you can fight (Enemy.gd
    # "frond"), so their painted art doubles as a 4-frame fauna sheet:
    # frames 0/2 are variant 1, frames 1/3 variant 2. Footprint at (80,100).
    era = os.path.join("assets", "eras", "ediacaran")
    a = Image.open(os.path.join(era, "tall.png")).convert("RGBA")
    b = Image.open(os.path.join(era, "tall_2.png")).convert("RGBA")
    sheet = Image.new("RGBA", (a.width * 4, a.height), (0, 0, 0, 0))
    for i, im in enumerate((a, b, a, b)):
        sheet.paste(im, (i * a.width, 0))
    sheet.save(os.path.join("assets", "fauna", "charnia_sheet.png"))
    print("  wrote assets/fauna/charnia_sheet.png")


if __name__ == "__main__":
    main()
