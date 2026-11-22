# generate_grow_icons.py
"""
Pen-and-ink pictures for the parts you GROW (data/Biominerals.gd RECIPES),
one per recipe, so each tile shows the part itself: a calcite spine, a bone,
red blood cells, a magnetite-capped tooth... Drawn like a naturalist's
sketch: brown ink lines, pale washes, cross-hatched shading. The game shows
them through the sepia shader (UIStyle.sepia_material).
  assets/ui/icons/adapt_grow_<id>.png   (recipe "icon": "grow_<id>")
Uses the drawing helpers in generate_ui_icons.py. Run:
  python3 generate_grow_icons.py
"""

import math
import random
import os
from generate_ui_icons import new, save, p, pts, K, OUT

INK = (62, 38, 20, 255)
PAPER = (246, 236, 214, 255)
BONE = (236, 224, 196, 255)
SHELL = (232, 214, 186, 255)
RUST = (196, 104, 74, 255)
BLOOD = (204, 92, 84, 255)
BLUE = (132, 176, 190, 255)
DARK = (110, 84, 62, 255)
GREEN = (176, 196, 140, 255)
YELLOW = (232, 204, 128, 255)
OL = 3.2  # outline width in design units


def poly(d, seq, fill, width=OL):
    d.polygon(pts(seq), fill=fill)
    d.line(pts(seq + [seq[0]]), fill=INK, width=int(width * K), joint="curve")


def oval(d, box, fill, width=OL):
    d.ellipse([p(box[0], box[1]), p(box[2], box[3])], fill=fill, outline=INK, width=int(width * K))


def ink(d, seq, width=2.0, col=INK):
    d.line(pts(seq), fill=col, width=int(width * K), joint="curve")


def hatch(d, box, step=6, width=1.2, slope=1.0, inside=None):
    """Diagonal pen hatching across box, kept to points where inside(x, y)."""
    x0, y0, x1, y1 = box
    span = (x1 - x0) + (y1 - y0)
    for i in range(int(span / step) + 2):
        c = x0 + i * step - (y1 - y0)
        seg = []
        for t in range(0, 41):
            y = y0 + (y1 - y0) * t / 40
            x = c + (y - y0) * slope
            if x0 <= x <= x1 and (inside is None or inside(x, y)):
                seg.append((x, y))
            elif seg:
                if len(seg) > 1:
                    ink(d, seg, width, (62, 38, 20, 150))
                seg = []
        if len(seg) > 1:
            ink(d, seg, width, (62, 38, 20, 150))


def in_ellipse(cx, cy, rx, ry):
    return lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


# ---------------------------------------------------------------- calcium

def calcite_spines():
    img, d = new()
    # an urchin's test with long single-crystal spines
    for i in range(14):
        a = math.tau * i / 14 + 0.1
        r0, r1 = 20, 44 if i % 2 == 0 else 36
        cx, cy = 48 + math.cos(a) * r0, 50 + math.sin(a) * r0
        tip = (48 + math.cos(a) * r1, 50 + math.sin(a) * r1)
        side = (math.cos(a + math.pi / 2) * 3, math.sin(a + math.pi / 2) * 3)
        poly(d, [(cx + side[0], cy + side[1]), tip, (cx - side[0], cy - side[1])], SHELL, 2.2)
    oval(d, (28, 30, 68, 70), PAPER)
    for i in range(5):
        a = math.tau * i / 5 - math.pi / 2
        ink(d, [(48, 50), (48 + math.cos(a) * 18, 50 + math.sin(a) * 18)], 1.6)
    hatch(d, (28, 50, 68, 70), 5, 1.0, inside=in_ellipse(48, 50, 19, 19))
    return img


def shell_plates():
    img, d = new()
    # a mollusc shell: growth lines and radial ribs
    seq = [(14, 70), (20, 40), (36, 22), (56, 18), (74, 26), (84, 46), (82, 70)]
    poly(d, seq + [(48, 78)], SHELL)
    for k in (0.75, 0.5, 0.28):
        arc = [(48 + (x - 48) * k, 74 + (y - 74) * k) for x, y in seq]
        ink(d, arc, 1.4)
    for x, y in seq[1:-1]:
        ink(d, [(48, 76), (x, y)], 1.0)
    oval(d, (40, 70, 56, 82), BONE, 2.4)
    return img


def calcite_lenses():
    img, d = new()
    # a trilobite's compound eye: a kidney of hexagonal calcite lenses
    seq = [(16, 56), (22, 30), (48, 18), (74, 30), (80, 56), (66, 60), (48, 52), (30, 60)]
    poly(d, seq, SHELL)
    for row in range(3):
        for col in range(6 - row):
            cx = 26 + col * 9 + row * 4.5
            cy = 30 + row * 8
            hexa = [(cx + 4 * math.cos(math.tau * i / 6), cy + 4 * math.sin(math.tau * i / 6)) for i in range(6)]
            poly(d, hexa, PAPER, 1.3)
            oval(d, (cx - 1.4, cy - 1.4, cx + 1.4, cy + 1.4), INK, 0.5)
    # a single lens, enlarged, below
    oval(d, (36, 64, 60, 88), PAPER)
    ink(d, [(40, 70), (46, 66)], 1.4)
    return img


def bone():
    img, d = new()
    # a long bone with knobbed ends, spongy bone shown at one end
    def knob(cx, cy):
        oval(d, (cx - 12, cy - 16, cx + 4, cy), BONE)
        oval(d, (cx - 4, cy - 8, cx + 12, cy + 8), BONE)
    knob(22, 76)
    knob(74, 24)
    poly(d, [(22, 66), (30, 74), (78, 30), (70, 22)], BONE)
    knob(22, 76)
    knob(74, 24)
    ink(d, [(30, 62), (66, 28)], 1.2)
    for i in range(6):
        x, y = 70 + (i % 3) * 3, 22 + (i // 3) * 4
        oval(d, (x - 1.2, y - 1.2, x + 1.2, y + 1.2), PAPER, 0.8)
    return img


# ---------------------------------------------------------------- phosphorus

def phosphagen():
    img, d = new()
    # a muscle fibre with a spark of stored energy
    seq = [(10, 60), (30, 40), (60, 30), (86, 32), (86, 44), (62, 50), (34, 64), (12, 74)]
    poly(d, seq, (226, 176, 156, 255))
    for t in range(1, 7):
        x = 14 + t * 11
        ink(d, [(x, 72 - t * 5), (x + 6, 50 - t * 3)], 1.1)
    bolt = [(58, 8), (44, 34), (54, 34), (46, 58), (66, 28), (56, 28), (64, 8)]
    poly(d, bolt, YELLOW, 2.6)
    return img


def regeneration():
    img, d = new()
    # a starfish regrowing a lost arm
    arms = []
    for i in range(5):
        a = math.tau * i / 5 - math.pi / 2
        r = 16 if i == 2 else 38
        arms.append((48 + math.cos(a) * r, 50 + math.sin(a) * r))
        b = a + math.tau / 10
        arms.append((48 + math.cos(b) * 12, 50 + math.sin(b) * 12))
    poly(d, arms, SHELL)
    for i in range(5):
        a = math.tau * i / 5 - math.pi / 2
        r = 10 if i == 2 else 30
        for k in range(2, int(r / 4)):
            x, y = 48 + math.cos(a) * k * 4, 50 + math.sin(a) * k * 4
            oval(d, (x - 1.3, y - 1.3, x + 1.3, y + 1.3), INK, 0.4)
    # the new growth, drawn dashed
    a = math.tau * 2 / 5 - math.pi / 2
    for k in range(4, 9):
        x, y = 48 + math.cos(a) * k * 4.4, 50 + math.sin(a) * k * 4.4
        ink(d, [(x - 1.5, y), (x + 1.5, y)], 1.6)
    return img


def electric_organ():
    img, d = new()
    # stacked electrocyte discs, like a battery, with a spark
    for i in range(6):
        y = 24 + i * 9
        oval(d, (18, y, 66, y + 10), PAPER if i % 2 else SHELL, 2.2)
    ink(d, [(18, 29), (18, 74)], 2.2)
    ink(d, [(66, 29), (66, 74)], 2.2)
    poly(d, [(80, 16), (70, 40), (78, 40), (72, 64), (90, 34), (82, 34), (88, 16)], YELLOW, 2.4)
    return img


# ---------------------------------------------------------------- iron

def haemoglobin():
    img, d = new()
    # red blood cells, biconcave discs
    for cx, cy, r in ((34, 38, 20), (64, 58, 20), (30, 72, 13)):
        oval(d, (cx - r, cy - r * 0.8, cx + r, cy + r * 0.8), BLOOD)
        oval(d, (cx - r * 0.45, cy - r * 0.35, cx + r * 0.45, cy + r * 0.35), (226, 140, 128, 255), 1.4)
    hatch(d, (44, 44, 84, 74), 5, 1.0, inside=in_ellipse(64, 58, 19, 15))
    return img


def iron_sulfur():
    img, d = new()
    # a mitochondrion with folded cristae and an iron-sulfur cube
    oval(d, (8, 28, 72, 72), SHELL)
    seq = []
    for i in range(9):
        x = 16 + i * 6.5
        seq += [(x, 36), (x + 3, 64)]
    ink(d, seq, 1.6)
    # Fe4S4 cube
    cube = [(66, 20), (84, 14), (90, 30), (72, 36)]
    poly(d, cube, RUST, 2.2)
    poly(d, [(72, 36), (90, 30), (90, 46), (72, 52)], (170, 90, 60, 255), 2.2)
    poly(d, [(66, 20), (72, 36), (72, 52), (66, 36)], YELLOW, 2.2)
    return img


def magnetite_teeth():
    img, d = new()
    # a chiton's radula: a row of teeth, black magnetite caps
    ink(d, [(10, 74), (86, 50)], 3.0)
    for i in range(5):
        x = 16 + i * 15
        y = 72 - i * 5
        poly(d, [(x - 5, y), (x + 5, y - 3), (x + 4, y - 22), (x - 2, y - 26)], BONE, 2.2)
        poly(d, [(x + 4, y - 22), (x - 2, y - 26), (x + 1, y - 34)], DARK, 2.0)
    return img


# ---------------------------------------------------------------- zinc

def zinc_jaws():
    img, d = new()
    # a ragworm's pair of hooked jaws, tips hardened
    def jaw(sx):
        seq = [(48 + sx * 6, 80), (48 + sx * 22, 62), (48 + sx * 24, 36), (48 + sx * 12, 16),
               (48 + sx * 6, 26), (48 + sx * 14, 40), (48 + sx * 12, 62)]
        poly(d, seq, BONE)
        for k in range(4):
            y = 44 + k * 7
            ink(d, [(48 + sx * 13, y), (48 + sx * 8, y + 2)], 1.6)
        poly(d, [(48 + sx * 12, 16), (48 + sx * 6, 26), (48 + sx * 10, 28)], DARK, 1.6)
    jaw(-1)
    jaw(1)
    return img


def zinc_venom():
    img, d = new()
    # a spider's fang with a bead of venom
    seq = [(24, 8), (54, 8), (60, 30), (54, 52), (40, 66), (44, 48), (38, 26)]
    poly(d, seq, BONE)
    hatch(d, (24, 8, 60, 50), 5, 1.0, inside=lambda x, y: x > 48)
    tip = (40, 66)
    drop = [(tip[0], tip[1] + 2)]
    for i in range(0, 181, 20):
        a = math.radians(i)
        drop.append((tip[0] + 9 * math.cos(a), tip[1] + 14 + 9 * math.sin(a)))
    poly(d, drop, GREEN, 2.0)
    return img


# ---------------------------------------------------------------- copper

def hemocyanin():
    img, d = new()
    # a horseshoe crab's blue blood dripping
    for cx, cy, r in ((34, 30, 13), (62, 48, 16), (36, 70, 11)):
        seq = [(cx, cy - r * 1.7)]
        for i in range(0, 361, 20):
            a = math.radians(i)
            if math.sin(a) > -0.2:
                seq.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        seq = [seq[0]] + sorted(seq[1:], key=lambda q: -math.atan2(q[1] - cy, q[0] - cx))
        poly(d, seq, BLUE)
        ink(d, [(cx - r * 0.4, cy - r * 0.2), (cx - r * 0.2, cy - r * 0.6)], 1.6, PAPER)
    return img


def melanin():
    img, d = new()
    # a mottled skin patch with expanded pigment cells
    oval(d, (10, 16, 86, 82), SHELL)
    rnd = random.Random(7)
    for i in range(12):
        x, y = rnd.uniform(22, 74), rnd.uniform(26, 72)
        r = rnd.uniform(4, 9)
        seq = [(x + r * math.cos(math.tau * k / 9) * rnd.uniform(0.7, 1.2),
                y + r * math.sin(math.tau * k / 9) * rnd.uniform(0.7, 1.2)) for k in range(9)]
        poly(d, seq, DARK, 1.3)
    return img


# ---------------------------------------------------------------- sulfur

def keratin_claws():
    img, d = new()
    # a curved claw on a toe
    seq = [(18, 70), (24, 44), (40, 24), (62, 16), (82, 22), (64, 26), (48, 38), (40, 56), (40, 76)]
    poly(d, seq, BONE)
    for k in range(3):
        ink(d, [(30 + k * 6, 66 - k * 4), (44 + k * 8, 34 - k * 4)], 1.1)
    oval(d, (12, 66, 46, 90), SHELL)
    return img


def keratin_horn():
    img, d = new()
    # a ridged horn on a brow
    seq = [(18, 82), (24, 54), (38, 30), (60, 12), (52, 34), (50, 56), (54, 82)]
    poly(d, seq, BONE)
    for k in range(6):
        t = k / 6
        a = (18 + (60 - 18) * t, 82 - 70 * t)
        b = (54 + (52 - 54) * t, 82 - 48 * t)
        ink(d, [(a[0] + 2, a[1]), (b[0] - 1, b[1])], 1.2)
    ink(d, [(8, 84), (88, 84)], 3.0)
    return img


def photoreceptors():
    img, d = new()
    # a pigment-cup eyespot: light rays falling into a cup of dark pigment
    # cells, with the photoreceptor cells lining it
    for i, x in enumerate((26, 40, 54, 68)):
        ink(d, [(x - 10, 8), (x + 2, 30)], 1.4)
        ink(d, [(x + 2, 30), (x - 2, 27)], 1.2)
        ink(d, [(x + 2, 30), (x + 3, 25)], 1.2)
    cup = [(14, 40), (20, 66), (48, 84), (76, 66), (82, 40), (70, 42), (64, 60), (48, 68), (32, 60), (26, 42)]
    poly(d, cup, DARK)
    hatch(d, (14, 40, 82, 84), 4, 1.0, inside=lambda x, y: y > 46 and (x - 48) ** 2 / 34 ** 2 + (y - 46) ** 2 / 38 ** 2 < 1)
    for i in range(7):
        a = math.pi * (0.1 + 0.8 * i / 6)
        cx = 48 - math.cos(a) * 20
        cy = 46 + math.sin(a) * 16
        oval(d, (cx - 4.5, cy - 4.5, cx + 4.5, cy + 4.5), YELLOW, 1.6)
    return img


def membrane_repair():
    img, d = new()
    # a phospholipid bilayer: round phosphate heads with two fatty tails,
    # one gap being closed by a new lipid sliding in
    for row, y0, dy in ((0, 26, 1), (1, 74, -1)):
        for i in range(6):
            x = 14 + i * 13.6
            if row == 0 and i == 3:
                continue
            ink(d, [(x - 2, y0 + dy * 5), (x - 2.5, y0 + dy * 20)], 1.6)
            ink(d, [(x + 2, y0 + dy * 5), (x + 2.5, y0 + dy * 19)], 1.6)
            oval(d, (x - 5.5, y0 - 5.5, x + 5.5, y0 + 5.5), YELLOW, 2.0)
    # the new lipid arriving from above
    x = 14 + 3 * 13.6
    ink(d, [(x - 2, 10 + 5), (x - 2.5, 10 + 20)], 1.6)
    ink(d, [(x + 2, 10 + 5), (x + 2.5, 10 + 19)], 1.6)
    oval(d, (x - 5.5, 4.5, x + 5.5, 15.5), PAPER, 2.0)
    ink(d, [(x + 12, 6), (x + 12, 22)], 1.2)
    ink(d, [(x + 9, 18), (x + 12, 22), (x + 15, 18)], 1.2)
    return img


ICONS = {
    "adapt_grow_calcite_spines": calcite_spines,
    "adapt_grow_shell_plates": shell_plates,
    "adapt_grow_photoreceptors": photoreceptors,
    "adapt_grow_calcite_lenses": calcite_lenses,
    "adapt_grow_bone": bone,
    "adapt_grow_membrane_repair": membrane_repair,
    "adapt_grow_phosphagen": phosphagen,
    "adapt_grow_regeneration": regeneration,
    "adapt_grow_electric_organ": electric_organ,
    "adapt_grow_haemoglobin": haemoglobin,
    "adapt_grow_iron_sulfur": iron_sulfur,
    "adapt_grow_magnetite_teeth": magnetite_teeth,
    "adapt_grow_zinc_jaws": zinc_jaws,
    "adapt_grow_zinc_venom": zinc_venom,
    "adapt_grow_hemocyanin": hemocyanin,
    "adapt_grow_melanin": melanin,
    "adapt_grow_keratin_claws": keratin_claws,
    "adapt_grow_keratin_horn": keratin_horn,
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in ICONS.items():
        save(fn(), name)
    print("wrote %d icons to %s" % (len(ICONS), OUT))
