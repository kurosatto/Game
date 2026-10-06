import os
import math
from PIL import Image, ImageDraw

def create_directory():
    os.makedirs("assets", exist_ok=True)

# ── FLOOR 4: ARTHROPLEURA GIGANTEA (Carboniferous Titanic Myriapod) ──
def draw_arthropleura_frame(draw, frame=0):
    cx, cy = 130, 110
    t = frame / 6.0 * math.pi * 2

    # Shadow
    draw.ellipse([35, 175, 225, 215], fill=(4, 8, 16, 160))

    # Long multi-segmented chitinous body
    num_segments = 14
    for i in range(num_segments):
        frac = i / float(num_segments - 1)
        seg_y = cy - 65 + i * 9.5
        seg_w = 40.0 - abs(frac - 0.4) * 16.0
        seg_x = cx + math.sin(t + i * 0.45) * 6.0

        # Segment legs on both sides
        for side in [-1, 1]:
            leg_phase = t + i * 0.7 + (0 if side == 1 else math.pi)
            leg_base_x = seg_x + side * (seg_w - 4)
            leg_knee_x = leg_base_x + side * (16.0 + math.sin(leg_phase) * 6.0)
            leg_knee_y = seg_y - 6.0 + math.cos(leg_phase) * 4.0
            leg_tip_x = leg_knee_x + side * 12.0
            leg_tip_y = seg_y + 10.0 + math.sin(leg_phase) * 6.0

            draw.line([(leg_base_x, seg_y), (leg_knee_x, leg_knee_y)], fill=(130, 80, 40, 255), width=3)
            draw.line([(leg_knee_x, leg_knee_y), (leg_tip_x, leg_tip_y)], fill=(180, 110, 50, 255), width=2)
            # Claw tip
            draw.ellipse([leg_tip_x - 2, leg_tip_y - 2, leg_tip_x + 2, leg_tip_y + 2], fill=(230, 180, 80, 255))

        # Dorsal tergite plate (amber-brown armored carapace)
        c_fill = (75 + int(frac * 30), 45 + int(frac * 20), 20 + int(frac * 10), 255)
        c_out = (170, 110, 45, 255) if i % 2 == 0 else (210, 150, 60, 255)
        draw.rounded_rectangle([seg_x - seg_w, seg_y - 6, seg_x + seg_w, seg_y + 6], radius=4, fill=c_fill, outline=c_out, width=2)
        # Spine nodules
        draw.ellipse([seg_x - seg_w + 4, seg_y - 3, seg_x - seg_w + 8, seg_y + 1], fill=(240, 180, 50, 255))
        draw.ellipse([seg_x + seg_w - 8, seg_y - 3, seg_x + seg_w - 4, seg_y + 1], fill=(240, 180, 50, 255))

    # Head capsule at top
    head_x = cx + math.sin(t) * 6.0
    head_y = cy - 72
    draw.ellipse([head_x - 24, head_y - 18, head_x + 24, head_y + 18], fill=(95, 45, 20, 255), outline=(230, 150, 50, 255), width=3)

    # Multi-faceted compound eyes
    for side in [-1, 1]:
        ex = head_x + side * 14
        ey = head_y - 6
        draw.ellipse([ex - 6, ey - 6, ex + 6, ey + 6], fill=(255, 60, 40, 255), outline=(255, 200, 50, 255), width=1)
        draw.ellipse([ex - 2, ey - 2, ex + 2, ey + 2], fill=(255, 255, 200, 255))

    # Sensory antennae
    for side in [-1, 1]:
        ant_pts = [
            (head_x + side * 8, head_y - 16),
            (head_x + side * 22 + math.sin(t * 1.5 + side) * 8, head_y - 36),
            (head_x + side * 36 + math.cos(t * 1.5 + side) * 12, head_y - 52)
        ]
        draw.line(ant_pts, fill=(230, 160, 60, 255), width=2)

    # Piercing raptorial mandibles
    draw.line([(head_x - 8, head_y + 12), (head_x - 16, head_y + 24)], fill=(255, 200, 70, 255), width=4)
    draw.line([(head_x + 8, head_y + 12), (head_x + 16, head_y + 24)], fill=(255, 200, 70, 255), width=4)

# ── FLOOR 5: POSTOSUCHUS KIRKPATRICKI (Triassic Apex Archosaur) ──
def draw_postosuchus_frame(draw, frame=0):
    cx, cy = 130, 110
    t = frame / 6.0 * math.pi * 2

    # Shadow
    draw.ellipse([30, 175, 230, 215], fill=(4, 8, 16, 160))

    # Powerful muscular reptilian quadruped / semi-erect predator
    # Heavy tail waving behind
    tail_pts = []
    for i in range(12):
        frac = i / 11.0
        tx = cx + 55 + frac * 65.0
        ty = cy + 20 + math.sin(t + frac * 2.0) * (6.0 + frac * 12.0)
        tail_pts.append((tx, ty))
    for w in [16, 10, 4]:
        draw.line(tail_pts, fill=(130, 45, 25, 255) if w > 6 else (180, 80, 40, 255), width=w)

    # Hind muscular legs
    for side in [-1, 1]:
        foot_phase = t + (0 if side == 1 else math.pi)
        hx = cx + 30 + side * 14
        hy = cy + 30
        kx = hx + 10 + math.sin(foot_phase) * 10
        ky = hy + 35
        fx = kx - 5
        fy = ky + 25
        draw.line([(hx, hy), (kx, ky)], fill=(120, 40, 20, 255), width=10)
        draw.line([(kx, ky), (fx, fy)], fill=(150, 60, 30, 255), width=6)
        # Talons
        for to in [-6, 0, 6]:
            draw.line([(fx, fy), (fx + to - 8, fy + 8)], fill=(255, 210, 90, 255), width=3)

    # Muscular saurian torso
    torso_rect = [cx - 50, cy - 25 + math.sin(t) * 3, cx + 55, cy + 35 + math.sin(t) * 3]
    draw.rounded_rectangle(torso_rect, radius=22, fill=(155, 55, 30, 255), outline=(220, 110, 50, 255), width=3)

    # Rows of armored dorsal osteoderm scutes along spine
    for i in range(8):
        ox = cx - 40 + i * 12
        oy = cy - 30 + math.sin(t + i * 0.4) * 3
        draw.polygon([(ox - 4, oy + 4), (ox, oy - 10), (ox + 4, oy + 4)], fill=(80, 25, 15, 255), outline=(255, 170, 70, 255), width=2)

    # Forelimbs
    for side in [-1, 1]:
        arm_phase = t + (math.pi if side == 1 else 0)
        ax = cx - 25 + side * 12
        ay = cy + 20
        akx = ax - 12 + math.sin(arm_phase) * 8
        aky = ay + 30
        afx = akx - 4
        afy = aky + 20
        draw.line([(ax, ay), (akx, aky)], fill=(130, 50, 25, 255), width=8)
        draw.line([(akx, aky), (afx, afy)], fill=(160, 70, 35, 255), width=5)
        for to in [-4, 0, 4]:
            draw.line([(afx, afy), (afx + to - 6, afy + 6)], fill=(255, 210, 90, 255), width=2)

    # Massive deep archosaur skull
    snout_x = cx - 80 + math.sin(t) * 4
    snout_y = cy - 20 + math.cos(t) * 3
    skull_poly = [
        (cx - 35, cy - 32),
        (cx - 35, cy + 10),
        (snout_x + 10, cy + 8),
        (snout_x - 10, cy - 6),
        (snout_x + 10, cy - 24),
    ]
    draw.polygon(skull_poly, fill=(165, 50, 25, 255), outline=(245, 130, 60, 255), width=3)

    # Menacing glowing predatory reptilian eye
    draw.ellipse([cx - 48, cy - 24, cx - 36, cy - 12], fill=(255, 220, 30, 255), outline=(100, 20, 10, 255), width=2)
    draw.line([(cx - 42, cy - 22), (cx - 42, cy - 14)], fill=(10, 0, 0, 255), width=3) # Slit pupil

    # Razor serrated teeth in jawline
    for i in range(6):
        tx = snout_x + 5 + i * 8
        ty = cy + 7
        draw.polygon([(tx - 2, ty), (tx, ty + 7), (tx + 2, ty)], fill=(255, 255, 220, 255))

# ── FLOOR 6: TYRANNOSAURUS REX (Cretaceous Apex Saurian Monarch) ──
def draw_tyrannosaurus_frame(draw, frame=0):
    cx, cy = 140, 120
    t = frame / 6.0 * math.pi * 2

    # Shadow
    draw.ellipse([30, 195, 250, 235], fill=(4, 8, 16, 170))

    # Colossal balance tail
    tail_pts = []
    for i in range(14):
        frac = i / 13.0
        tx = cx + 60 + frac * 75.0
        ty = cy + 10 + math.sin(t + frac * 2.2) * (8.0 + frac * 14.0)
        tail_pts.append((tx, ty))
    for w in [24, 16, 8, 3]:
        draw.line(tail_pts, fill=(150, 30, 20, 255) if w > 10 else (220, 60, 35, 255), width=w)

    # Massive muscular bipedal hindlimbs (theropod titan)
    for side in [-1, 1]:
        stride = t + (0 if side == 1 else math.pi)
        thigh_x = cx + 24 + side * 14
        thigh_y = cy + 20
        knee_x = thigh_x - 14 + math.sin(stride) * 14
        knee_y = thigh_y + 45
        ankle_x = knee_x + 12
        ankle_y = knee_y + 35
        foot_x = ankle_x - 18
        foot_y = ankle_y + 12

        draw.line([(thigh_x, thigh_y), (knee_x, knee_y)], fill=(140, 25, 20, 255), width=16)
        draw.line([(knee_x, knee_y), (ankle_x, ankle_y)], fill=(180, 45, 30, 255), width=11)
        draw.line([(ankle_x, ankle_y), (foot_x, foot_y)], fill=(220, 75, 40, 255), width=7)
        # Giant theropod claws
        for to in [-8, 0, 8]:
            draw.line([(foot_x, foot_y), (foot_x - 12, foot_y + to)], fill=(255, 230, 120, 255), width=4)

    # Colossal muscular torso with glowing primordial core
    torso_rect = [cx - 60, cy - 35 + math.sin(t) * 4, cx + 55, cy + 30 + math.sin(t) * 4]
    draw.rounded_rectangle(torso_rect, radius=26, fill=(175, 35, 25, 255), outline=(255, 95, 45, 255), width=4)

    # Dorsal crest spikes
    for i in range(9):
        dx = cx - 45 + i * 11
        dy = cy - 38 + math.sin(t + i * 0.4) * 4
        draw.polygon([(dx - 4, dy + 6), (dx, dy - 12), (dx + 4, dy + 6)], fill=(90, 15, 15, 255), outline=(255, 180, 50, 255), width=2)

    # Tiny theropod arms (two claws)
    arm_x = cx - 40
    arm_y = cy + 18
    draw.line([(arm_x, arm_y), (arm_x - 14, arm_y + 12)], fill=(190, 50, 30, 255), width=5)
    draw.line([(arm_x - 14, arm_y + 12), (arm_x - 22, arm_y + 8)], fill=(255, 200, 80, 255), width=3)
    draw.line([(arm_x - 14, arm_y + 12), (arm_x - 20, arm_y + 16)], fill=(255, 200, 80, 255), width=3)

    # Gigantic bone-crushing skull
    head_x = cx - 95 + math.sin(t) * 5
    head_y = cy - 35 + math.cos(t) * 4
    jaw_open = 10.0 + math.sin(t * 1.5) * 8.0

    # Upper skull
    upper_poly = [
        (cx - 45, cy - 48),
        (head_x + 20, cy - 54),
        (head_x - 25, cy - 30),
        (head_x + 10, cy - 14),
        (cx - 45, cy - 16),
    ]
    draw.polygon(upper_poly, fill=(195, 35, 25, 255), outline=(255, 110, 50, 255), width=4)

    # Lower jaw
    lower_poly = [
        (cx - 45, cy - 10),
        (head_x + 12, cy - 8 + jaw_open),
        (head_x - 20, cy - 22 + jaw_open),
        (cx - 45, cy + 4),
    ]
    draw.polygon(lower_poly, fill=(150, 25, 20, 255), outline=(230, 75, 35, 255), width=3)

    # Tyrannosaur binocular amber eye with red iris
    draw.ellipse([cx - 62, cy - 42, cx - 48, cy - 28], fill=(255, 40, 20, 255), outline=(255, 230, 60, 255), width=2)
    draw.ellipse([cx - 57, cy - 37, cx - 51, cy - 31], fill=(255, 255, 180, 255))

    # Serrated 12-inch banana teeth
    for i in range(7):
        tx = head_x - 18 + i * 9
        ty = cy - 24
        draw.polygon([(tx - 2, ty), (tx, ty + 12), (tx + 2, ty)], fill=(255, 255, 230, 255))
    for i in range(5):
        tx = head_x - 12 + i * 9
        ty = cy - 18 + jaw_open
        draw.polygon([(tx - 2, ty), (tx, ty - 10), (tx + 2, ty)], fill=(255, 255, 230, 255))

# ── FLOOR 7: THE EXTINCTION SOVEREIGN (Apex Extinction Calamity) ──
def draw_apex_sovereign_frame(draw, frame=0):
    cx, cy = 140, 120
    t = frame / 6.0 * math.pi * 2

    # Deep abyssal cosmic shadow
    draw.ellipse([25, 195, 255, 235], fill=(8, 2, 16, 190))

    # Radiant celestial aureole / energy field
    for r in range(5, 0, -1):
        rad = 85 + r * 14 + math.sin(t + r) * 8.0
        draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(120, 0, 255, 12 + r * 10))

    # Vast multi-feathered celestial / dragon wings
    for side in [-1, 1]:
        w_phase = t + (0 if side == 1 else 0.5)
        w_flap = math.sin(w_phase) * 16.0
        wing_base_x = cx + side * 30
        wing_base_y = cy - 20
        wing_tip_x = wing_base_x + side * (90.0 + math.cos(w_phase) * 10.0)
        wing_tip_y = wing_base_y - 65.0 + w_flap

        # Primary feathered rays
        for ray in range(6):
            rf = ray / 5.0
            rx = wing_tip_x - side * rf * 40.0
            ry = wing_tip_y + rf * 60.0
            draw.line([(wing_base_x, wing_base_y), (rx, ry)], fill=(0, 230, 255, 200), width=4)
            draw.line([(rx, ry), (rx + side * 14, ry + 12)], fill=(255, 100, 220, 240), width=3)

    # Central armored apex body (convergence of animal forms)
    body_rect = [cx - 48, cy - 50 + math.sin(t) * 4, cx + 48, cy + 45 + math.sin(t) * 4]
    draw.rounded_rectangle(body_rect, radius=24, fill=(35, 10, 60, 255), outline=(0, 255, 240, 255), width=4)

    # Concentric pulsing extinction core (the burning eye of geological time)
    core_rad = 24.0 + math.sin(t * 2.0) * 4.0
    draw.ellipse([cx - core_rad, cy - core_rad, cx + core_rad, cy + core_rad], fill=(255, 30, 100, 255), outline=(255, 230, 90, 255), width=3)
    draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(255, 255, 255, 255))

    # Sweeping crown of ancient horns / crests
    for side in [-1, 1]:
        horn_pts = [
            (cx + side * 22, cy - 48),
            (cx + side * 45, cy - 80),
            (cx + side * 65, cy - 105 + math.sin(t + side) * 6)
        ]
        draw.line(horn_pts, fill=(255, 215, 0, 255), width=5)
        draw.ellipse([horn_pts[-1][0] - 4, horn_pts[-1][1] - 4, horn_pts[-1][0] + 4, horn_pts[-1][1] + 4], fill=(0, 255, 255, 255))

    # Sweeping twin predatory tails
    for side in [-1, 1]:
        tail_pts = []
        for i in range(10):
            frac = i / 9.0
            tx = cx + side * (25 + frac * 45.0 + math.sin(t + frac * 2.5) * 12.0)
            ty = cy + 40 + frac * 50.0
            tail_pts.append((tx, ty))
        draw.line(tail_pts, fill=(160, 30, 220, 255), width=5)
        draw.line(tail_pts, fill=(0, 255, 240, 200), width=2)


def generate_all_sheets():
    create_directory()
    
    # Floor 4: Arthropleura
    sheet4 = Image.new("RGBA", (1560, 220), (0, 0, 0, 0))
    for i in range(6):
        frame = Image.new("RGBA", (260, 220), (0, 0, 0, 0))
        draw_arthropleura_frame(ImageDraw.Draw(frame), frame=i)
        sheet4.paste(frame, (i * 260, 0))
    sheet4.save("assets/boss_arthropleura_sheet.png")
    print("  Boss Arthropleura Sheet: assets/boss_arthropleura_sheet.png")

    # Floor 5: Postosuchus
    sheet5 = Image.new("RGBA", (1560, 220), (0, 0, 0, 0))
    for i in range(6):
        frame = Image.new("RGBA", (260, 220), (0, 0, 0, 0))
        draw_postosuchus_frame(ImageDraw.Draw(frame), frame=i)
        sheet5.paste(frame, (i * 260, 0))
    sheet5.save("assets/boss_postosuchus_sheet.png")
    print("  Boss Postosuchus Sheet: assets/boss_postosuchus_sheet.png")

    # Floor 6: Tyrannosaurus
    sheet6 = Image.new("RGBA", (1680, 240), (0, 0, 0, 0))
    for i in range(6):
        frame = Image.new("RGBA", (280, 240), (0, 0, 0, 0))
        draw_tyrannosaurus_frame(ImageDraw.Draw(frame), frame=i)
        sheet6.paste(frame, (i * 280, 0))
    sheet6.save("assets/boss_tyrannosaurus_sheet.png")
    print("  Boss Tyrannosaurus Sheet: assets/boss_tyrannosaurus_sheet.png")

    # Floor 7: Apex Sovereign
    sheet7 = Image.new("RGBA", (1680, 240), (0, 0, 0, 0))
    for i in range(6):
        frame = Image.new("RGBA", (280, 240), (0, 0, 0, 0))
        draw_apex_sovereign_frame(ImageDraw.Draw(frame), frame=i)
        sheet7.paste(frame, (i * 280, 0))
    sheet7.save("assets/boss_apex_sovereign_sheet.png")
    print("  Boss Apex Sovereign Sheet: assets/boss_apex_sovereign_sheet.png")

if __name__ == "__main__":
    generate_all_sheets()
    print("All 4 era boss sprite sheets generated successfully!")
