import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter

random.seed(42)  # Deterministic for consistent art

def create_directory():
    os.makedirs("assets", exist_ok=True)

# ─────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────

def lerp_color(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))

def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v)))

def radial_gradient(draw, cx, cy, r_outer, r_inner, color_outer, color_inner, steps=80):
    """Draw a smooth radial gradient as concentric ellipses."""
    for i in range(steps, 0, -1):
        t = i / steps
        r = r_inner + (r_outer - r_inner) * t
        col = lerp_color(color_inner, color_outer, t)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col + (255,))

def glow_ellipse(draw, cx, cy, rx, ry, color, layers=6, max_alpha=200):
    """Draw a soft glowing ellipse with layered halos."""
    for i in range(layers, 0, -1):
        t = i / layers
        ex_rx = rx * (1.0 + (1.0 - t) * 1.2)
        ex_ry = ry * (1.0 + (1.0 - t) * 1.2)
        alpha = int(max_alpha * t * t)
        draw.ellipse([cx - ex_rx, cy - ex_ry, cx + ex_rx, cy + ex_ry],
                     fill=color + (alpha,))

def draw_hex_grid(draw, img_w, img_h, hex_r, line_col, jitter=0):
    """Draw a subtle hexagonal grid pattern."""
    h = hex_r * math.sqrt(3)
    col_w = hex_r * 1.5
    row_h = h

    cols = int(img_w / col_w) + 3
    rows = int(img_h / row_h) + 3

    for row in range(-1, rows):
        for col in range(-1, cols):
            cx = col * col_w + (hex_r if (row % 2 == 1) else 0)
            cy = row * row_h
            if jitter > 0:
                cx += random.uniform(-jitter, jitter)
                cy += random.uniform(-jitter, jitter)
            pts = []
            for k in range(6):
                angle = math.radians(60 * k - 30)
                pts.append((cx + hex_r * math.cos(angle), cy + hex_r * math.sin(angle)))
            draw.polygon(pts, outline=line_col, fill=None)


# ─────────────────────────────────────────────────────────
# 1. FLOOR TILES — 3 variants, 128×128
# ─────────────────────────────────────────────────────────

def draw_floor_tile(filename, variant=0, seed_offset=0):
    """Generate a rich bioluminescent floor tile with organic texture."""
    random.seed(42 + seed_offset)
    w, h = 128, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    base = Image.new("RGBA", (w, h))

    # Base palette variants
    palettes = [
        {"bg": (11, 24, 42),  "vein": (0, 190, 230),   "glow": (0, 230, 255),  "spot": (0, 110, 200)},
        {"bg": (8, 28, 32),   "vein": (0, 210, 160),   "glow": (0, 250, 200),  "spot": (0, 150, 110)},
        {"bg": (20, 12, 38),  "vein": (160, 30, 220),  "glow": (200, 80, 255), "spot": (100, 10, 160)},
    ]
    p = palettes[variant % 3]
    bg = p["bg"]
    vein_col = p["vein"]
    glow_col = p["glow"]
    spot_col = p["spot"]

    # 1. Base colour with subtle noise
    for x in range(w):
        for y in range(h):
            nx = x / w
            ny = y / h
            # Gentle noise to break up flat colour
            n1 = math.sin(nx * 9.4 + ny * 7.1) * 4
            n2 = math.cos(nx * 14.2 - ny * 6.8) * 3
            r = clamp(bg[0] + n1 + n2)
            g = clamp(bg[1] + n1 * 1.2 + n2 * 0.8)
            b = clamp(bg[2] + n1 * 0.5 + n2 * 1.5 + 6)
            base.putpixel((x, y), (r, g, b, 255))

    draw = ImageDraw.Draw(base)

    # 2. Hex-grid veins (subtle)
    hex_r = 24 if variant < 2 else 18
    draw_hex_grid(draw, w, h, hex_r,
                  line_col=(vein_col[0], vein_col[1], vein_col[2], 55),
                  jitter=1.5)

    # 3. Bioluminescent micro-spots (plankton scatter)
    num_spots = 14 + variant * 4
    for _ in range(num_spots):
        sx = random.randint(3, w - 3)
        sy = random.randint(3, h - 3)
        sr = random.randint(1, 3)
        alpha = random.randint(80, 160)
        # Outer glow
        draw.ellipse([sx - sr*2, sy - sr*2, sx + sr*2, sy + sr*2],
                     fill=(glow_col[0], glow_col[1], glow_col[2], alpha // 3))
        # Core dot
        draw.ellipse([sx - sr, sy - sr, sx + sr, sy + sr],
                     fill=(glow_col[0], glow_col[1], glow_col[2], alpha))
        draw.point((sx, sy), fill=(255, 255, 255, 200))

    # 4. Capillary vein lines
    num_veins = 3 + variant * 2
    for _ in range(num_veins):
        x0 = random.randint(0, w)
        y0 = random.randint(0, h)
        angle = random.uniform(0, math.pi * 2)
        length = random.randint(20, 50)
        x1 = x0 + math.cos(angle) * length
        y1 = y0 + math.sin(angle) * length
        alpha = random.randint(40, 90)
        draw.line([x0, y0, x1, y1],
                  fill=(vein_col[0], vein_col[1], vein_col[2], alpha), width=1)

    # 5. Subtle centre brightening (makes tile feel lit from below)
    cx, cy = w // 2, h // 2
    for rx in range(48, 0, -8):
        a = int(12 * (1 - rx / 48))
        draw.ellipse([cx - rx, cy - rx, cx + rx, cy + rx],
                     fill=(spot_col[0], spot_col[1], spot_col[2], a))

    # 6. Faint edge vignette to help tiles blend
    for side in range(4):
        for i in range(6):
            a = int(30 * (1 - i / 6))
            if side == 0:
                draw.line([(0, i), (w, i)], fill=(0, 0, 0, a))
            elif side == 1:
                draw.line([(0, h - 1 - i), (w, h - 1 - i)], fill=(0, 0, 0, a))
            elif side == 2:
                draw.line([(i, 0), (i, h)], fill=(0, 0, 0, a))
            else:
                draw.line([(w - 1 - i, 0), (w - 1 - i, h)], fill=(0, 0, 0, a))

    # Slight blur to smooth out noise
    base = base.filter(ImageFilter.GaussianBlur(radius=0.6))
    img.paste(base, (0, 0))
    img.save(f"assets/{filename}")
    print(f"  Floor tile: assets/{filename}")


# ─────────────────────────────────────────────────────────
# 2. WALL TILE — 128×128  (calcified reef + phosphorescent veins)
# ─────────────────────────────────────────────────────────

def draw_wall():
    random.seed(99)
    w, h = 128, 128
    img = Image.new("RGBA", (w, h))
    draw = ImageDraw.Draw(img)

    # Base: dark stone
    for x in range(w):
        for y in range(h):
            t = y / h
            r = clamp(14 + t * 10 + math.sin(x * 0.18 + y * 0.12) * 4)
            g = clamp(20 + t * 12 + math.cos(x * 0.14 - y * 0.09) * 4)
            b = clamp(36 + t * 16 + math.sin(x * 0.22 + y * 0.07) * 6)
            img.putpixel((x, y), (r, g, b, 255))

    # Layered rock ridge lines
    ridge_y_positions = [18, 38, 58, 78, 98, 114]
    for ry in ridge_y_positions:
        jit = random.randint(-4, 4)
        for dy in range(-2, 3):
            alpha = 60 - abs(dy) * 20
            if alpha > 0:
                draw.line([(0, ry + jit + dy), (w, ry + jit + dy)],
                          fill=(45, 65, 90, alpha))

    # Craggy crack lines
    for _ in range(5):
        x0 = random.randint(0, w)
        y0 = random.randint(0, h)
        segs = random.randint(3, 6)
        pts = [(x0, y0)]
        for _ in range(segs):
            pts.append((pts[-1][0] + random.randint(-18, 18),
                        pts[-1][1] + random.randint(-18, 18)))
        draw.line(pts, fill=(8, 12, 22, 100), width=1)

    # Phosphorescent vein lines (glowing cyan)
    vein_colour = (0, 220, 255)
    for _ in range(4):
        x0 = random.randint(0, w)
        y0 = random.randint(0, h)
        segs = random.randint(2, 4)
        pts = [(x0, y0)]
        for _ in range(segs):
            pts.append((pts[-1][0] + random.randint(-20, 20),
                        pts[-1][1] + random.randint(-20, 20)))
        # Outer glow
        draw.line(pts, fill=(vein_colour[0], vein_colour[1], vein_colour[2], 50), width=3)
        # Inner bright
        draw.line(pts, fill=(vein_colour[0], vein_colour[1], vein_colour[2], 140), width=1)

    # Bioluminescent micro-dots
    for _ in range(12):
        sx = random.randint(4, w - 4)
        sy = random.randint(4, h - 4)
        sr = random.randint(1, 2)
        draw.ellipse([sx - sr*2, sy - sr*2, sx + sr*2, sy + sr*2],
                     fill=(0, 200, 240, 40))
        draw.ellipse([sx - sr, sy - sr, sx + sr, sy + sr],
                     fill=(0, 240, 255, 120))

    # Strong inner edge glow (bottom & right faces of the wall)
    for i in range(8):
        a = int(120 * (1 - i / 8))
        draw.line([(0, h - 1 - i), (w, h - 1 - i)],
                  fill=(0, 200, 240, a))
    for i in range(5):
        a = int(80 * (1 - i / 5))
        draw.line([(w - 1 - i, 0), (w - 1 - i, h)],
                  fill=(0, 180, 220, a))

    # Hard dark outline (top and left — shadow sides)
    draw.rectangle([0, 0, w - 1, h - 1], outline=(4, 8, 16, 200), width=2)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.5))
    img.save("assets/wall.png")
    print("  Wall tile: assets/wall.png")


# ─────────────────────────────────────────────────────────
# 3. FULLSCREEN ROOM BACKGROUNDS — 1920×1080
# ─────────────────────────────────────────────────────────

def draw_fullscreen_background(filename, theme_type="normal"):
    random.seed({"normal": 1, "boss": 2, "treasure": 3, "shop": 4, "start": 5}.get(theme_type, 1))
    width, height = 1920, 1080
    cx, cy = width / 2.0, height / 2.0

    # Calming, harmonious, eye-pleasing marine palettes
    palettes = {
        "boss":     {"base": (16, 20, 38), "glow": (120, 145, 240), "accent": (0, 190, 220), "floor": (12, 16, 32)},
        "treasure": {"base": (8, 30, 36),  "glow": (0, 230, 180),   "accent": (0, 130, 110), "floor": (6, 24, 30)},
        "shop":     {"base": (20, 26, 38), "glow": (235, 185, 60),  "accent": (150, 110, 20), "floor": (16, 22, 34)},
        "start":    {"base": (12, 28, 48), "glow": (60, 210, 255),  "accent": (20, 130, 180), "floor": (10, 24, 42)},
        "normal":   {"base": (12, 24, 44), "glow": (0, 185, 220),   "accent": (0, 100, 160), "floor": (10, 20, 38)},
    }
    pal = palettes.get(theme_type, palettes["normal"])
    base_col = pal["base"]
    glow_col = pal["glow"]
    floor_col = pal["floor"]

    img = Image.new("RGBA", (width, height), base_col + (255,))

    # ── Low-res organic gradient ──────────────────────────────
    lw, lh = width // 3, height // 3
    low_img = Image.new("RGBA", (lw, lh))
    for x in range(lw):
        for y in range(lh):
            rx = x * 3
            ry = y * 3
            dx = (rx - cx) / cx
            dy = (ry - cy) / cy
            dist = math.sqrt(dx*dx + dy*dy)

            w1 = math.sin(rx * 0.007 + ry * 0.003) * 12
            w2 = math.cos(rx * 0.013 - ry * 0.009) * 8
            w3 = math.sin((rx + ry) * 0.004) * 6
            w4 = math.cos(rx * 0.019 + ry * 0.011) * 4

            center_glow = max(0.0, 1.0 - dist * 0.75) * 26.0
            vignette = min(40, dist * dist * 18)

            r = clamp(base_col[0] + w1 * 0.3 + center_glow * (glow_col[0] / 255.0) - vignette)
            g = clamp(base_col[1] + w1 * 0.8 + w2 * 0.8 + w3 * 0.5 + center_glow * (glow_col[1] / 255.0) - vignette)
            b = clamp(base_col[2] + w1 * 1.3 + w2 * 1.1 + w3 + w4 + center_glow * (glow_col[2] / 255.0) - vignette)
            low_img.putpixel((x, y), (r, g, b, 255))

    upscaled = low_img.resize((width, height), Image.Resampling.BILINEAR)
    upscaled = upscaled.filter(ImageFilter.GaussianBlur(radius=8))
    img.paste(upscaled, (0, 0))
    draw = ImageDraw.Draw(img)

    # ── Floor area lighter tint (inner play area) ─────────────
    floor_overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    fd = ImageDraw.Draw(floor_overlay)
    fd.rectangle([128, 148, 1792, 932],
                 fill=(floor_col[0], floor_col[1], floor_col[2], 55))
    floor_overlay = floor_overlay.filter(ImageFilter.GaussianBlur(radius=24))
    img = Image.alpha_composite(img, floor_overlay)
    draw = ImageDraw.Draw(img)

    # ── Bioluminescent current strands ────────────────────────
    for _ in range(18):
        sx = random.randint(200, 1720)
        sy = random.randint(160, 920)
        length = random.randint(120, 320)
        angle = random.uniform(0, math.pi * 2)
        ex = sx + math.cos(angle) * length
        ey = sy + math.sin(angle) * length
        alpha = random.randint(20, 55)
        width_px = random.choice([2, 3])
        # Outer glow
        draw.line([sx, sy, ex, ey], fill=(glow_col[0], glow_col[1], glow_col[2], alpha // 2), width=width_px + 4)
        # Inner bright line
        draw.line([sx, sy, ex, ey], fill=(glow_col[0], glow_col[1], glow_col[2], alpha), width=width_px)

    # ── Glowing plankton colonies ─────────────────────────────
    num_colonies = 26 if theme_type == "normal" else 32
    for _ in range(num_colonies):
        nx = random.randint(160, 1760)
        ny = random.randint(140, 940)
        rad = random.randint(3, 12)
        colony_alpha = random.randint(50, 110)
        # 3-layer glow
        draw.ellipse([nx - rad*3, ny - rad*3, nx + rad*3, ny + rad*3],
                     fill=(glow_col[0], glow_col[1], glow_col[2], colony_alpha // 5))
        draw.ellipse([nx - rad*2, ny - rad*2, nx + rad*2, ny + rad*2],
                     fill=(glow_col[0], glow_col[1], glow_col[2], colony_alpha // 2))
        draw.ellipse([nx - rad, ny - rad, nx + rad, ny + rad],
                     fill=(glow_col[0], glow_col[1], glow_col[2], colony_alpha))
        draw.ellipse([nx - rad//3, ny - rad//3, nx + rad//3, ny + rad//3],
                     fill=(240, 255, 255, 200))

    # ── Wall border (solid boundary with 4 arched door openings) ──
    wall_col  = (base_col[0] + 6, base_col[1] + 10, base_col[2] + 16, 255)
    wall_glow = (glow_col[0], glow_col[1], glow_col[2], 120)
    wall_dark = (base_col[0] - 2, base_col[1] - 1, base_col[2], 255)
    thickness = 128

    # Top wall (leaving 895..1025 open for top door slot)
    draw.rectangle([0, 0, 895, thickness], fill=wall_col)
    draw.rectangle([1025, 0, width, thickness], fill=wall_col)
    # Bottom wall (leaving 895..1025 open for bottom door slot)
    draw.rectangle([0, height - thickness, 895, height], fill=wall_col)
    draw.rectangle([1025, height - thickness, width, height], fill=wall_col)
    # Left wall (leaving 476..604 open for left door slot)
    draw.rectangle([0, thickness, thickness, 476], fill=wall_col)
    draw.rectangle([0, 604, thickness, height - thickness], fill=wall_col)
    # Right wall (leaving 476..604 open for right door slot)
    draw.rectangle([width - thickness, thickness, width, 476], fill=wall_col)
    draw.rectangle([width - thickness, 604, width, height - thickness], fill=wall_col)

    # Inner edge glows (soft gradient simulation with layered lines)
    for i in range(8):
        a = int(140 * (1 - i / 8.0))
        col = (glow_col[0], glow_col[1], glow_col[2], a)
        # Top inner edge
        draw.line([0, thickness + i, 895, thickness + i], fill=col)
        draw.line([1025, thickness + i, width, thickness + i], fill=col)
        # Bottom inner edge
        draw.line([0, height - thickness - 1 - i, 895, height - thickness - 1 - i], fill=col)
        draw.line([1025, height - thickness - 1 - i, width, height - thickness - 1 - i], fill=col)
        # Left inner edge
        draw.line([thickness + i, thickness, thickness + i, 476], fill=col)
        draw.line([thickness + i, 604, thickness + i, height - thickness], fill=col)
        # Right inner edge
        draw.line([width - thickness - 1 - i, thickness, width - thickness - 1 - i, 476], fill=col)
        draw.line([width - thickness - 1 - i, 604, width - thickness - 1 - i, height - thickness], fill=col)

    # Wall detail: horizontal soft ridge lines inside wall sections
    for ry in [30, 55, 80, 100]:
        draw.line([0, ry, 895, ry], fill=(glow_col[0], glow_col[1], glow_col[2], 20))
        draw.line([1025, ry, width, ry], fill=(glow_col[0], glow_col[1], glow_col[2], 20))
        draw.line([0, height - ry, 895, height - ry], fill=(glow_col[0], glow_col[1], glow_col[2], 20))
        draw.line([1025, height - ry, width, height - ry], fill=(glow_col[0], glow_col[1], glow_col[2], 20))

    # Wall phosphorescent micro-dots
    for _ in range(35):
        wx = random.randint(0, width)
        wy = random.choice(
            list(range(0, thickness)) + list(range(height - thickness, height))
        )
        wr = random.randint(2, 5)
        draw.ellipse([wx - wr, wy - wr, wx + wr, wy + wr],
                     fill=(glow_col[0], glow_col[1], glow_col[2], random.randint(25, 80)))
        draw.point((wx, wy), fill=(255, 255, 255, 140))

    # Organic corner brackets
    corner_pts = [
        [(0, 0), (160, 0), (0, 160)],
        [(width, 0), (width - 160, 0), (width, 160)],
        [(0, height), (160, height), (0, height - 160)],
        [(width, height), (width - 160, height), (width, height - 160)],
    ]
    for pts in corner_pts:
        draw.polygon(pts, fill=wall_dark)
        corner_cx = sum(p[0] for p in pts) / 3
        corner_cy = sum(p[1] for p in pts) / 3
        draw.ellipse([corner_cx - 25, corner_cy - 25, corner_cx + 25, corner_cy + 25],
                     fill=(glow_col[0], glow_col[1], glow_col[2], 45))

    # ── Theme-specific centre art ──────────────────────────────
    if theme_type == "boss":
        # Majestic deep abyssal caldera with soothing periwinkle and cyan concentric rings
        draw.ellipse([cx - 220, cy - 140, cx + 220, cy + 140],
                     fill=(10, 14, 28, 220), outline=(110, 135, 230, 140), width=4)
        draw.ellipse([cx - 150, cy - 95, cx + 150, cy + 95],
                     fill=(14, 18, 34, 240), outline=(0, 200, 225, 120), width=3)
        draw.ellipse([cx - 80, cy - 50, cx + 80, cy + 50],
                     fill=(18, 24, 46, 255), outline=(130, 170, 255, 180), width=2)
        for r in [50, 110, 180]:
            draw.arc([cx - r * 1.4, cy - r * 0.85, cx + r * 1.4, cy + r * 0.85], 0, 360,
                     fill=(120, 160, 240, 70), width=2)
        for angle_deg in range(0, 360, 45):
            a = math.radians(angle_deg)
            rx = cx + math.cos(a) * 110 * 1.4
            ry = cy + math.sin(a) * 110 * 0.85
            draw.ellipse([rx - 6, ry - 6, rx + 6, ry + 6], fill=(0, 220, 240, 160))
            draw.point((int(rx), int(ry)), fill=(255, 255, 255, 220))

    elif theme_type == "treasure":
        # DNA double-helix emblem in serene seafoam & mint
        draw.ellipse([cx - 180, cy - 115, cx + 180, cy + 115],
                     fill=(4, 16, 22, 210), outline=(0, 230, 180, 140), width=4)
        for i in range(12):
            t = i / 11
            hx = cx + math.sin(t * math.pi * 2) * 70
            hy = cy - 90 + t * 180
            draw.ellipse([hx - 10, hy - 6, hx + 10, hy + 6],
                         fill=(0, 245, 195, 200))
            hx2 = cx - math.sin(t * math.pi * 2) * 70
            draw.ellipse([hx2 - 10, hy - 6, hx2 + 10, hy + 6],
                         fill=(0, 210, 155, 180))
            draw.line([hx, hy, hx2, hy], fill=(0, 245, 210, 80), width=2)
        draw.arc([cx - 90, cy - 56, cx + 90, cy + 56], 0, 360,
                 fill=(0, 245, 210, 160), width=3)

    elif theme_type == "shop":
        # Gene shrine concentric rings with warm golden amber glow
        draw.ellipse([cx - 180, cy - 115, cx + 180, cy + 115],
                     fill=(14, 18, 28, 200), outline=(235, 185, 50, 130), width=4)
        for r in [80, 55, 30]:
            draw.arc([cx - r, cy - r * 0.65, cx + r, cy + r * 0.65], 0, 360,
                     fill=(235, 185, 50, 100), width=2)
        for angle_deg in range(0, 360, 45):
            a = math.radians(angle_deg)
            rx = cx + math.cos(a) * 68
            ry = cy + math.sin(a) * 44
            draw.ellipse([rx - 6, ry - 6, rx + 6, ry + 6],
                         fill=(235, 185, 50, 180))

    elif theme_type == "start":
        # Pristine primordial genesis pool with soft azure life ripples
        draw.ellipse([cx - 180, cy - 110, cx + 180, cy + 110],
                     fill=(8, 22, 38, 210), outline=(50, 200, 255, 140), width=3)
        for r in [40, 80, 120]:
            draw.arc([cx - r * 1.3, cy - r * 0.75, cx + r * 1.3, cy + r * 0.75], 0, 360,
                     fill=(60, 210, 255, 60), width=2)
        draw.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=(200, 245, 255, 200))

    # Final subtle vignette pass
    vignette_overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vignette_overlay)
    for r in range(700, 0, -50):
        a = int(70 * (1 - r / 700))
        vd.ellipse([cx - r * 1.7, cy - r, cx + r * 1.7, cy + r], fill=(0, 0, 0, a))
    vignette_overlay = vignette_overlay.filter(ImageFilter.GaussianBlur(radius=30))
    img = Image.alpha_composite(img, vignette_overlay)

    img.save(f"assets/{filename}")
    print(f"  Background: assets/{filename}")


# ─────────────────────────────────────────────────────────
# 4. DOOR SPRITES — 128×128
# ─────────────────────────────────────────────────────────

def draw_door():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Outer ring — dark metal housing
    draw.ellipse([4, 4, 123, 123], fill=(16, 32, 54, 255), outline=(6, 14, 28, 255), width=5)
    # Mid ring — glowing frame
    for i in range(6, 0, -1):
        a = int(60 + i * 25)
        draw.ellipse([18 + i, 18 + i, 109 - i, 109 - i],
                     fill=(0, 220 - i*8, 255, a))
    draw.ellipse([20, 20, 107, 107], fill=(12, 26, 46, 255), outline=(0, 240, 255, 255), width=4)

    # Inner void / portal
    draw.ellipse([32, 32, 95, 95], fill=(0, 4, 10, 255))

    # Portal swirl — 3 arc rings
    for r, a_start, a_end, alpha in [(30, 0, 260, 200), (20, 80, 340, 160), (12, 160, 360, 120)]:
        cx, cy = 63, 63
        draw.arc([cx - r, cy - r, cx + r, cy + r], a_start, a_end,
                 fill=(0, 255, 230, alpha), width=3)

    # Centre bright dot
    draw.ellipse([56, 56, 71, 71], fill=(180, 255, 255, 255))
    draw.ellipse([60, 60, 67, 67], fill=(255, 255, 255, 255))

    # Bolt accents at compass points
    for angle_deg in [0, 90, 180, 270]:
        a = math.radians(angle_deg)
        bx = int(63 + math.cos(a) * 50)
        by = int(63 + math.sin(a) * 50)
        draw.ellipse([bx - 5, by - 5, bx + 5, by + 5], fill=(30, 55, 85, 255), outline=(0, 200, 230, 200), width=2)

    img.save("assets/door.png")
    print("  Door: assets/door.png")


def draw_door_locked():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Outer ring — dull grey-blue
    draw.ellipse([4, 4, 123, 123], fill=(30, 36, 50, 255), outline=(12, 16, 26, 255), width=5)
    draw.ellipse([20, 20, 107, 107], fill=(20, 26, 40, 255), outline=(50, 60, 80, 255), width=3)

    # Inner golden lock plate
    draw.ellipse([34, 34, 93, 93], fill=(200, 140, 10, 255), outline=(140, 90, 0, 255), width=4)
    draw.ellipse([44, 44, 83, 83], fill=(255, 215, 60, 255))

    # Keyhole shape
    draw.ellipse([53, 50, 74, 71], fill=(40, 20, 0, 255))
    draw.polygon([(58, 66), (69, 66), (66, 82), (61, 82)], fill=(40, 20, 0, 255))

    # Lock shackle
    draw.arc([50, 38, 77, 62], 180, 360, fill=(180, 110, 0, 255), width=5)

    # Bolts at corners
    for angle_deg in [45, 135, 225, 315]:
        a = math.radians(angle_deg)
        bx = int(63 + math.cos(a) * 50)
        by = int(63 + math.sin(a) * 50)
        draw.ellipse([bx - 4, by - 4, bx + 4, by + 4], fill=(26, 32, 48, 255), outline=(55, 65, 85, 180), width=2)

    img.save("assets/door_locked.png")
    print("  Door locked: assets/door_locked.png")


# ─────────────────────────────────────────────────────────
# 5. PLAYER — 128×128  (detailed microbe / primordial organism)
# ─────────────────────────────────────────────────────────

def draw_player_frame(draw, frame=0):
    """Draw a detailed player microbe on the given ImageDraw context. frame 0–3."""
    cx, cy = 64, 60
    t = frame / 4.0 * math.pi * 2  # animation phase

    # Drop shadow
    draw.ellipse([22, 90, 106, 118], fill=(2, 6, 14, 130))

    # ── Cytoplasmic membrane layers ──
    # Outermost layer — translucent
    for i in range(5, 0, -1):
        a = 120 + i * 16
        r_off = i * 3
        draw.ellipse([cx - 46 - r_off, cy - 46 - r_off, cx + 46 + r_off, cy + 46 + r_off],
                     fill=(18, 140, 220, a))
    # Main body
    draw.ellipse([cx - 46, cy - 46, cx + 46, cy + 46],
                 fill=(22, 160, 240, 230), outline=(100, 235, 255, 255), width=4)
    # Inner cytoplasm
    draw.ellipse([cx - 38, cy - 38, cx + 38, cy + 38],
                 fill=(14, 130, 210, 220))

    # Membrane highlight (top-left specular)
    draw.ellipse([cx - 32, cy - 40, cx - 8, cy - 20],
                 fill=(200, 250, 255, 90))

    # ── Floating organelles ──
    # Mitochondrion (elongated oval, top-left)
    draw.ellipse([cx - 34, cy - 28, cx - 12, cy - 14],
                 fill=(255, 100, 170, 220), outline=(200, 30, 100, 240), width=2)
    # inner ridge
    draw.arc([cx - 30, cy - 26, cx - 16, cy - 16], 0, 180,
             fill=(255, 200, 225, 180), width=1)

    # Vacuole (round, bottom-right)
    draw.ellipse([cx + 12, cy + 8, cx + 36, cy + 32],
                 fill=(80, 255, 155, 200), outline=(20, 190, 80, 240), width=2)
    draw.ellipse([cx + 18, cy + 12, cx + 26, cy + 20],
                 fill=(200, 255, 235, 160))

    # Small lipid droplet (bottom-left)
    draw.ellipse([cx - 28, cy + 14, cx - 12, cy + 30],
                 fill=(255, 200, 60, 190), outline=(190, 130, 10, 220), width=2)

    # ── Nucleus with glow ──
    # Outer glow
    for ng in range(4, 0, -1):
        draw.ellipse([cx - 24 - ng*2, cy - 22 - ng*2, cx + 24 + ng*2, cy + 22 + ng*2],
                     fill=(255, 245, 80, 20 + ng * 12))
    # Nucleus body
    draw.ellipse([cx - 24, cy - 22, cx + 24, cy + 22],
                 fill=(255, 245, 80, 255), outline=(255, 165, 0, 255), width=3)
    # Nuclear envelope membrane
    draw.arc([cx - 20, cy - 18, cx + 20, cy + 18], 30, 200,
             fill=(255, 220, 100, 180), width=2)
    # Bright nucleolus
    draw.ellipse([cx - 8, cy - 6, cx + 8, cy + 6],
                 fill=(255, 255, 220, 255))
    draw.ellipse([cx - 3, cy - 2, cx + 3, cy + 2],
                 fill=(255, 255, 255, 255))

    # ── Expressive eyes ──
    eye_lx, eye_rx = cx - 22, cx + 10
    eye_y = cy - 24
    eye_w, eye_h = 16, 18
    # Left eye
    draw.ellipse([eye_lx, eye_y, eye_lx + eye_w, eye_y + eye_h],
                 fill=(6, 12, 28, 255))
    draw.ellipse([eye_lx + 4, eye_y + 2, eye_lx + 10, eye_y + 8],
                 fill=(255, 255, 255, 255))
    draw.ellipse([eye_lx + 8, eye_y + 8, eye_lx + 12, eye_y + 12],
                 fill=(255, 255, 255, 160))
    # Right eye
    draw.ellipse([eye_rx, eye_y, eye_rx + eye_w, eye_y + eye_h],
                 fill=(6, 12, 28, 255))
    draw.ellipse([eye_rx + 4, eye_y + 2, eye_rx + 10, eye_y + 8],
                 fill=(255, 255, 255, 255))
    draw.ellipse([eye_rx + 8, eye_y + 8, eye_rx + 12, eye_y + 12],
                 fill=(255, 255, 255, 160))

    # ── Smile ──
    draw.arc([cx - 14, cy - 2, cx + 14, cy + 16], 10, 170,
             fill=(6, 12, 28, 255), width=3)

    # ── Flagella (4 curved appendages) ──
    flagella_data = [
        # (x, y, x_end, y_end, arc_box, start_angle, end_angle)
        (-50, 30, -46, 62, [-62, 30, -28, 72], 220, 360),   # left
        (96, 30, 110, 60, [94, 28, 130, 68], 150, 310),      # right
        (20, -50, -10, -46, [-8, -68, 36, -34], 0, 180),     # top
        (20, 108, -10, 104, [-8, 94, 36, 128], 180, 360),    # bottom
    ]
    for (lx, ly, _, __, bbox, a1, a2) in flagella_data:
        # Convert relative to absolute
        abbox = [cx + bbox[0], cy + bbox[1], cx + bbox[2], cy + bbox[3]]
        # Glow
        draw.arc(abbox, a1, a2, fill=(0, 200, 255, 80), width=6)
        # Bright core
        draw.arc(abbox, a1, a2, fill=(0, 240, 255, 200), width=3)


def draw_player():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_player_frame(draw, frame=0)
    img.save("assets/player.png")
    print("  Player: assets/player.png")


def draw_player_sheet():
    """4-frame idle animation strip: 512×128."""
    sheet = Image.new("RGBA", (512, 128), (0, 0, 0, 0))
    for i in range(4):
        frame_img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame_img)
        draw_player_frame(draw, frame=i)
        # Apply subtle per-frame scale variation for pulsing feel
        scale = 1.0 + math.sin(i / 4.0 * math.pi * 2) * 0.04
        new_size = int(128 * scale)
        offset = (128 - new_size) // 2
        if scale != 1.0:
            frame_img = frame_img.resize((new_size, new_size), Image.Resampling.LANCZOS)
            padded = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
            padded.paste(frame_img, (max(0, offset), max(0, offset)))
            frame_img = padded
        sheet.paste(frame_img, (i * 128, 0))
    sheet.save("assets/player_sheet.png")
    print("  Player sheet: assets/player_sheet.png")


# ─────────────────────────────────────────────────────────
# 6. TEAR PROJECTILES — 48×48
# ─────────────────────────────────────────────────────────

def draw_tear():
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = 24, 24
    # Outer glow
    for g in range(5, 0, -1):
        draw.ellipse([cx - 20 - g, cy - 20 - g, cx + 20 + g, cy + 20 + g],
                     fill=(0, 220, 255, 18 + g * 10))
    # Body
    draw.ellipse([4, 4, 43, 43], fill=(0, 235, 255, 255), outline=(180, 255, 255, 255), width=3)
    # Inner bright core
    draw.ellipse([12, 12, 35, 35], fill=(200, 255, 255, 255))
    draw.ellipse([17, 17, 28, 28], fill=(255, 255, 255, 255))
    # Specular highlight
    draw.ellipse([10, 9, 18, 17], fill=(255, 255, 255, 200))
    img.save("assets/tear.png")
    print("  Tear: assets/tear.png")


def draw_enemy_tear():
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = 24, 24
    for g in range(5, 0, -1):
        draw.ellipse([cx - 20 - g, cy - 20 - g, cx + 20 + g, cy + 20 + g],
                     fill=(245, 20, 60, 15 + g * 8))
    draw.ellipse([4, 4, 43, 43], fill=(245, 35, 75, 255), outline=(255, 160, 190, 255), width=3)
    draw.ellipse([13, 13, 34, 34], fill=(255, 230, 240, 255))
    draw.ellipse([18, 18, 27, 27], fill=(255, 255, 255, 255))
    draw.ellipse([10, 9, 17, 16], fill=(255, 255, 255, 200))
    img.save("assets/enemy_tear.png")
    print("  Enemy tear: assets/enemy_tear.png")


def draw_tear_sheet():
    """3-frame rotating tear strip: 144×48."""
    sheet = Image.new("RGBA", (144, 48), (0, 0, 0, 0))
    for i in range(3):
        frame = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        d = ImageDraw.Draw(frame)
        cx, cy = 24, 24
        for g in range(4, 0, -1):
            d.ellipse([cx - 20 - g, cy - 20 - g, cx + 20 + g, cy + 20 + g],
                      fill=(0, 220, 255, 15 + g * 10))
        d.ellipse([4, 4, 43, 43], fill=(0, 235, 255, 255), outline=(180, 255, 255, 255), width=3)
        d.ellipse([12, 12, 35, 35], fill=(200, 255, 255, 255))
        d.ellipse([17, 17, 28, 28], fill=(255, 255, 255, 255))
        # Rotating specular highlight position
        spec_angle = i / 3.0 * math.pi * 2
        sx = int(cx + math.cos(spec_angle) * 9)
        sy = int(cy + math.sin(spec_angle) * 9)
        d.ellipse([sx - 4, sy - 4, sx + 4, sy + 4], fill=(255, 255, 255, 200))
        sheet.paste(frame, (i * 48, 0))
    sheet.save("assets/tear_sheet.png")
    print("  Tear sheet: assets/tear_sheet.png")


# ─────────────────────────────────────────────────────────
# 7. ENEMIES
# ─────────────────────────────────────────────────────────

def draw_enemy_amoeba_frame(draw, frame=0):
    """Amoeba swarmer on 88×88 canvas."""
    cx, cy = 44, 44
    t = frame / 4.0 * math.pi * 2

    # Drop shadow
    draw.ellipse([12, 68, 76, 84], fill=(4, 8, 16, 120))

    # Pseudopod protrusions (spiky outline effect)
    num_pods = 8
    for i in range(num_pods):
        angle = i / num_pods * math.pi * 2 + t * 0.3
        pod_len = 32 + math.sin(t + i * 0.7) * 5
        px = cx + math.cos(angle) * pod_len
        py = cy + math.sin(angle) * pod_len
        pod_r = 10 - i % 3 * 2
        draw.ellipse([px - pod_r, py - pod_r, px + pod_r, py + pod_r],
                     fill=(175, 30, 230, 180), outline=(245, 120, 255, 200), width=2)

    # Main body
    for i in range(5, 0, -1):
        a = 160 + i * 15
        draw.ellipse([cx - 30 - i, cy - 30 - i, cx + 30 + i, cy + 30 + i],
                     fill=(175, 30, 230, a))
    draw.ellipse([cx - 30, cy - 30, cx + 30, cy + 30],
                 fill=(195, 50, 240, 240), outline=(245, 130, 255, 255), width=3)
    draw.ellipse([cx - 22, cy - 22, cx + 22, cy + 22],
                 fill=(240, 40, 130, 255))

    # Nucleus
    draw.ellipse([cx - 10, cy - 8, cx + 10, cy + 8],
                 fill=(255, 240, 40, 220), outline=(200, 150, 0, 255), width=2)

    # Eyes with glow
    for ex, ey in [(cx - 14, cy - 14), (cx + 2, cy - 14)]:
        draw.ellipse([ex - 8, ey - 8, ex + 8, ey + 8], fill=(255, 250, 40, 220))
        draw.ellipse([ex - 5, ey - 5, ex + 5, ey + 5], fill=(220, 0, 0, 255))
        draw.ellipse([ex - 2, ey - 4, ex + 2, ey], fill=(10, 0, 0, 255))
        draw.ellipse([ex - 4, ey - 6, ex - 1, ey - 3], fill=(255, 255, 255, 160))

    # Membrane highlight
    draw.ellipse([cx - 22, cy - 28, cx - 4, cy - 16],
                 fill=(255, 200, 255, 80))


def draw_enemy_amoeba():
    img = Image.new("RGBA", (88, 88), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_enemy_amoeba_frame(draw, frame=0)
    img.save("assets/enemy_fly.png")
    print("  Amoeba enemy: assets/enemy_fly.png")


def draw_enemy_amoeba_sheet():
    """4-frame amoeba animation strip: 352×88."""
    sheet = Image.new("RGBA", (352, 88), (0, 0, 0, 0))
    for i in range(4):
        frame = Image.new("RGBA", (88, 88), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame)
        draw_enemy_amoeba_frame(draw, frame=i)
        sheet.paste(frame, (i * 88, 0))
    sheet.save("assets/enemy_fly_sheet.png")
    print("  Amoeba sheet: assets/enemy_fly_sheet.png")


def draw_enemy_trilobite_frame(draw, frame=0):
    """Trilobite pacer on 104×104 canvas."""
    cx, cy = 52, 52
    t = frame / 4.0 * math.pi * 2

    # Drop shadow
    draw.ellipse([14, 82, 90, 100], fill=(4, 8, 16, 140))

    # Body segments — 3 stacked rounded plates
    for seg, (sy_off, sw) in enumerate([(- 24, 36), (0, 42), (24, 34)]):
        sy = cy + sy_off
        # Shadow underside
        draw.ellipse([cx - sw - 2, sy - 14 + 4, cx + sw + 2, sy + 14 + 4],
                     fill=(20, 35, 55, 180))
        # Segment body
        draw.ellipse([cx - sw, sy - 14, cx + sw, sy + 14],
                     fill=(58, 90, 124, 255), outline=(20, 40, 62, 255), width=3)
        # Highlight ridge
        draw.arc([cx - sw + 4, sy - 10, cx + sw - 4, sy + 4], 180, 360,
                 fill=(110, 155, 190, 200), width=4)

    # Glowing compound eyes
    for ex, ey in [(cx - 28, cy - 24), (cx + 16, cy - 24)]:
        draw.ellipse([ex - 10, ey - 10, ex + 10, ey + 10],
                     fill=(0, 255, 230, 255), outline=(0, 180, 160, 255), width=2)
        draw.ellipse([ex - 5, ey - 5, ex + 5, ey + 5], fill=(255, 255, 255, 255))
        draw.ellipse([ex + 1, ey - 3, ex + 4, ey], fill=(255, 255, 255, 180))

    # Antennae
    ant_sway = math.sin(t) * 6
    for ax, ay, ex2, ey2 in [(cx - 24, cy - 36, cx - 34 + ant_sway, cy - 68),
                              (cx + 24, cy - 36, cx + 34 - ant_sway, cy - 68)]:
        draw.line([ax, ay, ex2, ey2], fill=(0, 255, 220, 255), width=4)
        draw.line([ax, ay, ex2, ey2], fill=(0, 255, 220, 140), width=8)
        draw.ellipse([ex2 - 5, ey2 - 5, ex2 + 5, ey2 + 5], fill=(0, 255, 230, 255))

    # Leg pairs along sides (3 pairs, rippling)
    for li in range(3):
        leg_y = cy - 22 + li * 22
        for side in [-1, 1]:
            leg_sway = math.sin(t + li * 1.2) * 5 * side
            lx = cx + side * 44
            lx2 = cx + side * 58 + leg_sway
            draw.line([lx, leg_y, lx2, leg_y + 8], fill=(40, 70, 100, 255), width=3)


def draw_enemy_trilobite():
    img = Image.new("RGBA", (104, 104), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_enemy_trilobite_frame(draw, frame=0)
    img.save("assets/enemy_gusha.png")
    print("  Trilobite enemy: assets/enemy_gusha.png")


def draw_enemy_trilobite_sheet():
    """4-frame trilobite animation strip: 416×104."""
    sheet = Image.new("RGBA", (416, 104), (0, 0, 0, 0))
    for i in range(4):
        frame = Image.new("RGBA", (104, 104), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame)
        draw_enemy_trilobite_frame(draw, frame=i)
        sheet.paste(frame, (i * 104, 0))
    sheet.save("assets/enemy_gusha_sheet.png")
    print("  Trilobite sheet: assets/enemy_gusha_sheet.png")


def draw_boss_nautiloid_frame(draw, frame=0):
    """Nautiloid boss on 220×220 canvas."""
    cx, cy = 110, 110
    t = frame / 6.0 * math.pi * 2

    # Drop shadow
    draw.ellipse([28, 175, 192, 218], fill=(4, 8, 16, 160))

    # Shell — layered arcs to create spiral illusion
    draw.ellipse([18, 18, 201, 201],
                 fill=(42, 65, 96, 255), outline=(14, 28, 48, 255), width=7)
    # Spiral bands
    for arc_r, alpha in [(80, 190), (60, 160), (42, 130)]:
        draw.arc([cx - arc_r, cy - arc_r, cx + arc_r, cy + arc_r],
                 20 + t * 10, 220 + t * 10, fill=(90, 135, 180, alpha), width=6)
    # Shell texture lines (concentric growth rings)
    for gr in range(12, 88, 14):
        draw.arc([cx - gr, cy - gr, cx + gr, cy + gr], 30, 210,
                 fill=(70, 110, 150, 80), width=2)
    # Shell highlight
    draw.arc([30, 30, 100, 95], 200, 330, fill=(160, 200, 235, 160), width=5)

    # Mantle / body core
    draw.ellipse([cx - 60, cy - 60, cx + 60, cy + 60],
                 fill=(220, 40, 105, 255), outline=(255, 140, 180, 255), width=5)
    draw.ellipse([cx - 46, cy - 46, cx + 46, cy + 46],
                 fill=(255, 240, 220, 255), outline=(40, 10, 20, 255), width=3)

    # Glowing eye
    for eg in range(5, 0, -1):
        draw.ellipse([cx - 20 - eg, cy - 25 - eg, cx + 20 + eg, cy + 25 + eg],
                     fill=(255, 40, 80, 25 + eg * 15))
    draw.ellipse([cx - 20, cy - 25, cx + 20, cy + 25], fill=(250, 20, 50, 255))
    # Slit pupil
    draw.ellipse([cx - 5, cy - 20, cx + 5, cy + 20], fill=(8, 0, 0, 255))
    # Specular
    draw.ellipse([cx - 16, cy - 22, cx - 8, cy - 14], fill=(255, 255, 255, 180))

    # Tentacles (4, with sucker dots)
    tentacle_data = [
        (cx - 55, cy + 58, cx - 90, cy + 105),
        (cx - 20, cy + 62, cx - 28, cy + 108),
        (cx + 20, cy + 62, cx + 28, cy + 108),
        (cx + 55, cy + 58, cx + 90, cy + 105),
    ]
    for i, (tx1, ty1, tx2, ty2) in enumerate(tentacle_data):
        sway = math.sin(t + i * 0.9) * 10
        tx2 += int(sway)
        draw.polygon([
            (tx1 - 10, ty1), (tx1 + 10, ty1),
            (tx2 + 6, ty2), (tx2 - 6, ty2)
        ], fill=(185, 36, 94, 255), outline=(110, 10, 50, 255))
        # Sucker dots along tentacle
        for si in range(3):
            s_t = (si + 1) / 4.0
            sx = tx1 + (tx2 - tx1) * s_t
            sy_val = ty1 + (ty2 - ty1) * s_t
            draw.ellipse([sx - 5, sy_val - 5, sx + 5, sy_val + 5],
                         fill=(255, 180, 210, 200), outline=(130, 20, 60, 200), width=1)


def draw_boss_nautiloid():
    img = Image.new("RGBA", (220, 220), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_boss_nautiloid_frame(draw, frame=0)
    img.save("assets/boss.png")
    print("  Boss: assets/boss.png")


def draw_boss_sheet():
    """6-frame boss animation strip: 1320×220."""
    sheet = Image.new("RGBA", (1320, 220), (0, 0, 0, 0))
    for i in range(6):
        frame = Image.new("RGBA", (220, 220), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame)
        draw_boss_nautiloid_frame(draw, frame=i)
        sheet.paste(frame, (i * 220, 0))
    sheet.save("assets/boss_sheet.png")
    print("  Boss sheet: assets/boss_sheet.png")


# ─────────────────────────────────────────────────────────
# 8. OBSTACLES & PROPS
# ─────────────────────────────────────────────────────────

def draw_rock():
    random.seed(77)
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Shadow
    draw.ellipse([18, 92, 110, 122], fill=(4, 8, 16, 140))

    # Main rock body
    pts = [(24, 98), (12, 58), (30, 22), (86, 12), (114, 38), (118, 90), (88, 114), (50, 118)]
    draw.polygon(pts, fill=(48, 70, 92, 255), outline=(18, 32, 46, 255), width=5)

    # Top face (lit)
    draw.polygon([(30, 22), (86, 12), (114, 38), (74, 54), (44, 42)],
                 fill=(82, 118, 148, 255))

    # Bottom shadow face
    draw.polygon([(24, 98), (88, 114), (50, 118), (62, 82)],
                 fill=(28, 44, 62, 255))

    # Phosphorescent crack vein
    draw.line([(44, 38), (72, 72), (40, 98)],
              fill=(0, 245, 220, 255), width=3)
    draw.line([(44, 38), (72, 72), (40, 98)],
              fill=(0, 245, 220, 100), width=7)

    # Secondary crack
    draw.line([(72, 24), (88, 52)], fill=(0, 220, 200, 140), width=2)

    # Micro-crystal spots
    for _ in range(6):
        rx = random.randint(28, 100)
        ry = random.randint(24, 96)
        draw.ellipse([rx - 3, ry - 3, rx + 3, ry + 3],
                     fill=(0, 245, 220, random.randint(60, 140)))

    # Highlight (specular)
    draw.ellipse([32, 18, 56, 36], fill=(140, 185, 215, 100))

    img.save("assets/rock.png")
    print("  Rock: assets/rock.png")


def draw_coral_spire():
    """Graceful, bioluminescent staghorn & fan coral with soft seafoam teal, lavender-periwinkle polyps, and pearl highlights."""
    random.seed(88)
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Ambient soft drop shadow
    draw.ellipse([14, 96, 114, 124], fill=(6, 16, 28, 140))

    # Sculpted marine reef mound (deep slate/marine crust)
    draw.polygon([(22, 114), (32, 92), (64, 86), (96, 92), (106, 114), (64, 120)],
                 fill=(26, 44, 60, 255), outline=(14, 26, 38, 255), width=3)

    # Graceful branching coral antlers reaching upward
    branches = [
        # (stalk_pts, tip_center, tip_rad, color_poly)
        ([(64, 96), (62, 58), (58, 24)], (58, 22), 10, (130, 190, 245)), # Center tall (ethereal periwinkle)
        ([(52, 92), (38, 68), (28, 40)], (28, 38), 8, (110, 220, 210)),  # Left main (aquamarine)
        ([(76, 92), (90, 68), (100, 42)], (100, 40), 8, (140, 180, 250)), # Right main (soft lavender)
        ([(42, 66), (22, 60)], (22, 58), 6, (100, 215, 205)),             # Left twig
        ([(86, 66), (108, 58)], (108, 56), 6, (125, 195, 240)),           # Right twig
        ([(60, 52), (76, 36)], (76, 34), 7, (120, 230, 220)),             # Center-right fork
    ]

    # Draw branch stalks with smooth organic tapering
    for pts, _, _, _ in branches:
        for w_line, a_line in [(14, 255), (10, 255), (6, 255)]:
            col = (28, 62, 80, a_line) if w_line == 14 else (42, 94, 112, a_line)
            draw.line(pts, fill=col, width=w_line)
        # Inner bioluminescent vein along stalk
        draw.line(pts, fill=(0, 230, 220, 220), width=2)

    # Draw glowing coral polyp tips (soft bloom + luminous core)
    for _, (tx, ty), rad, (cr, cg, cb) in branches:
        # Outer soft glow
        for g in range(6, 0, -1):
            draw.ellipse([tx - rad - g*2, ty - rad - g*2, tx + rad + g*2, ty + rad + g*2],
                         fill=(cr, cg, cb, 10 + g * 7))
        # Bulb tip
        draw.ellipse([tx - rad, ty - rad, tx + rad, ty + rad],
                     fill=(cr, cg, cb, 255), outline=(210, 245, 255, 220), width=2)
        # Inner pearlescent bead
        draw.ellipse([tx - rad//2, ty - rad//2, tx + rad//2, ty + rad//2],
                     fill=(240, 250, 255, 240))
        draw.ellipse([tx - 2, ty - 3, tx + 2, ty + 1], fill=(255, 255, 255, 255))

    # Gentle bioluminescent barnacles on base with calm micro-glow
    for bx, by in [(34, 104), (48, 110), (80, 108), (92, 102)]:
        draw.ellipse([bx - 4, by - 4, bx + 4, by + 4], fill=(36, 72, 92, 255), outline=(0, 230, 220, 180), width=1)
        draw.ellipse([bx - 1, by - 1, bx + 1, by + 1], fill=(0, 240, 230, 255))

    img = img.filter(ImageFilter.GaussianBlur(radius=0.4))
    img.save("assets/coral_spire.png")
    print("  Redesigned Coral Spire: assets/coral_spire.png")


def draw_biocrystal():
    random.seed(91)
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Base shadow
    draw.ellipse([20, 96, 108, 122], fill=(4, 8, 16, 160))

    # Cluster of prismatic hexagonal crystals
    # (top_pt, left_pt, right_pt, base_left, base_right, base_bot, color_front, color_side)
    crystals = [
        # Left crystal (tilted left)
        ([(36, 38), (22, 60), (38, 66), (28, 104), (44, 108), (36, 112)], (0, 220, 255), (0, 140, 200)),
        # Right crystal (tilted right)
        ([(92, 34), (80, 58), (104, 56), (82, 106), (102, 104), (94, 110)], (140, 60, 255), (90, 30, 180)),
        # Small front crystals
        ([(48, 62), (38, 80), (56, 82), (42, 112), (58, 112), (50, 116)], (0, 255, 220), (0, 180, 160)),
        ([(78, 58), (66, 76), (86, 76), (70, 114), (88, 112), (80, 116)], (180, 80, 255), (120, 40, 200)),
        # Giant Center crystal (dominant spire)
        ([(64, 12), (46, 42), (82, 40), (50, 110), (78, 110), (64, 118)], (120, 230, 255), (50, 150, 230)),
    ]

    for poly_pts, col_front, col_side in crystals:
        top_pt = poly_pts[0]
        l_pt = poly_pts[1]
        r_pt = poly_pts[2]
        bl_pt = poly_pts[3]
        br_pt = poly_pts[4]
        bb_pt = poly_pts[5]

        # Ambient crystal halo glow
        for g in range(4, 0, -1):
            draw.polygon([
                (top_pt[0], top_pt[1] - g*2),
                (l_pt[0] - g*2, l_pt[1]),
                (bl_pt[0] - g*2, bl_pt[1]),
                (bb_pt[0], bb_pt[1] + g*2),
                (br_pt[0] + g*2, br_pt[1]),
                (r_pt[0] + g*2, r_pt[1])
            ], fill=(col_front[0], col_front[1], col_front[2], 10 + g * 8))

        # Left facet (shadowed)
        draw.polygon([top_pt, l_pt, bl_pt, bb_pt], fill=col_side + (240,), outline=(20, 30, 50, 255), width=2)
        # Right facet (bright front face)
        draw.polygon([top_pt, r_pt, br_pt, bb_pt], fill=col_front + (240,), outline=(20, 30, 50, 255), width=2)
        # Center facet / ridge line
        draw.line([top_pt, bb_pt], fill=(255, 255, 255, 220), width=2)
        # Sharp specular highlight along top edge
        draw.line([top_pt, (int((top_pt[0]+r_pt[0])/2), int((top_pt[1]+r_pt[1])/2))], fill=(255, 255, 255, 255), width=3)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.3))
    img.save("assets/biocrystal.png")
    print("  Biocrystal: assets/biocrystal.png")


def draw_fossil_bone():
    random.seed(64)
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Shadow
    draw.ellipse([16, 96, 112, 122], fill=(4, 8, 16, 140))

    # Calcified fossilized leviathan rib arc
    # Deep stone base
    draw.polygon([(24, 110), (36, 88), (92, 88), (104, 110)], fill=(32, 40, 48, 255), outline=(16, 22, 28, 255), width=3)

    # 3 Arched rib segments
    ribs = [
        # (base_x, base_y, peak_x, peak_y, width, col)
        (34, 105, 48, 26, 16),
        (64, 105, 76, 18, 18),
        (94, 105, 102, 38, 14),
    ]

    for bx, by, px, py, w, in ribs:
        # Outer ancient bone shadow
        draw.line([(bx, by), (px, py)], fill=(75, 85, 95, 255), width=w + 4)
        # Calcified bone ivory body
        draw.line([(bx, by), (px, py)], fill=(175, 185, 180, 255), width=w)
        # Spine crest highlight
        draw.line([(bx - 2, by), (px - 2, py)], fill=(225, 235, 230, 255), width=w // 3)
        # Ancient moss / algae fissures
        f_mid_x = (bx + px) // 2
        f_mid_y = (by + py) // 2
        draw.line([(f_mid_x - 3, f_mid_y - 8), (f_mid_x + 4, f_mid_y + 6)], fill=(0, 190, 160, 200), width=2)
        # Top rounded condyle
        draw.ellipse([px - w//2, py - w//2, px + w//2, py + w//2], fill=(210, 220, 215, 255), outline=(90, 100, 105, 255), width=2)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.4))
    img.save("assets/fossil_bone.png")
    print("  Fossil Bone: assets/fossil_bone.png")


def draw_floor_decals():
    """Generate subtle decorative floor decals: bio-moss, ancient rune, fossil imprint, hydrothermal vent."""
    # 1. Bio-Moss
    img_moss = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img_moss)
    random.seed(55)
    for _ in range(16):
        mx = random.randint(30, 98)
        my = random.randint(30, 98)
        mr = random.randint(8, 24)
        alpha = random.randint(25, 60)
        d.ellipse([mx - mr, my - mr, mx + mr, my + mr], fill=(0, 210, 150, alpha))
        # Spore beads
        for _ in range(3):
            sx = mx + random.randint(-mr//2, mr//2)
            sy = my + random.randint(-mr//2, mr//2)
            d.ellipse([sx - 2, sy - 2, sx + 2, sy + 2], fill=(0, 255, 200, 120))
    img_moss = img_moss.filter(ImageFilter.GaussianBlur(radius=1.2))
    img_moss.save("assets/decal_moss.png")
    print("  Decal Moss: assets/decal_moss.png")

    # 2. Ancient Rune / Glyphs
    img_rune = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img_rune)
    cx, cy = 64, 64
    for r, width_a, alpha in [(44, 2, 80), (32, 1, 60), (18, 2, 90)]:
        d.arc([cx - r, cy - r, cx + r, cy + r], 0, 360, fill=(0, 240, 255, alpha), width=width_a)
    for ang in [0, 60, 120, 180, 240, 300]:
        rad = math.radians(ang)
        gx = cx + math.cos(rad) * 38
        gy = cy + math.sin(rad) * 38
        d.ellipse([gx - 3, gy - 3, gx + 3, gy + 3], fill=(0, 255, 230, 110))
    # Center glyph dot
    d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(0, 255, 240, 130))
    img_rune = img_rune.filter(ImageFilter.GaussianBlur(radius=0.6))
    img_rune.save("assets/decal_rune.png")
    print("  Decal Rune: assets/decal_rune.png")

    # 3. Ammonite Fossil
    img_fossil = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img_fossil)
    cx, cy = 64, 64
    # Spiral coil of ammonite
    for step in range(80):
        t = step / 80.0
        angle = t * math.pi * 5.5
        r = 6 + t * 40
        fx = cx + math.cos(angle) * r
        fy = cy + math.sin(angle) * r
        w = int(2 + t * 6)
        alpha = int(35 + t * 55)
        d.ellipse([fx - w, fy - w, fx + w, fy + w], fill=(20, 50, 75, alpha))
        if step % 5 == 0:
            d.line([(fx, fy), (cx + math.cos(angle) * (r - 8), cy + math.sin(angle) * (r - 8))],
                   fill=(30, 80, 110, 65), width=2)
    img_fossil = img_fossil.filter(ImageFilter.GaussianBlur(radius=0.8))
    img_fossil.save("assets/decal_fossil.png")
    print("  Decal Fossil: assets/decal_fossil.png")

    # 4. Thermal Seep Vent
    img_vent = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img_vent)
    cx, cy = 64, 64
    # Dark crater
    d.ellipse([cx - 32, cy - 20, cx + 32, cy + 20], fill=(8, 14, 22, 180), outline=(20, 36, 50, 200), width=3)
    # Geothermal fissure cracks with magma/cyan glow
    for g in range(4, 0, -1):
        d.ellipse([cx - 18 - g, cy - 10 - g, cx + 18 + g, cy + 10 + g], fill=(255, 120, 20, 20 + g * 15))
    d.ellipse([cx - 14, cy - 7, cx + 14, cy + 7], fill=(255, 160, 40, 180))
    d.ellipse([cx - 6, cy - 3, cx + 6, cy + 3], fill=(255, 230, 120, 220))
    img_vent = img_vent.filter(ImageFilter.GaussianBlur(radius=0.8))
    img_vent.save("assets/decal_vent.png")
    print("  Decal Vent: assets/decal_vent.png")



def draw_trapdoor():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Outer ring with glow
    for g in range(6, 0, -1):
        draw.ellipse([6 - g, 6 - g, 121 + g, 121 + g],
                     fill=(0, 200, 255, 12 + g * 8))
    draw.ellipse([6, 6, 121, 121], fill=(4, 10, 22, 255), outline=(0, 220, 255, 255), width=6)

    # Spiral vortex arcs (5 nested, offset angles)
    for i in range(6):
        r = 50 - i * 7
        start_a = i * 60
        draw.arc([64 - r, 64 - r, 64 + r, 64 + r], start_a, start_a + 200,
                 fill=(0, 245, 255, 220 - i * 25), width=4)

    # Inner glow pool
    draw.ellipse([44, 44, 83, 83], fill=(0, 30, 50, 255))
    for g in range(4, 0, -1):
        draw.ellipse([56 - g, 56 - g, 71 + g, 71 + g],
                     fill=(0, 220, 255, 30 + g * 30))
    draw.ellipse([58, 58, 69, 69], fill=(0, 255, 255, 220))

    # Ring bolt accents
    for angle_deg in [45, 135, 225, 315]:
        a = math.radians(angle_deg)
        bx = int(64 + math.cos(a) * 52)
        by = int(64 + math.sin(a) * 52)
        draw.ellipse([bx - 6, by - 6, bx + 6, by + 6], fill=(16, 30, 50, 255), outline=(0, 180, 220, 200), width=2)

    img.save("assets/trapdoor.png")
    print("  Trapdoor: assets/trapdoor.png")


# ─────────────────────────────────────────────────────────
# 9. PICKUPS — 64×64
# ─────────────────────────────────────────────────────────

def draw_pickups():
    # ── DNA Coin ──
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = 32, 32
    # Outer glow
    for g in range(4, 0, -1):
        draw.ellipse([cx - 18 - g, cy - 20 - g, cx + 18 + g, cy + 20 + g],
                     fill=(0, 220, 180, 20 + g * 15))
    # Body
    draw.ellipse([cx - 18, cy - 20, cx + 18, cy + 20],
                 fill=(0, 230, 185, 240), outline=(200, 255, 240, 255), width=3)
    # DNA strand symbol
    for i in range(6):
        t = i / 5.0
        hx = cx + math.sin(t * math.pi * 2) * 9
        hy = cy - 14 + t * 28
        draw.ellipse([hx - 4, hy - 3, hx + 4, hy + 3], fill=(255, 255, 255, 220))
        hx2 = cx - math.sin(t * math.pi * 2) * 9
        draw.ellipse([hx2 - 4, hy - 3, hx2 + 4, hy + 3], fill=(200, 255, 240, 200))
    # Specular
    draw.ellipse([cx - 14, cy - 17, cx - 5, cy - 10], fill=(255, 255, 255, 160))
    img.save("assets/pickup_coin.png")
    print("  Pickup coin: assets/pickup_coin.png")

    # ── Full Heart ──
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Glow
    for g in range(4, 0, -1):
        draw.ellipse([8 - g, 12 - g, 34 + g, 36 + g], fill=(255, 40, 90, 15 + g * 12))
        draw.ellipse([28 - g, 12 - g, 54 + g, 36 + g], fill=(255, 40, 90, 15 + g * 12))
    # Main lobes
    draw.ellipse([8, 12, 34, 36], fill=(255, 45, 95, 255))
    draw.ellipse([28, 12, 54, 36], fill=(255, 45, 95, 255))
    draw.polygon([(8, 26), (54, 26), (30, 54)], fill=(255, 45, 95, 255))
    # Shadow detail
    draw.arc([8, 12, 34, 36], 180, 360, fill=(170, 10, 50, 255), width=3)
    draw.arc([28, 12, 54, 36], 180, 360, fill=(170, 10, 50, 255), width=3)
    draw.line([8, 24, 30, 54], fill=(170, 10, 50, 255), width=3)
    draw.line([54, 24, 30, 54], fill=(170, 10, 50, 255), width=3)
    # Gloss highlight
    draw.ellipse([13, 16, 22, 24], fill=(255, 200, 220, 220))
    img.save("assets/pickup_heart.png")
    print("  Pickup heart: assets/pickup_heart.png")

    # ── Half Heart ──
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([8, 12, 34, 36], fill=(255, 45, 95, 255))
    draw.polygon([(8, 26), (30, 26), (30, 54)], fill=(255, 45, 95, 255))
    draw.arc([8, 12, 34, 36], 180, 360, fill=(170, 10, 50, 255), width=3)
    draw.arc([28, 12, 54, 36], 180, 360, fill=(55, 65, 90, 255), width=3)
    draw.line([8, 24, 30, 54], fill=(170, 10, 50, 255), width=3)
    draw.line([54, 24, 30, 54], fill=(55, 65, 90, 255), width=3)
    draw.line([30, 12, 30, 54], fill=(140, 20, 50, 255), width=2)
    draw.ellipse([13, 16, 22, 24], fill=(255, 200, 220, 220))
    img.save("assets/pickup_heart_half.png")
    print("  Pickup heart half: assets/pickup_heart_half.png")

    # ── Empty Heart ──
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.arc([8, 12, 34, 36], 180, 360, fill=(50, 62, 84, 255), width=3)
    draw.arc([28, 12, 54, 36], 180, 360, fill=(50, 62, 84, 255), width=3)
    draw.line([8, 24, 30, 54], fill=(50, 62, 84, 255), width=3)
    draw.line([54, 24, 30, 54], fill=(50, 62, 84, 255), width=3)
    img.save("assets/pickup_heart_empty.png")
    print("  Pickup heart empty: assets/pickup_heart_empty.png")

    # ── Key ──
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Glow
    for g in range(3, 0, -1):
        draw.ellipse([12 - g, 12 - g, 34 + g, 34 + g],
                     fill=(255, 210, 40, 20 + g * 20))
    # Bow (ring)
    draw.ellipse([12, 12, 34, 34], fill=None, outline=(255, 215, 50, 255), width=4)
    draw.ellipse([16, 16, 30, 30], fill=(200, 160, 10, 180))
    # Shaft
    draw.line([(32, 23), (54, 23)], fill=(255, 215, 50, 255), width=4)
    # Teeth
    draw.line([(44, 23), (44, 34)], fill=(255, 215, 50, 255), width=3)
    draw.line([(50, 23), (50, 30)], fill=(255, 215, 50, 255), width=3)
    # Specular
    draw.ellipse([15, 14, 22, 21], fill=(255, 255, 200, 160))
    img.save("assets/pickup_key.png")
    print("  Pickup key: assets/pickup_key.png")

    # ── Bomb ──
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Glow
    for g in range(3, 0, -1):
        draw.ellipse([10 - g, 14 - g, 52 + g, 56 + g],
                     fill=(180, 65, 16, 15 + g * 12))
    # Body
    draw.ellipse([10, 14, 52, 56], fill=(185, 70, 20, 255), outline=(90, 24, 6, 255), width=3)
    # Highlight spots
    draw.ellipse([14, 22, 24, 32], fill=(240, 140, 42, 220))
    draw.ellipse([34, 32, 44, 42], fill=(240, 140, 42, 180))
    # Gloss highlight
    draw.ellipse([13, 16, 22, 24], fill=(255, 200, 160, 200))
    # Fuse
    draw.line([(32, 14), (32, 2)], fill=(0, 240, 180, 255), width=4)
    draw.line([(32, 14), (32, 2)], fill=(0, 240, 180, 120), width=8)
    # Fuse tip glow
    draw.ellipse([28, -2, 36, 6], fill=(255, 255, 100, 255))
    draw.ellipse([29, -1, 35, 5], fill=(255, 255, 255, 200))
    img.save("assets/pickup_bomb.png")
    print("  Pickup bomb: assets/pickup_bomb.png")


# ─────────────────────────────────────────────────────────
# 10. PEDESTAL
# ─────────────────────────────────────────────────────────

def draw_pedestal():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Shadow
    draw.ellipse([10, 106, 118, 126], fill=(4, 8, 16, 140))

    # Platform base
    draw.rectangle([12, 116, 115, 128], fill=(54, 80, 110, 255), outline=(24, 40, 62, 255), width=2)
    # Base highlight
    draw.line([(14, 118), (113, 118)], fill=(90, 125, 160, 180), width=2)

    # Column shaft
    draw.rectangle([34, 80, 93, 118], fill=(38, 58, 82, 255), outline=(18, 32, 52, 255), width=2)
    # Column highlight strip
    draw.rectangle([36, 82, 44, 116], fill=(58, 84, 114, 200))

    # Neck cap (narrower)
    draw.rectangle([28, 72, 99, 82], fill=(54, 80, 110, 255), outline=(22, 38, 58, 255), width=2)

    # Top platform
    draw.rectangle([14, 62, 113, 74], fill=(62, 90, 124, 255), outline=(26, 44, 68, 255), width=2)
    # Top glow line
    draw.line([(16, 64), (111, 64)], fill=(0, 255, 220, 200), width=3)
    draw.line([(16, 65), (111, 65)], fill=(0, 255, 220, 80), width=2)

    # Column vein lines
    for vx in [48, 62, 76]:
        draw.line([(vx, 82), (vx, 118)], fill=(0, 200, 230, 50), width=1)

    # Ornamental glow dots on top platform corners
    for dx in [20, 108]:
        draw.ellipse([dx - 5, 65, dx + 5, 75], fill=(0, 220, 255, 160))
        draw.ellipse([dx - 2, 67, dx + 2, 73], fill=(255, 255, 255, 200))

    img.save("assets/pedestal.png")
    print("  Pedestal: assets/pedestal.png")


# ─────────────────────────────────────────────────────────
# 11. ITEMS — 64×64
# ─────────────────────────────────────────────────────────

def draw_items():
    # ── Onion (speed/fire rate item) ──
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Glow
    for g in range(4, 0, -1):
        draw.ellipse([14 - g, 14 - g, 48 + g, 48 + g],
                     fill=(0, 200, 255, 15 + g * 12))
    draw.ellipse([14, 14, 48, 48], fill=(0, 225, 255, 255), outline=(180, 255, 255, 255), width=3)
    draw.ellipse([20, 20, 42, 42], fill=(180, 248, 255, 255))
    draw.ellipse([24, 24, 34, 34], fill=(255, 255, 255, 255))
    # Ring arc (orbit)
    draw.arc([6, 10, 58, 52], 30, 220, fill=(0, 160, 240, 200), width=3)
    # Gloss
    draw.ellipse([18, 16, 28, 24], fill=(255, 255, 255, 160))
    img.save("assets/item_onion.png")
    print("  Item onion: assets/item_onion.png")

    # ── Eye (triple shot) ──
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for g in range(3, 0, -1):
        draw.ellipse([6 - g, 18 - g, 58 + g, 44 + g],
                     fill=(240, 248, 255, 15 + g * 12))
    draw.ellipse([6, 18, 58, 44], fill=(240, 248, 255, 255), outline=(28, 38, 80, 255), width=3)
    # Iris
    draw.ellipse([20, 22, 44, 40], fill=(0, 220, 255, 255))
    # Pupil
    draw.ellipse([28, 26, 36, 36], fill=(10, 8, 20, 255))
    draw.ellipse([27, 24, 32, 29], fill=(255, 255, 255, 200))
    # Eyelid
    draw.arc([6, 18, 58, 44], 0, 180, fill=(220, 230, 250, 180), width=2)
    img.save("assets/item_eye.png")
    print("  Item eye: assets/item_eye.png")

    # ── Hormones (damage + speed boost) ──
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for g in range(3, 0, -1):
        draw.rectangle([18 - g, 10 - g, 44 + g, 42 + g],
                       fill=(240, 40, 80, 12 + g * 10))
    draw.rounded_rectangle([18, 10, 44, 42], radius=6,
                           fill=(230, 40, 80, 255), outline=(130, 8, 32, 255), width=3)
    # Label cross
    draw.line([(32, 18), (32, 34)], fill=(255, 255, 255, 220), width=3)
    draw.line([(24, 26), (40, 26)], fill=(255, 255, 255, 220), width=3)
    # Gloss
    draw.ellipse([21, 13, 32, 22], fill=(255, 180, 200, 160))
    # Drip
    draw.line([(32, 42), (32, 56)], fill=(200, 200, 220, 220), width=3)
    draw.ellipse([29, 54, 35, 60], fill=(200, 200, 220, 180))
    img.save("assets/item_hormones.png")
    print("  Item hormones: assets/item_hormones.png")

    # ── Cells (health boost) ──
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for g in range(3, 0, -1):
        draw.ellipse([10 - g, 18 - g, 36 + g, 44 + g],
                     fill=(255, 140, 0, 12 + g * 10))
        draw.ellipse([26 - g, 18 - g, 52 + g, 44 + g],
                     fill=(255, 190, 40, 12 + g * 8))
    draw.ellipse([10, 18, 36, 44], fill=(255, 140, 0, 255), outline=(160, 70, 0, 255), width=3)
    draw.ellipse([26, 18, 52, 44], fill=(255, 195, 40, 255), outline=(200, 100, 0, 255), width=3)
    # Cell nuclei
    draw.ellipse([18, 26, 28, 36], fill=(255, 200, 100, 200))
    draw.ellipse([34, 26, 44, 36], fill=(255, 230, 130, 200))
    # Gloss
    draw.ellipse([13, 20, 20, 27], fill=(255, 220, 160, 180))
    img.save("assets/item_cells.png")
    print("  Item cells: assets/item_cells.png")


# ─────────────────────────────────────────────────────────
# 12. LIGHT TEXTURE — 512×512
# ─────────────────────────────────────────────────────────

def draw_light():
    img = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = 256, 256
    for r in range(1, 256):
        # Power curve for softer falloff
        decay = (1.0 - (r / 256.0)) ** 1.8
        alpha = int(255 * decay * 0.55)
        # Slight warmth towards centre
        blue = int(255 * min(1.0, 1.0 - (r / 256.0) * 0.2))
        draw.ellipse([cx - r, cy - r, cx + r - 1, cy + r - 1],
                     fill=(200, 240, blue, alpha))
    img.save("assets/light.png")
    print("  Light: assets/light.png")


# ─────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────

if __name__ == "__main__":
    create_directory()

    print("\n=== Phase 1: Backgrounds & Tiles ===")
    draw_fullscreen_background("room_bg_start.png", "start")
    draw_fullscreen_background("room_bg_normal.png", "normal")
    draw_fullscreen_background("room_bg_boss.png", "boss")
    draw_fullscreen_background("room_bg_treasure.png", "treasure")
    draw_fullscreen_background("room_bg_shop.png", "shop")
    draw_floor_tile("floor.png", variant=0, seed_offset=0)          # default (used by Room.gd)
    draw_floor_tile("floor_a.png", variant=0, seed_offset=0)
    draw_floor_tile("floor_b.png", variant=1, seed_offset=100)
    draw_floor_tile("floor_c.png", variant=2, seed_offset=200)
    draw_wall()

    print("\n=== Phase 2: Doors & Props ===")
    draw_door()
    draw_door_locked()
    draw_rock()
    draw_coral_spire()
    draw_biocrystal()
    draw_fossil_bone()
    draw_floor_decals()
    draw_trapdoor()
    draw_pedestal()
    draw_light()

    print("\n=== Phase 3: Player & Projectiles ===")
    draw_player()
    draw_player_sheet()
    draw_tear()
    draw_enemy_tear()
    draw_tear_sheet()

    print("\n=== Phase 4: Enemies ===")
    draw_enemy_amoeba()
    draw_enemy_amoeba_sheet()
    draw_enemy_trilobite()
    draw_enemy_trilobite_sheet()
    draw_boss_nautiloid()
    draw_boss_sheet()

    print("\n=== Phase 5: Pickups & Items ===")
    draw_pickups()
    print("\n=== Phase 6: Satisfying Obstacles & Seamless Doors ===")
    try:
        import generate_satisfying_art
        generate_satisfying_art.draw_fossil_bone()
        generate_satisfying_art.draw_hydrothermal_vent()
        generate_satisfying_art.draw_rock()
        generate_satisfying_art.draw_biocrystal()
        generate_satisfying_art.draw_door()
        generate_satisfying_art.draw_door_closed()
        generate_satisfying_art.draw_door_locked()
        generate_satisfying_art.draw_fullscreen_background("room_bg_normal.png", "normal")
        generate_satisfying_art.draw_fullscreen_background("room_bg_start.png", "start")
        generate_satisfying_art.draw_fullscreen_background("room_bg_boss.png", "boss")
        generate_satisfying_art.draw_fullscreen_background("room_bg_treasure.png", "treasure")
        generate_satisfying_art.draw_fullscreen_background("room_bg_shop.png", "shop")
    except Exception as e:
        print("  Warning: could not run generate_satisfying_art:", e)

    print("\nAll assets generated successfully!")
