# generate_ui_icons.py
"""
Small picture icons for the pause screen (HUD.gd), so it shows what you have
instead of describing it in sentences:
  assets/ui/icons/adapt_<id>.png  one per adaptation in data/Adaptations.gd
  assets/ui/icons/item_<id>.png   one per treasure item in data/Items.gd
  assets/ui/icons/stat_<name>.png damage, speed, sight, sense, attack
Each is drawn 4x large and scaled down to 96 px for smooth edges, in the
organic UI palette (data/UIStyle.gd): cream outlines, warm fills.
Run: python3 generate_ui_icons.py
"""

import math
import os
from PIL import Image, ImageDraw

S = 96
K = 4  # supersampling
W = S * K
OUT = "assets/ui/icons"

INK = (14, 26, 23, 255)
CREAM = (250, 240, 214, 255)
SUN = (255, 204, 102, 255)
LEAF = (158, 237, 128, 255)
AQUA = (115, 230, 217, 255)
CORAL = (255, 120, 102, 255)
MOSS = (148, 204, 140, 255)
PINK = (240, 150, 160, 255)
RED = (190, 50, 60, 255)
BONE = (225, 215, 190, 255)
VIOLET = (190, 150, 240, 255)
OL = 7 * K // 2  # outline width


def p(x, y):
    """Design coordinates are 0..96; scale to the big canvas."""
    return (x * K, y * K)


def pts(seq):
    return [p(x, y) for x, y in seq]


def new():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def save(img, name):
    img = img.resize((S, S), Image.LANCZOS)
    img.save(os.path.join(OUT, name + ".png"))


def ellipse(d, box, fill, outline=INK, width=OL):
    d.ellipse([p(box[0], box[1]), p(box[2], box[3])], fill=fill, outline=outline, width=width)


def poly(d, seq, fill, outline=INK, width=OL):
    d.polygon(pts(seq), fill=fill)
    d.line(pts(seq + [seq[0]]), fill=outline, width=width, joint="curve")


def line(d, seq, fill, width):
    d.line(pts(seq), fill=fill, width=int(width * K), joint="curve")
    r = width * K / 2
    for x, y in (seq[0], seq[-1]):
        d.ellipse([x * K - r, y * K - r, x * K + r, y * K + r], fill=fill)


def stroke(d, seq, fill, width):
    """A line with a dark rim around it."""
    line(d, seq, INK, width + 3.5)
    line(d, seq, fill, width)


def bolt(d, cx, cy, s, fill):
    seq = [(cx + 4 * s, cy - 22 * s), (cx - 10 * s, cy + 2 * s), (cx - 1 * s, cy + 2 * s),
           (cx - 5 * s, cy + 22 * s), (cx + 10 * s, cy - 3 * s), (cx + 1 * s, cy - 3 * s)]
    poly(d, seq, fill)


def drop(d, cx, cy, r, fill):
    seq = [(cx, cy - r * 1.7)]
    for i in range(0, 181, 15):
        a = math.radians(i)
        seq.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    seq = [seq[0]] + sorted(seq[1:], key=lambda q: -math.atan2(q[1] - cy, q[0] - cx))
    poly(d, seq, fill)


def eye(d, cx, cy, w, fill_iris):
    up = [(cx - w + i * w / 10, cy - math.sin(math.pi * i / 20) * w * 0.55) for i in range(21)]
    dn = [(cx + w - i * w / 10, cy + math.sin(math.pi * i / 20) * w * 0.55) for i in range(21)]
    poly(d, up + dn, CREAM)
    ellipse(d, (cx - w * 0.42, cy - w * 0.42, cx + w * 0.42, cy + w * 0.42), fill_iris, width=OL - 4)
    ellipse(d, (cx - w * 0.18, cy - w * 0.18, cx + w * 0.18, cy + w * 0.18), INK, width=1)
    ellipse(d, (cx - w * 0.3, cy - w * 0.32, cx - w * 0.1, cy - w * 0.12), CREAM, width=1)


# ---------------------------------------------------------------- adaptations

def muscle():
    img, d = new()
    # a spindle of muscle fibres
    seq = [(14, 62), (30, 36), (54, 26), (80, 28), (84, 40), (64, 52), (40, 70), (20, 76)]
    poly(d, seq, CORAL)
    for t in (0.3, 0.5, 0.7):
        a = (14 + (80 - 14) * t, 76 - (76 - 28) * t - 10)
        line(d, [(a[0] - 12, a[1] + 16), (a[0] + 10, a[1] - 10)], (255, 175, 160, 255), 3)
    ellipse(d, (8, 64, 24, 80), BONE)
    ellipse(d, (76, 22, 92, 38), BONE)
    return img


def mitochondria():
    img, d = new()
    ellipse(d, (8, 26, 88, 70), CORAL)
    ellipse(d, (16, 33, 80, 63), (255, 190, 160, 255), width=OL - 3)
    # folded cristae
    seq = []
    for i in range(41):
        x = 20 + i * 1.5
        seq.append((x, 48 + math.sin(i / 40 * math.pi * 5) * 10))
    line(d, seq, CORAL, 4)
    return img


def myoglobin():
    img, d = new()
    drop(d, 40, 56, 22, RED)
    ellipse(d, (28, 52, 38, 62), (240, 120, 120, 255), width=1)
    # speed lines
    for y, l in ((30, 20), (44, 26), (58, 18)):
        stroke(d, [(68, y), (68 + l, y)], SUN, 4)
    return img


def body_wall():
    img, d = new()
    seq = [(48, 10), (82, 22), (78, 56), (48, 88), (18, 56), (14, 22)]
    poly(d, seq, MOSS)
    inner = [(48, 24), (70, 32), (67, 54), (48, 74), (29, 54), (26, 32)]
    poly(d, inner, LEAF, width=OL - 3)
    ellipse(d, (40, 38, 56, 54), PINK, width=OL - 3)
    return img


def fast_twitch():
    img, d = new()
    for y, l in ((30, 26), (50, 34), (70, 22)):
        stroke(d, [(8, y), (8 + l, y)], AQUA, 4)
    bolt(d, 60, 48, 1.7, SUN)
    return img


def ion_channels():
    img, d = new()
    # membrane band with pores
    d.rectangle([p(6, 40), p(90, 58)], fill=SUN, outline=INK, width=OL)
    for x in (22, 48, 74):
        d.rectangle([p(x - 6, 36), p(x + 6, 62)], fill=AQUA, outline=INK, width=OL - 3)
    for x, y in ((22, 22), (48, 18), (74, 22), (35, 78), (61, 78)):
        line(d, [(x - 6, y), (x + 6, y)], CREAM, 3.5)
        line(d, [(x, y - 6), (x, y + 6)], CREAM, 3.5)
    return img


def reach():
    img, d = new()
    seq = [(12, 84)]
    for i in range(1, 30):
        t = i / 29
        seq.append((12 + 70 * t, 84 - 70 * t + math.sin(t * math.pi * 2) * 14))
    stroke(d, seq, PINK, 9)
    for i in range(4, 28, 5):
        x, y = seq[i]
        ellipse(d, (x - 3, y - 3, x + 3, y + 3), CREAM, width=1)
    return img


def regeneration():
    img, d = new()
    # a sea star with one arm regrowing
    cx, cy = 48, 50
    seq = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = (38 if i != 4 else 20) if i % 2 == 0 else 15
        seq.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    poly(d, seq, SUN)
    a = -math.pi / 2 + 4 * math.pi / 5
    tip = (cx + 22 * math.cos(a), cy + 22 * math.sin(a))
    ellipse(d, (tip[0] - 6, tip[1] - 6, tip[0] + 6, tip[1] + 6), LEAF, width=OL - 3)
    ellipse(d, (cx - 6, cy - 6, cx + 6, cy + 6), CORAL, width=OL - 4)
    return img


def gut():
    img, d = new()
    seq = []
    for i in range(140):
        t = i / 139
        a = t * math.pi * 5
        r = 6 + 30 * t
        seq.append((48 + r * math.cos(a), 48 + r * math.sin(a) * 0.85))
    stroke(d, seq, PINK, 8)
    return img


def toxins():
    img, d = new()
    drop(d, 48, 56, 25, LEAF)
    ellipse(d, (36, 50, 46, 60), INK, width=1)
    ellipse(d, (51, 50, 61, 60), INK, width=1)
    line(d, [(40, 70), (56, 70)], INK, 3)
    return img


def senses():
    img, d = new()
    eye(d, 48, 48, 38, AQUA)
    return img


def mass():
    img, d = new()
    seq = [(16, 84), (22, 40), (36, 32), (60, 32), (74, 40), (80, 84)]
    poly(d, seq, (150, 150, 140, 255))
    d.arc([p(34, 10), p(62, 40)], 180, 360, fill=INK, width=OL + 6)
    d.arc([p(34, 10), p(62, 40)], 180, 360, fill=BONE, width=OL)
    line(d, [(30, 70), (66, 70)], (110, 110, 105, 255), 4)
    return img


def armour():
    img, d = new()
    for cx, cy in ((35, 26), (61, 26), (22, 48), (48, 48), (74, 48), (35, 70), (61, 70)):
        seq = [(cx + 13 * math.cos(math.radians(60 * i + 30)), cy + 13 * math.sin(math.radians(60 * i + 30))) for i in range(6)]
        poly(d, seq, BONE, width=OL - 3)
    return img


def autotomy():
    img, d = new()
    # a lizard-ish tail coming apart at a fracture plane
    for i, (cx, cy) in enumerate(((22, 72), (38, 60), (56, 50), (78, 40))):
        r = 12 - i * 1.5
        ellipse(d, (cx - r, cy - r, cx + r, cy + r), SUN if i < 2 else MOSS, width=OL - 3)
    line(d, [(44, 38), (50, 70)], CORAL, 4)
    return img


def mauthner():
    img, d = new()
    ellipse(d, (10, 30, 40, 60), VIOLET)
    for a in (200, 240, 140):
        r = math.radians(a)
        line(d, [(25 + 14 * math.cos(r), 45 + 14 * math.sin(r)), (25 + 26 * math.cos(r), 45 + 26 * math.sin(r))], VIOLET, 4)
    stroke(d, [(40, 45), (60, 45), (86, 45)], VIOLET, 6)
    bolt(d, 70, 24, 0.9, SUN)
    return img


def serrated():
    img, d = new()
    seq = [(10, 72), (86, 72), (86, 58)]
    x = 86
    while x > 10:
        seq.append((x - 7, 36))
        seq.append((x - 14, 58))
        x -= 14
    poly(d, seq, BONE)
    return img


def symbionts():
    img, d = new()
    ellipse(d, (10, 10, 86, 86), (90, 140, 110, 255))
    for x, y, a in ((32, 34, 20), (60, 30, -30), (50, 56, 60), (28, 62, -10), (66, 64, 30)):
        r = math.radians(a)
        dx, dy = 8 * math.cos(r), 8 * math.sin(r)
        stroke(d, [(x - dx, y - dy), (x + dx, y + dy)], LEAF, 6)
    return img


def thorns():
    img, d = new()
    seq = []
    for i in range(24):
        a = i * math.pi / 12
        r = 40 if i % 2 == 0 else 22
        seq.append((48 + r * math.cos(a), 48 + r * math.sin(a)))
    poly(d, seq, SUN)
    ellipse(d, (34, 34, 62, 62), CORAL, width=OL - 3)
    return img


def camouflage():
    img, d = new()
    ellipse(d, (8, 18, 88, 78), (120, 150, 100, 255))
    for x, y, r, c in ((30, 36, 10, (80, 105, 70, 255)), (58, 34, 8, (170, 180, 120, 255)),
                       (44, 58, 12, (80, 105, 70, 255)), (70, 56, 7, (170, 180, 120, 255)),
                       (22, 56, 6, (170, 180, 120, 255))):
        ellipse(d, (x - r, y - r, x + r, y + r), c, outline=c, width=1)
    eye(d, 66, 44, 9, SUN)
    return img


def electrocytes():
    img, d = new()
    for i in range(5):
        x = 14 + i * 12
        d.rounded_rectangle([p(x, 26), p(x + 9, 70)], radius=3 * K, fill=AQUA, outline=INK, width=OL - 3)
    bolt(d, 78, 48, 1.1, SUN)
    return img



# ---------------------------------------------------------------- items
# Treasure-room finds (data/Items.gd); also drawn on the item pedestal.

def item_onion():
    img, d = new()
    ellipse(d, (8, 8, 88, 88), (90, 170, 120, 255))
    seq = []
    for i in range(61):
        a = i / 60 * math.pi * 1.6 + 0.4
        seq.append((48 + 28 * math.cos(a), 48 + 28 * math.sin(a)))
    stroke(d, seq, CREAM, 5)
    poly(d, [(seq[-1][0] + 9, seq[-1][1] - 2), (seq[-1][0] - 6, seq[-1][1] - 10), (seq[-1][0] - 2, seq[-1][1] + 9)], CREAM, width=OL - 3)
    for x, y in ((40, 40), (56, 52), (44, 58)):
        ellipse(d, (x - 6, y - 6, x + 6, y + 6), LEAF, width=OL - 4)
    return img


def item_eye():
    img, d = new()
    for cx, cy in ((48, 28), (26, 62), (70, 62)):
        ellipse(d, (cx - 17, cy - 17, cx + 17, cy + 17), AQUA)
        ellipse(d, (cx - 7, cy - 7, cx + 7, cy + 7), INK, width=1)
        ellipse(d, (cx - 11, cy - 12, cx - 4, cy - 5), CREAM, width=1)
    return img


def item_hormones():
    img, d = new()
    # a gland pouring droplets, with a flash
    ellipse(d, (10, 14, 58, 52), CORAL)
    ellipse(d, (20, 22, 40, 36), (255, 175, 160, 255), width=1)
    for x, y in ((26, 66), (44, 78)):
        drop(d, x, y, 8, SUN)
    bolt(d, 72, 50, 1.3, SUN)
    return img


def item_cells():
    img, d = new()
    # two copies of a coiled chromosome pair
    for cx in (32, 64):
        stroke(d, [(cx - 12, 18), (cx + 12, 78)], VIOLET, 11)
        stroke(d, [(cx + 12, 18), (cx - 12, 78)], VIOLET, 11)
        ellipse(d, (cx - 6, 42, cx + 6, 54), SUN, width=OL - 4)
    return img


def item_plasmid():
    img, d = new()
    # rod bacterium with a ring of DNA beside it
    d.rounded_rectangle([p(8, 50), p(54, 82)], radius=16 * K, fill=MOSS, outline=INK, width=OL)
    ellipse(d, (50, 10, 90, 50), None, outline=INK, width=OL + 10)
    ellipse(d, (50, 10, 90, 50), None, outline=SUN, width=OL + 2)
    for a in range(0, 360, 45):
        r = math.radians(a)
        x, y = 70 + 20 * math.cos(r), 30 + 20 * math.sin(r)
        ellipse(d, (x - 3, y - 3, x + 3, y + 3), CORAL, width=1)
    stroke(d, [(54, 54), (62, 46)], CREAM, 3)
    return img


def item_kleptoplasty():
    img, d = new()
    # a leaf-green sea slug with chloroplast dots and a sun
    ellipse(d, (62, 6, 90, 34), SUN)
    seq = [(8, 70), (20, 52), (40, 46), (62, 50), (80, 60), (88, 74), (60, 80), (30, 82)]
    poly(d, seq, (90, 175, 80, 255))
    for x, y in ((28, 64), (42, 58), (56, 62), (70, 68), (40, 72), (58, 74)):
        ellipse(d, (x - 4, y - 4, x + 4, y + 4), LEAF, width=1)
    stroke(d, [(80, 60), (88, 46)], (90, 175, 80, 255), 4)
    return img


def item_ink_sac():
    img, d = new()
    for x, y, r in ((34, 56, 24), (60, 46, 22), (52, 70, 18), (24, 36, 13)):
        ellipse(d, (x - r, y - r, x + r, y + r), (50, 35, 80, 255))
    ellipse(d, (54, 40, 64, 50), (110, 90, 150, 255), width=1)
    drop(d, 76, 20, 9, VIOLET)
    return img


def item_nematocysts():
    img, d = new()
    # a coiled stinging capsule firing its thread
    ellipse(d, (8, 30, 50, 80), AQUA)
    seq = []
    for i in range(50):
        t = i / 49
        a = t * math.pi * 4
        seq.append((29 + (14 - 10 * t) * math.cos(a), 55 + (14 - 10 * t) * math.sin(a)))
    line(d, seq, (40, 120, 120, 255), 3)
    seq = [(40, 36)]
    for i in range(1, 20):
        t = i / 19
        seq.append((40 + 46 * t, 36 - 26 * t + math.sin(t * math.pi * 3) * 5))
    stroke(d, seq, CREAM, 4)
    poly(d, [(86, 6), (80, 18), (90, 16)], CORAL, width=OL - 4)
    return img


def item_glow_bacteria():
    img, d = new()
    ellipse(d, (6, 6, 90, 90), (40, 70, 110, 255), outline=(40, 70, 110, 255), width=1)
    ellipse(d, (20, 20, 76, 76), (120, 210, 255, 255))
    ellipse(d, (32, 32, 64, 64), (220, 250, 255, 255), outline=(220, 250, 255, 255), width=1)
    for x, y, a in ((30, 40, 30), (60, 34, -20), (48, 60, 80), (64, 58, 10)):
        r = math.radians(a)
        stroke(d, [(x - 5 * math.cos(r), y - 5 * math.sin(r)), (x + 5 * math.cos(r), y + 5 * math.sin(r))], SUN, 4)
    return img


def item_tetrodotoxin():
    img, d = new()
    # a puffed-up pufferfish
    for i in range(16):
        a = i * math.pi / 8
        stroke(d, [(46 + 30 * math.cos(a), 50 + 28 * math.sin(a)), (46 + 40 * math.cos(a), 50 + 38 * math.sin(a))], BONE, 3)
    ellipse(d, (14, 20, 78, 80), SUN)
    ellipse(d, (24, 50, 70, 78), CREAM, outline=CREAM, width=1)
    poly(d, [(76, 50), (92, 38), (92, 62)], SUN)
    ellipse(d, (24, 36, 38, 50), CREAM, width=OL - 4)
    ellipse(d, (28, 40, 35, 47), INK, width=1)
    return img


def item_decomposers():
    img, d = new()
    # a bone with mushrooms and spores rising off it
    stroke(d, [(14, 78), (82, 78)], BONE, 10)
    for x in (14, 82):
        ellipse(d, (x - 8, 70, x + 8, 86), BONE, width=OL - 3)
    for cx, h, w in ((34, 30, 14), (58, 22, 11)):
        stroke(d, [(cx, 74), (cx, 74 - h)], CREAM, 6)
        d.pieslice([p(cx - w, 74 - h - w), p(cx + w, 74 - h + w)], 180, 360, fill=CORAL, outline=INK, width=OL - 3)
    for x, y in ((24, 20), (48, 12), (72, 26), (80, 12)):
        ellipse(d, (x - 4, y - 4, x + 4, y + 4), LEAF, width=1)
    return img


def item_alarm():
    img, d = new()
    # a small fish with warning rings spreading out
    for r in (40, 30):
        d.arc([p(48 - r, 48 - r), p(48 + r, 48 + r)], 200, 340, fill=SUN, width=5 * K)
    seq = [(18, 64), (40, 50), (64, 56), (80, 64), (64, 72), (40, 78)]
    poly(d, seq, (180, 190, 200, 255))
    poly(d, [(18, 64), (6, 54), (6, 76)], (180, 190, 200, 255))
    ellipse(d, (62, 60, 70, 68), INK, width=1)
    line(d, [(44, 62), (40, 72)], CORAL, 3)
    return img


def item_headshield():
    img, d = new()
    # Cephalaspis-like horseshoe head shield
    seq = []
    for i in range(25):
        a = math.pi + i / 24 * math.pi
        seq.append((48 + 40 * math.cos(a), 56 + 42 * math.sin(a)))
    seq += [(88, 80), (70, 70), (48, 72), (26, 70), (8, 80)]
    poly(d, seq, BONE)
    ellipse(d, (36, 30, 46, 40), INK, width=1)
    ellipse(d, (50, 30, 60, 40), INK, width=1)
    for x, y in ((30, 52), (48, 50), (66, 52)):
        ellipse(d, (x - 4, y - 4, x + 4, y + 4), (190, 180, 150, 255), width=1)
    stroke(d, [(48, 72), (48, 92)], MOSS, 8)
    return img


def item_lateral_line():
    img, d = new()
    seq = [(8, 48), (30, 28), (62, 26), (80, 40), (90, 48), (80, 56), (62, 70), (30, 68)]
    poly(d, seq, (110, 160, 190, 255))
    poly(d, [(8, 48), (0 + 2, 32), (2, 64)], (110, 160, 190, 255))
    ellipse(d, (70, 38, 78, 46), INK, width=1)
    for i in range(6):
        x = 22 + i * 10
        ellipse(d, (x - 3, 46, x + 3, 52), SUN, width=1)
    for y in (14, 84):
        line(d, [(28, y), (40, y - 4), (52, y), (64, y - 4)], AQUA, 3)
    return img


# ---------------------------------------------------------------- stats

def stat_damage():
    img, d = new()
    # a fang
    seq = [(22, 12), (74, 12), (70, 36), (58, 62), (40, 86), (36, 84), (38, 60), (30, 34)]
    poly(d, seq, CREAM)
    d.rectangle([p(18, 8), p(78, 16)], fill=PINK, outline=INK, width=OL - 2)
    line(d, [(42, 26), (44, 60)], (255, 255, 255, 255), 3)
    return img


def stat_speed():
    img, d = new()
    for y, l in ((30, 30), (48, 42), (66, 26)):
        stroke(d, [(10, y), (10 + l, y)], AQUA, 5)
    seq = [(52, 24), (88, 48), (52, 72), (60, 48)]
    poly(d, seq, AQUA)
    return img


def stat_sight():
    img, d = new()
    eye(d, 48, 48, 38, SUN)
    return img


def stat_sense():
    img, d = new()
    # antennae with scent waves
    stroke(d, [(40, 88), (34, 50), (20, 14)], CREAM, 6)
    stroke(d, [(56, 88), (62, 50), (76, 14)], CREAM, 6)
    for r in (10, 18):
        d.arc([p(48 - r, 30 - r), p(48 + r, 30 + r)], 220, 320, fill=LEAF, width=int(3.5 * K))
    return img


def stat_attack():
    img, d = new()
    # three claw slashes
    for i in range(3):
        x = 22 + i * 18
        stroke(d, [(x, 84), (x + 10, 50), (x + 26, 14)], CORAL, 6)
    return img


ICONS = {
    "adapt_muscle": muscle, "adapt_mitochondria": mitochondria, "adapt_myoglobin": myoglobin,
    "adapt_body_wall": body_wall, "adapt_fast_twitch": fast_twitch, "adapt_ion_channels": ion_channels,
    "adapt_reach": reach, "adapt_regeneration": regeneration, "adapt_gut": gut,
    "adapt_toxins": toxins, "adapt_senses": senses, "adapt_mass": mass, "adapt_armour": armour,
    "adapt_autotomy": autotomy, "adapt_mauthner": mauthner, "adapt_serrated": serrated,
    "adapt_symbionts": symbionts, "adapt_thorns": thorns, "adapt_camouflage": camouflage,
    "adapt_electrocytes": electrocytes,
    "item_onion": item_onion, "item_eye": item_eye, "item_hormones": item_hormones,
    "item_cells": item_cells, "item_plasmid": item_plasmid, "item_kleptoplasty": item_kleptoplasty,
    "item_ink_sac": item_ink_sac, "item_nematocysts": item_nematocysts,
    "item_glow_bacteria": item_glow_bacteria, "item_tetrodotoxin": item_tetrodotoxin,
    "item_decomposers": item_decomposers, "item_alarm": item_alarm,
    "item_headshield": item_headshield, "item_lateral_line": item_lateral_line,
    "stat_damage": stat_damage, "stat_speed": stat_speed, "stat_sight": stat_sight,
    "stat_sense": stat_sense, "stat_attack": stat_attack,
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in ICONS.items():
        save(fn(), name)
    print("wrote %d icons to %s" % (len(ICONS), OUT))
