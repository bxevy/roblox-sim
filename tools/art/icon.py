import sys
sys.path.insert(0, ".")
from draw import *

def make_icon(with_text: bool, out: str, size: int):
    S = 2048
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bg = Image.new("RGBA", (S, S), rgba(NIGHT1))
    d = ImageDraw.Draw(bg)
    # Concentric hard bands, lighter toward the moon
    cx, cy = S * 0.62, S * 0.3
    for i, col in enumerate([NIGHT1, (48, 22, 70), NIGHT2, (80, 36, 100), NIGHT3]):
        r = S * (1.05 - i * 0.17)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgba(col))
    # Stars
    rng = random.Random(3)
    for _ in range(40):
        x, y = rng.uniform(80, S - 80), rng.uniform(80, S * 0.55)
        r = rng.choice([4, 5, 7])
        d.ellipse([x - r, y - r, x + r, y + r], fill=rgba(CREAM, 200))
    moon(bg, S * 0.62, S * 0.30, S * 0.2)
    d = ImageDraw.Draw(bg)
    bat(d, S * 0.24, S * 0.22, 170, rgba(INK), 0.0, 1)
    bat(d, S * 0.80, S * 0.16, 120, rgba(INK), 0.15, 3)
    bat(d, S * 0.40, S * 0.12, 90, rgba(INK), -0.05, 5)
    # Hill with gravestones
    hill = ellipse_points(S * 0.5, S * 1.02, S * 0.75, S * 0.3, 120, math.pi, 2 * math.pi)
    hill = wobble(hill, 6, 2) + [(S * 1.3, S * 1.2), (-S * 0.3, S * 1.2)]
    for gx, gy, gw, gh, tilt in [(S * 0.16, S * 0.80, 150, 220, -8), (S * 0.84, S * 0.78, 170, 250, 6)]:
        stone = Image.new("RGBA", (gw + 40, gh + 40), (0, 0, 0, 0))
        sd = ImageDraw.Draw(stone)
        sd.rounded_rectangle([20, 20, gw + 20, gh + 20], radius=gw // 2, fill=rgba((70, 60, 88)), outline=rgba(INK), width=14)
        sd.line([(gw // 2 + 20, 60), (gw // 2 + 20, 140)], fill=rgba(INK), width=14)
        sd.line([(gw // 2 - 20, 90), (gw // 2 + 60, 90)], fill=rgba(INK), width=14)
        stone = stone.rotate(tilt, expand=True, resample=Image.BICUBIC)
        bg.alpha_composite(stone, (int(gx - stone.width / 2), int(gy - stone.height / 2)))
    d = ImageDraw.Draw(bg)
    d.polygon(hill, fill=rgba((20, 10, 28)))
    pumpkin(bg, S * 0.5, S * (0.64 if with_text else 0.66), S * 0.68, S * 0.52, seed=11)

    if with_text:
        # Ribbon banner with notched ends
        y = S * 0.86
        h = S * 0.13
        x0, x1 = S * 0.06, S * 0.94
        notch = h * 0.35
        ribbon = [(x0, y - h / 2), (x1, y - h / 2), (x1 - notch, y), (x1, y + h / 2), (x0, y + h / 2), (x0 + notch, y)]
        d.polygon([(x + 14, yy + 18) for x, yy in ribbon], fill=rgba(INK))
        draw_outlined_polygon(d, ribbon, rgba(EMBER), rgba(INK), 16)
        font = ImageFont.truetype(FONT_BLACK, int(S * 0.105))
        text_with_shadow(bg, (S * 0.5, y + 4), "HALLOWEEN", font, CREAM, INK, 14, rgba(INK), (10, 12))

    # Rounded-square badge with a thick ember frame
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
