import math, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

FONT_BLACK = "/usr/share/fonts/opentype/inter/InterDisplay-Black.otf"
FONT_XB = "/usr/share/fonts/opentype/inter/InterDisplay-ExtraBold.otf"

# Palette (kept small on purpose)
INK = (24, 12, 34)        # outlines / deepest shadow
NIGHT1 = (38, 18, 58)
NIGHT2 = (62, 28, 86)
NIGHT3 = (98, 44, 112)
DUSK = (168, 72, 96)
EMBER = (232, 110, 46)
PUMPKIN_D = (196, 82, 18)
PUMPKIN_M = (232, 112, 24)
PUMPKIN_L = (250, 146, 40)
GLOW = (255, 214, 92)
GLOW2 = (255, 170, 50)
CREAM = (255, 240, 212)
MOON = (250, 228, 170)
MOON_D = (226, 196, 138)
STEM = (86, 102, 44)
STEM_D = (52, 66, 30)

def rgba(c, a=255):
    return (c[0], c[1], c[2], a)

def wobble(points, amount, seed):
    rng = random.Random(seed)
    return [(x + rng.uniform(-amount, amount), y + rng.uniform(-amount, amount)) for x, y in points]

def banded_sky(w, h, stops, bands):
    """Vertical gradient quantised into hard bands (poster look, not airbrushed)."""
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    for i in range(bands):
        t = i / (bands - 1)
        # piecewise colour between stops
        seg = t * (len(stops) - 1)
        k = min(int(seg), len(stops) - 2)
        f = seg - k
        c = tuple(int(stops[k][j] + (stops[k + 1][j] - stops[k][j]) * f) for j in range(3))
        y0 = int(h * i / bands)
        y1 = int(h * (i + 1) / bands) + 1
        d.rectangle([0, y0, w, y1], fill=rgba(c))
    return img

def ellipse_points(cx, cy, rx, ry, n=90, start=0, end=2 * math.pi):
    return [(cx + math.cos(start + (end - start) * i / (n - 1)) * rx, cy + math.sin(start + (end - start) * i / (n - 1)) * ry) for i in range(n)]

def draw_outlined_polygon(d, pts, fill, outline, width):
    d.polygon(pts, fill=fill)
    d.line(pts + [pts[0]], fill=outline, width=width, joint="curve")

def pumpkin(img, cx, cy, w, h, seed=1, face=True, outline_w=None, ko=False):
    """A carved jack-o'-lantern: ribbed body, outlined, carved face lit from inside."""
    ow = outline_w or max(2, int(w * 0.018))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    ribs = [(-0.30, 0.52, PUMPKIN_D), (0.30, 0.52, PUMPKIN_D), (-0.15, 0.56, PUMPKIN_M), (0.15, 0.56, PUMPKIN_M), (0.0, 0.46, PUMPKIN_L)]
    for i, (off, wf, col) in enumerate(ribs):
        pts = wobble(ellipse_points(cx + off * w, cy, wf * w / 2, h / 2, 80), w * 0.004, seed + i)
        draw_outlined_polygon(d, pts, rgba(col), rgba(INK), ow)
    # Cel highlight on the middle rib
    hl = ellipse_points(cx - w * 0.11, cy - h * 0.33, w * 0.03, h * 0.085, 40)
    d.polygon(hl, fill=rgba((255, 196, 110)))
    # Stem
    s = w * 0.07
    stem = [(cx - s * 0.6, cy - h * 0.44), (cx + s * 0.5, cy - h * 0.46), (cx + s * 0.9, cy - h * 0.62), (cx + s * 1.6, cy - h * 0.70), (cx + s * 1.2, cy - h * 0.74), (cx + s * 0.2, cy - h * 0.66), (cx - s * 0.5, cy - h * 0.58)]
    draw_outlined_polygon(d, wobble(stem, w * 0.004, seed + 9), rgba(STEM), rgba(INK), ow)
    d.line([(cx - s * 0.1, cy - h * 0.47), (cx + s * 0.6, cy - h * 0.64)], fill=rgba(STEM_D), width=max(1, ow // 2))
    img.alpha_composite(layer)
    if not face:
        return
    # Carved face: dark cut edge, then the glowing inside (inset), then bloom
    def tri(x, y, sw, sh, flip=False):
        if flip:
            return [(x - sw / 2, y - sh / 2), (x + sw / 2, y - sh / 2), (x, y + sh / 2)]
        return [(x - sw / 2, y + sh / 2), (x + sw / 2, y + sh / 2), (x, y - sh / 2)]
    eyes = [tri(cx - w * 0.19, cy - h * 0.1, w * 0.21, h * 0.25), tri(cx + w * 0.19, cy - h * 0.1, w * 0.21, h * 0.25)]
    nose = [tri(cx, cy + h * 0.05, w * 0.07, h * 0.09)]
    mouth_top = cy + h * 0.13
    mw = w * 0.38
    mouth = [(cx - mw, mouth_top), (cx - mw * 0.55, mouth_top + h * 0.03), (cx - mw * 0.45, mouth_top - h * 0.03), (cx - mw * 0.2, mouth_top + h * 0.03),
             (cx + mw * 0.2, mouth_top + h * 0.03), (cx + mw * 0.45, mouth_top - h * 0.03), (cx + mw * 0.55, mouth_top + h * 0.03), (cx + mw, mouth_top),
             (cx + mw * 0.7, mouth_top + h * 0.17), (cx + mw * 0.3, mouth_top + h * 0.21), (cx + mw * 0.15, mouth_top + h * 0.14), (cx - mw * 0.05, mouth_top + h * 0.22),
             (cx - mw * 0.3, mouth_top + h * 0.21), (cx - mw * 0.7, mouth_top + h * 0.17)]
    if ko:
        # Knocked out: carved X eyes and a wobbly, gaping mouth
        def bar(x, y, length, thick, angle):
            a = math.radians(angle)
            dx, dy = math.cos(a) * length / 2, math.sin(a) * length / 2
            nx, ny = -math.sin(a) * thick / 2, math.cos(a) * thick / 2
            return [(x - dx + nx, y - dy + ny), (x + dx + nx, y + dy + ny), (x + dx - nx, y + dy - ny), (x - dx - nx, y - dy - ny)]
        eyes = []
        for ex in (cx - w * 0.19, cx + w * 0.19):
            eyes += [bar(ex, cy - h * 0.1, w * 0.2, w * 0.06, 45), bar(ex, cy - h * 0.1, w * 0.2, w * 0.06, -45)]
        nose = []
        mouth = []
        for i in range(13):
            t = i / 12
            mouth.append((cx - w * 0.22 + t * w * 0.44, cy + h * 0.2 + math.sin(t * math.pi * 3) * h * 0.035))
        for i in range(13):
            t = 1 - i / 12
            mouth.append((cx - w * 0.22 + t * w * 0.44, cy + h * 0.31 + math.sin(t * math.pi * 3) * h * 0.035))
    shapes = eyes + nose + [mouth]
    bloom = Image.new("RGBA", img.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(bloom)
    for sh in shapes:
        bd.polygon(sh, fill=rgba(GLOW2, 200))
    bloom = bloom.filter(ImageFilter.GaussianBlur(w * 0.03))
    img.alpha_composite(bloom)
    face_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(face_layer)
    for k, sh in enumerate(shapes):
        sh = wobble(sh, w * 0.003, seed + 20 + k)
        fd.polygon(sh, fill=rgba((92, 30, 6)))
        mx = sum(p[0] for p in sh) / len(sh)
        my = sum(p[1] for p in sh) / len(sh)
        inner = [(mx + (x - mx) * 0.8, my + (y - my) * 0.8 + h * 0.008) for x, y in sh]
        fd.polygon(inner, fill=rgba(GLOW))
        hot = [(mx + (x - mx) * 0.45, my + (y - my) * 0.45 + h * 0.012) for x, y in sh]
        fd.polygon(hot, fill=rgba((255, 246, 200)))
    img.alpha_composite(face_layer)

def bat(d, cx, cy, size, color, flap=0.0, seed=0):
    s = size
    up = -0.35 + flap
    wing_r = [(cx + s * 0.08, cy), (cx + s * 0.45, cy + s * up), (cx + s * 0.95, cy + s * (up - 0.05)), (cx + s * 0.82, cy + s * 0.18),
              (cx + s * 0.66, cy + s * 0.08), (cx + s * 0.55, cy + s * 0.24), (cx + s * 0.38, cy + s * 0.12), (cx + s * 0.25, cy + s * 0.25), (cx + s * 0.08, cy + s * 0.12)]
    wing_l = [(2 * cx - x, y) for x, y in wing_r]
    d.polygon(wobble(wing_r, s * 0.015, seed), fill=color)
    d.polygon(wobble(wing_l, s * 0.015, seed + 1), fill=color)
    d.ellipse([cx - s * 0.11, cy - s * 0.1, cx + s * 0.11, cy + s * 0.22], fill=color)
    d.polygon([(cx - s * 0.1, cy - s * 0.05), (cx - s * 0.07, cy - s * 0.2), (cx - s * 0.02, cy - s * 0.07)], fill=color)
    d.polygon([(cx + s * 0.1, cy - s * 0.05), (cx + s * 0.07, cy - s * 0.2), (cx + s * 0.02, cy - s * 0.07)], fill=color)

def moon(img, cx, cy, r, halo_steps=4):
    d = ImageDraw.Draw(img)
    # Stepped halo rings (hard edges, low alpha)
    for i in range(halo_steps, 0, -1):
        rr = r * (1 + 0.16 * i)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=rgba(MOON, 14 + 6 * (halo_steps - i)))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgba(MOON))
    rng = random.Random(4)
    for _ in range(7):
        a = rng.uniform(0, 2 * math.pi)
        dist = rng.uniform(0.1, 0.65) * r
        cr = rng.uniform(0.06, 0.16) * r
        x, y = cx + math.cos(a) * dist, cy + math.sin(a) * dist
        d.ellipse([x - cr, y - cr, x + cr, y + cr], fill=rgba(MOON_D))
    # Shaded crescent edge on the lower right
    shade = Image.new("L", img.size, 0)
    sd = ImageDraw.Draw(shade)
    sd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    sd.ellipse([cx - r * 1.1, cy - r * 1.12, cx + r * 0.9, cy + r * 0.88], fill=0)
    tint = Image.new("RGBA", img.size, rgba(MOON_D))
    img.paste(tint, (0, 0), shade)

def grain(img, amount, seed=7):
    rng = np.random.default_rng(seed)
    w, h = img.size
    noise = rng.normal(0, 1, (h, w))
    arr = np.array(img).astype(np.float32)
    arr[..., :3] += noise[..., None] * amount
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))

def text_with_shadow(img, xy, text, font, fill, outline, outline_w, shadow, shadow_off, anchor="mm"):
    d = ImageDraw.Draw(img)
    x, y = xy
    d.text((x + shadow_off[0], y + shadow_off[1]), text, font=font, fill=shadow, anchor=anchor, stroke_width=outline_w, stroke_fill=shadow)
    d.text((x, y), text, font=font, fill=fill, anchor=anchor, stroke_width=outline_w, stroke_fill=outline)
