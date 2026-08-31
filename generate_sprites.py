import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter

def create_directory():
    os.makedirs("assets", exist_ok=True)

# -------------------------------------------------------------
# 1. 1080p HD Environment Tiles (128x128 px)
# -------------------------------------------------------------
def draw_floor():
    # 128x128 Deep primordial aquatic ooze with layered cellular textures
    img = Image.new("RGBA", (128, 128), (18, 30, 48, 255))
    draw = ImageDraw.Draw(img)
    
    # Texture noise & organic wave
    for x in range(128):
        for y in range(128):
            wave = math.sin(x * 0.08) * math.cos(y * 0.08) * 8
            noise = random.randint(-5, 5)
            r, g, b, a = img.getpixel((x, y))
            r = max(0, min(255, int(r + wave + noise * 0.5)))
            g = max(0, min(255, int(g + wave * 1.5 + noise)))
            b = max(0, min(255, int(b + wave * 2.2 + noise)))
            img.putpixel((x, y), (r, g, b, 255))
            
    # Organic cell border divisions
    draw.rectangle([0, 0, 127, 127], outline=(10, 18, 32, 255), width=3)
    # Bioluminescent micro-specks
    for _ in range(16):
        bx = random.randint(8, 119)
        by = random.randint(8, 119)
        size = random.randint(2, 4)
        draw.ellipse([bx, by, bx+size, by+size], fill=(0, 230, 255, 200))
        
    # Faint inner membrane lines
    draw.arc([16, 16, 111, 111], 0, 180, fill=(30, 70, 105, 140), width=2)
    draw.arc([32, 32, 95, 95], 180, 360, fill=(20, 60, 95, 120), width=2)
    img.save("assets/floor.png")

def draw_wall():
    # 128x128 Calcified primordial reef / fossil sediment wall
    img = Image.new("RGBA", (128, 128), (22, 28, 40, 255))
    draw = ImageDraw.Draw(img)
    
    for x in range(128):
        for y in range(128):
            noise = random.randint(-7, 7)
            r, g, b, a = img.getpixel((x, y))
            img.putpixel((x, y), (max(0, min(255, r + noise)), max(0, min(255, g + noise)), max(0, min(255, b + noise * 2)), 255))
            
    # Sedimentary horizontal strata
    draw.line([0, 0, 127, 0], fill=(8, 10, 16, 255), width=4)
    draw.line([0, 36, 127, 36], fill=(12, 16, 24, 255), width=3)
    draw.line([0, 76, 127, 76], fill=(12, 16, 24, 255), width=3)
    draw.line([0, 127, 127, 127], fill=(8, 10, 16, 255), width=4)
    
    # Fossilized organic segments
    draw.line([44, 0, 44, 36], fill=(10, 12, 18, 255), width=3)
    draw.line([92, 36, 92, 76], fill=(10, 12, 18, 255), width=3)
    draw.line([52, 76, 52, 127], fill=(10, 12, 18, 255), width=3)
    
    # Bioluminescent moss highlights
    draw.line([4, 4, 123, 4], fill=(40, 140, 160, 255), width=2)
    draw.line([4, 40, 123, 40], fill=(35, 120, 140, 255), width=2)
    draw.line([4, 80, 123, 80], fill=(30, 100, 120, 255), width=2)
    
    # Trapped micro-fossil imprint
    draw.ellipse([64, 48, 76, 60], fill=(50, 75, 100, 255), outline=(20, 35, 55, 255), width=2)
    img.save("assets/wall.png")

# -------------------------------------------------------------
# 2. Doors & Gateways (128x128 px)
# -------------------------------------------------------------
def draw_door():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Outer sphincter valve
    draw.ellipse([12, 12, 115, 115], fill=(28, 52, 78, 255), outline=(12, 24, 42, 255), width=6)
    draw.ellipse([26, 26, 101, 101], fill=(18, 36, 58, 255), outline=(0, 180, 220, 255), width=4)
    # Open dark passage
    draw.ellipse([38, 38, 89, 89], fill=(4, 8, 16, 255))
    # Glowing pulsing ring
    draw.arc([34, 34, 93, 93], 0, 360, fill=(0, 240, 255, 240), width=3)
    img.save("assets/door.png")

def draw_door_locked():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([12, 12, 115, 115], fill=(40, 44, 56, 255), outline=(16, 20, 30, 255), width=6)
    draw.ellipse([26, 26, 101, 101], fill=(26, 30, 42, 255))
    # Enzymatic DNA Helix Lock
    draw.ellipse([42, 42, 85, 85], fill=(255, 195, 30, 255), outline=(180, 120, 0, 255), width=4)
    draw.line([50, 54, 77, 72], fill=(50, 30, 5, 255), width=4)
    draw.line([50, 72, 77, 54], fill=(50, 30, 5, 255), width=4)
    img.save("assets/door_locked.png")

# -------------------------------------------------------------
# 3. Player: Primordial Microbe (128x128 px)
# -------------------------------------------------------------
def draw_player():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Outer glowing cytoplasmic membrane
    draw.ellipse([16, 16, 111, 111], fill=(30, 170, 230, 210), outline=(120, 245, 255, 255), width=5)
    # Membrane inner glow
    draw.ellipse([24, 24, 103, 103], fill=(20, 140, 210, 230))
    
    # Floating organelles
    draw.ellipse([32, 40, 52, 64], fill=(255, 130, 180, 200), outline=(200, 60, 120, 200), width=2)
    draw.ellipse([76, 72, 96, 92], fill=(120, 255, 160, 200), outline=(40, 180, 80, 200), width=2)
    
    # Core Glowing Nucleus
    draw.ellipse([44, 44, 84, 84], fill=(255, 240, 100, 255), outline=(240, 160, 0, 255), width=3)
    draw.ellipse([52, 52, 76, 76], fill=(255, 255, 220, 255))
    
    # Big expressive eyes
    draw.ellipse([40, 36, 56, 56], fill=(10, 20, 40, 255))
    draw.ellipse([72, 36, 88, 56], fill=(10, 20, 40, 255))
    # Eye highlights
    draw.ellipse([44, 40, 50, 46], fill=(255, 255, 255, 255))
    draw.ellipse([76, 40, 82, 46], fill=(255, 255, 255, 255))
    
    # Smile
    draw.arc([54, 56, 74, 72], 0, 180, fill=(10, 20, 40, 255), width=3)
    
    # Flagella hairs
    draw.arc([4, 52, 20, 76], 90, 270, fill=(60, 200, 255, 200), width=4)
    draw.arc([108, 52, 124, 76], 270, 90, fill=(60, 200, 255, 200), width=4)
    
    img.save("assets/player.png")

# -------------------------------------------------------------
# 4. Projectiles (40x40 px)
# -------------------------------------------------------------
def draw_tear():
    img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([4, 4, 35, 35], fill=(0, 225, 255, 255), outline=(200, 255, 255, 255), width=3)
    draw.ellipse([10, 10, 29, 29], fill=(255, 255, 255, 255))
    img.save("assets/tear.png")

def draw_enemy_tear():
    img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([4, 4, 35, 35], fill=(235, 40, 60, 255), outline=(255, 160, 180, 255), width=3)
    draw.ellipse([12, 12, 27, 27], fill=(255, 230, 240, 255))
    img.save("assets/enemy_tear.png")

# -------------------------------------------------------------
# 5. Enemies (HD Sprites)
# -------------------------------------------------------------
def draw_enemy_amoeba():
    # 80x80 Amoeba Swarmer
    img = Image.new("RGBA", (80, 80), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([6, 8, 73, 71], fill=(165, 40, 210, 225), outline=(230, 110, 255, 255), width=4)
    draw.ellipse([22, 22, 57, 57], fill=(235, 50, 120, 255), outline=(130, 10, 70, 255), width=2)
    # Glowing Eyes
    draw.ellipse([20, 26, 34, 40], fill=(255, 235, 50, 255))
    draw.ellipse([46, 26, 60, 40], fill=(255, 235, 50, 255))
    draw.ellipse([25, 30, 31, 36], fill=(210, 0, 0, 255))
    draw.ellipse([51, 30, 57, 36], fill=(210, 0, 0, 255))
    img.save("assets/enemy_fly.png")

def draw_enemy_trilobite():
    # 96x96 Proto-Trilobite Crawler
    img = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([12, 16, 83, 79], fill=(65, 90, 115, 255), outline=(25, 40, 55, 255), width=4)
    # Armor ridges
    draw.arc([16, 24, 79, 44], 0, 180, fill=(110, 145, 175, 255), width=3)
    draw.arc([16, 40, 79, 60], 0, 180, fill=(110, 145, 175, 255), width=3)
    draw.arc([16, 56, 79, 76], 0, 180, fill=(110, 145, 175, 255), width=3)
    
    # Antennae
    draw.line([28, 20, 16, 4], fill=(0, 240, 200, 255), width=3)
    draw.line([67, 20, 79, 4], fill=(0, 240, 200, 255), width=3)
    
    # Multi-ocelli eyes
    draw.ellipse([28, 28, 38, 38], fill=(0, 255, 220, 255))
    draw.ellipse([57, 28, 67, 38], fill=(0, 255, 220, 255))
    img.save("assets/enemy_gusha.png")

def draw_boss_nautiloid():
    # 200x200 Ancient Apex Nautiloid
    img = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Shell
    draw.ellipse([20, 20, 179, 179], fill=(48, 70, 96, 255), outline=(16, 32, 52, 255), width=6)
    draw.arc([32, 32, 167, 167], 30, 210, fill=(95, 140, 185, 255), width=5)
    draw.arc([48, 48, 151, 151], 30, 210, fill=(95, 140, 185, 255), width=5)
    
    # Core
    draw.ellipse([60, 64, 139, 143], fill=(215, 50, 105, 255), outline=(255, 130, 170, 255), width=4)
    
    # Eye
    draw.ellipse([72, 76, 127, 131], fill=(255, 245, 220, 255), outline=(40, 10, 20, 255), width=3)
    draw.ellipse([86, 88, 113, 119], fill=(245, 20, 45, 255))
    draw.ellipse([94, 94, 105, 113], fill=(10, 0, 0, 255))
    draw.ellipse([90, 86, 97, 95], fill=(255, 255, 255, 255))
    
    # Tentacles
    tentacle_pts = [
        [(50, 150), (30, 184), (56, 176)],
        [(80, 160), (76, 194), (96, 180)],
        [(120, 160), (124, 194), (104, 180)],
        [(150, 150), (170, 184), (144, 176)]
    ]
    for pts in tentacle_pts:
        draw.polygon(pts, fill=(185, 45, 95, 255), outline=(105, 15, 50, 255))
        
    img.save("assets/boss.png")

# -------------------------------------------------------------
# 6. Obstacles & Pickups (HD Sprites)
# -------------------------------------------------------------
def draw_rock():
    # 128x128 Coral Fossil Rock
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    points = [(28, 96), (16, 56), (36, 20), (88, 12), (112, 40), (116, 88), (88, 112), (52, 116)]
    draw.polygon(points, fill=(52, 74, 92, 255), outline=(22, 38, 50, 255), width=5)
    draw.polygon([(36, 20), (88, 12), (112, 40), (76, 56), (48, 44)], fill=(85, 118, 140, 255))
    draw.polygon([(28, 96), (88, 112), (52, 116), (64, 84)], fill=(32, 48, 64, 255))
    draw.line([48, 36, 76, 72], fill=(0, 230, 210, 255), width=3)
    draw.line([76, 72, 44, 96], fill=(0, 230, 210, 255), width=2)
    img.save("assets/rock.png")

def draw_trapdoor():
    # 128x128 Swirling Abyss Vortex
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([8, 8, 119, 119], fill=(6, 12, 24, 255), outline=(0, 210, 250, 255), width=5)
    for i in range(5):
        draw.arc([18 + i*8, 18 + i*8, 109 - i*8, 109 - i*8], i*72, i*72 + 160, fill=(0, 240, 255, 210), width=3)
    img.save("assets/trapdoor.png")

def draw_pickups():
    # 1. DNA Biomass Helix (64x64)
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([20, 8, 43, 55], fill=(0, 245, 190, 225), outline=(210, 255, 245, 255), width=3)
    draw.line([22, 20, 41, 28], fill=(255, 255, 255, 255), width=3)
    draw.line([22, 34, 41, 42], fill=(255, 255, 255, 255), width=3)
    draw.line([24, 46, 39, 38], fill=(255, 255, 255, 255), width=3)
    img.save("assets/pickup_coin.png")
    
    # 2. Vitality Heart (64x64)
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

    # 3. Half Heart (64x64)
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

    # 4. Empty Heart (64x64)
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.arc([8, 12, 34, 38], 180, 360, fill=(50, 60, 80, 255), width=3)
    draw.arc([28, 12, 54, 38], 180, 360, fill=(50, 60, 80, 255), width=3)
    draw.line([8, 26, 30, 54], fill=(50, 60, 80, 255), width=3)
    draw.line([54, 26, 30, 54], fill=(50, 60, 80, 255), width=3)
    img.save("assets/pickup_heart_empty.png")

    # 5. Enzymatic Key (64x64)
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([12, 12, 34, 34], fill=None, outline=(255, 205, 35, 255), width=4)
    draw.line([32, 24, 52, 24], fill=(255, 205, 35, 255), width=4)
    draw.line([44, 24, 44, 36], fill=(255, 205, 35, 255), width=3)
    draw.line([50, 24, 50, 36], fill=(255, 205, 35, 255), width=3)
    img.save("assets/pickup_key.png")

    # 6. Spore Bomb (64x64)
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([12, 16, 50, 54], fill=(190, 75, 22, 255), outline=(95, 28, 6, 255), width=3)
    draw.ellipse([16, 24, 26, 34], fill=(255, 150, 45, 255))
    draw.ellipse([36, 32, 46, 42], fill=(255, 150, 45, 255))
    draw.line([32, 16, 32, 4], fill=(0, 245, 190, 255), width=4)
    img.save("assets/pickup_bomb.png")

def draw_pedestal():
    # 128x128 Gene Incubator Pedestal
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([12, 100, 115, 124], fill=(10, 15, 25, 120))
    draw.rectangle([24, 68, 103, 84], fill=(48, 70, 96, 255), outline=(22, 38, 60, 255), width=3)
    draw.rectangle([36, 84, 91, 112], fill=(32, 48, 70, 255), outline=(16, 28, 45, 255), width=3)
    draw.rectangle([16, 112, 111, 126], fill=(60, 85, 118, 255), outline=(28, 44, 66, 255), width=3)
    draw.line([32, 76, 95, 76], fill=(0, 245, 210, 255), width=3)
    img.save("assets/pedestal.png")

def draw_items():
    # 64x64 Item Icons
    # 1. Cytoplasmic Surge
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([16, 16, 46, 46], fill=(0, 225, 255, 255), outline=(190, 255, 255, 255), width=3)
    draw.arc([8, 8, 54, 54], 45, 225, fill=(0, 150, 250, 255), width=3)
    img.save("assets/item_onion.png")

    # 2. Compound Ocelli
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([8, 16, 54, 46], fill=(245, 250, 255, 255), outline=(30, 40, 80, 255), width=3)
    draw.ellipse([18, 22, 32, 36], fill=(0, 210, 250, 255))
    draw.ellipse([34, 22, 48, 36], fill=(0, 210, 250, 255))
    img.save("assets/item_eye.png")

    # 3. Adrenal Mutagen
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle([20, 12, 42, 40], fill=(230, 45, 85, 255), outline=(130, 10, 35, 255), width=3)
    draw.line([32, 40, 32, 56], fill=(210, 210, 230, 255), width=3)
    img.save("assets/item_hormones.png")

    # 4. Cellular Duplication
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([12, 20, 36, 44], fill=(255, 145, 0, 255), outline=(150, 65, 0, 255), width=3)
    draw.ellipse([28, 20, 52, 44], fill=(255, 190, 45, 255), outline=(190, 95, 0, 255), width=3)
    img.save("assets/item_cells.png")

def draw_light():
    img = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for r in range(1, 256):
        alpha = int(255 * (1.0 - (r / 256.0) ** 1.5))
        draw.ellipse([256 - r, 256 - r, 256 + r - 1, 256 + r - 1], fill=(180, 240, 255, int(alpha * 0.22)))
    img.save("assets/light.png")

if __name__ == "__main__":
    create_directory()
    draw_floor()
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
    print("All 1080p High-Resolution assets generated successfully!")
