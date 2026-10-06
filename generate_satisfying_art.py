# generate_satisfying_art.py
"""
High-fidelity art generation for Evo Roguelike: Primordial Genesis.
Generates:
1. Redesigned, imposing, solid obstacle sprites (fossil_bone, hydrothermal_vent, rock, biocrystal, coral_spire, stromatolite, calcified_sponge, ediacaran_frond).
2. Redesigned seamless door system (door.png [open], door_closed.png, door_locked.png).
3. Seamless full-screen room backgrounds with solid, continuous perimeter walls (no baked cutouts/boxes!).
"""

import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter

def clamp(v, lo=0, hi=255):
    return int(max(lo, min(hi, v)))

def ensure_dir(path="assets"):
    os.makedirs(path, exist_ok=True)

# ==============================================================================
# 1. OBSTACLES: FOSSIL BONE & HYDROTHERMAL VENT (AND ENHANCED REEF OBSTACLES)
# ==============================================================================

def draw_fossil_bone():
    """
    Massive prehistoric leviathan skull & armored bone mound (128x128).
    Unmistakably a solid, heavy obstacle!
    """
    random.seed(142)
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Heavy seabed drop shadow
    draw.ellipse([14, 96, 114, 124], fill=(3, 8, 18, 160))
    draw.ellipse([24, 102, 104, 120], fill=(2, 5, 12, 190))

    # 2. Dark sedimentary rock matrix embedding the fossil base
    rock_base = [
        (16, 112), (24, 92), (38, 88), (64, 84), (90, 88), (104, 92), (112, 112), (64, 118)
    ]
    draw.polygon(rock_base, fill=(24, 32, 42, 255), outline=(12, 18, 26, 255), width=3)
    # Rock crags & cracks
    for x in range(24, 104, 14):
        draw.line([(x, 92), (x + random.randint(-4, 4), 114)], fill=(14, 20, 28, 200), width=2)

    # 3. Main fossil leviathan skull / vertebrae mass
    # Massive calcified bone body
    skull_pts = [
        (22, 94), (18, 72), (26, 52), (38, 34), (54, 20), (74, 20), (90, 34), (102, 52), (110, 72), (106, 94),
        (92, 102), (64, 104), (36, 102)
    ]
    draw.polygon(skull_pts, fill=(160, 172, 168, 255), outline=(50, 60, 65, 255), width=4)

    # 4. Heavy calcified cranial crest & horn spikes (massive curved horn protrusions)
    left_horn = [(38, 38), (22, 22), (14, 12), (28, 16), (44, 30)]
    draw.polygon(left_horn, fill=(195, 205, 200, 255), outline=(65, 75, 80, 255), width=2)
    right_horn = [(90, 38), (106, 22), (114, 12), (100, 16), (84, 30)]
    draw.polygon(right_horn, fill=(195, 205, 200, 255), outline=(65, 75, 80, 255), width=2)
    # Center dorsal spine spike
    spine_pts = [(56, 22), (64, 8), (72, 22)]
    draw.polygon(spine_pts, fill=(215, 225, 220, 255), outline=(75, 85, 90, 255), width=2)

    # 5. Prehistoric cranial plate faceting and chiseled bone contours
    # Left cranial plate (mid-tone)
    draw.polygon([(26, 52), (38, 34), (64, 30), (64, 68), (34, 76)], fill=(175, 185, 180, 255))
    # Right cranial plate (shadow side)
    draw.polygon([(64, 30), (90, 34), (102, 52), (94, 76), (64, 68)], fill=(135, 148, 144, 255))
    # Brow ridge highlight (bright ivory)
    draw.polygon([(40, 36), (64, 26), (88, 36), (64, 32)], fill=(230, 240, 235, 255))

    # 6. Deep ancient orbital cavities (eye sockets) with crystalline fossil glow
    # Left eye socket
    draw.ellipse([34, 52, 54, 72], fill=(18, 24, 28, 255), outline=(70, 80, 82, 255), width=2)
    draw.ellipse([39, 57, 49, 67], fill=(0, 160, 150, 180))
    draw.ellipse([42, 60, 46, 64], fill=(160, 255, 240, 240))
    # Right eye socket
    draw.ellipse([74, 52, 94, 72], fill=(18, 24, 28, 255), outline=(55, 65, 68, 255), width=2)
    draw.ellipse([79, 57, 89, 67], fill=(0, 140, 130, 180))
    draw.ellipse([82, 60, 86, 64], fill=(140, 240, 220, 230))

    # Nasal cavity / central aperture
    draw.polygon([(60, 68), (68, 68), (64, 82)], fill=(12, 16, 20, 255), outline=(50, 60, 62, 255), width=2)

    # 7. Ancient jaw armor plates / serrated placoderm fossil ridges
    jaw_plates = [
        (30, 80, 48, 98), (46, 82, 64, 100), (64, 82, 82, 100), (80, 80, 98, 98)
    ]
    for x1, y1, x2, y2 in jaw_plates:
        draw.polygon([(x1, y1), (x2, y1), (x2 - 3, y2), (x1 + 3, y2)],
                     fill=(145, 155, 150, 255), outline=(45, 55, 58, 255), width=2)
        # Ridge highlight
        draw.line([(x1 + 2, y1 + 2), (x2 - 2, y1 + 2)], fill=(210, 220, 215, 255), width=1)

    # 8. Weathered bone micro-fissures with glowing teal fossil minerals
    fissures = [
        [(42, 28), (48, 44), (44, 52)],
        [(86, 28), (80, 44), (84, 52)],
        [(64, 32), (64, 60)],
        [(24, 66), (32, 74)],
        [(104, 66), (96, 74)]
    ]
    for f in fissures:
        draw.line(f, fill=(0, 230, 200, 90), width=4)
        draw.line(f, fill=(0, 255, 220, 210), width=1)

    # 9. Top-down rim highlights
    draw.arc([20, 18, 108, 60], 190, 350, fill=(245, 250, 248, 255), width=2)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.35))
    img.save("assets/fossil_bone.png")
    print("  Enhanced Fossil Bone Obstacle: assets/fossil_bone.png")


def draw_hydrothermal_vent():
    """
    Colossal deep-sea volcanic basalt spire / black smoker chimney (128x128).
    Wide, rugged, multi-tiered volcanic rock pillar with boiling geothermal caldera!
    """
    random.seed(268)
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Broad volcanic floor drop shadow
    draw.ellipse([10, 96, 118, 124], fill=(3, 6, 14, 180))
    draw.ellipse([20, 102, 108, 120], fill=(2, 4, 10, 210))

    # 2. Heavy basaltic stepped base shelves (terraced volcanic rock)
    base_shelf_1 = [
        (14, 114), (22, 94), (42, 88), (86, 88), (106, 94), (114, 114), (64, 120)
    ]
    draw.polygon(base_shelf_1, fill=(24, 32, 44, 255), outline=(12, 18, 26, 255), width=3)
    
    # Sulfur & iron mineral staining crust on base
    draw.chord([26, 92, 102, 116], 190, 350, fill=(120, 95, 25, 140))
    
    base_shelf_2 = [
        (24, 102), (32, 78), (50, 74), (78, 74), (96, 78), (104, 102), (64, 108)
    ]
    draw.polygon(base_shelf_2, fill=(32, 42, 56, 255), outline=(16, 24, 34, 255), width=3)

    # 3. Main rugged volcanic chimney column
    column_pts = [
        (38, 86), (32, 58), (38, 32), (90, 32), (96, 58), (90, 86)
    ]
    draw.polygon(column_pts, fill=(38, 50, 66, 255), outline=(18, 26, 36, 255), width=3)

    # 4. Jagged chiseled 3D rock facets on the chimney
    # Left lit face (oceanic rim glow)
    draw.polygon([(32, 58), (38, 32), (54, 30), (52, 60), (44, 84), (38, 86)], fill=(52, 70, 92, 255))
    # Center face (main rock plane)
    draw.polygon([(54, 30), (74, 30), (72, 62), (52, 60)], fill=(44, 58, 78, 255))
    # Right shadow face
    draw.polygon([(74, 30), (90, 32), (96, 58), (90, 86), (70, 84), (72, 62)], fill=(22, 30, 42, 255))

    # Stepped buttress spires flanking chimney
    draw.polygon([(24, 82), (30, 52), (40, 54), (36, 84)], fill=(40, 54, 72, 255), outline=(16, 24, 34, 255), width=2)
    draw.polygon([(88, 84), (98, 54), (104, 56), (96, 84)], fill=(26, 36, 48, 255), outline=(14, 20, 30, 255), width=2)

    # 5. Intense geothermal plasma fissures (molten gold/orange core + electric cyan boundary)
    fissures = [
        [(54, 34), (48, 52), (56, 68), (50, 88), (62, 102)],
        [(70, 36), (74, 56), (68, 74), (74, 94)],
        [(36, 62), (44, 72)],
        [(92, 64), (84, 74)],
        [(28, 92), (38, 98)],
        [(90, 94), (100, 98)]
    ]
    for f in fissures:
        # Fiery molten outer aura
        draw.line(f, fill=(255, 120, 0, 110), width=6)
        # Geothermal orange/cyan channel
        draw.line(f, fill=(0, 225, 240, 200), width=3)
        # White-hot fissure core
        draw.line(f, fill=(255, 250, 220, 255), width=1)

    # 6. Active Summit Caldera / Chimney Crater
    # Crater basalt rim
    draw.ellipse([36, 20, 92, 38], fill=(20, 28, 38, 255), outline=(10, 16, 24, 255), width=3)
    # Luminous geothermal magma pool inside orifice
    draw.ellipse([42, 23, 86, 35], fill=(255, 140, 20, 240), outline=(255, 200, 40, 255), width=2)
    draw.ellipse([48, 25, 80, 33], fill=(255, 240, 160, 255))
    draw.ellipse([54, 27, 74, 31], fill=(255, 255, 255, 255))

    # 7. Rising hydrothermal plume (thermal smoke, bubbles, sparks)
    # Plume vapor clouds
    plumes = [
        ([52, 12, 76, 24], (0, 200, 230, 80)),
        ([46, 4, 82, 18], (0, 180, 210, 60)),
        ([50, -4, 78, 10], (20, 150, 190, 45)),
    ]
    for box, col in plumes:
        draw.ellipse(box, fill=col)

    # Rising buoyant boiling bubbles
    bubbles = [
        (64, 18, 4), (56, 12, 3), (72, 8, 3.5), (60, 2, 2.5), (68, -2, 2),
        (50, 16, 2), (78, 14, 2.5)
    ]
    for bx, by, br in bubbles:
        if by > -6:
            draw.ellipse([bx - br*2, by - br*2, bx + br*2, by + br*2], fill=(0, 230, 255, 45))
            draw.ellipse([bx - br, by - br, bx + br, by + br], fill=(210, 250, 255, 210), outline=(0, 245, 255, 255), width=1)
            draw.point((int(bx), int(by)), fill=(255, 255, 255, 255))

    # Floating magma sparks
    sparks = [(62, 14), (66, 8), (58, 4), (74, 3), (64, -1)]
    for sx, sy in sparks:
        if sy > -4:
            draw.point((sx, sy), fill=(255, 240, 120, 255))

    # Chiseled top-down rim highlights
    draw.arc([34, 30, 94, 60], 190, 350, fill=(120, 170, 210, 180), width=2)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.35))
    img.save("assets/hydrothermal_vent.png")
    print("  Enhanced Hydrothermal Vent Obstacle: assets/hydrothermal_vent.png")


def draw_rock():
    """Deep-sea faceted basalt meteorite boulder with bioluminescent crystal fissures (128x128)."""
    random.seed(88)
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Shadow
    draw.ellipse([14, 94, 114, 124], fill=(3, 8, 18, 160))

    # Heavy faceted rock body
    pts = [(20, 96), (14, 62), (28, 28), (56, 14), (88, 18), (114, 44), (116, 88), (92, 112), (48, 116)]
    draw.polygon(pts, fill=(34, 48, 66, 255), outline=(14, 22, 32, 255), width=4)

    # Chiseled facet planes
    # Top lit facet
    draw.polygon([(28, 28), (56, 14), (88, 18), (82, 46), (46, 44)], fill=(65, 92, 122, 255))
    # Left facet
    draw.polygon([(14, 62), (28, 28), (46, 44), (54, 76), (28, 92)], fill=(48, 68, 92, 255))
    # Right shadow facet
    draw.polygon([(88, 18), (114, 44), (116, 88), (84, 84), (82, 46)], fill=(20, 30, 44, 255))
    # Center facet
    draw.polygon([(46, 44), (82, 46), (84, 84), (54, 76)], fill=(38, 54, 74, 255))

    # Glowing crystal fracture veins
    cracks = [
        [(36, 32), (54, 56), (42, 86), (62, 108)],
        [(54, 56), (78, 62), (86, 48)],
        [(80, 24), (82, 46)]
    ]
    for c in cracks:
        draw.line(c, fill=(0, 220, 240, 80), width=5)
        draw.line(c, fill=(0, 245, 230, 200), width=2)
        draw.line(c, fill=(220, 255, 250, 255), width=1)

    # Micro crystals
    for rx, ry in [(44, 50), (62, 60), (74, 70), (48, 80)]:
        draw.ellipse([rx - 2, ry - 2, rx + 2, ry + 2], fill=(160, 255, 240, 230))

    # Specular rim highlights
    draw.line([(28, 28), (56, 14), (88, 18)], fill=(140, 190, 235, 220), width=2)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.35))
    img.save("assets/rock.png")
    print("  Enhanced Rock: assets/rock.png")


def draw_biocrystal():
    """Giant cluster of luminous prismatic biocrystals on an abyssal rock pedestal (128x128)."""
    random.seed(92)
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Shadow
    draw.ellipse([16, 96, 112, 124], fill=(2, 6, 16, 160))

    # Dark rock pedestal base
    pedestal = [(22, 114), (32, 92), (64, 88), (96, 92), (106, 114), (64, 118)]
    draw.polygon(pedestal, fill=(24, 34, 46, 255), outline=(12, 18, 26, 255), width=3)

    # Prismatic crystal shards (clustered spire formation)
    # Background crystals (darker)
    draw.polygon([(30, 96), (36, 44), (46, 24), (54, 48), (48, 98)], fill=(0, 140, 170, 230), outline=(0, 190, 210, 255), width=2)
    draw.polygon([(74, 98), (72, 46), (84, 20), (94, 48), (92, 96)], fill=(0, 130, 160, 230), outline=(0, 180, 200, 255), width=2)

    # Main foreground towering crystal spire
    center_shard = [(50, 102), (46, 46), (64, 12), (80, 46), (76, 102)]
    draw.polygon(center_shard, fill=(0, 210, 235, 255), outline=(0, 255, 255, 255), width=3)
    # Crystal left facet (bright)
    draw.polygon([(50, 102), (46, 46), (64, 12), (64, 102)], fill=(80, 240, 255, 240))
    # Crystal right facet (shaded)
    draw.polygon([(64, 12), (80, 46), (76, 102), (64, 102)], fill=(0, 180, 210, 240))
    # Center light prism spine
    draw.line([(64, 12), (64, 102)], fill=(240, 255, 255, 255), width=2)

    # Flanking crystal spires
    draw.polygon([(26, 104), (20, 68), (30, 52), (40, 72), (38, 104)], fill=(0, 190, 220, 240), outline=(0, 240, 255, 255), width=2)
    draw.polygon([(88, 104), (88, 70), (98, 50), (108, 68), (102, 104)], fill=(0, 170, 200, 240), outline=(0, 230, 245, 255), width=2)

    # Bioluminescent glow aura
    for r in range(40, 0, -8):
        draw.ellipse([64 - r, 54 - r, 64 + r, 54 + r], fill=(0, 230, 255, int(15 * (1 - r/40.0))))

    img = img.filter(ImageFilter.GaussianBlur(radius=0.35))
    img.save("assets/biocrystal.png")
    print("  Enhanced Biocrystal: assets/biocrystal.png")


# ==============================================================================
# 2. DOORS: OPEN, CLOSED, AND LOCKED PORTAL GATEWAYS (128x128)
# ==============================================================================

def draw_door_frame(draw, w=128, h=128):
    """
    Draws the heavy megalithic / calcified bio-stone gateway arch.
    Frames the aperture at (24..104, 28..124).
    """
    # Outer stone jambs and lintel
    # Left stone pillar
    draw.polygon([(4, 127), (4, 34), (18, 16), (28, 24), (26, 127)], fill=(28, 38, 52, 255), outline=(12, 18, 26, 255), width=3)
    # Right stone pillar
    draw.polygon([(102, 127), (100, 24), (110, 16), (124, 34), (124, 127)], fill=(22, 30, 42, 255), outline=(12, 18, 26, 255), width=3)
    # Top arch header / lintel
    arch_pts = [(14, 26), (40, 8), (64, 4), (88, 8), (114, 26), (100, 36), (64, 24), (28, 36)]
    draw.polygon(arch_pts, fill=(36, 48, 64, 255), outline=(14, 20, 28, 255), width=3)

    # Carved bio-runic conduits running along pillars
    draw.line([(14, 38), (14, 120)], fill=(0, 200, 230, 80), width=4)
    draw.line([(14, 38), (14, 120)], fill=(0, 235, 245, 190), width=2)
    draw.line([(114, 38), (114, 120)], fill=(0, 170, 200, 80), width=4)
    draw.line([(114, 38), (114, 120)], fill=(0, 210, 230, 180), width=2)

    # Arch keystone emblem at top center
    draw.polygon([(56, 22), (64, 6), (72, 22), (64, 30)], fill=(44, 60, 80, 255), outline=(0, 220, 240, 220), width=2)
    draw.ellipse([61, 15, 67, 21], fill=(180, 255, 250, 255))

    # Inner arch rim
    draw.arc([24, 22, 104, 66], 180, 360, fill=(0, 220, 240, 200), width=3)
    draw.line([(24, 44), (24, 127)], fill=(0, 220, 240, 160), width=2)
    draw.line([(104, 44), (104, 127)], fill=(0, 220, 240, 160), width=2)


def draw_door():
    """
    OPEN DOOR: Gateway arch with swirling bioluminescent aquatic portal passage!
    """
    w, h = 128, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Swirling abyssal portal passage inside the doorway aperture (x: 26..102, y: 32..127)
    draw.chord([26, 24, 102, 120], 180, 360, fill=(4, 12, 24, 255))
    draw.rectangle([26, 72, 102, 127], fill=(4, 12, 24, 255))

    # Concentric water vortex spiral rings
    cx, cy = 64, 80
    for r, start_deg, end_deg, col in [
        (34, 40, 320, (0, 180, 220, 160)),
        (26, 90, 370, (0, 220, 240, 200)),
        (18, 140, 420, (0, 245, 250, 230)),
        (10, 0, 360, (180, 255, 255, 255))
    ]:
        draw.arc([cx - r, cy - r, cx + r, cy + r], start_deg, end_deg, fill=col, width=3)

    # Luminous portal core
    draw.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(220, 255, 255, 255))
    draw.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(255, 255, 255, 255))

    # Floating portal motes
    for mx, my in [(52, 60), (76, 68), (56, 94), (74, 98), (64, 52)]:
        draw.ellipse([mx - 2, my - 2, mx + 2, my + 2], fill=(160, 255, 240, 220))

    # Threshold floor light projection
    for i in range(10):
        a = int(90 * (1 - i / 10.0))
        draw.line([(26, 127 - i), (102, 127 - i)], fill=(0, 220, 255, a))

    # 2. Draw the heavy stone archway frame OVER the portal
    draw_door_frame(draw, w, h)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.35))
    img.save("assets/door.png")
    print("  Enhanced Door (Open): assets/door.png")


def draw_door_closed():
    """
    CLOSED DOOR: Same gateway arch, but sealed shut by an interlocking chitinous/organic iris membrane!
    """
    w, h = 128, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Sealed organic iris membrane filling aperture (x: 26..102, y: 32..127)
    draw.chord([26, 24, 102, 120], 180, 360, fill=(18, 28, 42, 255))
    draw.rectangle([26, 72, 102, 127], fill=(18, 28, 42, 255))

    # Interlocking radial chitin plates (sealed iris valve)
    cx, cy = 64, 80
    num_petals = 6
    for i in range(num_petals):
        angle = (i / float(num_petals)) * math.pi * 2
        px = cx + math.cos(angle) * 36
        py = cy + math.sin(angle) * 36
        next_angle = ((i + 1) / float(num_petals)) * math.pi * 2
        npx = cx + math.cos(next_angle) * 36
        npy = cy + math.sin(next_angle) * 36

        plate_pts = [(cx, cy), (int(px), int(py)), (int(npx), int(npy))]
        col_val = 30 + (i % 2) * 10
        draw.polygon(plate_pts, fill=(col_val, col_val + 14, col_val + 28, 255), outline=(12, 18, 28, 255), width=2)
        # Chitinous striations on each plate
        mid_x = (px + npx) / 2.0
        mid_y = (py + npy) / 2.0
        draw.line([(cx, cy), (int(mid_x), int(mid_y))], fill=(45, 65, 85, 200), width=1)

    # Heavy central bio-valve seal
    draw.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=(24, 38, 54, 255), outline=(0, 160, 200, 220), width=2)
    draw.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=(0, 120, 160, 200))

    # Dim dormant seam lines
    draw.arc([cx - 26, cy - 26, cx + 26, cy + 26], 0, 360, fill=(0, 140, 180, 120), width=2)

    # 2. Draw stone archway frame
    draw_door_frame(draw, w, h)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.35))
    img.save("assets/door_closed.png")
    print("  Enhanced Door (Closed): assets/door_closed.png")


def draw_door_locked():
    """
    LOCKED DOOR: Gateway arch reinforced by calcified bars & golden runic keyhole seal!
    """
    w, h = 128, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Dark interior void behind bars
    draw.chord([26, 24, 102, 120], 180, 360, fill=(10, 16, 26, 255))
    draw.rectangle([26, 72, 102, 127], fill=(10, 16, 26, 255))

    # Heavy fossilized portcullis bars (vertical calcified columns)
    for bx in [36, 50, 64, 78, 92]:
        draw.line([(bx, 36), (bx, 127)], fill=(65, 78, 90, 255), width=7)
        draw.line([(bx, 36), (bx, 127)], fill=(150, 165, 175, 255), width=3)
        draw.line([(bx - 1, 36), (bx - 1, 127)], fill=(210, 225, 235, 255), width=1)

    # Horizontal reinforcement bar
    draw.line([(26, 80), (102, 80)], fill=(50, 62, 74, 255), width=8)
    draw.line([(26, 80), (102, 80)], fill=(140, 155, 165, 255), width=4)

    # 2. Golden Runic Lock Plaque in Center
    cx, cy = 64, 80
    # Outer lock housing
    draw.ellipse([cx - 24, cy - 24, cx + 24, cy + 24], fill=(18, 22, 32, 255), outline=(160, 110, 10, 255), width=3)
    draw.ellipse([cx - 20, cy - 20, cx + 20, cy + 20], fill=(215, 155, 20, 255), outline=(130, 85, 5, 255), width=2)
    # Shackle
    draw.arc([cx - 14, cy - 32, cx + 14, cy - 8], 180, 360, fill=(240, 190, 40, 255), width=4)
    # Inner glowing keyhole
    draw.ellipse([cx - 6, cy - 10, cx + 6, cy - 2], fill=(24, 16, 8, 255))
    draw.polygon([(cx - 4, cy - 4), (cx + 4, cy - 4), (cx + 2, cy + 10), (cx - 2, cy + 10)], fill=(24, 16, 8, 255))
    draw.point((cx, cy - 6), fill=(255, 220, 100, 255))

    # Amber lock glow
    for r in range(30, 0, -6):
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 190, 30, int(18 * (1 - r/30.0))))

    # 3. Draw stone archway frame
    draw_door_frame(draw, w, h)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.35))
    img.save("assets/door_locked.png")
    print("  Enhanced Door (Locked): assets/door_locked.png")


# ==============================================================================
# 3. FULL-SCREEN ROOM BACKGROUNDS (1920x1080) WITH SEAMLESS, SOLID WALLS!
# ==============================================================================

def draw_fullscreen_background(filename, theme_type="normal"):
    """
    Seamless 1920x1080 room background with:
    - Completely SOLID, CONTINUOUS perimeter walls (no baked-in door cutouts or square gaps!).
    - Rich organic rock/reef texturing, multi-layer depth, and soft atmospheric bioluminescence.
    - Gorgeous floor gradients and theme-specific center art.
    """
    random.seed({"normal": 101, "boss": 202, "treasure": 303, "shop": 404, "start": 505}.get(theme_type, 101))
    width, height = 1920, 1080
    cx, cy = width / 2.0, height / 2.0

    palettes = {
        "boss":     {"base": (14, 18, 36), "glow": (120, 150, 245), "wall": (24, 30, 52), "floor": (10, 14, 28)},
        "treasure": {"base": (6, 26, 32),  "glow": (0, 230, 185),   "wall": (14, 40, 48), "floor": (5, 20, 26)},
        "shop":     {"base": (18, 24, 36), "glow": (240, 190, 60),  "wall": (32, 40, 54), "floor": (14, 18, 28)},
        "start":    {"base": (10, 26, 46), "glow": (60, 215, 255),  "wall": (18, 38, 62), "floor": (8, 20, 36)},
        "normal":   {"base": (10, 22, 40), "glow": (0, 190, 225),   "wall": (18, 34, 56), "floor": (8, 18, 32)},
    }
    pal = palettes.get(theme_type, palettes["normal"])
    base_col = pal["base"]
    glow_col = pal["glow"]
    wall_col = pal["wall"]
    floor_col = pal["floor"]

    img = Image.new("RGBA", (width, height), base_col + (255,))

    # 1. Deep abyssal organic floor gradient
    lw, lh = width // 4, height // 4
    low_img = Image.new("RGBA", (lw, lh))
    for x in range(lw):
        for y in range(lh):
            rx = x * 4
            ry = y * 4
            dx = (rx - cx) / cx
            dy = (ry - cy) / cy
            dist = math.sqrt(dx*dx + dy*dy)

            w1 = math.sin(rx * 0.006 + ry * 0.003) * 12
            w2 = math.cos(rx * 0.012 - ry * 0.008) * 8
            w3 = math.sin((rx + ry) * 0.004) * 6

            center_glow = max(0.0, 1.0 - dist * 0.7) * 28.0
            vignette = min(40, dist * dist * 20)

            r = clamp(floor_col[0] + w1 * 0.3 + center_glow * (glow_col[0] / 255.0) - vignette)
            g = clamp(floor_col[1] + w1 * 0.8 + w2 * 0.7 + w3 * 0.5 + center_glow * (glow_col[1] / 255.0) - vignette)
            b = clamp(floor_col[2] + w1 * 1.3 + w2 * 1.1 + w3 + center_glow * (glow_col[2] / 255.0) - vignette)
            low_img.putpixel((x, y), (r, g, b, 255))

    upscaled = low_img.resize((width, height), Image.Resampling.BILINEAR)
    upscaled = upscaled.filter(ImageFilter.GaussianBlur(radius=10))
    img.paste(upscaled, (0, 0))
    draw = ImageDraw.Draw(img)

    # 2. Oceanic current strands
    for _ in range(22):
        sx = random.randint(180, 1740)
        sy = random.randint(150, 930)
        length = random.randint(140, 360)
        angle = random.uniform(0, math.pi * 2)
        ex = sx + math.cos(angle) * length
        ey = sy + math.sin(angle) * length
        alpha = random.randint(25, 60)
        draw.line([sx, sy, ex, ey], fill=(glow_col[0], glow_col[1], glow_col[2], alpha // 2), width=7)
        draw.line([sx, sy, ex, ey], fill=(glow_col[0], glow_col[1], glow_col[2], alpha), width=3)

    # 3. Bioluminescent plankton colonies
    for _ in range(30):
        nx = random.randint(180, 1740)
        ny = random.randint(150, 930)
        rad = random.randint(4, 14)
        alpha = random.randint(60, 120)
        draw.ellipse([nx - rad*2, ny - rad*2, nx + rad*2, ny + rad*2], fill=(glow_col[0], glow_col[1], glow_col[2], alpha // 3))
        draw.ellipse([nx - rad, ny - rad, nx + rad, ny + rad], fill=(glow_col[0], glow_col[1], glow_col[2], alpha))
        draw.point((nx, ny), fill=(245, 255, 255, 220))

    # 4. SOLID, CONTINUOUS PERIMETER WALLS (THICKNESS = 128) - NO DOOR CUTOUTS!
    thickness = 128
    wall_dark = (wall_col[0] - 6, wall_col[1] - 8, wall_col[2] - 10, 255)

    # Top Wall (entire 0..width)
    draw.rectangle([0, 0, width, thickness], fill=wall_col)
    # Bottom Wall (entire 0..width)
    draw.rectangle([0, height - thickness, width, height], fill=wall_col)
    # Left Wall (between top and bottom)
    draw.rectangle([0, thickness, thickness, height - thickness], fill=wall_col)
    # Right Wall (between top and bottom)
    draw.rectangle([width - thickness, thickness, width, height - thickness], fill=wall_col)

    # Layered craggy rock strata lines along all walls
    for ry in [28, 56, 84, 108]:
        draw.line([(0, ry), (width, ry)], fill=(glow_col[0], glow_col[1], glow_col[2], 25), width=2)
        draw.line([(0, height - ry), (width, height - ry)], fill=(glow_col[0], glow_col[1], glow_col[2], 25), width=2)
    for rx in [28, 56, 84, 108]:
        draw.line([(rx, thickness), (rx, height - thickness)], fill=(glow_col[0], glow_col[1], glow_col[2], 25), width=2)
        draw.line([(width - rx, thickness), (width - rx, height - thickness)], fill=(glow_col[0], glow_col[1], glow_col[2], 25), width=2)

    # Craggy fissures across walls
    for _ in range(40):
        if random.random() < 0.5:
            # Top or bottom wall
            wx = random.randint(20, width - 20)
            wy = random.choice([random.randint(10, thickness - 10), random.randint(height - thickness + 10, height - 10)])
        else:
            # Left or right wall
            wx = random.choice([random.randint(10, thickness - 10), random.randint(width - thickness + 10, width - 10)])
            wy = random.randint(20, height - 20)
        draw.ellipse([wx - 3, wy - 3, wx + 3, wy + 3], fill=(glow_col[0], glow_col[1], glow_col[2], random.randint(30, 90)))
        draw.point((wx, wy), fill=(240, 255, 255, 160))

    # CONTINUOUS Inner edge glows (smooth biological rim lighting around the whole arena)
    for i in range(10):
        a = int(140 * (1 - i / 10.0))
        c = (glow_col[0], glow_col[1], glow_col[2], a)
        # Top inner edge
        draw.line([(0, thickness + i), (width, thickness + i)], fill=c)
        # Bottom inner edge
        draw.line([(0, height - thickness - 1 - i), (width, height - thickness - 1 - i)], fill=c)
        # Left inner edge
        draw.line([(thickness + i, 0), (thickness + i, height)], fill=c)
        # Right inner edge
        draw.line([(width - thickness - 1 - i, 0), (width - thickness - 1 - i, height)], fill=c)

    # Organic corner brackets
    corner_pts = [
        [(0, 0), (180, 0), (0, 180)],
        [(width, 0), (width - 180, 0), (width, 180)],
        [(0, height), (180, height), (0, height - 180)],
        [(width, height), (width - 180, height), (width, height - 180)],
    ]
    for pts in corner_pts:
        draw.polygon(pts, fill=wall_dark)
        corner_cx = sum(p[0] for p in pts) / 3.0
        corner_cy = sum(p[1] for p in pts) / 3.0
        draw.ellipse([corner_cx - 30, corner_cy - 30, corner_cx + 30, corner_cy + 30],
                     fill=(glow_col[0], glow_col[1], glow_col[2], 50))

    # 5. Theme-specific Center Art
    if theme_type == "boss":
        # Abyssal Caldera with celestial periwinkle rings
        draw.ellipse([cx - 240, cy - 150, cx + 240, cy + 150], fill=(8, 12, 26, 230), outline=(120, 150, 245, 160), width=4)
        draw.ellipse([cx - 160, cy - 100, cx + 160, cy + 100], fill=(12, 16, 32, 245), outline=(0, 210, 235, 140), width=3)
        draw.ellipse([cx - 80, cy - 50, cx + 80, cy + 50], fill=(16, 22, 42, 255), outline=(140, 180, 255, 200), width=2)
        for r in [60, 120, 190]:
            draw.arc([cx - r * 1.4, cy - r * 0.85, cx + r * 1.4, cy + r * 0.85], 0, 360, fill=(120, 160, 245, 80), width=2)
    elif theme_type == "treasure":
        # DNA Double-Helix Emblem in pristine seafoam mint
        draw.ellipse([cx - 200, cy - 125, cx + 200, cy + 125], fill=(4, 18, 24, 220), outline=(0, 235, 185, 160), width=4)
        for i in range(14):
            t = i / 13.0
            hx = cx + math.sin(t * math.pi * 2) * 75
            hy = cy - 95 + t * 190
            draw.ellipse([hx - 10, hy - 6, hx + 10, hy + 6], fill=(0, 250, 200, 220))
            hx2 = cx - math.sin(t * math.pi * 2) * 75
            draw.ellipse([hx2 - 10, hy - 6, hx2 + 10, hy + 6], fill=(0, 215, 165, 200))
            draw.line([(hx, hy), (hx2, hy)], fill=(0, 250, 215, 90), width=2)
    elif theme_type == "shop":
        # Gene Shrine concentric circles in warm amber
        draw.ellipse([cx - 200, cy - 125, cx + 200, cy + 125], fill=(16, 20, 30, 220), outline=(240, 190, 50, 150), width=4)
        for r in [90, 60, 35]:
            draw.arc([cx - r, cy - r * 0.65, cx + r, cy + r * 0.65], 0, 360, fill=(240, 190, 50, 120), width=2)
    elif theme_type == "start":
        # Primordial Genesis Pool with serene azure ripples
        draw.ellipse([cx - 200, cy - 120, cx + 200, cy + 120], fill=(6, 20, 36, 220), outline=(60, 215, 255, 160), width=4)
        for r in [45, 90, 135]:
            draw.arc([cx - r * 1.3, cy - r * 0.75, cx + r * 1.3, cy + r * 0.75], 0, 360, fill=(60, 215, 255, 80), width=2)
        draw.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=(210, 250, 255, 220))

    # Outer soft vignette
    vignette = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vignette)
    for r in range(720, 0, -60):
        a = int(60 * (1 - r / 720.0))
        vd.ellipse([cx - r * 1.6, cy - r, cx + r * 1.6, cy + r], fill=(0, 0, 0, a))
    vignette = vignette.filter(ImageFilter.GaussianBlur(radius=32))
    img = Image.alpha_composite(img, vignette)

    img.save(f"assets/{filename}")
    print(f"  Seamless Background ({theme_type}): assets/{filename}")


# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

if __name__ == "__main__":
    ensure_dir("assets")

    print("\n--- Generating Solid, High-Impact Obstacles ---")
    draw_fossil_bone()
    draw_hydrothermal_vent()
    draw_rock()
    draw_biocrystal()

    print("\n--- Generating Seamless Door Systems ---")
    draw_door()
    draw_door_closed()
    draw_door_locked()

    print("\n--- Generating Seamless Room Backgrounds (Solid Perimeter Walls) ---")
    draw_fullscreen_background("room_bg_normal.png", "normal")
    draw_fullscreen_background("room_bg_start.png", "start")
    draw_fullscreen_background("room_bg_boss.png", "boss")
    draw_fullscreen_background("room_bg_treasure.png", "treasure")
    draw_fullscreen_background("room_bg_shop.png", "shop")

    print("\n=== All High-Fidelity Satisfying Assets Generated! ===")
