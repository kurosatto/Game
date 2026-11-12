# generate_ink_hearts.py
# Health pips in the sepia ink sketch style (replaces the glossy pink cells
# from generate_biology_art.py): a cell drawn in brown ink over a brick-red
# wash, hatched on its shaded side, with a nucleus. Half = left half washed,
# empty = a dashed tan outline for the dark HUD bar. Drawn at 4x, then scaled down.
#   python3 generate_ink_hearts.py
from PIL import Image, ImageDraw
import math

S = 256
INK = (69, 41, 23, 255)
WASH = (176, 58, 46, 255)
WASH_DARK = (128, 36, 30, 255)
PAPER = (240, 226, 196, 255)
C = S / 2
R = S * 0.40

def base(fill_left, fill_right):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # paper disc behind so it reads on any background (an empty pip is
    # only an outline: it sits on the dark HUD bar)
    if fill_left or fill_right:
        d.ellipse([C - R, C - R, C + R, C + R], fill=PAPER)
        if not fill_right:
            d.rectangle([C, 0, S, S], fill=(0, 0, 0, 0))
    wash = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wash)
    wd.ellipse([C - R, C - R, C + R, C + R], fill=WASH)
    # shaded lower right: darker wash crescent
    wd.ellipse([C - R * 0.75, C - R * 0.75, C + R * 1.05, C + R * 1.05], fill=WASH_DARK)
    wd.ellipse([C - R * 1.0, C - R * 1.0, C + R * 0.8, C + R * 0.8], fill=WASH)
    mask = Image.new("L", (S, S), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([C - R, C - R, C + R, C + R], fill=255)
    if not fill_left:
        md.rectangle([0, 0, C, S], fill=0)
    if not fill_right:
        md.rectangle([C, 0, S, S], fill=0)
    img.paste(wash, (0, 0), mask)
    d = ImageDraw.Draw(img)
    filled = fill_left or fill_right
    if filled:
        # pen hatching on the shaded side, clipped to the washed part
        hatch = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        hd = ImageDraw.Draw(hatch)
        for k in range(-S, S, 14):
            hd.line([(k, S), (k + S, 0)], fill=(69, 41, 23, 150), width=4)
        hm = Image.new("L", (S, S), 0)
        hmd = ImageDraw.Draw(hm)
        hmd.ellipse([C - R * 0.2, C - R * 0.2, C + R * 1.4, C + R * 1.4], fill=255)
        hmd.ellipse([C - R * 1.3, C - R * 1.3, C + R * 0.55, C + R * 0.55], fill=0)
        hm = Image.composite(hm, Image.new("L", (S, S), 0), mask)
        img.paste(hatch, (0, 0), Image.composite(hatch.split()[3], Image.new("L", (S, S), 0), hm))
        d = ImageDraw.Draw(img)
    # outline: a slightly wobbly double pen stroke
    for wob, w in ((0.0, 11), (2.5, 4)):
        pts = []
        for i in range(73):
            a = TAU * i / 72
            rr = R + math.sin(a * 3 + wob) * 2.5 + wob
            pts.append((C + math.cos(a) * rr, C + math.sin(a) * rr))
        if fill_left and fill_right:
            d.line(pts, fill=INK, width=w, joint="curve")
        elif filled:
            # half: inked round the washed left, dashed round the empty right
            for i in range(72):
                left = math.cos(TAU * (i + 0.5) / 72) < 0
                if left:
                    d.line(pts[i:i + 2], fill=INK, width=w)
                elif i % 2 == 0:
                    d.line(pts[i:i + 2], fill=(205, 180, 140, 210), width=w)
        else:
            # empty: dashed outline
            for i in range(0, 72, 2):
                d.line(pts[i:i + 2], fill=(205, 180, 140, 210), width=w)
    if fill_left and not fill_right:
        d.line([(C, C - R), (C, C + R)], fill=INK, width=6)
    if filled:
        # nucleus (on the washed side for a half pip)
        nx = C - R * 0.12 if fill_left else C + R * 0.25
        d.ellipse([nx - R * 0.26, C - R * 0.30, nx + R * 0.22, C + R * 0.16], fill=(232, 205, 170, 255), outline=INK, width=7)
        d.ellipse([nx - R * 0.10, C - R * 0.14, nx + R * 0.04, C + R * 0.0], fill=INK)
    return img.resize((64, 64), Image.LANCZOS)

TAU = math.tau
base(True, True).save("assets/pickup_heart.png")
base(True, False).save("assets/pickup_heart_half.png")
base(False, False).save("assets/pickup_heart_empty.png")
print("ink hearts saved")
