import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter

def create_directory():
    os.makedirs("assets", exist_ok=True)

# -------------------------------------------------------------
# 1. 1920x1080 Full-Screen Unique Chamber Backgrounds
# -------------------------------------------------------------
def draw_fullscreen_background(filename, theme_type="normal"):
    # 1920x1080 non-repeating seamless atmospheric chamber
    width, height = 1920, 1080
    cx, cy = width / 2.0, height / 2.0
    
    # Base palette selection
    if theme_type == "boss":
        base_r, base_g, base_b = 24, 14, 28 # Dark crimson/violet abyss
        glow_r, glow_g, glow_b = 220, 30, 80
    elif theme_type == "treasure":
        base_r, base_g, base_b = 12, 32, 36 # Rich cyan/emerald gene vault
        glow_r, glow_g, glow_b = 0, 240, 190
    elif theme_type == "shop":
        base_r, base_g, base_b = 20, 28, 42 # Golden bioluminescent tidepool
        glow_r, glow_g, glow_b = 240, 190, 40
    else: # normal
        base_r, base_g, base_b = 14, 26, 44 # Deep primordial tidepool
        glow_r, glow_g, glow_b = 0, 220, 255

    img = Image.new("RGBA", (width, height), (base_r, base_g, base_b, 255))
    draw = ImageDraw.Draw(img)
    
    # 1. Multi-layered smooth organic gradient & current fields
    # Sample every 2 pixels and blur for performance and ultra-smooth look
    low_w, low_h = width // 4, height // 4
    low_img = Image.new("RGBA", (low_w, low_h), (base_r, base_g, base_b, 255))
    low_draw = ImageDraw.Draw(low_img)
    
    for x in range(low_w):
        for y in range(low_h):
            real_x = x * 4
            real_y = y * 4
            
            # Distance from center
            dx = (real_x - cx) / cx
            dy = (real_y - cy) / cy
            dist_sq = dx*dx + dy*dy
            
            # Organic undulating wave functions
            w1 = math.sin(real_x * 0.008) * math.cos(real_y * 0.008) * 12.0
            w2 = math.sin((real_x + real_y) * 0.005) * 8.0
            w3 = math.cos(real_x * 0.015 - real_y * 0.01) * 6.0
            
            # Center illumination gradient (arena is brighter in center, darker towards borders)
            center_glow = max(0.0, 1.0 - math.sqrt(dist_sq) * 0.8) * 22.0
            vignette = max(0.0, dist_sq * 18.0)
            
            r = max(0, min(255, int(base_r + w1 * 0.5 + center_glow * (glow_r / 255.0) - vignette)))
            g = max(0, min(255, int(base_g + w1 + w2 + center_glow * (glow_g / 255.0) - vignette)))
            b = max(0, min(255, int(base_b + w1 * 1.8 + w2 * 1.5 + w3 + center_glow * (glow_b / 255.0) - vignette)))
            
            low_img.putpixel((x, y), (r, g, b, 255))
            
    # Upscale and blur smooth background
    upscaled = low_img.resize((width, height), Image.Resampling.BILINEAR)
    upscaled = upscaled.filter(ImageFilter.GaussianBlur(radius=6))
    img.paste(upscaled, (0, 0))
    draw = ImageDraw.Draw(img)
    
    # 2. Ambient Bioluminescent Currents & Cellular Web Lines
    for i in range(12):
        start_x = random.randint(200, 1720)
        start_y = random.randint(150, 930)
        length = random.randint(100, 260)
        angle = random.uniform(0, math.pi * 2)
        end_x = start_x + math.cos(angle) * length
        end_y = start_y + math.sin(angle) * length
        
        # Soft glowing current strand
        alpha = random.randint(30, 70)
        draw.line([start_x, start_y, end_x, end_y], fill=(glow_r, glow_g, glow_b, alpha), width=3)
        
    # 3. Glowing Microbial Colonies & Fossil Nodes
    num_colonies = 18 if theme_type == "normal" else 24
    for _ in range(num_colonies):
        nx = random.randint(180, 1740)
        ny = random.randint(140, 940)
        rad = random.randint(4, 12)
        # Glow halo
        draw.ellipse([nx - rad*2, ny - rad*2, nx + rad*2, ny + rad*2], fill=(glow_r, glow_g, glow_b, 40))
        draw.ellipse([nx - rad, ny - rad, nx + rad, ny + rad], fill=(glow_r, glow_g, glow_b, 90))
        draw.ellipse([nx - rad//2, ny - rad//2, nx + rad//2, ny + rad//2], fill=(240, 255, 255, 180))
        
    # 4. Perimeter Calcified Reef Border (Top, Bottom, Left, Right Framing)
    # Wall border thickness is 128px
    wall_col = (base_r + 6, base_g + 6, base_b + 10, 255)
    wall_inner_edge = (glow_r, glow_g, glow_b, 160)
    
    # Top Wall Frame (leave opening for top door at 896..1024)
    draw.rectangle([0, 0, 896, 120], fill=wall_col)
    draw.rectangle([1024, 0, 1920, 120], fill=wall_col)
    draw.line([0, 120, 896, 120], fill=wall_inner_edge, width=4)
    draw.line([1024, 120, 1920, 120], fill=wall_inner_edge, width=4)
    
    # Bottom Wall Frame (leave opening for bottom door at 896..1024)
    draw.rectangle([0, 960, 896, 1080], fill=wall_col)
    draw.rectangle([1024, 960, 1920, 1080], fill=wall_col)
    draw.line([0, 960, 896, 960], fill=wall_inner_edge, width=4)
    draw.line([1024, 960, 1920, 960], fill=wall_inner_edge, width=4)
    
    # Left Wall Frame (leave opening for left door at 476..604)
    draw.rectangle([0, 120, 120, 476], fill=wall_col)
    draw.rectangle([0, 604, 120, 960], fill=wall_col)
    draw.line([120, 120, 120, 476], fill=wall_inner_edge, width=4)
    draw.line([120, 604, 120, 960], fill=wall_inner_edge, width=4)
    
    # Right Wall Frame (leave opening for right door at 476..604)
    draw.rectangle([1800, 120, 1920, 476], fill=wall_col)
    draw.rectangle([1800, 604, 1920, 960], fill=wall_col)
    draw.line([1800, 120, 1800, 476], fill=wall_inner_edge, width=4)
    draw.line([1800, 604, 1800, 960], fill=wall_inner_edge, width=4)
    
    # Corner Accents (Organic sediment brackets)
    corner_size = 140
    draw.polygon([(0, 0), (corner_size, 0), (0, corner_size)], fill=(base_r - 4, base_g - 4, base_b - 4, 255))
    draw.polygon([(1920, 0), (1920 - corner_size, 0), (1920, corner_size)], fill=(base_r - 4, base_g - 4, base_b - 4, 255))
    draw.polygon([(0, 1080), (corner_size, 1080), (0, 1080 - corner_size)], fill=(base_r - 4, base_g - 4, base_b - 4, 255))
    draw.polygon([(1920, 1080), (1920 - corner_size, 1080), (1920, 1080 - corner_size)], fill=(base_r - 4, base_g - 4, base_b - 4, 255))

    # 5. Theme-specific Center Art
    if theme_type == "boss":
        # Titan abyss eye crater in center floor
        draw.ellipse([cx - 160, cy - 100, cx + 160, cy + 100], fill=(12, 4, 16, 220), outline=(220, 30, 80, 180), width=4)
        draw.ellipse([cx - 80, cy - 50, cx + 80, cy + 50], fill=(60, 10, 25, 240))
        draw.ellipse([cx - 20, cy - 35, cx + 20, cy + 35], fill=(255, 40, 80, 255))
    elif theme_type == "treasure":
        # Mutagen helix emblem in center floor
        draw.ellipse([cx - 140, cy - 90, cx + 140, cy + 90], fill=(6, 18, 24, 200), outline=(0, 240, 190, 160), width=3)
        draw.arc([cx - 80, cy - 50, cx + 80, cy + 50], 0, 360, fill=(0, 255, 220, 200), width=3)
    elif theme_type == "shop":
        # Gene shrine ring in center floor
        draw.ellipse([cx - 140, cy - 90, cx + 140, cy + 90], fill=(14, 18, 28, 200), outline=(240, 190, 40, 160), width=3)
    
    img.save(f"assets/{filename}")
    print(f"Generated 1920x1080 Fullscreen Background: assets/{filename}")

# -------------------------------------------------------------
# 2. Modern High-Tech / Organic Doors (128x128 px)
# -------------------------------------------------------------
def draw_door():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([8, 8, 119, 119], fill=(22, 44, 68, 255), outline=(10, 20, 36, 255), width=6)
    draw.ellipse([22, 22, 105, 105], fill=(14, 30, 50, 255), outline=(0, 220, 255, 255), width=4)
    draw.ellipse([34, 34, 93, 93], fill=(2, 6, 12, 255))
    draw.arc([30, 30, 97, 97], 0, 360, fill=(0, 255, 230, 255), width=4)
    draw.arc([42, 42, 85, 85], 0, 360, fill=(100, 255, 255, 180), width=2)
    img.save("assets/door.png")

def draw_door_locked():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([8, 8, 119, 119], fill=(36, 42, 54, 255), outline=(14, 18, 26, 255), width=6)
    draw.ellipse([22, 22, 105, 105], fill=(24, 28, 38, 255), outline=(60, 70, 90, 255), width=3)
    draw.ellipse([38, 38, 89, 89], fill=(255, 185, 20, 255), outline=(180, 110, 0, 255), width=4)
    draw.ellipse([46, 46, 81, 81], fill=(255, 220, 80, 255))
    draw.line([50, 54, 77, 74], fill=(40, 20, 0, 255), width=4)
    draw.line([50, 74, 77, 54], fill=(40, 20, 0, 255), width=4)
    img.save("assets/door_locked.png")

def draw_wall():
    # 128x128 Wall fill tile for closed door gaps
    img = Image.new("RGBA", (128, 128), (20, 28, 42, 255))
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, 127, 127], fill=(16, 24, 38, 255), outline=(8, 14, 24, 255), width=4)
    draw.line([4, 4, 123, 4], fill=(0, 200, 220, 180), width=2)
    draw.line([4, 123, 123, 123], fill=(0, 160, 180, 160), width=2)
    img.save("assets/wall.png")

# -------------------------------------------------------------
# 3. Player: 2026 Primordial Microbe (128x128 px)
# -------------------------------------------------------------
def draw_player():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 1. Soft drop shadow
    draw.ellipse([24, 88, 104, 116], fill=(4, 8, 16, 140))
    
    # 2. Outer translucent cytoplasmic membrane
    draw.ellipse([16, 12, 111, 107], fill=(25, 165, 235, 200), outline=(130, 250, 255, 255), width=5)
    draw.ellipse([24, 20, 103, 99], fill=(15, 130, 210, 220))
    
    # 3. Floating vibrant organelles
    draw.ellipse([30, 36, 52, 60], fill=(255, 110, 175, 220), outline=(220, 40, 110, 240), width=2)
    draw.ellipse([76, 68, 98, 90], fill=(90, 255, 160, 220), outline=(20, 190, 80, 240), width=2)
    draw.ellipse([34, 70, 48, 84], fill=(255, 200, 80, 200), outline=(200, 140, 20, 220), width=2)
    
    # 4. Core Pulsing Glowing Nucleus
    draw.ellipse([42, 38, 86, 82], fill=(255, 245, 90, 255), outline=(255, 170, 0, 255), width=4)
    draw.ellipse([50, 46, 78, 74], fill=(255, 255, 210, 255))
    
    # 5. Expressive eyes
    draw.ellipse([40, 36, 56, 54], fill=(8, 16, 32, 255))
    draw.ellipse([72, 36, 88, 54], fill=(8, 16, 32, 255))
    draw.ellipse([44, 38, 52, 46], fill=(255, 255, 255, 255))
    draw.ellipse([76, 38, 84, 46], fill=(255, 255, 255, 255))
    draw.ellipse([48, 48, 52, 52], fill=(255, 255, 255, 200))
    draw.ellipse([80, 48, 84, 52], fill=(255, 255, 255, 200))
    
    # 6. Smile
    draw.arc([54, 56, 74, 72], 0, 180, fill=(8, 16, 32, 255), width=3)
    
    # 7. Flagella hairs
    draw.arc([4, 48, 22, 74], 90, 270, fill=(0, 230, 255, 220), width=4)
    draw.arc([106, 48, 124, 74], 270, 90, fill=(0, 230, 255, 220), width=4)
    
    img.save("assets/player.png")

# -------------------------------------------------------------
# 4. High-Energy Bio Projectiles (48x48 px)
# -------------------------------------------------------------
def draw_tear():
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([4, 4, 43, 43], fill=(0, 235, 255, 255), outline=(220, 255, 255, 255), width=3)
    draw.ellipse([12, 12, 35, 35], fill=(255, 255, 255, 255))
    draw.ellipse([16, 16, 26, 26], fill=(200, 255, 255, 255))
    img.save("assets/tear.png")

def draw_enemy_tear():
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([4, 4, 43, 43], fill=(245, 35, 75, 255), outline=(255, 180, 200, 255), width=3)
    draw.ellipse([14, 14, 33, 33], fill=(255, 240, 245, 255))
    img.save("assets/enemy_tear.png")

# -------------------------------------------------------------
# 5. Primordial Organism Enemies (HD Sprites)
# -------------------------------------------------------------
def draw_enemy_amoeba():
    img = Image.new("RGBA", (88, 88), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([14, 62, 74, 82], fill=(4, 8, 16, 120))
    draw.ellipse([6, 6, 81, 79], fill=(175, 35, 225, 225), outline=(245, 130, 255, 255), width=4)
    draw.ellipse([24, 22, 63, 61], fill=(245, 45, 130, 255), outline=(140, 10, 75, 255), width=3)
    draw.ellipse([22, 28, 38, 44], fill=(255, 240, 40, 255))
    draw.ellipse([50, 28, 66, 44], fill=(255, 240, 40, 255))
    draw.ellipse([27, 32, 34, 39], fill=(220, 0, 0, 255))
    draw.ellipse([55, 32, 62, 39], fill=(220, 0, 0, 255))
    img.save("assets/enemy_fly.png")

def draw_enemy_trilobite():
    img = Image.new("RGBA", (104, 104), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([16, 76, 88, 98], fill=(4, 8, 16, 140))
    draw.ellipse([10, 14, 93, 89], fill=(68, 96, 124, 255), outline=(24, 42, 60, 255), width=5)
    draw.arc([16, 24, 87, 48], 0, 180, fill=(120, 160, 195, 255), width=4)
    draw.arc([16, 44, 87, 68], 0, 180, fill=(120, 160, 195, 255), width=4)
    draw.arc([16, 64, 87, 86], 0, 180, fill=(120, 160, 195, 255), width=4)
    draw.line([30, 20, 16, 2], fill=(0, 255, 220, 255), width=4)
    draw.line([74, 20, 88, 2], fill=(0, 255, 220, 255), width=4)
    draw.ellipse([28, 30, 40, 42], fill=(0, 255, 230, 255))
    draw.ellipse([64, 30, 76, 42], fill=(0, 255, 230, 255))
    img.save("assets/enemy_gusha.png")

def draw_boss_nautiloid():
    img = Image.new("RGBA", (220, 220), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([24, 160, 196, 210], fill=(4, 8, 16, 160))
    draw.ellipse([20, 16, 199, 195], fill=(48, 72, 102, 255), outline=(16, 30, 50, 255), width=7)
    draw.arc([36, 32, 183, 179], 30, 210, fill=(100, 150, 200, 255), width=6)
    draw.arc([54, 50, 165, 161], 30, 210, fill=(100, 150, 200, 255), width=6)
    draw.ellipse([64, 68, 155, 159], fill=(225, 45, 110, 255), outline=(255, 140, 180, 255), width=5)
    draw.ellipse([78, 82, 141, 145], fill=(255, 245, 220, 255), outline=(40, 10, 20, 255), width=4)
    draw.ellipse([92, 96, 127, 131], fill=(250, 20, 50, 255))
    draw.ellipse([102, 104, 117, 123], fill=(10, 0, 0, 255))
    draw.ellipse([96, 94, 106, 104], fill=(255, 255, 255, 255))
    tentacles = [
        [(54, 166), (30, 204), (62, 196)],
        [(88, 176), (82, 216), (106, 200)],
        [(132, 176), (138, 216), (114, 200)],
        [(166, 166), (190, 204), (158, 196)]
    ]
    for pts in tentacles:
        draw.polygon(pts, fill=(195, 40, 100, 255), outline=(115, 12, 55, 255))
    img.save("assets/boss.png")

# -------------------------------------------------------------
# 6. Obstacles & Pickups (128x128 / 64x64 px)
# -------------------------------------------------------------
def draw_rock():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([20, 88, 108, 120], fill=(4, 8, 16, 140))
    points = [(28, 96), (16, 56), (36, 20), (88, 12), (112, 40), (116, 88), (88, 112), (52, 116)]
    draw.polygon(points, fill=(54, 78, 98, 255), outline=(20, 36, 48, 255), width=5)
    draw.polygon([(36, 20), (88, 12), (112, 40), (76, 56), (48, 44)], fill=(90, 125, 150, 255))
    draw.polygon([(28, 96), (88, 112), (52, 116), (64, 84)], fill=(32, 48, 64, 255))
    draw.line([48, 36, 76, 72], fill=(0, 245, 220, 255), width=3)
    draw.line([76, 72, 44, 96], fill=(0, 245, 220, 255), width=2)
    img.save("assets/rock.png")

def draw_trapdoor():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([8, 8, 119, 119], fill=(6, 12, 24, 255), outline=(0, 220, 255, 255), width=6)
    for i in range(5):
        draw.arc([18 + i*8, 18 + i*8, 109 - i*8, 109 - i*8], i*72, i*72 + 160, fill=(0, 245, 255, 220), width=3)
    img.save("assets/trapdoor.png")

def draw_pickups():
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([18, 6, 45, 57], fill=(0, 245, 195, 230), outline=(210, 255, 245, 255), width=3)
    draw.line([20, 18, 43, 26], fill=(255, 255, 255, 255), width=3)
    draw.line([20, 32, 43, 40], fill=(255, 255, 255, 255), width=3)
    draw.line([22, 44, 41, 36], fill=(255, 255, 255, 255), width=3)
    img.save("assets/pickup_coin.png")
    
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([8, 12, 34, 38], fill=(255, 45, 95, 255))
    draw.ellipse([28, 12, 54, 38], fill=(255, 45, 95, 255))
    draw.polygon([(8, 28), (54, 28), (30, 54)], fill=(255, 45, 95, 255))
    draw.arc([8, 12, 34, 38], 180, 360, fill=(130, 10, 45, 255), width=3)
    draw.arc([28, 12, 54, 38], 180, 360, fill=(130, 10, 45, 255), width=3)
    draw.line([8, 26, 30, 54], fill=(130, 10, 45, 255), width=3)
    draw.line([54, 26, 30, 54], fill=(130, 10, 45, 255), width=3)
    draw.ellipse([14, 18, 22, 26], fill=(255, 190, 220, 255))
    img.save("assets/pickup_heart.png")

    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([8, 12, 34, 38], fill=(255, 45, 95, 255))
    draw.polygon([(8, 28), (30, 28), (30, 54)], fill=(255, 45, 95, 255))
    draw.arc([8, 12, 34, 38], 180, 360, fill=(130, 10, 45, 255), width=3)
    draw.arc([28, 12, 54, 38], 180, 360, fill=(60, 60, 80, 255), width=3)
    draw.line([8, 26, 30, 54], fill=(130, 10, 45, 255), width=3)
    draw.line([54, 26, 30, 54], fill=(60, 60, 80, 255), width=3)
    draw.line([30, 12, 30, 54], fill=(130, 10, 45, 255), width=2)
    img.save("assets/pickup_heart_half.png")

    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.arc([8, 12, 34, 38], 180, 360, fill=(50, 60, 80, 255), width=3)
    draw.arc([28, 12, 54, 38], 180, 360, fill=(50, 60, 80, 255), width=3)
    draw.line([8, 26, 30, 54], fill=(50, 60, 80, 255), width=3)
    draw.line([54, 26, 30, 54], fill=(50, 60, 80, 255), width=3)
    img.save("assets/pickup_heart_empty.png")

    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([12, 12, 34, 34], fill=None, outline=(255, 210, 40, 255), width=4)
    draw.line([32, 24, 52, 24], fill=(255, 210, 40, 255), width=4)
    draw.line([44, 24, 44, 36], fill=(255, 210, 40, 255), width=3)
    draw.line([50, 24, 50, 36], fill=(255, 210, 40, 255), width=3)
    img.save("assets/pickup_key.png")

    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([12, 16, 50, 54], fill=(195, 75, 22, 255), outline=(95, 28, 6, 255), width=3)
    draw.ellipse([16, 24, 26, 34], fill=(255, 150, 45, 255))
    draw.ellipse([36, 32, 46, 42], fill=(255, 150, 45, 255))
    draw.line([32, 16, 32, 4], fill=(0, 245, 190, 255), width=4)
    img.save("assets/pickup_bomb.png")

def draw_pedestal():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([12, 100, 115, 124], fill=(4, 8, 16, 140))
    draw.rectangle([24, 68, 103, 84], fill=(48, 72, 98, 255), outline=(22, 38, 60, 255), width=3)
    draw.rectangle([36, 84, 91, 112], fill=(32, 50, 72, 255), outline=(16, 28, 45, 255), width=3)
    draw.rectangle([16, 112, 111, 126], fill=(62, 88, 120, 255), outline=(28, 44, 66, 255), width=3)
    draw.line([32, 76, 95, 76], fill=(0, 255, 220, 255), width=3)
    img.save("assets/pedestal.png")

def draw_items():
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([16, 16, 46, 46], fill=(0, 230, 255, 255), outline=(200, 255, 255, 255), width=3)
    draw.arc([8, 8, 54, 54], 45, 225, fill=(0, 150, 250, 255), width=3)
    img.save("assets/item_onion.png")

    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([8, 16, 54, 46], fill=(245, 250, 255, 255), outline=(30, 40, 80, 255), width=3)
    draw.ellipse([18, 22, 32, 36], fill=(0, 220, 255, 255))
    draw.ellipse([34, 22, 48, 36], fill=(0, 220, 255, 255))
    img.save("assets/item_eye.png")

    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle([20, 12, 42, 40], fill=(235, 45, 85, 255), outline=(130, 10, 35, 255), width=3)
    draw.line([32, 40, 32, 56], fill=(210, 210, 230, 255), width=3)
    img.save("assets/item_hormones.png")

    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([12, 20, 36, 44], fill=(255, 150, 0, 255), outline=(150, 65, 0, 255), width=3)
    draw.ellipse([28, 20, 52, 44], fill=(255, 195, 45, 255), outline=(190, 95, 0, 255), width=3)
    img.save("assets/item_cells.png")

def draw_light():
    img = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for r in range(1, 256):
        decay = (1.0 - (r / 256.0)) ** 2.2
        alpha = int(255 * decay)
        draw.ellipse([256 - r, 256 - r, 256 + r - 1, 256 + r - 1], fill=(200, 245, 255, int(alpha * 0.45)))
    img.save("assets/light.png")

if __name__ == "__main__":
    create_directory()
    draw_fullscreen_background("room_bg_normal.png", "normal")
    draw_fullscreen_background("room_bg_boss.png", "boss")
    draw_fullscreen_background("room_bg_treasure.png", "treasure")
    draw_fullscreen_background("room_bg_shop.png", "shop")
    draw_wall()
    draw_door()
    draw_door_locked()
    draw_player()
    draw_tear()
    draw_enemy_tear()
    draw_enemy_amoeba()
    draw_enemy_trilobite()
    draw_boss_nautiloid()
    draw_rock()
    draw_trapdoor()
    draw_pickups()
    draw_pedestal()
    draw_items()
    draw_light()
    print("All 1920x1080 Fullscreen backgrounds and assets created successfully!")
