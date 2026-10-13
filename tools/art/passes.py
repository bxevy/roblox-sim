# Game pass icons for the Robux Store: 2x Luck (four-leaf clover) and 2x Coins (coin pile).
#   python3 tools/art/passes.py assets/store
# Drawn big with thick ink outlines and flat banded shading, then scaled down to 512x512.
# Roblox shows game pass icons cropped to a circle, so everything important sits inside it.
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from draw import *

S = 2048
OUT = 512
INK_W = 30

GREEN_D = (24, 110, 52)
GREEN_M = (52, 168, 74)
GREEN_L = (110, 214, 104)
GREEN_XL = (176, 240, 150)
GOLD_D = (190, 112, 20)
GOLD_M = (240, 168, 40)
GOLD_L = (255, 210, 80)
GOLD_XL = (255, 238, 160)
RED = (220, 52, 60)


def blank():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def inked(mask, fill_layer, width=INK_W):
    """Composite: ink outline around `mask`, then `fill_layer` clipped to it."""
    out = blank()
    # Round dilation: blur then threshold (fast, and no square corners like MaxFilter)
    grow = mask.filter(ImageFilter.GaussianBlur(width * 0.6)).point(lambda v: 255 if v > 8 else 0)
    ink = Image.new("RGBA", (S, S), rgba(INK))
    out.paste(ink, (0, 0), grow)
    clipped = blank()
    clipped.paste(fill_layer, (0, 0), mask)
    out.alpha_composite(clipped)
    return out


def sunburst(c1, c2, rays, rot, center_glow):
    img = Image.new("RGBA", (S, S), rgba(c1))
    d = ImageDraw.Draw(img)
    cx = cy = S / 2
    R = S * 1.2
    for i in range(rays):
        if i % 2:
            continue
        a0 = rot + i / rays * 2 * math.pi
        a1 = rot + (i + 1) / rays * 2 * math.pi
        d.polygon([(cx, cy), (cx + math.cos(a0) * R, cy + math.sin(a0) * R), (cx + math.cos(a1) * R, cy + math.sin(a1) * R)], fill=rgba(c2))
    # Banded glow in the middle and a dark rim (poster look, no airbrush)
    for k, (r, a) in enumerate([(0.62, 40), (0.5, 55), (0.38, 70)]):
        g = blank()
        ImageDraw.Draw(g).ellipse([cx - S * r, cy - S * r, cx + S * r, cy + S * r], fill=rgba(center_glow, a))
        img.alpha_composite(g)
    rim = blank()
    ImageDraw.Draw(rim).ellipse([-S * 0.1, -S * 0.1, S * 1.1, S * 1.1], outline=rgba(INK, 120), width=int(S * 0.09))
    img.alpha_composite(rim)
    return img


def sparkle(d, cx, cy, r, color):
    pts = []
    for i in range(8):
        a = i / 8 * 2 * math.pi - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.28
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=rgba(INK))
    inner = [(cx + (x - cx) * 0.72, cy + (y - cy) * 0.72) for x, y in pts]
    d.polygon(inner, fill=rgba(color))


def badge_text(img, text, cx, cy, size, fill, angle=-8, font=FONT_BLACK, outline=None):
    """Chunky outlined text, rotated a little, with a hard drop shadow."""
    f = ImageFont.truetype(font, size)
    layer = blank()
    d = ImageDraw.Draw(layer)
    w = int(size * 0.13)
    d.text((S / 2 + size * 0.05, S / 2 + size * 0.07), text, font=f, fill=rgba(INK), anchor="mm", stroke_width=w, stroke_fill=rgba(INK))
    d.text((S / 2, S / 2), text, font=f, fill=rgba(fill), anchor="mm", stroke_width=w, stroke_fill=rgba(outline or INK))
    layer = layer.rotate(angle, resample=Image.BICUBIC, center=(S / 2, S / 2))
    img.alpha_composite(layer, (int(cx - S / 2), int(cy - S / 2)))


def ribbon(img, text, cy, color, dark):
    """A banner across the bottom with folded ends."""
    d = ImageDraw.Draw(img)
    w, h = S * 0.62, S * 0.15
    x0, x1 = S / 2 - w / 2, S / 2 + w / 2
    tail = S * 0.09
    for side in (-1, 1):
        ex = x0 if side < 0 else x1
        pts = [(ex, cy - h * 0.25), (ex + side * tail * 1.4, cy - h * 0.25), (ex + side * tail * 0.9, cy + h * 0.25), (ex + side * tail * 1.4, cy + h * 0.75), (ex, cy + h * 0.75)]
        draw_outlined_polygon(d, pts, rgba(dark), rgba(INK), INK_W)
    body = [(x0, cy - h / 2), (x1, cy - h / 2), (x1, cy + h / 2), (x0, cy + h / 2)]
    draw_outlined_polygon(d, body, rgba(color), rgba(INK), INK_W)
    d.rectangle([x0 + INK_W, cy + h * 0.18, x1 - INK_W, cy + h / 2 - INK_W / 2], fill=rgba(dark))
    f = ImageFont.truetype(FONT_BLACK, int(h * 0.7))
    d.text((S / 2, cy - h * 0.02), text, font=f, fill=rgba(CREAM), anchor="mm", stroke_width=int(h * 0.07), stroke_fill=rgba(INK))


# 2x Luck ----------------------------------------------------------------------------

def heart_mask(cx, cy, size, angle):
    """One clover leaf: a heart pointing at the clover's centre."""
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    r = size * 0.3
    # Build the heart pointing down (tip at bottom), then rotate it into place
    hx, hy = S / 2, S / 2
    d.ellipse([hx - size * 0.5, hy - size * 0.5, hx - size * 0.5 + 2 * r * 1.05, hy - size * 0.5 + 2 * r * 1.05], fill=255)
    d.ellipse([hx + size * 0.5 - 2 * r * 1.05, hy - size * 0.5, hx + size * 0.5, hy - size * 0.5 + 2 * r * 1.05], fill=255)
    d.polygon([(hx - size * 0.49, hy - size * 0.12), (hx + size * 0.49, hy - size * 0.12), (hx, hy + size * 0.5)], fill=255)
    m = m.rotate(angle, resample=Image.BICUBIC, center=(hx, hy))
    out = Image.new("L", (S, S), 0)
    out.paste(m, (int(cx - hx), int(cy - hy)))
    return out


def luck_icon():
    img = sunburst(GREEN_M, GREEN_L, 24, 0.07, GREEN_XL)
    cx, cy = S * 0.5, S * 0.44
    leaf = S * 0.36
    off = leaf * 0.5

    # Stem
    stem = blank()
    sd = ImageDraw.Draw(stem)
    pts = [(cx + S * 0.02 + math.sin(t * 2.2) * S * 0.05 + t * S * 0.16, cy + t * S * 0.34) for t in [i / 30 for i in range(31)]]
    sd.line(pts, fill=rgba(INK), width=int(S * 0.075), joint="curve")
    sd.line(pts, fill=rgba(GREEN_D), width=int(S * 0.04), joint="curve")
    img.alpha_composite(stem)

    # Four leaves (top, right, bottom, left), each a heart whose tip meets the middle
    for k in range(4):
        a = k * 90 + 45
        rad = math.radians(a - 90)
        lx, ly = cx + math.cos(rad) * off, cy + math.sin(rad) * off
        mask = heart_mask(lx, ly, leaf, -a)  # tip points at the middle
        fill = blank()
        fd = ImageDraw.Draw(fill)
        fd.rectangle([0, 0, S, S], fill=rgba(GREEN_M))
        # Lit half: the half of each leaf facing up-left is lighter
        shade = Image.new("L", (S, S), 0)
        ImageDraw.Draw(shade).polygon([(cx - S, cy + S - S * 0.02), (cx + S, cy - S - S * 0.02), (0, 0)], fill=255)
        light = Image.new("RGBA", (S, S), rgba(GREEN_L))
        fill.paste(light, (0, 0), shade)
        # Highlight dab
        hx, hy = cx + math.cos(rad) * off * 1.25 - leaf * 0.12, cy + math.sin(rad) * off * 1.25 - leaf * 0.14
        fd.ellipse([hx - leaf * 0.07, hy - leaf * 0.045, hx + leaf * 0.07, hy + leaf * 0.045], fill=rgba(GREEN_XL))
        img.alpha_composite(inked(mask, fill))
        # Vein from the middle out to the leaf's notch
        d = ImageDraw.Draw(img)
        d.line([(cx, cy), (cx + math.cos(rad) * off * 1.45, cy + math.sin(rad) * off * 1.45)], fill=rgba(GREEN_D), width=int(S * 0.016))
    d = ImageDraw.Draw(img)
    d.ellipse([cx - S * 0.03, cy - S * 0.03, cx + S * 0.03, cy + S * 0.03], fill=rgba(GREEN_D), outline=rgba(INK), width=12)

    for x, y, r, c in [(0.2, 0.22, 0.07, GOLD_XL), (0.82, 0.2, 0.055, CREAM), (0.86, 0.5, 0.04, GOLD_XL), (0.15, 0.55, 0.045, CREAM)]:
        sparkle(d, S * x, S * y, S * r, c)

    badge_text(img, "2X", S * 0.73, S * 0.66, int(S * 0.3), GOLD_L, angle=12)
    ribbon(img, "LUCK", S * 0.83, GREEN_M, GREEN_D)
    return img


# 2x Coins ---------------------------------------------------------------------------

def coin(img, cx, cy, rx, ry, thick, emblem=True, tilt=0):
    """A gold coin seen at an angle: rim thickness below, face on top, star emblem."""
    layer = blank()
    d = ImageDraw.Draw(layer)
    # Edge (the coin's thickness) then face
    d.ellipse([cx - rx, cy - ry + thick, cx + rx, cy + ry + thick], fill=rgba(GOLD_D), outline=rgba(INK), width=INK_W)
    d.rectangle([cx - rx + INK_W / 2, cy, cx + rx - INK_W / 2, cy + thick], fill=rgba(GOLD_D))
    d.line([(cx - rx, cy), (cx - rx, cy + thick)], fill=rgba(INK), width=INK_W)
    d.line([(cx + rx, cy), (cx + rx, cy + thick)], fill=rgba(INK), width=INK_W)
    for i in range(1, 9):
        x = cx - rx + 2 * rx * i / 9
        dy = ry * math.sqrt(max(0, 1 - ((x - cx) / rx) ** 2))
        d.line([(x, cy + dy + 6), (x, cy + dy + thick - 6)], fill=rgba(GOLD_M), width=8)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=rgba(GOLD_M), outline=rgba(INK), width=INK_W)
    d.ellipse([cx - rx * 0.8, cy - ry * 0.8, cx + rx * 0.8, cy + ry * 0.8], fill=rgba(GOLD_L), outline=rgba(GOLD_D), width=14)
    if emblem:
        pts = []
        for i in range(10):
            a = i / 10 * 2 * math.pi - math.pi / 2
            r = 0.5 if i % 2 == 0 else 0.21
            pts.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
        d.polygon([(x + 8, y + 10) for x, y in pts], fill=rgba(GOLD_D))
        d.polygon(pts, fill=rgba(GOLD_XL))
    # Shine streak
    d.line([(cx - rx * 0.55, cy - ry * 0.25), (cx - rx * 0.25, cy - ry * 0.6)], fill=rgba(CREAM), width=int(rx * 0.09))
    if tilt:
        layer = layer.rotate(tilt, resample=Image.BICUBIC, center=(cx, cy))
    img.alpha_composite(layer)


def coins_icon():
    img = sunburst(GOLD_M, GOLD_L, 24, 0.0, GOLD_XL)
    # Pile in the back
    pile = [(0.3, 0.66, 0.15), (0.7, 0.68, 0.14), (0.42, 0.7, 0.15), (0.6, 0.62, 0.13)]
    for x, y, r in pile:
        coin(img, S * x, S * y, S * r, S * r * 0.42, S * 0.04, emblem=False)
    # Stack on the left
    for i in range(5):
        coin(img, S * 0.27, S * (0.6 - i * 0.055), S * 0.14, S * 0.06, S * 0.05, emblem=False)
    # Hero coin, standing up and tilted
    coin(img, S * 0.55, S * 0.4, S * 0.26, S * 0.26, S * 0.06, tilt=-12)

    d = ImageDraw.Draw(img)
    for x, y, r, c in [(0.2, 0.2, 0.065, CREAM), (0.84, 0.22, 0.05, CREAM), (0.86, 0.48, 0.04, GOLD_XL), (0.13, 0.42, 0.04, CREAM)]:
        sparkle(d, S * x, S * y, S * r, c)

    badge_text(img, "2X", S * 0.74, S * 0.64, int(S * 0.3), (120, 235, 120), angle=12)
    ribbon(img, "COINS", S * 0.83, (226, 140, 30), GOLD_D)
    return img


def save(img, path):
    img = grain(img, 3)
    img.convert("RGB").resize((OUT, OUT), Image.LANCZOS).save(path)
    print("saved", path)


if __name__ == "__main__":
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out_dir, exist_ok=True)
    save(luck_icon(), os.path.join(out_dir, "pass_2x_luck_512.png"))
    save(coins_icon(), os.path.join(out_dir, "pass_2x_coins_512.png"))
