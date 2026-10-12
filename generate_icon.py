# generate_icon.py
# Draws the app icon: an ancestral collared cell (choanoflagellate-like) glowing
# in a deep tidepool. Outputs the project icon and Android adaptive icon layers.
import math
from PIL import Image, ImageDraw, ImageFilter

SS = 4  # supersampling for smooth edges


def background(size):
    img = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(img)
    cx, cy = size / 2, size / 2
    max_r = math.hypot(cx, cy)
    for r in range(int(max_r), 0, -2):
        t = r / max_r
        col = (int(4 + 10 * (1 - t)), int(30 + 70 * (1 - t)), int(52 + 80 * (1 - t)), 255)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
    return img


def cell(size, scale=1.0):
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = s / 2, s * 0.58
    r = s * 0.2 * scale

    # Flagellum: a wavy line rising out of the collar
    pts = []
    for i in range(60):
        t = i / 59
        y = cy - r * 0.9 - t * s * 0.36 * scale
        x = cx + math.sin(t * math.pi * 2.6) * s * 0.05 * scale * (0.4 + t)
        pts.append((x, y))
    d.line(pts, fill=(170, 255, 235, 255), width=int(s * 0.018 * scale), joint="curve")

    # Collar of microvilli
    collar_w = r * 0.95
    for i in range(9):
        t = i / 8
        bx = cx - collar_w * 0.55 + t * collar_w * 1.1
        tx = cx - collar_w + t * collar_w * 2.0
        d.line([(bx, cy - r * 0.75), (tx, cy - r * 1.75)], fill=(120, 240, 220, 230), width=int(s * 0.012 * scale))

    # Cell body with membrane
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 200, 170, 255))
    inner = r * 0.86
    d.ellipse([cx - inner, cy - inner, cx + inner, cy + inner], fill=(40, 235, 200, 255))
    # Nucleus
    nr = r * 0.38
    nx, ny = cx - r * 0.12, cy + r * 0.1
    d.ellipse([nx - nr, ny - nr, nx + nr, ny + nr], fill=(20, 110, 150, 255))
    d.ellipse([nx - nr * 0.35, ny - nr * 0.35, nx + nr * 0.35, ny + nr * 0.35], fill=(90, 190, 255, 255))
    # Highlight
    hr = r * 0.22
    hx, hy = cx + r * 0.42, cy - r * 0.4
    d.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=(220, 255, 250, 200))

    img = img.resize((size, size), Image.LANCZOS)
    glow = img.filter(ImageFilter.GaussianBlur(size * 0.03))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(img)
    return out


def main():
    icon = background(512)
    icon.alpha_composite(cell(512))
    icon.save("icon.png")

    # Android adaptive layers: keep the cell inside the 66% safe zone
    background(432).save("assets/icon_background.png")
    cell(432, scale=0.72).save("assets/icon_foreground.png")
    # Legacy launcher icon
    icon.resize((192, 192), Image.LANCZOS).save("assets/icon_192.png")


if __name__ == "__main__":
    main()
