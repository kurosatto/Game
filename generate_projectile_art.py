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


K = 4  # drawn 4x bigger, then scaled down for smooth, soft edges
INK = (52, 26, 44, 255)  # the same plum-brown outline as the player art


def canvas():
    return Image.new("RGBA", (S * K, S * K), (0, 0, 0, 0))


def box(x0, y0, x1, y1):
    return [x0 * K, y0 * K, x1 * K, y1 * K]


def pts(*xy):
    return [(x * K, y * K) for x, y in xy]


def finish(img, color, radius=3):
    img = img.resize((S, S), Image.LANCZOS)
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
    alpha = img.split()[3].filter(ImageFilter.GaussianBlur(radius))
    halo.paste(Image.new("RGBA", img.size, color), (0, 0), alpha)
    return Image.alpha_composite(halo, img)


def bubble(d, x0, y0, x1, y1, fill, shine=True, ink=INK, w=1.6):
    # Outlined round blob with a glossy highlight, like the player's eyes
    d.ellipse(box(x0, y0, x1, y1), fill=fill, outline=ink, width=int(w * K))
    if shine:
        cw, ch = x1 - x0, y1 - y0
        d.ellipse(box(x0 + cw * 0.2, y0 + ch * 0.16, x0 + cw * 0.46, y0 + ch * 0.38), fill=(255, 255, 255, 235))
        d.ellipse(box(x0 + cw * 0.62, y0 + ch * 0.62, x0 + cw * 0.74, y0 + ch * 0.74), fill=(255, 255, 255, 170))


def vesicle():
    # Lysosome: a soft round bubble of membrane holding enzyme granules
    img = canvas(); d = ImageDraw.Draw(img)
    bubble(d, 10, 10, 38, 38, (255, 150, 200, 235), shine=False)
    d.ellipse(box(14, 14, 34, 34), outline=(235, 95, 165, 255), width=int(1.2 * K))
    for x, y, r in [(21, 26, 2.6), (28, 22, 2.2), (27, 30, 2.4), (32, 27, 1.8)]:
        d.ellipse(box(x - r, y - r, x + r, y + r), fill=(185, 50, 125, 255))
    d.ellipse(box(15, 14, 22, 20), fill=(255, 255, 255, 240))
    d.ellipse(box(29, 31, 32, 34), fill=(255, 255, 255, 170))
    return finish(img, (255, 110, 180, 120))


def jet():
    # A squirt of water: round droplet with soft wake rings behind
    img = canvas(); d = ImageDraw.Draw(img)
    for x, r, a in [(9, 3.2, 120), (16, 4.4, 170)]:
        d.ellipse(box(x - r, 24 - r, x + r, 24 + r), fill=(170, 225, 255, a))
    d.polygon(pts((14, 24), (31, 17.5), (31, 30.5)), fill=(170, 225, 255, 170))
    bubble(d, 24, 15, 42, 33, (190, 238, 255, 255))
    return finish(img, (110, 190, 255, 130))


def spit():
    # Venom droplet: a teardrop of green with a pointed tail
    img = canvas(); d = ImageDraw.Draw(img)
    d.polygon(pts((9, 24), (30, 16.5), (30, 31.5)), fill=INK)
    d.polygon(pts((11.5, 24), (30, 18.2), (30, 29.8)), fill=(200, 240, 80, 255))
    bubble(d, 22, 15, 40, 33, (205, 245, 85, 255))
    return finish(img, (180, 255, 60, 120))


def harpoon():
    # Cone snail radular tooth: a hollow, barbed little dart
    img = canvas(); d = ImageDraw.Draw(img)
    d.rounded_rectangle(box(5, 21.5, 36, 26.5), radius=2.5 * K, fill=(250, 238, 210, 255), outline=INK, width=int(1.4 * K))
    d.polygon(pts((45, 24), (33, 17), (35.5, 24), (33, 31)), fill=(255, 248, 230, 255), outline=INK, width=int(1.4 * K))
    d.line(pts((29, 22), (25, 17.5)), fill=INK, width=int(2.6 * K))
    d.line(pts((29, 22), (25, 17.5)), fill=(250, 238, 210, 255), width=int(1.2 * K))
    d.rounded_rectangle(box(4, 21.5, 10, 26.5), radius=2.5 * K, fill=(205, 120, 225, 255), outline=INK, width=int(1.4 * K))
    return finish(img, (255, 230, 180, 110), 2)


def slime():
    # Hagfish slime / sea cucumber tubules: a wobbly sticky glob with drips
    img = canvas(); d = ImageDraw.Draw(img)
    for a in range(0, 360, 72):
        r = math.radians(a + 20)
        x, y = C + math.cos(r) * 15, C + math.sin(r) * 15
        d.ellipse(box(x - 4.2, y - 4.2, x + 4.2, y + 4.2), fill=(215, 248, 225, 255), outline=INK, width=int(1.4 * K))
    bubble(d, 11, 11, 37, 37, (220, 250, 228, 245))
    return finish(img, (190, 255, 210, 110))


def silk():
    # A thrown silk line ending in a sticky, fluffy glob
    img = canvas(); d = ImageDraw.Draw(img)
    d.line(pts((3, 26), (12, 22), (21, 25.5), (31, 23.5)), fill=(240, 240, 255, 230), width=int(1.8 * K), joint="curve")
    d.line(pts((5, 22), (16, 26), (28, 22.5)), fill=(215, 215, 240, 170), width=int(1.1 * K), joint="curve")
    for x, y in [(33, 20.5), (38, 22), (35, 27.5), (39.5, 27)]:
        d.ellipse(box(x - 4, y - 4, x + 4, y + 4), fill=(250, 250, 255, 255), outline=INK, width=int(1.3 * K))
    d.ellipse(box(32, 19, 41, 28.5), fill=(250, 250, 255, 255))
    d.ellipse(box(33, 19.5, 36.5, 22.5), fill=(255, 255, 255, 255))
    return finish(img, (230, 230, 255, 110), 2)


def spray():
    # Hot defensive spray (bombardier beetle quinones): a puff of droplets
    img = canvas(); d = ImageDraw.Draw(img)
    for x, y, r, col in [(13, 25, 5, (255, 190, 90, 190)), (21, 20, 6, (255, 170, 60, 230)), (22, 30, 5.5, (255, 175, 70, 220))]:
        d.ellipse(box(x - r, y - r, x + r, y + r), fill=col, outline=INK, width=int(1.3 * K))
    bubble(d, 24, 15, 42, 33, (255, 205, 90, 255))
    return finish(img, (255, 140, 30, 130))


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
