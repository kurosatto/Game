import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter

random.seed(42)

def create_directory():
    os.makedirs("assets", exist_ok=True)

def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v)))

# ─────────────────────────────────────────────────────────
# 1. BIOLOGICALLY ACCURATE PROTIST / EUKARYOTE (PLAYER)
# ─────────────────────────────────────────────────────────

def draw_player_frame(draw, frame=0):
    """
    Biologically authentic primordial eukaryote / flagellate (128x128).
    Includes:
    - Double phospholipid bilayer membrane with embedded receptor proteins
    - Central nucleus with nuclear envelope, dense chromatin & glowing nucleolus
    - 2 Mitochondria with visible inner cristae folds
    - Rough Endoplasmic Reticulum (ribosome-studded folds)
    - Pulsing contractile vacuole with radial ampullae
    - Carotenoid Eyespot Apparatus (Stigma) for phototaxis
    - Prominent sinusoidal undulating whip flagellum (9+2 axoneme) with mastigonemes
    """
    cx, cy = 64, 62
    t = frame / 4.0 * math.pi * 2

    # Drop shadow
    draw.ellipse([22, 92, 106, 120], fill=(2, 6, 14, 140))

    # 1. Undulating Sinusoidal Flagellum (9+2 Microtubule Axoneme)
    # Emerges from anterior flagellar pocket (cx, cy - 44) and projects forward
    flagellum_pts = []
    num_pts = 32
    for i in range(num_pts):
        fract = i / float(num_pts - 1)
        fy = cy - 44 - fract * 52.0
        # Sinusoidal traveling wave
        phase = t + fract * math.pi * 2.8
        fx = cx + math.sin(phase) * (6.0 + fract * 14.0)
        flagellum_pts.append((fx, fy))

    # Outer axoneme sheath glow
    for w, a in [(7, 50), (4, 130), (2, 255)]:
        col = (0, 230, 255, a) if w < 4 else (0, 180, 240, a)
        draw.line(flagellum_pts, fill=col, width=w)

    # Lateral mastigoneme hair fibrils along flagellum
    for i in range(2, num_pts - 2, 3):
        pt = flagellum_pts[i]
        next_pt = flagellum_pts[i+1]
        dx = next_pt[0] - pt[0]
        dy = next_pt[1] - pt[1]
        length = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / length, dx / length
        side = 1 if (i % 2 == 0) else -1
        hair_len = 5.0 + math.sin(t + i) * 2.0
        hx = pt[0] + nx * hair_len * side
        hy = pt[1] + ny * hair_len * side
        draw.line([pt, (hx, hy)], fill=(0, 240, 255, 140), width=1)

    # 2. Phospholipid Bilayer & Cytoplasm
    # Outer lipid bilayer
    draw.ellipse([cx - 46, cy - 44, cx + 46, cy + 44],
                 fill=(14, 130, 200, 215), outline=(0, 240, 255, 255), width=3)
    # Inner bilayer leaflet
    draw.ellipse([cx - 43, cy - 41, cx + 43, cy + 41],
                 fill=(10, 110, 180, 225), outline=(0, 180, 230, 180), width=1)
    # Granular inner cytosol
    draw.ellipse([cx - 40, cy - 38, cx + 40, cy + 38],
                 fill=(8, 85, 155, 235))

    # Transmembrane transport protein complexes along perimeter
    for ang_deg in range(0, 360, 24):
        a_rad = math.radians(ang_deg + (t * 8.0))
        px = cx + math.cos(a_rad) * 44.5
        py = cy + math.sin(a_rad) * 42.5
        col = (0, 255, 220, 240) if ang_deg % 48 == 0 else (240, 190, 40, 220)
        draw.ellipse([px - 2.5, py - 2.5, px + 2.5, py + 2.5], fill=col)

    # 3. Organelles:
    # A) Endoplasmic Reticulum (convoluted folded cisternae wrapping nucleus)
    er_pts_1 = [(cx - 28, cy - 8), (cx - 32, cy - 2), (cx - 30, cy + 10), (cx - 24, cy + 16)]
    er_pts_2 = [(cx + 26, cy - 6), (cx + 30, cy + 2), (cx + 28, cy + 12), (cx + 22, cy + 18)]
    draw.line(er_pts_1, fill=(70, 180, 240, 190), width=2)
    draw.line(er_pts_2, fill=(70, 180, 240, 190), width=2)
    # Ribosome beads on ER
    for rx, ry in [(cx - 30, cy - 5), (cx - 33, cy + 4), (cx + 28, cy - 2), (cx + 31, cy + 7)]:
        draw.ellipse([rx - 1.5, ry - 1.5, rx + 1.5, ry + 1.5], fill=(255, 240, 160, 220))

    # B) Mitochondria with real cristae folds
    # Left mitochondrion
    mx, my = cx - 24, cy + 18
    draw.ellipse([mx - 12, my - 6, mx + 12, my + 6],
                 fill=(220, 50, 130, 230), outline=(255, 140, 190, 240), width=2)
    for off in [-6, -2, 2, 6]:
        draw.line([(mx + off, my - 4), (mx + off, my + 4)], fill=(255, 200, 230, 200), width=1)

    # Right mitochondrion
    mx2, my2 = cx + 22, cy - 14
    draw.ellipse([mx2 - 6, my2 - 10, mx2 + 6, my2 + 10],
                 fill=(220, 50, 130, 230), outline=(255, 140, 190, 240), width=2)
    for off in [-6, -2, 2, 6]:
        draw.line([(mx2 - 4, my2 + off), (mx2 + 4, my2 + off)], fill=(255, 200, 230, 200), width=1)

    # C) Contractile Vacuole (pulses across frames)
    vac_r = 7.0 + math.sin(t) * 3.5
    vx, vy = cx - 18, cy - 20
    draw.ellipse([vx - vac_r, vy - vac_r, vx + vac_r, vy + vac_r],
                 fill=(40, 230, 160, 190), outline=(120, 255, 210, 230), width=2)
    # Radiating collecting ampullae
    for a_deg in [0, 90, 180, 270]:
        rad = math.radians(a_deg)
        ax = vx + math.cos(rad) * (vac_r + 4)
        ay = vy + math.sin(rad) * (vac_r + 4)
        draw.line([(vx, vy), (ax, ay)], fill=(120, 255, 210, 170), width=2)

    # D) Nucleus (Dense chromatin + double envelope + nucleolus)
    nx, ny = cx, cy - 2
    # Outer nuclear envelope
    draw.ellipse([nx - 19, ny - 17, nx + 19, ny + 17],
                 fill=(140, 40, 200, 240), outline=(220, 120, 255, 255), width=2)
    # Nuclear pores
    for ang_p in range(0, 360, 45):
        pr = math.radians(ang_p)
        px = nx + math.cos(pr) * 18
        py = ny + math.sin(pr) * 16
        draw.ellipse([px - 1.5, py - 1.5, px + 1.5, py + 1.5], fill=(255, 255, 200, 255))
    # Chromatin threads
    draw.arc([nx - 14, ny - 12, nx + 14, ny + 12], 20, 160, fill=(240, 140, 255, 200), width=2)
    draw.arc([nx - 12, ny - 8, nx + 12, ny + 8], 180, 320, fill=(240, 140, 255, 200), width=2)
    # Dense glowing Nucleolus
    draw.ellipse([nx - 6, ny - 5, nx + 6, ny + 5],
                 fill=(255, 255, 180, 255), outline=(255, 200, 50, 255), width=1)
    draw.ellipse([nx - 2, ny - 2, nx + 2, ny + 2], fill=(255, 255, 255, 255))

    # E) Phototaxis Eyespot (Stigma) - Authentic euglenoid carotenoid shield
    sx, sy = cx + 16, cy - 32
    # Carotenoid pigment granule cluster (deep red-orange curved shield)
    draw.arc([sx - 8, sy - 8, sx + 8, sy + 8], 140, 330, fill=(240, 40, 10, 255), width=4)
    # Photoreceptor paraxonemal swelling bead (sensitive light-gathering focus)
    draw.ellipse([sx - 2, sy - 3, sx + 4, sy + 3], fill=(255, 225, 40, 255))
    draw.ellipse([sx, sy - 1, sx + 2, sy + 1], fill=(255, 255, 255, 255))

    # F) Cytosolic streaming granules
    for gx, gy in [(cx + 10, cy + 24), (cx + 28, cy + 12), (cx - 10, cy + 28), (cx - 32, cy)]:
        draw.ellipse([gx - 2, gy - 2, gx + 2, gy + 2], fill=(120, 240, 255, 180))


def draw_player():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_player_frame(draw, frame=0)
    img.save("assets/player.png")
    print("  Bio Player: assets/player.png")

def draw_player_sheet():
    sheet = Image.new("RGBA", (512, 128), (0, 0, 0, 0))
    for i in range(4):
        frame_img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame_img)
        draw_player_frame(draw, frame=i)
        sheet.paste(frame_img, (i * 128, 0))
    sheet.save("assets/player_sheet.png")
    print("  Bio Player Sheet: assets/player_sheet.png")


# ─────────────────────────────────────────────────────────
# 2. BIOLOGICALLY ACCURATE ENEMIES
# ─────────────────────────────────────────────────────────

def draw_enemy_amoeba_frame(draw, frame=0):
    """Authentic Amoeba proteus: streaming lobopodia, granular endoplasm, food vacuoles (88x88)."""
    cx, cy = 44, 44
    t = frame / 4.0 * math.pi * 2

    # Drop shadow
    draw.ellipse([12, 68, 76, 84], fill=(4, 8, 16, 130))

    # 6 Dynamic lobose pseudopods
    num_pods = 7
    pod_pts = []
    for i in range(num_pods):
        angle = (i / float(num_pods)) * math.pi * 2 + math.sin(t + i) * 0.25
        reach = 28.0 + math.sin(t * 1.5 + i * 1.3) * 8.0
        px = cx + math.cos(angle) * reach
        py = cy + math.sin(angle) * reach
        pr = 10.0 + math.cos(t + i) * 2.5
        # Transparent hyaline ectoplasm cap (advancing zone)
        draw.ellipse([px - pr - 3, py - pr - 3, px + pr + 3, py + pr + 3],
                     fill=(140, 40, 200, 110))
        draw.ellipse([px - pr, py - pr, px + pr, py + pr],
                     fill=(180, 50, 220, 210), outline=(220, 140, 255, 230), width=2)
        pod_pts.append((px, py))

    # Central granular endoplasm core
    draw.ellipse([cx - 24, cy - 24, cx + 24, cy + 24],
                 fill=(160, 35, 200, 240), outline=(230, 120, 255, 255), width=2)

    # Organelles inside Amoeba:
    # A) Nucleus with distinct chromatin granules
    draw.ellipse([cx - 9, cy - 8, cx + 9, cy + 8],
                 fill=(240, 220, 50, 240), outline=(190, 140, 20, 255), width=2)
    draw.ellipse([cx - 4, cy - 3, cx + 4, cy + 3], fill=(255, 255, 140, 255))

    # B) Phagocytosed Food Vacuoles (digested green cyanobacteria / diatoms)
    draw.ellipse([cx - 16, cy + 6, cx - 6, cy + 16],
                 fill=(20, 170, 70, 220), outline=(80, 240, 130, 240), width=2)
    draw.ellipse([cx + 8, cy - 14, cx + 18, cy - 4],
                 fill=(30, 190, 120, 220), outline=(100, 255, 180, 240), width=1)
    draw.ellipse([cx + 6, cy + 10, cx + 14, cy + 18],
                 fill=(200, 120, 30, 200)) # lipid droplet

    # C) Contractile Vacuole
    draw.ellipse([cx - 14, cy - 14, cx - 4, cy - 4],
                 fill=(40, 220, 240, 180), outline=(160, 255, 255, 220), width=1)

def draw_enemy_amoeba():
    img = Image.new("RGBA", (88, 88), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_enemy_amoeba_frame(draw, frame=0)
    img.save("assets/enemy_fly.png")
    print("  Bio Amoeba: assets/enemy_fly.png")

def draw_enemy_amoeba_sheet():
    sheet = Image.new("RGBA", (352, 88), (0, 0, 0, 0))
    for i in range(4):
        frame = Image.new("RGBA", (88, 88), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame)
        draw_enemy_amoeba_frame(draw, frame=i)
        sheet.paste(frame, (i * 88, 0))
    sheet.save("assets/enemy_fly_sheet.png")
    print("  Bio Amoeba Sheet: assets/enemy_fly_sheet.png")


def draw_enemy_trilobite_frame(draw, frame=0):
    """Authentic Cambrian Trilobite: cephalon, calcite compound eyes, 5 thoracic segments, pygidium, biramous legs (104x104)."""
    cx, cy = 52, 52
    t = frame / 4.0 * math.pi * 2

    # Drop shadow
    draw.ellipse([14, 82, 90, 100], fill=(4, 8, 16, 140))

    # 1. Ventral Biramous Appendages (Jointed legs + gills rippling)
    for i in range(5):
        leg_y = cy - 14 + i * 14
        leg_phase = t + i * 1.2
        for side in [-1, 1]:
            lx1 = cx + side * 28
            lx2 = cx + side * (46 + math.sin(leg_phase) * 6)
            ly2 = leg_y + 8 + math.cos(leg_phase) * 4
            draw.line([(lx1, leg_y), (lx2, ly2)], fill=(30, 60, 85, 240), width=3)
            # Exopodite gill branch
            draw.line([(lx1 + side*6, leg_y - 2), (lx2 - side*4, ly2 - 5)], fill=(0, 210, 190, 160), width=2)

    # 2. Cephalon (Semicircular head shield)
    # Cranial shield
    draw.chord([cx - 36, cy - 42, cx + 36, cy - 8], 180, 360,
               fill=(45, 75, 105, 255), outline=(18, 38, 58, 255), width=3)
    # Glabella (central raised axial lobe of head)
    draw.ellipse([cx - 11, cy - 38, cx + 11, cy - 14],
                 fill=(60, 95, 130, 255), outline=(24, 46, 70, 255), width=2)
    # Genal spines (sharp backward flares from head corners)
    draw.polygon([(cx - 35, cy - 14), (cx - 44, cy + 6), (cx - 31, cy - 10)], fill=(35, 60, 85, 255))
    draw.polygon([(cx + 35, cy - 14), (cx + 44, cy + 6), (cx + 31, cy - 10)], fill=(35, 60, 85, 255))

    # 3. Calcite Crystal Compound Eyes (Crescent holochroal eye lobes)
    for side in [-1, 1]:
        ex = cx + side * 22
        ey = cy - 26
        # Crescent ocular lobe
        draw.ellipse([ex - 7, ey - 10, ex + 7, ey + 10],
                     fill=(0, 230, 210, 255), outline=(0, 140, 130, 255), width=2)
        # Calcite hexagonal lens prism texture
        draw.ellipse([ex - 4, ey - 6, ex + 4, ey + 6], fill=(160, 255, 245, 255))
        draw.ellipse([ex - 1, ey - 3, ex + 2, ey + 1], fill=(255, 255, 255, 255))

    # 4. Jointed Sensory Antennae
    ant_w = math.sin(t) * 6
    draw.line([(cx - 8, cy - 38), (cx - 24 + ant_w, cy - 58)], fill=(0, 240, 220, 240), width=3)
    draw.line([(cx + 8, cy - 38), (cx + 24 - ant_w, cy - 58)], fill=(0, 240, 220, 240), width=3)

    # 5. Articulated Thoracic Tergites (5 segments with axial rings and pleurae)
    for seg in range(5):
        sy = cy - 10 + seg * 11
        w_seg = 34 - seg * 3
        # Left pleura, axial lobe, right pleura
        draw.ellipse([cx - w_seg, sy - 5, cx + w_seg, sy + 5],
                     fill=(52, 85, 118, 255), outline=(20, 42, 65, 255), width=2)
        # Axial ridge ring (center lobe)
        draw.ellipse([cx - 9, sy - 5, cx + 9, sy + 5],
                     fill=(70, 108, 145, 255), outline=(25, 50, 75, 255), width=1)

    # 6. Pygidium (Tail shield)
    pyg_y = cy + 46
    draw.chord([cx - 18, pyg_y - 12, cx + 18, pyg_y + 12], 0, 180,
               fill=(42, 70, 98, 255), outline=(18, 36, 55, 255), width=2)

def draw_enemy_trilobite():
    img = Image.new("RGBA", (104, 104), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_enemy_trilobite_frame(draw, frame=0)
    img.save("assets/enemy_gusha.png")
    print("  Bio Trilobite: assets/enemy_gusha.png")

def draw_enemy_trilobite_sheet():
    sheet = Image.new("RGBA", (416, 104), (0, 0, 0, 0))
    for i in range(4):
        frame = Image.new("RGBA", (104, 104), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame)
        draw_enemy_trilobite_frame(draw, frame=i)
        sheet.paste(frame, (i * 104, 0))
    sheet.save("assets/enemy_gusha_sheet.png")
    print("  Bio Trilobite Sheet: assets/enemy_gusha_sheet.png")


# ─────────────────────────────────────────────────────────
# 3. THREE NEW LEVEL BOSSES
# ─────────────────────────────────────────────────────────

# ── LEVEL 1 BOSS: STENTOR TITAN (The Apex Heterotrich / Colossal Ciliate) ──
def draw_boss_stentor_frame(draw, frame=0):
    """
    Stentor Titan (220x220).
    Trumpet-shaped predatory ciliate:
    - Flared anterior bell with spiral adoral zone of membranelles (AZM cilia vortex)
    - Longitudinal blue-green cortical myoneme stripes
    - Beaded chain macronucleus looping along interior
    - Basal contractile holdfast
    """
    cx, cy = 110, 110
    t = frame / 6.0 * math.pi * 2

    # Drop shadow
    draw.ellipse([30, 175, 190, 215], fill=(4, 8, 16, 160))

    # Holdfast stalk at bottom (cx, cy + 85) to bell at top (cx, cy - 65)
    # Trumpet polygon outline
    bell_w = 78.0 + math.sin(t) * 4.0
    stem_w = 16.0
    pts = [
        (cx - bell_w, cy - 60),
        (cx - bell_w * 0.7, cy - 20),
        (cx - 28, cy + 25),
        (cx - stem_w, cy + 80),
        (cx + stem_w, cy + 80),
        (cx + 28, cy + 25),
        (cx + bell_w * 0.7, cy - 20),
        (cx + bell_w, cy - 60),
    ]
    # Body fill with stentorin pigment gradient
    draw.polygon(pts, fill=(16, 85, 120, 230), outline=(0, 220, 210, 255), width=4)

    # Longitudinal cortical striping (myoneme fiber tracks)
    num_stripes = 10
    for s in range(num_stripes):
        sfract = (s / float(num_stripes - 1)) * 2.0 - 1.0
        top_x = cx + sfract * (bell_w - 6)
        bot_x = cx + sfract * (stem_w - 4)
        mid_x = cx + sfract * 24.0 + math.sin(t + s) * 3.0
        draw.line([(top_x, cy - 58), (mid_x, cy + 20), (bot_x, cy + 78)],
                  fill=(0, 240, 210, 120 if s % 2 == 0 else 60), width=2)

    # Beaded chain macronucleus (8 glowing nuclear beads in a chain)
    for b in range(8):
        bfract = b / 7.0
        bx = cx + math.sin(bfract * math.pi * 1.5 + t * 0.5) * 30.0
        by = (cy - 40) + bfract * 105.0
        draw.ellipse([bx - 8, by - 8, bx + 8, by + 8],
                     fill=(255, 225, 60, 240), outline=(255, 160, 0, 255), width=2)
        draw.ellipse([bx - 3, by - 3, bx + 3, by + 3], fill=(255, 255, 220, 255))
        if b > 0:
            # connecting strand
            prev_bf = (b - 1) / 7.0
            pbx = cx + math.sin(prev_bf * math.pi * 1.5 + t * 0.5) * 30.0
            pby = (cy - 40) + prev_bf * 105.0
            draw.line([(pbx, pby), (bx, by)], fill=(255, 200, 40, 180), width=2)

    # Anterior Peristome Rim & Spiral Adoral Cilia Vortex (AZM)
    peristome_y = cy - 65
    draw.ellipse([cx - bell_w - 4, peristome_y - 20, cx + bell_w + 4, peristome_y + 20],
                 fill=(12, 110, 145, 255), outline=(0, 255, 230, 255), width=4)
    # Cytostome vortex (spiral mouth)
    for r_c, start_a, end_a in [(38, 0, 280), (26, 60, 320), (14, 120, 360)]:
        draw.arc([cx - r_c, peristome_y - r_c*0.4, cx + r_c, peristome_y + r_c*0.4],
                 start_a + t * 30, end_a + t * 30, fill=(0, 255, 240, 240), width=3)
    # Beating cilia fringe around perimeter
    num_cilia = 28
    for c in range(num_cilia):
        c_ang = (c / float(num_cilia)) * math.pi * 2 + t
        c_r_x = bell_w + 5
        c_r_y = 22
        c_bx = cx + math.cos(c_ang) * c_r_x
        c_by = peristome_y + math.sin(c_ang) * c_r_y
        c_tip_x = c_bx + math.cos(c_ang) * 12 + math.sin(t * 2.0 + c) * 4
        c_tip_y = c_by + math.sin(c_ang) * 12
        draw.line([(c_bx, c_by), (c_tip_x, c_tip_y)], fill=(0, 255, 220, 220), width=2)

    # Basal holdfast foot disc
    draw.ellipse([cx - stem_w - 6, cy + 76, cx + stem_w + 6, cy + 88],
                 fill=(8, 55, 80, 255), outline=(0, 200, 180, 255), width=2)

def draw_boss_stentor():
    img = Image.new("RGBA", (220, 220), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_boss_stentor_frame(draw, frame=0)
    img.save("assets/boss_stentor.png")
    print("  Boss Stentor: assets/boss_stentor.png")

def draw_boss_stentor_sheet():
    sheet = Image.new("RGBA", (1320, 220), (0, 0, 0, 0))
    for i in range(6):
        frame = Image.new("RGBA", (220, 220), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame)
        draw_boss_stentor_frame(draw, frame=i)
        sheet.paste(frame, (i * 220, 0))
    sheet.save("assets/boss_stentor_sheet.png")
    print("  Boss Stentor Sheet: assets/boss_stentor_sheet.png")


# ── LEVEL 2 BOSS: ANOMALOCARIS BRIGGSI (The Apex Radiodont) ──
def draw_boss_anomalocaris_frame(draw, frame=0):
    """
    Anomalocaris (260x220).
    Apex Cambrian Radiodont:
    - Hydrodynamic segmented body tapering to tail
    - 11 pairs of swimming lobes (lateral flaps) undulating in metachronal wave
    - Stalked bulbous compound eyes
    - Pair of prehensile spiny great appendages
    - Radial Peytoia mouthcone
    - Tail furca fin assembly
    """
    cx, cy = 130, 110
    t = frame / 6.0 * math.pi * 2

    # Drop shadow
    draw.ellipse([40, 175, 220, 215], fill=(4, 8, 16, 160))

    # 1. Undulating Lateral Swimming Lobes (Flaps) along sides
    num_flaps = 9
    for f in range(num_flaps):
        fy = cy - 40 + f * 15
        flap_phase = t + f * 0.85
        flap_reach = 48.0 + math.sin(flap_phase) * 12.0
        for side in [-1, 1]:
            bx = cx + side * (32 - f * 1.8)
            tx = cx + side * (32 + flap_reach)
            # Flap polygon
            f_pts = [(bx, fy - 6), (tx, fy + 4), (bx, fy + 12)]
            draw.polygon(f_pts, fill=(185, 45, 65, 220), outline=(255, 120, 130, 200), width=2)
            # Rib lines on flap
            draw.line([(bx, fy), (tx, fy + 4)], fill=(255, 170, 180, 180), width=2)

    # 2. Main Segmented Dorsal Body
    body_pts = [
        (cx - 32, cy - 50),
        (cx - 36, cy - 20),
        (cx - 32, cy + 20),
        (cx - 22, cy + 60),
        (cx - 12, cy + 85),
        (cx + 12, cy + 85),
        (cx + 22, cy + 60),
        (cx + 32, cy + 20),
        (cx + 36, cy - 20),
        (cx + 32, cy - 50),
    ]
    draw.polygon(body_pts, fill=(155, 30, 50, 255), outline=(80, 10, 25, 255), width=4)

    # Segment Tergite Lines
    for seg in range(7):
        sy = cy - 35 + seg * 16
        sw = 33 - seg * 3
        draw.arc([cx - sw, sy - 6, cx + sw, sy + 6], 0, 180, fill=(230, 85, 105, 255), width=3)

    # 3. Tail Furca (3-pair fan blades at posterior)
    for tf, tangle in [(-24, 40), (0, 75), (24, 110)]:
        fx = cx + tf
        fy = cy + 82
        draw.polygon([(cx, fy), (fx - 8, fy + 24), (fx + 8, fy + 24)],
                     fill=(200, 50, 70, 255), outline=(255, 140, 150, 255), width=2)

    # 4. Stalked Compound Eyes (Bulbous lateral stalks)
    for side in [-1, 1]:
        stalk_bx = cx + side * 22
        stalk_by = cy - 48
        eye_x = cx + side * 54
        eye_y = cy - 62
        # Articulated eye stalk
        draw.line([(stalk_bx, stalk_by), (eye_x, eye_y)], fill=(120, 20, 35, 255), width=6)
        # Large compound eye bulb
        draw.ellipse([eye_x - 14, eye_y - 14, eye_x + 14, eye_y + 14],
                     fill=(0, 230, 200, 255), outline=(0, 140, 120, 255), width=3)
        # Calcite ommatidia honeycomb glint
        draw.ellipse([eye_x - 8, eye_y - 8, eye_x + 8, eye_y + 8], fill=(180, 255, 240, 255))
        draw.ellipse([eye_x - 3, eye_y - 5, eye_x + 3, eye_y + 1], fill=(255, 255, 255, 255))

    # 5. Ventral Peytoia Mouthcone (radial circular plates)
    mouth_y = cy - 28
    draw.ellipse([cx - 18, mouth_y - 12, cx + 18, mouth_y + 12],
                 fill=(40, 8, 12, 255), outline=(230, 90, 100, 255), width=3)
    # Radial tooth plates
    for tp in range(8):
        trad = math.radians(tp * 45)
        tx = cx + math.cos(trad) * 12
        ty = mouth_y + math.sin(trad) * 8
        draw.line([(cx, mouth_y), (tx, ty)], fill=(255, 220, 180, 220), width=2)

    # 6. Prehensile Spiny Great Appendages (Formidable raptorial arms)
    for side in [-1, 1]:
        app_phase = t + side * 0.4
        curl = math.sin(app_phase) * 8
        base_x = cx + side * 12
        base_y = cy - 54
        joint1_x = cx + side * 28
        joint1_y = cy - 78
        joint2_x = cx + side * (18 + curl)
        joint2_y = cy - 98

        # Segmented arm segments
        draw.line([(base_x, base_y), (joint1_x, joint1_y)], fill=(220, 60, 80, 255), width=7)
        draw.line([(joint1_x, joint1_y), (joint2_x, joint2_y)], fill=(220, 60, 80, 255), width=5)

        # Dagger-like inward ventral spines (14 segments of spines)
        for sp in range(5):
            sf = sp / 4.0
            sx = base_x + (joint1_x - base_x) * sf
            sy = base_y + (joint1_y - base_y) * sf
            tip_x = sx - side * (12 - sp)
            tip_y = sy + 4
            draw.line([(sx, sy), (tip_x, tip_y)], fill=(255, 230, 200, 255), width=2)

def draw_boss_anomalocaris():
    img = Image.new("RGBA", (260, 220), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_boss_anomalocaris_frame(draw, frame=0)
    img.save("assets/boss_anomalocaris.png")
    print("  Boss Anomalocaris: assets/boss_anomalocaris.png")

def draw_boss_anomalocaris_sheet():
    sheet = Image.new("RGBA", (1560, 220), (0, 0, 0, 0))
    for i in range(6):
        frame = Image.new("RGBA", (260, 220), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame)
        draw_boss_anomalocaris_frame(draw, frame=i)
        sheet.paste(frame, (i * 260, 0))
    sheet.save("assets/boss_anomalocaris_sheet.png")
    print("  Boss Anomalocaris Sheet: assets/boss_anomalocaris_sheet.png")


# ── LEVEL 3 BOSS: CAMEROCERAS TRENTONENSE (Titanic Apex Orthocone) ──
def draw_boss_cameroceras_frame(draw, frame=0):
    """
    Cameroceras (280x220).
    Colossal Ordovician Orthoconic Cephalopod:
    - Massive straight conical shell with transversal septa growth lines
    - Large living chamber opening
    - 10 Muscular hooked tentacles lined with claws and suckers
    - Intelligent cephalopod camera eye with horizontal slit pupil
    - Parrot-like chitinous beak
    - Ventral hyponome propulsion funnel
    """
    cx, cy = 140, 110
    t = frame / 6.0 * math.pi * 2

    # Drop shadow
    draw.ellipse([35, 175, 245, 215], fill=(4, 8, 16, 170))

    # 1. Titanic Conical Orthocone Shell
    # Extends from apex high up (cx, cy - 100) down to living chamber rim (cx, cy + 20)
    apex_x, apex_y = cx, cy - 98
    base_left = (cx - 48, cy + 18)
    base_right = (cx + 48, cy + 18)

    shell_poly = [(apex_x, apex_y), base_left, (cx, cy + 24), base_right]
    draw.polygon(shell_poly, fill=(58, 48, 68, 255), outline=(28, 20, 36, 255), width=5)

    # Shell Transverse Camera Septa / Growth Rings & Camouflage Banding
    num_septa = 11
    for s in range(num_septa):
        sf = s / float(num_septa)
        sy = apex_y + sf * (base_left[1] - apex_y)
        sw = sf * 46.0
        # Curved septa line
        draw.arc([cx - sw, sy - 6, cx + sw, sy + 6], 0, 180,
                 fill=(130, 95, 140, 220) if s % 2 == 0 else (90, 65, 100, 180), width=3)

    # Longitudinal Siphuncle Canal (central line)
    draw.line([(apex_x, apex_y), (cx, cy + 18)], fill=(180, 140, 200, 100), width=3)

    # 2. Living Chamber Opening Rim
    draw.ellipse([cx - 48, cy + 12, cx + 48, cy + 28],
                 fill=(35, 24, 45, 255), outline=(160, 120, 180, 255), width=4)

    # 3. Head Emerging from Chamber
    draw.ellipse([cx - 36, cy + 20, cx + 36, cy + 54],
                 fill=(180, 35, 75, 255), outline=(100, 15, 40, 255), width=3)

    # 4. Cephalopod Camera Eyes with Horizontal Slit Pupil
    for side in [-1, 1]:
        eye_x = cx + side * 28
        eye_y = cy + 34
        # Outer iris ring
        draw.ellipse([eye_x - 11, eye_y - 11, eye_x + 11, eye_y + 11],
                     fill=(245, 180, 30, 255), outline=(140, 80, 0, 255), width=2)
        # Deep black horizontal slit pupil
        draw.line([(eye_x - 8, eye_y), (eye_x + 8, eye_y)], fill=(6, 0, 0, 255), width=4)
        # Specular glint
        draw.ellipse([eye_x - 4, eye_y - 5, eye_x, eye_y - 1], fill=(255, 255, 255, 220))

    # 5. Ventral Hyponome (Propulsion Siphon Funnel)
    hyp_x = cx
    hyp_y = cy + 46
    draw.polygon([(hyp_x - 12, hyp_y), (hyp_x + 12, hyp_y), (hyp_x + 8, hyp_y + 16), (hyp_x - 8, hyp_y + 16)],
                 fill=(140, 25, 60, 255), outline=(70, 10, 30, 255), width=2)

    # 6. Ring of 10 Muscular Hooked Tentacles
    num_tentacles = 8
    for i in range(num_tentacles):
        tfract = (i / float(num_tentacles - 1)) * 2.0 - 1.0 # -1 to 1
        t_phase = t + i * 0.8
        tx_base = cx + tfract * 34.0
        ty_base = cy + 48

        reach_x = tx_base + tfract * 30.0 + math.sin(t_phase) * 14.0
        reach_y = ty_base + 44.0 + math.cos(t_phase) * 10.0

        # Thick muscular tentacle
        draw.line([(tx_base, ty_base), (reach_x, reach_y)], fill=(195, 40, 85, 255), width=6)
        draw.line([(tx_base, ty_base), (reach_x, reach_y)], fill=(255, 120, 160, 200), width=2)

        # Hooked sucker claws along tentacle
        for hook_step in [0.4, 0.7, 0.95]:
            hx = tx_base + (reach_x - tx_base) * hook_step
            hy = ty_base + (reach_y - ty_base) * hook_step
            side_hook = 1 if i < num_tentacles // 2 else -1
            draw.line([(hx, hy), (hx + side_hook * 4, hy + 3)], fill=(255, 240, 210, 255), width=2)

    # Parrot-like Chitinous Beak (Center of Tentacle Crown)
    draw.polygon([(cx, cy + 48), (cx - 7, cy + 58), (cx + 7, cy + 58)],
                 fill=(20, 10, 14, 255), outline=(80, 40, 50, 255), width=2)

def draw_boss_cameroceras():
    img = Image.new("RGBA", (280, 220), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_boss_cameroceras_frame(draw, frame=0)
    img.save("assets/boss_cameroceras.png")
    print("  Boss Cameroceras: assets/boss_cameroceras.png")

def draw_boss_cameroceras_sheet():
    sheet = Image.new("RGBA", (1680, 220), (0, 0, 0, 0))
    for i in range(6):
        frame = Image.new("RGBA", (280, 220), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame)
        draw_boss_cameroceras_frame(draw, frame=i)
        sheet.paste(frame, (i * 280, 0))
    sheet.save("assets/boss_cameroceras_sheet.png")
    print("  Boss Cameroceras Sheet: assets/boss_cameroceras_sheet.png")


# ─────────────────────────────────────────────────────────
# 4. BIOLOGICALLY ACCURATE PREHISTORIC OBSTACLES
# ─────────────────────────────────────────────────────────

def draw_stromatolite():
    """Precambrian layered cyanobacterial dome (128x128)."""
    random.seed(33)
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Ambient drop shadow
    draw.ellipse([14, 94, 114, 124], fill=(4, 8, 16, 150))

    # Basal sediment mound
    draw.ellipse([16, 82, 112, 118], fill=(28, 38, 44, 255), outline=(12, 18, 22, 255), width=3)

    # Layered concentric domal laminae (concentric microbial mats)
    dome_layers = [
        # (box, fill_color, outline_color)
        ([22, 54, 106, 114], (40, 68, 62), (60, 110, 95)),
        ([26, 42, 102, 110], (34, 82, 70), (80, 145, 120)),
        ([32, 32, 96, 104], (45, 98, 80), (100, 175, 140)),
        ([38, 22, 90, 98], (55, 115, 92), (120, 210, 165)),
        ([46, 14, 82, 88], (68, 135, 105), (140, 235, 185)),
    ]
    for box, col, out_col in dome_layers:
        draw.chord(box, 180, 360, fill=col + (255,), outline=out_col + (255,), width=2)
        # Laminar sediment banding lines
        for ly in range(box[1] + 6, box[3] - 20, 8):
            draw.arc([box[0] + 4, ly, box[2] - 4, ly + 14], 180, 360,
                     fill=(col[0] - 10, col[1] + 20, col[2] + 15, 180), width=2)

    # Photosynthetic biofilm patina and micro-oxygen bubbles
    for ox, oy in [(54, 26), (68, 20), (44, 46), (78, 42), (60, 60)]:
        draw.ellipse([ox - 3, oy - 3, ox + 3, oy + 3], fill=(0, 255, 200, 220), outline=(200, 255, 240, 255), width=1)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.4))
    img.save("assets/stromatolite.png")
    print("  Stromatolite: assets/stromatolite.png")


def draw_ediacaran_frond():
    """Elegant, bioluminescent Rangeomorph sea-fern with soothing translucent sea-glass cyan and golden nodes (128x128)."""
    random.seed(52)
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = 64, 64
    # Ambient soft drop shadow
    draw.ellipse([24, 98, 104, 122], fill=(6, 16, 28, 130))

    # Smooth seafloor pebble anchor (smooth polished slate/limestone)
    draw.ellipse([42, 98, 86, 118], fill=(32, 54, 72, 255), outline=(20, 36, 50, 255), width=3)
    draw.ellipse([48, 102, 78, 112], fill=(48, 80, 104, 220))

    # Graceful central stalk (rachis) with gentle cyan glow
    stalk_pts = [(cx, 106), (cx - 1, 75), (cx + 1, 45), (cx, 16)]
    draw.line(stalk_pts, fill=(0, 200, 210, 100), width=6)
    draw.line(stalk_pts, fill=(50, 130, 150, 255), width=4)
    draw.line(stalk_pts, fill=(160, 245, 235, 220), width=1)

    # Quilted self-similar feather pinnules (soothing curved sea-fern vanes)
    num_pairs = 9
    for b in range(num_pairs):
        bf = b / float(num_pairs)
        by = 94 - bf * 74.0
        # Gentle natural tapering curve
        bw = (32.0 * math.sin((bf + 0.1) * math.pi * 0.85))
        for side in [-1, 1]:
            # Curved feather leaf
            bx_tip = cx + side * bw
            by_tip = by - 7.0 - bf * 4.0
            bx_mid = cx + side * (bw * 0.6)
            by_mid = by - 12.0

            # Soft translucent gradient petal
            petal_pts = [(cx, by), (bx_mid, by_mid), (bx_tip, by_tip), (bx_tip - side * 4, by_tip + 5), (cx, by + 4)]
            # Harmonious seafoam & aquamarine tones
            fill_col = (20, 135, 145, 210)
            outline_col = (0, 225, 215, 230)
            draw.polygon(petal_pts, fill=fill_col, outline=outline_col, width=2)

            # Delicate secondary veinlet
            draw.line([(cx, by - 2), (bx_tip, by_tip)], fill=(130, 245, 230, 180), width=1)

            # Ethereal bioluminescent pearl node on each frond tip
            draw.ellipse([bx_tip - 3, by_tip - 3, bx_tip + 3, by_tip + 3],
                         fill=(230, 255, 210, 240), outline=(255, 235, 130, 200), width=1)
            draw.point((int(bx_tip), int(by_tip)), fill=(255, 255, 255, 255))

    # Luminous apex crown
    draw.ellipse([cx - 5, 10, cx + 5, 22], fill=(220, 255, 245, 255), outline=(0, 230, 210, 220), width=2)
    draw.ellipse([cx - 2, 13, cx + 2, 17], fill=(255, 255, 255, 255))

    img = img.filter(ImageFilter.GaussianBlur(radius=0.4))
    img.save("assets/ediacaran_frond.png")
    print("  Redesigned Ediacaran Frond: assets/ediacaran_frond.png")


def draw_hydrothermal_vent():
    """Majestic deep-sea hydrothermal mineral spire with crystalline fissures and luminous aquatic thermal vapor (128x128)."""
    random.seed(67)
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Ambient soft drop shadow
    draw.ellipse([14, 96, 114, 124], fill=(6, 16, 28, 140))

    # Terraced basaltic mineral spire base
    base_shelf = [
        (24, 114), (32, 94), (54, 90), (74, 90), (96, 94), (104, 114), (64, 120)
    ]
    draw.polygon(base_shelf, fill=(28, 42, 58, 255), outline=(16, 26, 38, 255), width=3)

    # Stepped crystalline obsidian chimney columns
    column_pts = [
        (44, 110), (38, 54), (46, 26), (82, 26), (90, 54), (84, 110)
    ]
    draw.polygon(column_pts, fill=(36, 52, 70, 255), outline=(18, 30, 44, 255), width=3)

    # Secondary stepped shelf on the left & right
    draw.polygon([(30, 96), (36, 68), (48, 70), (44, 98)], fill=(44, 64, 84, 255), outline=(22, 36, 50, 255), width=2)
    draw.polygon([(84, 98), (80, 70), (92, 68), (98, 96)], fill=(44, 64, 84, 255), outline=(22, 36, 50, 255), width=2)

    # Luminous geothermal aquamarine crystal fissures
    fissures = [
        [(54, 34), (62, 56), (56, 80), (62, 104)],
        [(74, 38), (68, 62), (76, 88)],
        [(36, 78), (42, 86)],
        [(90, 78), (86, 86)],
    ]
    for f_pts in fissures:
        draw.line(f_pts, fill=(0, 180, 210, 90), width=6)
        draw.line(f_pts, fill=(0, 230, 240, 180), width=3)
        draw.line(f_pts, fill=(210, 255, 250, 230), width=1)

    # Vent orifice / geothermal pool at chimney crown
    draw.ellipse([46, 20, 82, 32], fill=(12, 30, 44, 255), outline=(0, 210, 220, 255), width=2)
    draw.ellipse([50, 22, 78, 30], fill=(0, 220, 235, 200))
    draw.ellipse([56, 24, 72, 28], fill=(230, 255, 255, 240))

    # Gentle rising thermal bubbles and luminous vapor motes
    bubbles = [
        (64, 16, 5), (58, 8, 4), (68, 4, 3), (62, -2, 2),
        (52, 12, 2.5), (74, 10, 3)
    ]
    for bx, by, br in bubbles:
        if by > -4:
            draw.ellipse([bx - br*2, by - br*2, bx + br*2, by + br*2], fill=(0, 220, 255, 40))
            draw.ellipse([bx - br, by - br, bx + br, by + br], fill=(180, 245, 255, 180), outline=(0, 240, 255, 220), width=1)
            draw.point((int(bx - 1), int(by - 1)), fill=(255, 255, 255, 255))

    img = img.filter(ImageFilter.GaussianBlur(radius=0.4))
    img.save("assets/hydrothermal_vent.png")
    print("  Redesigned Hydrothermal Vent: assets/hydrothermal_vent.png")


def draw_calcified_sponge():
    """Archaeocyathid double-walled conical porous sponge (128x128)."""
    random.seed(73)
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Drop shadow
    draw.ellipse([20, 96, 108, 122], fill=(4, 8, 16, 150))

    # Conical outer cup wall (inverted porous cone)
    sponge_poly = [
        (48, 112), (28, 42), (100, 42), (80, 112)
    ]
    draw.polygon(sponge_poly, fill=(55, 75, 90, 255), outline=(22, 34, 44, 255), width=4)

    # Central cavity (osculum) top opening
    draw.ellipse([28, 32, 100, 52], fill=(14, 22, 30, 255), outline=(120, 160, 180, 255), width=3)
    # Inner wall lining
    draw.ellipse([38, 38, 90, 48], fill=(6, 10, 16, 255), outline=(70, 100, 120, 255), width=2)

    # Pores (ostia) across outer calcareous wall
    for row in range(5):
        ry = 54 + row * 11
        r_cols = 5 - row % 2
        for col in range(r_cols):
            cfract = (col / float(r_cols - 1)) * 2.0 - 1.0
            half_w = (1.0 - (row / 5.0) * 0.3) * 28.0
            ox = 64 + cfract * half_w
            draw.ellipse([ox - 2.5, ry - 2, ox + 2.5, ry + 2],
                         fill=(0, 210, 230, 220), outline=(0, 140, 160, 255), width=1)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.4))
    img.save("assets/calcified_sponge.png")
    print("  Calcified Sponge: assets/calcified_sponge.png")


# ─────────────────────────────────────────────────────────
# 5. BIOLOGICALLY ACCURATE PICKUPS
# ─────────────────────────────────────────────────────────

def draw_pickups_biological():
    # ── ATP (Adenosine Triphosphate - Currency) ──
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = 32, 32
    # Triphosphate energy halo
    for g in range(4, 0, -1):
        draw.ellipse([cx - 20 - g, cy - 20 - g, cx + 20 + g, cy + 20 + g],
                     fill=(0, 240, 200, 15 + g * 12))

    # Adenine & Ribose core ring
    draw.ellipse([cx - 18, cy - 18, cx + 18, cy + 18],
                 fill=(12, 50, 75, 255), outline=(0, 245, 215, 255), width=3)
    draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10],
                 fill=(0, 180, 160, 220))

    # Three radiant high-energy Phosphate groups (P ~ P ~ P)
    phos_angles = [210, 270, 330]
    for pa in phos_angles:
        prad = math.radians(pa)
        px = cx + math.cos(prad) * 11
        py = cy + math.sin(prad) * 11
        draw.ellipse([px - 4, py - 4, px + 4, py + 4],
                     fill=(255, 230, 60, 255), outline=(255, 140, 0, 255), width=1)
        draw.ellipse([px - 1.5, py - 1.5, px + 1.5, py + 1.5], fill=(255, 255, 255, 255))

    img.save("assets/pickup_coin.png")
    print("  Bio ATP: assets/pickup_coin.png")

    # ── Enzymatic Ligand (Key) ──
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Tertiary folded protein ligand with active site cleft
    for g in range(3, 0, -1):
        draw.ellipse([14 - g, 14 - g, 50 + g, 50 + g], fill=(255, 210, 40, 15 + g * 15))
    # Globular protein domains
    draw.ellipse([16, 20, 38, 42], fill=(245, 195, 40, 255), outline=(180, 130, 10, 255), width=3)
    draw.ellipse([30, 16, 48, 34], fill=(255, 220, 60, 255), outline=(190, 140, 10, 255), width=2)
    # Active site binding cleft (lock-and-key complementary domain)
    draw.polygon([(36, 24), (48, 24), (44, 38), (34, 34)], fill=(80, 45, 0, 255))
    draw.ellipse([22, 26, 30, 34], fill=(255, 255, 220, 240)) # Catalytic center
    img.save("assets/pickup_key.png")
    print("  Bio Enzymatic Ligand: assets/pickup_key.png")

    # ── Cytolytic Lysosome (Bomb) ──
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Membrane vesicle filled with hydrolytic digestive enzymes
    for g in range(4, 0, -1):
        draw.ellipse([cx - 20 - g, cy - 20 - g, cx + 20 + g, cy + 20 + g],
                     fill=(255, 80, 20, 15 + g * 15))
    # Bilayer vesicle boundary
    draw.ellipse([cx - 18, cy - 18, cx + 18, cy + 18],
                 fill=(220, 40, 25, 255), outline=(255, 180, 120, 255), width=3)
    # Inner enzymatic matrix
    draw.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=(160, 15, 10, 255))
    # Acid hydrolase enzyme clusters inside
    for ex, ey in [(cx - 5, cy - 4), (cx + 5, cy - 3), (cx, cy + 6)]:
        draw.ellipse([ex - 3, ey - 3, ex + 3, ey + 3], fill=(255, 230, 80, 240))
    # Specular gloss
    draw.ellipse([cx - 12, cy - 14, cx - 4, cy - 8], fill=(255, 240, 220, 180))
    img.save("assets/pickup_bomb.png")
    print("  Bio Cytolytic Lysosome: assets/pickup_bomb.png")

    # ── Vitality Biomass / Hemolymph (Hearts) ──
    # Full Biomass
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Pulsating lipid-bound cellular biomass droplet
    for g in range(4, 0, -1):
        draw.ellipse([10 - g, 10 - g, 54 + g, 54 + g], fill=(255, 30, 80, 15 + g * 12))
    draw.ellipse([12, 12, 52, 52], fill=(245, 25, 75, 255), outline=(255, 140, 170, 255), width=3)
    # Oxygen-carrier metalloprotein core
    draw.ellipse([20, 20, 44, 44], fill=(190, 10, 50, 255))
    draw.ellipse([26, 26, 38, 38], fill=(255, 100, 140, 255))
    draw.ellipse([18, 16, 28, 24], fill=(255, 220, 235, 220)) # Specular
    img.save("assets/pickup_heart.png")

    # Half Biomass
    img_half = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_h = ImageDraw.Draw(img_half)
    draw_h.chord([12, 12, 52, 52], 90, 270, fill=(245, 25, 75, 255), outline=(255, 140, 170, 255), width=3)
    draw_h.chord([12, 12, 52, 52], 270, 90, fill=(35, 45, 60, 255), outline=(65, 80, 105, 255), width=2)
    draw_h.line([(32, 12), (32, 52)], fill=(120, 20, 40, 255), width=2)
    img_half.save("assets/pickup_heart_half.png")

    # Depleted Biomass
    img_empty = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw_e = ImageDraw.Draw(img_empty)
    draw_e.ellipse([12, 12, 52, 52], fill=(20, 28, 40, 255), outline=(50, 68, 92, 255), width=3)
    img_empty.save("assets/pickup_heart_empty.png")
    print("  Bio Vitality Biomass: assets/pickup_heart.png")


if __name__ == "__main__":
    create_directory()
    print("\n=== Generating Biological Visual Assets ===")
    draw_player()
    draw_player_sheet()
    draw_enemy_amoeba()
    draw_enemy_amoeba_sheet()
    draw_enemy_trilobite()
    draw_enemy_trilobite_sheet()

    print("\n=== Generating 3 Unique Apex Level Bosses ===")
    draw_boss_stentor()
    draw_boss_stentor_sheet()
    draw_boss_anomalocaris()
    draw_boss_anomalocaris_sheet()
    draw_boss_cameroceras()
    draw_boss_cameroceras_sheet()

    print("\n=== Generating Prehistoric Biological Obstacles ===")
    draw_stromatolite()
    draw_ediacaran_frond()
    try:
        import generate_satisfying_art
        generate_satisfying_art.draw_hydrothermal_vent()
        generate_satisfying_art.draw_fossil_bone()
    except Exception:
        draw_hydrothermal_vent()
    draw_calcified_sponge()

    print("\n=== Generating Biological Pickups & Biomass ===")
    draw_pickups_biological()

    print("\nBiological assets generated successfully!")
