# Halloween update icon: the Pumpkin King sliced in half (boss defeated) + an UPDATE badge.
#   python3 tools/art/icon.py assets/halloween
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from draw import *

GREEN = (74, 196, 96)
GREEN_D = (40, 130, 60)
CROWN = (140, 60, 200)
GOLD = (255, 204, 70)
FLESH = (255, 206, 120)

def starburst(d, cx, cy, r_out, r_in, points, color, rot=0.0, seed=0):
    rng = random.Random(seed)
    pts = []
    for i in range(points * 2):
        a = rot + i / (points * 2) * 2 * math.pi
        r = (r_out if i % 2 == 0 else r_in) * rng.uniform(0.9, 1.08)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d.polygon(pts, fill=color)

def crown(S, angle):
    layer = Image.new("RGBA", (int(S * 0.27), int(S * 0.22)), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w, h = layer.size
    base_y = h * 0.82
    pts = [(w * 0.1, base_y), (w * 0.08, h * 0.25), (w * 0.3, h * 0.55), (w * 0.5, h * 0.12), (w * 0.7, h * 0.55), (w * 0.92, h * 0.25), (w * 0.9, base_y)]
    draw_outlined_polygon(d, pts, rgba(CROWN), rgba(INK), 18)
    d.rectangle([w * 0.1, base_y - h * 0.16, w * 0.9, base_y], fill=rgba(GOLD), outline=rgba(INK), width=14)
    for x, y in [(w * 0.08, h * 0.25), (w * 0.5, h * 0.12), (w * 0.92, h * 0.25)]:
        d.ellipse([x - 26, y - 26, x + 26, y + 26], fill=rgba(GOLD), outline=rgba(INK), width=10)
    d.ellipse([w * 0.5 - 30, base_y - h * 0.14, w * 0.5 + 30, base_y - h * 0.02], fill=rgba((255, 70, 90)), outline=rgba(INK), width=8)
    return layer.rotate(angle, expand=True, resample=Image.BICUBIC)

def update_badge(S, with_tag):
    layer = Image.new("RGBA", (int(S * 0.36), int(S * 0.36)), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w = layer.size[0]
    c, r = w / 2, w * 0.36
    d.ellipse([c - r + 16, c - r + 22, c + r + 16, c + r + 22], fill=rgba(INK))
    d.ellipse([c - r, c - r, c + r, c + r], fill=rgba(GREEN), outline=rgba(INK), width=22)
    d.ellipse([c - r * 0.82, c - r * 0.82, c + r * 0.82, c + r * 0.82], outline=rgba(GREEN_D), width=10)
    # Two circular arrows (refresh)
    ar = r * 0.52
    thick = int(r * 0.17)
    for start in (200, 20):
        d.arc([c - ar, c - ar, c + ar, c + ar], start, start + 130, fill=rgba(CREAM), width=thick)
        end = math.radians(start + 130)
        tip = (c + math.cos(end) * ar, c + math.sin(end) * ar)
        tangent = (-math.sin(end), math.cos(end))
        normal = (math.cos(end), math.sin(end))
        size = r * 0.27
        head = [
            (tip[0] + tangent[0] * size, tip[1] + tangent[1] * size),
            (tip[0] + normal[0] * size * 0.75, tip[1] + normal[1] * size * 0.75),
            (tip[0] - normal[0] * size * 0.75, tip[1] - normal[1] * size * 0.75),
        ]
        d.polygon(head, fill=rgba(CREAM))
    return layer

def make_icon(with_text: bool, out: str, size: int):
    S = 2048
    bg = Image.new("RGBA", (S, S), rgba(NIGHT1))
    d = ImageDraw.Draw(bg)
    cx, cy = S * 0.5, S * 0.5
    for i, col in enumerate([NIGHT1, (48, 22, 70), NIGHT2, (80, 36, 100), NIGHT3]):
        r = S * (1.05 - i * 0.17)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgba(col))
    rng = random.Random(3)
    for _ in range(36):
        x, y = rng.uniform(80, S - 80), rng.uniform(80, S * 0.5)
        r = rng.choice([4, 5, 7])
        d.ellipse([x - r, y - r, x + r, y + r], fill=rgba(CREAM, 200))
    moon(bg, S * 0.5, S * 0.2, S * 0.14)
    d = ImageDraw.Draw(bg)
    bat(d, S * 0.84, S * 0.42, 110, rgba(INK), 0.1, 3)
    bat(d, S * 0.46, S * 0.13, 90, rgba(INK), -0.05, 5)

    # Impact starburst behind the boss
    boss_cx, boss_cy = S * 0.5, S * (0.58 if with_text else 0.6)
    starburst(d, boss_cx, boss_cy, S * 0.47, S * 0.33, 14, rgba(EMBER), 0.1, 1)
    starburst(d, boss_cx, boss_cy, S * 0.38, S * 0.27, 14, rgba(GLOW), 0.32, 2)

    # The Pumpkin King, knocked out...
    boss = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bw, bh = S * 0.6, S * 0.47
    pumpkin(boss, boss_cx, boss_cy, bw, bh, seed=11, ko=True)
    # ...and sliced: a band of pumpkin flesh along the cut, then split the halves apart
    angle = math.radians(-74)  # a steep cut straight down between the eyes
    ux, uy = math.cos(angle), math.sin(angle)
    nx, ny = -uy, ux
    p0 = (boss_cx - ux * S, boss_cy - uy * S)
    p1 = (boss_cx + ux * S, boss_cy + uy * S)
    band = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(band).line([p0, p1], fill=rgba(FLESH), width=int(S * 0.045))
    band_alpha = ImageChops.multiply(band.getchannel("A"), boss.getchannel("A"))
    band.putalpha(band_alpha)
    boss.alpha_composite(band)
    ImageDraw.Draw(boss).line([p0, p1], fill=rgba((150, 70, 20)), width=int(S * 0.008))
    halves = []
    for sign in (1, -1):
        mask = Image.new("L", (S, S), 0)
        far = S * 2
        poly = [p0, p1, (p1[0] + nx * far * sign, p1[1] + ny * far * sign), (p0[0] + nx * far * sign, p0[1] + ny * far * sign)]
        ImageDraw.Draw(mask).polygon(poly, fill=255)
        half = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        half.paste(boss, (0, 0), ImageChops.multiply(mask, boss.getchannel("A")))
        shift = S * 0.1
        half = half.rotate(sign * 11, center=(boss_cx, boss_cy), resample=Image.BICUBIC, translate=(nx * shift * sign, ny * shift * sign))
        halves.append(half)
    for half in halves:
        bg.alpha_composite(half)

    # The slash: a glowing streak along the cut
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    a0 = (boss_cx - ux * S * 0.46, boss_cy - uy * S * 0.46)
    a1 = (boss_cx + ux * S * 0.46, boss_cy + uy * S * 0.46)
    gd.line([a0, a1], fill=rgba(GLOW2, 200), width=int(S * 0.03))
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.012))
    bg.alpha_composite(glow)
    d = ImageDraw.Draw(bg)
    lens = []
    for i in range(41):
        t = i / 40
        half_w = math.sin(t * math.pi) * S * 0.011
        x = a0[0] + (a1[0] - a0[0]) * t
        y = a0[1] + (a1[1] - a0[1]) * t
        lens.append((x + nx * half_w, y + ny * half_w))
    for i in range(40, -1, -1):
        t = i / 40
        half_w = math.sin(t * math.pi) * S * 0.011
        x = a0[0] + (a1[0] - a0[0]) * t
        y = a0[1] + (a1[1] - a0[1]) * t
        lens.append((x - nx * half_w, y - ny * half_w))
    d.polygon(lens, fill=rgba((255, 252, 235)))

    # Chunks of pumpkin and sparks flying off the ends of the cut
    rng = random.Random(9)
    for end, direction in ((a1, 1), (a0, -1)):
        for k in range(6):
            dist = rng.uniform(0.02, 0.1) * S
            spread = rng.uniform(-0.9, 0.9)
            px = end[0] + (ux * direction + nx * spread) * dist
            py = end[1] + (uy * direction + ny * spread) * dist
            r = rng.uniform(0.012, 0.026) * S
            chunk = [(px + math.cos(a) * r * rng.uniform(0.6, 1.2), py + math.sin(a) * r * rng.uniform(0.6, 1.2)) for a in [j / 5 * 2 * math.pi for j in range(5)]]
            draw_outlined_polygon(d, chunk, rgba(PUMPKIN_M if k % 2 else FLESH), rgba(INK), 8)
    # The crown goes flying
    c = crown(S, 32)
    bg.alpha_composite(c, (int(S * 0.07), int(S * 0.06)))
    # Motion lines behind the flying crown
    d = ImageDraw.Draw(bg)
    for k in range(3):
        y0 = S * (0.27 + k * 0.035)
        d.line([(S * (0.3 + k * 0.02), y0 + S * 0.03), (S * (0.38 + k * 0.02), y0 + S * 0.09)], fill=rgba(CREAM, 220), width=14)

    # UPDATE badge
    badge = update_badge(S, with_text)
    bg.alpha_composite(badge, (int(S * 0.62), int(S * 0.02)))
    if with_text:
        tag = Image.new("RGBA", (int(S * 0.36), int(S * 0.13)), (0, 0, 0, 0))
        td = ImageDraw.Draw(tag)
        tw, th = tag.size
        td.rounded_rectangle([12, 18, tw - 4, th - 4], radius=th // 2, fill=rgba(INK))
        td.rounded_rectangle([0, 6, tw - 16, th - 16], radius=th // 2, fill=rgba(GLOW), outline=rgba(INK), width=14)
        td.text(((tw - 16) / 2, (th - 10) / 2), "UPDATE!", font=ImageFont.truetype(FONT_BLACK, int(th * 0.52)), fill=rgba(INK), anchor="mm")
        tag = tag.rotate(-8, expand=True, resample=Image.BICUBIC)
        bg.alpha_composite(tag, (int(S * 0.62), int(S * 0.3)))

    if with_text:
        y = S * 0.88
        h = S * 0.12
        x0, x1 = S * 0.06, S * 0.94
        notch = h * 0.35
        ribbon = [(x0, y - h / 2), (x1, y - h / 2), (x1 - notch, y), (x1, y + h / 2), (x0, y + h / 2), (x0 + notch, y)]
        d = ImageDraw.Draw(bg)
        d.polygon([(x + 14, yy + 18) for x, yy in ribbon], fill=rgba(INK))
        draw_outlined_polygon(d, ribbon, rgba(EMBER), rgba(INK), 16)
        font = ImageFont.truetype(FONT_BLACK, int(S * 0.098))
        text_with_shadow(bg, (S * 0.5, y + 4), "HALLOWEEN", font, CREAM, INK, 14, rgba(INK), (10, 12))

    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.2), fill=255)
    img.paste(bg, (0, 0), mask)
    frame = ImageDraw.Draw(img)
    frame.rounded_rectangle([18, 18, S - 19, S - 19], radius=int(S * 0.19), outline=rgba(EMBER), width=46)
    frame.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.2), outline=rgba(INK), width=26)
    img = grain(img, 5)
    img.resize((size, size), Image.LANCZOS).save(out)
    print("saved", out)

out_dir = sys.argv[1]
make_icon(True, f"{out_dir}/halloween_icon_512.png", 512)
make_icon(False, f"{out_dir}/halloween_icon_hud_256.png", 256)
