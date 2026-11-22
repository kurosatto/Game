# generate_health_pickups.py
# Health pickup + HUD pip alternatives in the sepia ink sketch style.
# Each design gives a silhouette, a wash and inner pen lines; the same
# pipeline makes the full, half and empty (dashed outline) pips.
#   python3 generate_health_pickups.py <heart|mito|algae> [out_dir]
# Writes pickup_heart.png, pickup_heart_half.png, pickup_heart_empty.png.
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math, sys, os

S = 256
C = S / 2
INK = (69, 41, 23, 255)
PAPER = (240, 226, 196, 255)
DASH = (205, 180, 140, 210)
TAU = math.tau

def wobble_line(d, pts, fill, width):
    d.line(pts, fill=fill, width=width, joint="curve")

def bezier(p0, p1, p2, p3, n=24):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append((u**3*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t**3*p3[0],
                    u**3*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t**3*p3[1]))
    return out

# ---------- designs: each returns (mask L, wash RGBA, lines RGBA, shade L) ----------

def design_heart():
    """Anatomical heart: tilted muscular body, aortic arch with three
    branches, pulmonary trunk, a coronary artery down the front."""
    mask = Image.new("L", (S, S), 0)
    md = ImageDraw.Draw(mask)
    body = (bezier((70, 98), (40, 150), (95, 205), (158, 232))
            + bezier((158, 232), (205, 190), (222, 140), (200, 100))[1:]
            + bezier((200, 100), (175, 78), (100, 74), (70, 98))[1:])
    md.polygon(body, fill=255)
    # aortic arch (thick tube) + its three branches
    arch = bezier((128, 100), (118, 48), (172, 30), (180, 76))
    md.line(arch, fill=255, width=34, joint="curve")
    for x0, y0, x1, y1 in ((134, 52, 128, 18), (152, 44, 156, 12), (168, 50, 182, 22)):
        md.line([(x0, y0), (x1, y1)], fill=255, width=13)
    # pulmonary trunk heading up-left
    pul = bezier((112, 100), (100, 70), (84, 62), (66, 58))
    md.line(pul, fill=255, width=26, joint="curve")
    # vena cava stub on the right
    md.line([(196, 104), (214, 70)], fill=255, width=22)
    wash = Image.new("RGBA", (S, S), (176, 58, 46, 255))
    wd = ImageDraw.Draw(wash)
    # vessels a touch bluer/darker on top, like an anatomy plate
    wd.line(pul, fill=(140, 70, 70, 255), width=26, joint="curve")
    wd.line([(196, 104), (214, 70)], fill=(120, 74, 82, 255), width=22)
    lines = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lines)
    # coronary artery with a side branch, and the groove between chambers
    cor = bezier((150, 98), (130, 140), (150, 180), (138, 214))
    ld.line(cor, fill=INK, width=7, joint="curve")
    ld.line(bezier((140, 150), (160, 160), (180, 168), (192, 160)), fill=INK, width=5, joint="curve")
    ld.line(bezier((120, 106), (100, 112), (88, 126), (86, 140)), fill=INK, width=5, joint="curve")
    # ends of the vessels: open rings
    for (x, y, r) in ((128, 18, 7), (156, 12, 7), (182, 22, 7), (66, 58, 13), (214, 70, 11)):
        ld.ellipse([x - r, y - r, x + r, y + r], outline=INK, width=4)
    shade = Image.new("L", (S, S), 0)
    sd = ImageDraw.Draw(shade)
    sd.polygon(bezier((150, 110), (215, 120), (205, 200), (158, 232))
               + [(158, 232), (130, 215)], fill=255)
    return mask, wash, lines, shade

def design_mito():
    """Mitochondrion: a tilted bean with a double membrane and folded
    cristae inside (the cell's power plant)."""
    ang = math.radians(-32)
    ca, sa = math.cos(ang), math.sin(ang)
    def rot(x, y):
        return (C + x * ca - y * sa, C + x * sa + y * ca)
    def capsule(rx, ry, n=96):
        pts = []
        for i in range(n):
            a = TAU * i / n
            # squarer than an ellipse: a bean/capsule
            cx = math.copysign(abs(math.cos(a)) ** 0.75, math.cos(a)) * rx
            cy = math.copysign(abs(math.sin(a)) ** 0.85, math.sin(a)) * ry
            cy += math.sin(a * 2) * 0  # keep symmetric
            pts.append(rot(cx, cy))
        return pts
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).polygon(capsule(110, 54), fill=255)
    wash = Image.new("RGBA", (S, S), (196, 92, 48, 255))
    wd = ImageDraw.Draw(wash)
    wd.polygon(capsule(96, 41), fill=(222, 150, 96, 255))  # paler matrix
    lines = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lines)
    inner = capsule(96, 41)
    ld.line(inner + [inner[0]], fill=INK, width=5, joint="curve")
    # cristae: folds pushing in from alternating sides
    xs = [-70, -42, -14, 14, 42, 70]
    for i, x in enumerate(xs):
        top = i % 2 == 0
        y0 = -40 if top else 40
        y1 = 10 if top else -10
        w = 9
        p = [rot(x - w, y0), rot(x - w * 0.8, y1), rot(x, y1 + (6 if top else -6)), rot(x + w * 0.8, y1), rot(x + w, y0)]
        ld.line(p, fill=INK, width=5, joint="curve")
    # a few granules / ribosomes in the matrix
    for (x, y) in ((-56, 22), (-28, -24), (0, 26), (28, -26), (56, 22), (84, -6)):
        px, py = rot(x, y)
        ld.ellipse([px - 4, py - 4, px + 4, py + 4], fill=INK)
    shade = Image.new("L", (S, S), 0)
    ImageDraw.Draw(shade).polygon([rot(-120, 20), rot(120, 20), rot(120, 70), rot(-120, 70)], fill=255)
    return mask, wash, lines, shade

def design_algae():
    """Green algal blade (food): a leafy blade on a holdfast stalk with a
    midrib and side veins, curling at the tip."""
    base = (66, 214)
    tip = (206, 44)
    ax, ay = tip[0] - base[0], tip[1] - base[1]
    L = math.hypot(ax, ay)
    ux, uy = ax / L, ay / L
    nx, ny = -uy, ux
    def at(t, side):
        w = 62 * (math.sin(math.pi * min(1, t * 1.05)) ** 0.75) * (1 - 0.25 * t)
        bend = math.sin(t * math.pi) * 16  # blade bows a little
        r = w * side + bend
        # ruffled edge
        r += side * math.sin(t * 38) * 3.5 * (t > 0.08)
        return (base[0] + ux * t * L + nx * r, base[1] + uy * t * L + ny * r)
    n = 60
    left = [at(i / n, 1) for i in range(n + 1)]
    right = [at(i / n, -1) for i in range(n + 1)]
    blade = left + right[::-1]
    mask = Image.new("L", (S, S), 0)
    md = ImageDraw.Draw(mask)
    md.polygon(blade, fill=255)
    stalk = bezier((70, 210), (60, 228), (48, 236), (36, 244))
    md.line(stalk, fill=255, width=14)
    # small holdfast knob
    md.ellipse([24, 234, 46, 252], fill=255)
    wash = Image.new("RGBA", (S, S), (104, 138, 62, 255))
    lines = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lines)
    mid = [at(i / n, 0) for i in range(4, n - 2)]
    ld.line(mid, fill=INK, width=6, joint="curve")
    for k in range(1, 8):
        t = k / 9
        p0 = at(t, 0)
        for side in (1, -1):
            p1 = at(t + 0.07, side * 0.85)
            ld.line([p0, ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2 - 3), p1], fill=INK, width=4)
    shade = Image.new("L", (S, S), 0)
    ImageDraw.Draw(shade).polygon(right + [at(1, 0), at(0, 0)], fill=255)
    return mask, wash, lines, shade

DESIGNS = {"heart": design_heart, "mito": design_mito, "algae": design_algae}

# ---------- shared pipeline ----------

def outline_of(mask, width):
    grown = mask.filter(ImageFilter.MaxFilter(width * 2 + 1))
    return ImageChops.subtract(grown, mask.filter(ImageFilter.MinFilter(3)))

def dashed(ring):
    stripes = Image.new("L", (S, S), 0)
    sd = ImageDraw.Draw(stripes)
    for k in range(-S, 2 * S, 22):
        sd.polygon([(k, 0), (k + 11, 0), (k + 11 - S, S), (k - S, S)], fill=255)
    return ImageChops.multiply(ring, stripes)

def compose(design, fill_left, fill_right):
    mask, wash, lines, shade = design()
    # pull the design inside a margin so the outline fits
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    filled_area = Image.new("L", (S, S), 0)
    fd = ImageDraw.Draw(filled_area)
    if fill_left:
        fd.rectangle([0, 0, C, S], fill=255)
    if fill_right:
        fd.rectangle([C, 0, S, S], fill=255)
    fmask = ImageChops.multiply(mask, filled_area)
    if fill_left or fill_right:
        img.paste(Image.new("RGBA", (S, S), PAPER), (0, 0), fmask)
        img.paste(wash, (0, 0), fmask)
        # pen hatching on the shaded side
        hatch = Image.new("RGBA", (S, S), (69, 41, 23, 150))
        hm = Image.new("L", (S, S), 0)
        hd = ImageDraw.Draw(hm)
        for k in range(-S, 2 * S, 14):
            hd.line([(k, S), (k + S, 0)], fill=255, width=4)
        hm = ImageChops.multiply(ImageChops.multiply(hm, shade), fmask)
        img.paste(hatch, (0, 0), hm)
        lmask = ImageChops.multiply(lines.split()[3], fmask)
        img.paste(lines, (0, 0), lmask)
    ring = outline_of(mask, 5)
    ink_ring = ImageChops.multiply(ring, filled_area)
    dash_ring = ImageChops.subtract(ring, filled_area)
    img.paste(Image.new("RGBA", (S, S), INK), (0, 0), ink_ring)
    img.paste(Image.new("RGBA", (S, S), DASH), (0, 0), dashed(dash_ring))
    if fill_left and not fill_right:
        cut = Image.new("L", (S, S), 0)
        ImageDraw.Draw(cut).rectangle([C - 3, 0, C + 3, S], fill=255)
        img.paste(Image.new("RGBA", (S, S), INK), (0, 0), ImageChops.multiply(cut, mask))
    return img.resize((64, 64), Image.LANCZOS)

if __name__ == "__main__":
    name = sys.argv[1] if len(sys.argv) > 1 else "heart"
    out = sys.argv[2] if len(sys.argv) > 2 else "assets"
    os.makedirs(out, exist_ok=True)
    d = DESIGNS[name]
    compose(d, True, True).save(os.path.join(out, "pickup_heart.png"))
    compose(d, True, False).save(os.path.join(out, "pickup_heart_half.png"))
    compose(d, False, False).save(os.path.join(out, "pickup_heart_empty.png"))
    print(name, "health pips saved to", out)
