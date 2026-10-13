import sys
sys.path.insert(0, ".")
from draw import *

W, H = 3840, 2160

def rot_rect(cx, cy, w, h, angle_deg, pivot):
    """Corners of a w x h rectangle centred at (cx, cy), rotated about `pivot`."""
    a = math.radians(angle_deg)
    pts = [(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2), (cx + w / 2, cy + h / 2), (cx - w / 2, cy + h / 2)]
    px, py = pivot
    return [(px + (x - px) * math.cos(a) - (y - py) * math.sin(a), py + (x - px) * math.sin(a) + (y - py) * math.cos(a)) for x, y in pts]

def dead_tree(d, x, y, height, color, seed):
    rng = random.Random(seed)
    def branch(x0, y0, length, angle, width, depth):
        x1 = x0 + math.cos(angle) * length
        y1 = y0 - math.sin(angle) * length
        d.line([(x0, y0), (x1, y1)], fill=color, width=int(width))
        d.ellipse([x1 - width / 2, y1 - width / 2, x1 + width / 2, y1 + width / 2], fill=color)
        if depth > 0:
            for _ in range(2 if depth > 1 else 3):
                branch(x1, y1, length * rng.uniform(0.55, 0.75), angle + rng.uniform(-0.75, 0.75), width * 0.62, depth - 1)
    branch(x, y, height * 0.45, math.pi / 2 + rng.uniform(-0.12, 0.12), height * 0.07, 4)

def manor(d, x, base, s, body, window):
    # A crooked haunted house on the hill
    d.rectangle([x, base - s * 1.1, x + s * 1.6, base], fill=body)
    d.polygon([(x - s * 0.1, base - s * 1.1), (x + s * 0.8, base - s * 1.75), (x + s * 1.7, base - s * 1.1)], fill=body)
    d.rectangle([x + s * 1.2, base - s * 2.1, x + s * 1.6, base - s * 1.0], fill=body)
    d.polygon([(x + s * 1.12, base - s * 2.1), (x + s * 1.43, base - s * 2.75), (x + s * 1.68, base - s * 2.1)], fill=body)
    d.rectangle([x - s * 0.5, base - s * 0.7, x, base], fill=body)
    d.polygon([(x - s * 0.58, base - s * 0.7), (x - s * 0.22, base - s * 1.05), (x + s * 0.06, base - s * 0.7)], fill=body)
    rng = random.Random(8)
    for wx, wy in [(0.25, 0.85), (0.6, 0.85), (0.95, 0.85), (0.25, 0.45), (0.95, 0.45), (1.32, 1.7), (1.32, 1.35), (-0.32, 0.4)]:
        if rng.random() < 0.8:
            d.rectangle([x + s * wx, base - s * wy, x + s * (wx + 0.16), base - s * (wy - 0.2)], fill=window)
    d.ellipse([x + s * 0.68, base - s * 1.5, x + s * 0.92, base - s * 1.26], fill=window)

def warlock(img, fx, fy, u):
    """Blocky Roblox-style Pumpkin Warlock: feet at (fx, fy), u = one stud in pixels."""
    d = ImageDraw.Draw(img)
    ow = int(u * 0.09)
    armor, armor_d, trim, cape, cape_d, skin = (52, 40, 64), (34, 26, 44), EMBER, (96, 42, 132), (64, 26, 92), (234, 184, 146)
    hip = fy - 2 * u
    shoulder = hip - 2 * u
    # Cape (behind everything)
    cape_pts = [(fx - 1.05 * u, shoulder + 0.1 * u), (fx + 1.05 * u, shoulder + 0.1 * u), (fx + 1.6 * u, fy - 0.2 * u), (fx + 1.1 * u, fy - 0.45 * u),
                (fx + 0.6 * u, fy - 0.1 * u), (fx, fy - 0.4 * u), (fx - 0.6 * u, fy - 0.05 * u), (fx - 1.1 * u, fy - 0.4 * u), (fx - 1.55 * u, fy - 0.15 * u)]
    draw_outlined_polygon(d, wobble(cape_pts, u * 0.02, 3), rgba(cape_d), rgba(INK), ow)
    # Legs
    for side in (-1, 1):
        x0 = fx + (0 if side > 0 else -1) * u
        d.rectangle([x0, hip, x0 + u, fy], fill=rgba(armor), outline=rgba(INK), width=ow)
        d.rectangle([x0 + ow, fy - 0.45 * u, x0 + u - ow, fy - ow], fill=rgba(armor_d))
    # Left arm (down, holding nothing)
    arm = rot_rect(fx - 1.5 * u, shoulder + u, u, 2 * u, 8, (fx - 1.5 * u, shoulder + 0.2 * u))
    draw_outlined_polygon(d, arm, rgba(armor), rgba(INK), ow)
    # Torso with belt and a glowing pumpkin emblem
    d.rectangle([fx - u, shoulder, fx + u, hip], fill=rgba(armor), outline=rgba(INK), width=ow)
    d.rectangle([fx - u + ow, shoulder + ow, fx - 0.55 * u, hip - ow], fill=rgba(armor_d))
    d.rectangle([fx - u + ow, hip - 0.38 * u, fx + u - ow, hip - 0.12 * u], fill=rgba(trim))
    d.polygon([(fx - 0.25 * u, shoulder + 0.7 * u), (fx + 0.25 * u, shoulder + 0.7 * u), (fx, shoulder + 1.15 * u)], fill=rgba(GLOW))
    d.line([(fx - u, shoulder + ow), (fx - 0.3 * u, shoulder + 0.55 * u), (fx + 0.3 * u, shoulder + 0.55 * u), (fx + u, shoulder + ow)], fill=rgba(trim), width=int(u * 0.12))
    # Right arm raised, holding the lantern staff up
    pivot = (fx + 1.5 * u, shoulder + 0.25 * u)
    arm = rot_rect(fx + 1.5 * u, shoulder + u, u, 2 * u, -150, pivot)
    hand_x = sum(p[0] for p in arm[2:]) / 2
    hand_y = sum(p[1] for p in arm[2:]) / 2
    # Staff goes up and out from the hand
    top = (hand_x + 1.2 * u, hand_y - 3.1 * u)
    bottom = (hand_x - 0.5 * u, hand_y + 1.6 * u)
    d.line([bottom, top], fill=rgba(INK), width=int(u * 0.32))
    d.line([bottom, top], fill=rgba((92, 62, 40)), width=int(u * 0.18))
    draw_outlined_polygon(d, arm, rgba(armor), rgba(INK), ow)
    # Lantern hook and the jack-o'-lantern itself
    hook_end = (top[0] + 0.7 * u, top[1] - 0.1 * u)
    d.line([top, hook_end], fill=rgba(INK), width=int(u * 0.2))
    d.line([hook_end, (hook_end[0], hook_end[1] + 0.5 * u)], fill=rgba(INK), width=int(u * 0.08))
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    lx, ly = hook_end[0], hook_end[1] + 1.15 * u
    for i, a in enumerate([40, 60, 85]):
        r = u * (1.7 - i * 0.35)
        gd.ellipse([lx - r, ly - r, lx + r, ly + r], fill=rgba(GLOW2, a))
    img.alpha_composite(glow)
    pumpkin(img, lx, ly, 1.3 * u, 1.05 * u, seed=30)
    d = ImageDraw.Draw(img)
    # Head: a jack-o'-lantern helm with a witch-hat brim
    pumpkin(img, fx, shoulder - 0.78 * u, 1.75 * u, 1.45 * u, seed=40)
    d = ImageDraw.Draw(img)
    hat_y = shoulder - 1.35 * u
    brim = [(fx - 1.3 * u, hat_y), (fx + 1.35 * u, hat_y - 0.15 * u), (fx + 1.2 * u, hat_y + 0.2 * u), (fx - 1.2 * u, hat_y + 0.3 * u)]
    draw_outlined_polygon(d, brim, rgba((40, 26, 52)), rgba(INK), ow)
    cone = [(fx - 0.7 * u, hat_y + 0.05 * u), (fx + 0.75 * u, hat_y - 0.05 * u), (fx + 0.35 * u, hat_y - 1.2 * u), (fx + 1.2 * u, hat_y - 1.9 * u), (fx - 0.05 * u, hat_y - 1.35 * u)]
    draw_outlined_polygon(d, wobble(cone, u * 0.02, 5), rgba((40, 26, 52)), rgba(INK), ow)
    d.polygon([(fx - 0.66 * u, hat_y - 0.05 * u), (fx + 0.72 * u, hat_y - 0.15 * u), (fx + 0.66 * u, hat_y - 0.42 * u), (fx - 0.55 * u, hat_y - 0.32 * u)], fill=rgba(trim))

img = banded_sky(W, H, [NIGHT1, NIGHT2, NIGHT3, DUSK, EMBER], 9)
d = ImageDraw.Draw(img)
rng = random.Random(12)
for _ in range(90):
    x, y = rng.uniform(0, W), rng.uniform(0, H * 0.5)
    r = rng.choice([4, 5, 6, 8])
    d.ellipse([x - r, y - r, x + r, y + r], fill=rgba(CREAM, rng.choice([140, 190, 230])))
moon(img, W * 0.70, H * 0.33, H * 0.22)
d = ImageDraw.Draw(img)
for bx, by, bs, flap in [(W * 0.60, H * 0.20, 150, 0.0), (W * 0.555, H * 0.47, 100, 0.2), (W * 0.79, H * 0.16, 120, -0.1), (W * 0.86, H * 0.30, 80, 0.15), (W * 0.52, H * 0.12, 70, 0.1)]:
    bat(d, bx, by, bs, rgba(INK), flap, int(bx))

# Far hills and the manor
far = ellipse_points(W * 0.78, H * 0.98, W * 0.45, H * 0.33, 160, math.pi, 2 * math.pi) + [(W, H), (W * 0.3, H)]
d.polygon(wobble(far, 5, 1), fill=rgba((54, 24, 70)))
manor(d, W * 0.80, H * 0.66, H * 0.13, rgba((40, 18, 54)), rgba(GLOW2))
near = ellipse_points(W * 0.18, H * 1.08, W * 0.5, H * 0.4, 160, math.pi, 2 * math.pi) + [(W * 0.7, H), (0, H)]
d.polygon(wobble(near, 5, 2), fill=rgba((44, 20, 58)))

# Dead trees
dead_tree(d, W * 0.06, H * 0.86, H * 0.9, rgba((26, 12, 34)), 3)
dead_tree(d, W * 0.95, H * 0.95, H * 0.75, rgba((26, 12, 34)), 9)

# Foreground ground with gravestones and a fence
ground = [(0, H * 0.84)] + [(x, H * 0.84 + math.sin(x / 260) * 18 - (x / W) * 40) for x in range(0, W + 1, 40)] + [(W, H), (0, H)]
for gx, gh, tilt in [(W * 0.30, 260, -6), (W * 0.37, 200, 8), (W * 0.88, 240, -4)]:
    stone = Image.new("RGBA", (260, gh + 60), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stone)
    sd.rounded_rectangle([30, 30, 230, gh + 30], radius=100, fill=rgba((66, 54, 84)), outline=rgba(INK), width=16)
    sd.text((130, 120), "RIP", font=ImageFont.truetype(FONT_XB, 60), fill=rgba(INK), anchor="mm")
    stone = stone.rotate(tilt, expand=True, resample=Image.BICUBIC)
    img.alpha_composite(stone, (int(gx - stone.width / 2), int(H * 0.86 - stone.height + 40)))
d = ImageDraw.Draw(img)
for i in range(9):
    x = W * 0.46 + i * 70
    d.rectangle([x, H * 0.80 - (i % 2) * 20, x + 22, H * 0.9], fill=rgba((30, 14, 38)))
d.rectangle([W * 0.46, H * 0.83, W * 0.46 + 8 * 70 + 22, H * 0.84], fill=rgba((30, 14, 38)))
d.polygon(ground, fill=rgba((22, 10, 30)))

# The hero, then pumpkins in front
warlock(img, W * 0.64, H * 0.90, H * 0.095)
pumpkin(img, W * 0.47, H * 0.90, H * 0.24, H * 0.19, seed=60)
pumpkin(img, W * 0.86, H * 0.93, H * 0.30, H * 0.24, seed=70)
pumpkin(img, W * 0.78, H * 0.95, H * 0.16, H * 0.13, seed=80)

# Title block
title_font = ImageFont.truetype(FONT_BLACK, 330)
text_with_shadow(img, (W * 0.245, H * 0.20), "DUNGEON", title_font, CREAM, INK, 22, rgba(EMBER), (22, 26))
text_with_shadow(img, (W * 0.245, H * 0.355), "DELVERS", title_font, CREAM, INK, 22, rgba(EMBER), (22, 26))

# Tilted ribbon: HALLOWEEN EVENT
ribbon_layer = Image.new("RGBA", (1700, 320), (0, 0, 0, 0))
rd = ImageDraw.Draw(ribbon_layer)
rw, rh, notch = 1600, 220, 80
ribbon = [(50, 50), (50 + rw, 50), (50 + rw - notch, 50 + rh / 2), (50 + rw, 50 + rh), (50, 50 + rh), (50 + notch, 50 + rh / 2)]
rd.polygon([(x + 16, y + 20) for x, y in ribbon], fill=rgba(INK))
draw_outlined_polygon(rd, ribbon, rgba(EMBER), rgba(INK), 16)
text_with_shadow(ribbon_layer, (50 + rw / 2, 50 + rh / 2 + 4), "HALLOWEEN EVENT", ImageFont.truetype(FONT_BLACK, 150), CREAM, INK, 12, rgba(INK), (8, 10))
ribbon_layer = ribbon_layer.rotate(4, expand=True, resample=Image.BICUBIC)
img.alpha_composite(ribbon_layer, (int(W * 0.245 - ribbon_layer.width / 2), int(H * 0.44)))

# Round sticker: NEW LIMITED CLASS
sticker = Image.new("RGBA", (620, 620), (0, 0, 0, 0))
sd = ImageDraw.Draw(sticker)
points = []
for i in range(36):
    r = 280 if i % 2 == 0 else 250
    a = i / 36 * 2 * math.pi
    points.append((310 + math.cos(a) * r, 310 + math.sin(a) * r))
sd.polygon([(x + 12, y + 14) for x, y in points], fill=rgba(INK))
draw_outlined_polygon(sd, points, rgba(GLOW), rgba(INK), 14)
sd.text((310, 230), "NEW", font=ImageFont.truetype(FONT_BLACK, 110), fill=rgba(INK), anchor="mm")
sd.text((310, 330), "LIMITED", font=ImageFont.truetype(FONT_BLACK, 86), fill=rgba((150, 40, 20)), anchor="mm")
sd.text((310, 415), "CLASS", font=ImageFont.truetype(FONT_BLACK, 86), fill=rgba((150, 40, 20)), anchor="mm")
sticker = sticker.rotate(-12, expand=True, resample=Image.BICUBIC)
img.alpha_composite(sticker, (int(W * 0.06), int(H * 0.60)))

# Small caption
cap_font = ImageFont.truetype(FONT_XB, 92)
text_with_shadow(img, (W * 0.335, H * 0.69), "NEW DUNGEON:", cap_font, CREAM, INK, 10, rgba(INK), (6, 8), anchor="lm")
text_with_shadow(img, (W * 0.335, H * 0.75), "HAUNTED MANOR", cap_font, GLOW, INK, 10, rgba(INK), (6, 8), anchor="lm")

img = grain(img, 6)
out = sys.argv[1]
img.convert("RGB").resize((1920, 1080), Image.LANCZOS).save(out, quality=95)
print("saved", out)
