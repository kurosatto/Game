# generate_icon.py
# Draws the app icon: the starting collared cell (choanoflagellate-like), inked
# like the in-game forms, with a faint tree of life branching above it. Outputs the project icon and Android adaptive icon layers.
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


INK = (14, 26, 23, 255)
RIM = (90, 235, 245, 255)


def branches(size, scale=1.0):
    """A faint tree of life fanning up and out from the cell."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    w = max(2, int(s * 0.016 * scale))

    def grow(x, y, ang, length, depth):
        if depth == 0:
            d.ellipse([x - w * 1.3, y - w * 1.3, x + w * 1.3, y + w * 1.3], fill=(255, 204, 102, 170))
            return
        x2 = x + math.cos(ang) * length
        y2 = y + math.sin(ang) * length
        d.line([(x, y), (x2, y2)], fill=(120, 225, 205, 110), width=w)
        for da in (-0.62, 0.62):
            grow(x2, y2, ang + da, length * 0.8, depth - 1)

    cx, cy = s / 2, s * (0.5 - 0.17 * scale)
    grow(cx, cy, -math.pi / 2, s * 0.07 * scale, 4)
    return img.resize((size, size), Image.LANCZOS)


def cell(size, scale=1.0):
    """The starting cell drawn like the in-game forms: ink outline, cyan rim."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = s / 2, s * 0.53
    r = s * 0.16 * scale
    ol = s * 0.016 * scale

    def outlined_line(pts, col, width, rim=True):
        if rim:
            d.line(pts, fill=RIM, width=int(width + ol * 3.2), joint="curve")
        d.line(pts, fill=INK, width=int(width + ol * 1.6), joint="curve")
        d.line(pts, fill=col, width=int(width), joint="curve")

    # Flagellum trailing below in a lazy S
    pts = []
    for i in range(60):
        t = i / 59
        y = cy + r * 0.95 + t * s * 0.2 * scale
        x = cx + math.sin(t * math.pi * 2.2) * s * 0.06 * scale * (0.3 + t)
        pts.append((x, y))
    outlined_line(pts, (170, 240, 225, 255), s * 0.012 * scale, False)

    # Collar of microvilli fanning up from the top
    for i in range(7):
        t = i / 6
        bx = cx - r * 0.45 + t * r * 0.9
        tx = cx - r * 0.85 + t * r * 1.7
        outlined_line([(bx, cy - r * 0.8), (tx, cy - r * 1.55)], (170, 240, 225, 255), s * 0.007 * scale, False)

    # Body: cyan rim, ink outline, translucent blue cytoplasm
    for rr, col in ((r + ol * 2.2, RIM), (r + ol, INK), (r, (110, 205, 230, 255))):
        d.ellipse([cx - rr, cy - rr * 1.08, cx + rr, cy + rr * 1.08], fill=col)
    inner = r * 0.82
    d.ellipse([cx - inner, cy - inner * 1.08, cx + inner, cy + inner * 1.08], fill=(150, 225, 240, 255))
    # Organelles
    for ox, oy, orr, col in ((-0.45, 0.35, 0.09, (110, 200, 120, 255)), (0.35, 0.5, 0.07, (255, 204, 102, 255)),
                             (-0.2, -0.5, 0.06, (110, 200, 120, 255))):
        x, y, rr = cx + ox * r, cy + oy * r, orr * r
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=col)
    # Nucleus with its nucleolus
    nr = r * 0.36
    nx, ny = cx + r * 0.08, cy - r * 0.05
    d.ellipse([nx - nr - ol, ny - nr - ol, nx + nr + ol, ny + nr + ol], fill=INK)
    d.ellipse([nx - nr, ny - nr, nx + nr, ny + nr], fill=(60, 80, 185, 255))
    d.ellipse([nx - nr * 0.38, ny - nr * 0.38, nx + nr * 0.38, ny + nr * 0.38], fill=(110, 200, 120, 255))
    # Shine
    hr = r * 0.16
    hx, hy = cx - r * 0.5, cy - r * 0.55
    d.ellipse([hx - hr, hy - hr * 1.4, hx + hr, hy + hr * 1.4], fill=(240, 255, 255, 220))

    img = img.resize((size, size), Image.LANCZOS)
    glow = img.filter(ImageFilter.GaussianBlur(size * 0.025))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(img)
    return out


def monochrome(fg):
    """Android 13 themed icon: a single-colour silhouette of the foreground,
    with the dark ink lines cut out so the nucleus and outline still read."""
    a = fg.getchannel("A").point(lambda v: 255 if v > 110 else 0)
    dark = fg.convert("L").point(lambda v: 255 if v < 40 else 0)
    a = Image.composite(Image.new("L", fg.size, 0), a, dark)
    out = Image.new("RGBA", fg.size, (255, 255, 255, 0))
    out.putalpha(a)
    return out


def main():
    icon = background(512)
    icon.alpha_composite(branches(512, 1.1))
    icon.alpha_composite(cell(512, 1.1))
    icon.save("icon.png")

    # Android adaptive layers: keep the cell inside the 66% safe zone
    bg = background(432)
    bg.alpha_composite(branches(432, 0.75))
    bg.save("assets/icon_background.png")
    fg = cell(432, scale=0.85)
    fg.save("assets/icon_foreground.png")
    monochrome(fg).save("assets/icon_monochrome.png")
    # Legacy launcher icon
    icon.resize((192, 192), Image.LANCZOS).save("assets/icon_192.png")


if __name__ == "__main__":
    main()
