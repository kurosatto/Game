"""Projectile art for ranged player weapons (data/Lineages.gd WEAPONS).

Each is a 48px PNG pointing right (+x); Tear.gd turns pointed kinds to face
their flight and slowly spins round ones. Tear.gd also sets a matching glow.

Run from the project root:  python generate_projectile_art.py
"""
import hashlib
import math
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = "assets/projectiles"
S = 48
C = S / 2


def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def glow(img, color, radius=3):
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
    alpha = img.split()[3].filter(ImageFilter.GaussianBlur(radius))
    halo.paste(Image.new("RGBA", img.size, color), (0, 0), alpha)
    return Image.alpha_composite(halo, img)


def vesicle():
    # Lysosome: a lipid bilayer (two thin rings) around acidic enzyme granules
    img = canvas(); d = ImageDraw.Draw(img)
    d.ellipse([9, 9, 39, 39], fill=(255, 120, 185, 150))
    d.ellipse([9, 9, 39, 39], outline=(255, 220, 240, 255), width=2)
    d.ellipse([12, 12, 36, 36], outline=(200, 70, 150, 255), width=1)
    for x, y in [(19, 20), (27, 18), (24, 27), (30, 28), (18, 29)]:
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(130, 20, 90, 255))
    d.ellipse([15, 14, 20, 18], fill=(255, 255, 255, 200))
    return glow(img, (255, 90, 170, 140))


def jet():
    # A fast squirt of water: bright head, thinning streak behind
    img = canvas(); d = ImageDraw.Draw(img)
    d.polygon([(4, 24), (30, 19), (30, 29)], fill=(150, 210, 255, 140))
    d.ellipse([26, 17, 42, 31], fill=(190, 235, 255, 255))
    d.ellipse([31, 20, 36, 24], fill=(255, 255, 255, 255))
    return glow(img, (110, 190, 255, 150))


def spit():
    # Venom droplet with a short tail
    img = canvas(); d = ImageDraw.Draw(img)
    d.polygon([(8, 24), (28, 18), (28, 30)], fill=(190, 230, 60, 150))
    d.ellipse([22, 15, 40, 33], fill=(205, 245, 70, 255), outline=(110, 150, 20, 255))
    d.ellipse([28, 19, 33, 23], fill=(255, 255, 220, 230))
    return glow(img, (180, 255, 40, 140))


def harpoon():
    # Cone snail radular tooth: hollow shaft with a barbed tip
    img = canvas(); d = ImageDraw.Draw(img)
    d.line([(4, 24), (36, 24)], fill=(245, 230, 200, 255), width=3)
    d.polygon([(46, 24), (34, 19), (36, 24), (34, 29)], fill=(255, 245, 225, 255))
    d.line([(30, 24), (26, 19)], fill=(225, 205, 170, 255), width=2)
    d.line([(4, 24), (8, 24)], fill=(170, 90, 200, 255), width=3)
    return glow(img, (255, 230, 180, 130), 2)


def slime():
    # Hagfish slime / sea cucumber tubules: pale sticky blob with strands
    img = canvas(); d = ImageDraw.Draw(img)
    d.ellipse([10, 11, 38, 37], fill=(215, 245, 220, 190))
    for a in range(0, 360, 60):
        r = math.radians(a)
        d.line([(C, C), (C + math.cos(r) * 19, C + math.sin(r) * 19)], fill=(235, 255, 240, 200), width=2)
    d.ellipse([17, 15, 23, 20], fill=(255, 255, 255, 230))
    return glow(img, (190, 255, 210, 120))


def silk():
    # A thrown silk line ending in a sticky glob
    img = canvas(); d = ImageDraw.Draw(img)
    d.line([(3, 26), (16, 22), (28, 25), (36, 24)], fill=(245, 245, 255, 230), width=2)
    d.line([(6, 22), (20, 26), (34, 23)], fill=(220, 220, 240, 160), width=1)
    d.ellipse([32, 19, 42, 29], fill=(250, 250, 255, 255))
    return glow(img, (230, 230, 255, 130), 2)


def spray():
    # Hot defensive spray (bombardier beetle quinones, millipede secretions)
    img = canvas(); d = ImageDraw.Draw(img)
    for x, y, r, a in [(16, 24, 7, 120), (24, 20, 8, 170), (25, 29, 7, 160), (33, 24, 9, 230)]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 170, 50, a))
    d.ellipse([31, 21, 37, 26], fill=(255, 240, 170, 255))
    return glow(img, (255, 140, 30, 150))


IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"
path="res://.godot/imported/{name}-{md5}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{res}"
dest_files=["res://.godot/imported/{name}-{md5}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fn in [vesicle, jet, spit, harpoon, slime, silk, spray]:
        name = fn.__name__ + ".png"
        path = os.path.join(OUT, name)
        fn().save(path)
        res = "res://" + path.replace(os.sep, "/")
        if not os.path.exists(path + ".import"):
            with open(path + ".import", "w", newline="\n") as f:
                f.write(IMPORT.format(name=name, md5=hashlib.md5(res.encode()).hexdigest(), res=res))
        print("wrote", path)
