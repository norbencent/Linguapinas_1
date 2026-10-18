"""Draw an illustrated card for every culture item in database/seed_data.json.

Writes assets/culture/<image>.png (640x360): the region's colors, a woven
pattern, an icon for the kind of item (festival, food, landmark, ...) and
its name. These are placeholders: to use a real photo or drawing instead,
save it as assets/culture/<image>.png with the same name (any size, it is
cropped to fit) and the game shows it.

Run from the project root:  python tools/art/make_culture_cards.py
Pass --all to redraw cards that already exist (by default existing files,
such as photos you added, are kept).
Needs: pip install pillow
"""

import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "culture")
FONTS = os.path.join(ROOT, "assets", "fonts")
W, H = 640, 360

REGION = {  # dark, light, accent
    "luzon": ((122, 16, 14), (214, 52, 40), (255, 210, 90)),
    "visayas": ((14, 40, 110), (40, 104, 200), (255, 220, 120)),
    "mindanao": ((120, 70, 6), (226, 160, 24), (255, 245, 200)),
}
CREAM = (255, 246, 222)
INK = (52, 26, 10)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def background(region):
    dark, light, accent = REGION[region]
    img = Image.new("RGB", (W, H), dark)
    px = img.load()
    for y in range(H):
        for x in range(W):
            t = min(1.0, math.hypot(x - W * 0.5, y - H * 0.42) / (W * 0.62))
            px[x, y] = tuple(int(light[i] * (1 - t) + dark[i] * t) for i in range(3))
    # Woven diamond pattern, like a banig mat.
    over = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    step = 32
    for y in range(-step, H + step, step):
        for x in range(-step, W + step, step):
            off = step // 2 if (y // step) % 2 else 0
            cx, cy = x + off, y
            d.polygon([(cx, cy - 9), (cx + 9, cy), (cx, cy + 9), (cx - 9, cy)], outline=accent + (38,), width=2)
    img = Image.alpha_composite(img.convert("RGBA"), over)
    # Gold frame.
    d = ImageDraw.Draw(img)
    d.rectangle([6, 6, W - 7, H - 7], outline=accent + (255,), width=4)
    d.rectangle([14, 14, W - 15, H - 15], outline=accent + (120,), width=2)
    return img


# ---------------------------------------------------------------- icons
# Each draws on a transparent 240x200 canvas, centred at (120, 100).

def icon_landmark(d):
    d.ellipse([150, 22, 196, 68], fill=(255, 214, 90), outline=INK, width=4)
    d.polygon([(10, 180), (90, 50), (170, 180)], fill=CREAM, outline=INK, width=5)
    d.polygon([(90, 50), (70, 84), (84, 78), (96, 90), (110, 82)], fill=(255, 255, 255), outline=INK, width=3)
    d.polygon([(110, 180), (170, 92), (232, 180)], fill=(230, 214, 180), outline=INK, width=5)


def icon_heritage(d):
    d.polygon([(20, 92), (120, 22), (220, 92)], fill=(214, 120, 60), outline=INK, width=5)
    d.rectangle([40, 92, 200, 182], fill=CREAM, outline=INK, width=5)
    d.rectangle([98, 120, 142, 182], fill=(150, 90, 40), outline=INK, width=4)
    for x in (54, 160):
        d.rectangle([x, 108, x + 28, 136], fill=(120, 190, 230), outline=INK, width=4)
        d.line([x + 14, 108, x + 14, 136], fill=INK, width=3)


def icon_festival(d):
    d.arc([0, -40, 240, 90], 20, 160, fill=INK, width=4)
    colors = [(230, 60, 50), (40, 110, 220), (250, 200, 40), (60, 170, 80), (230, 60, 50), (40, 110, 220)]
    for i, c in enumerate(colors):
        x = 26 + i * 36
        y = 44 + int(26 * math.sin(math.pi * (i + 0.5) / len(colors)))
        d.polygon([(x - 14, y), (x + 14, y), (x, y + 30)], fill=c, outline=INK, width=3)
    # Festival mask.
    d.ellipse([70, 92, 170, 190], fill=CREAM, outline=INK, width=5)
    d.ellipse([92, 122, 112, 140], fill=INK)
    d.ellipse([128, 122, 148, 140], fill=INK)
    d.arc([96, 132, 144, 172], 20, 160, fill=INK, width=5)
    for a, c in ((-60, (230, 60, 50)), (-90, (250, 200, 40)), (-120, (60, 170, 80))):
        x = 120 + 70 * math.cos(math.radians(a))
        y = 110 + 70 * math.sin(math.radians(a))
        d.line([120, 100, x, y], fill=c, width=9)


def icon_food(d):
    for i, x in enumerate((80, 120, 160)):
        pts = [(x + 10 * math.sin(t / 3 + i), 20 + t * 3) for t in range(0, 22)]
        d.line(pts, fill=CREAM, width=6)
    d.chord([20, 50, 220, 190], 0, 180, fill=CREAM, outline=INK, width=5)
    d.rectangle([20, 116, 220, 124], fill=CREAM)
    d.line([20, 120, 220, 120], fill=INK, width=5)
    d.ellipse([46, 104, 194, 136], fill=(240, 236, 220), outline=INK, width=4)
    for x, y in ((80, 112), (110, 108), (140, 114), (165, 110)):
        d.ellipse([x - 9, y - 6, x + 9, y + 6], fill=(214, 120, 60), outline=INK, width=2)
    d.rectangle([92, 186, 148, 196], fill=CREAM, outline=INK, width=4)


def icon_clothing(d):
    d.polygon([(70, 30), (100, 22), (120, 40), (140, 22), (170, 30), (220, 70), (196, 104),
               (172, 88), (172, 186), (68, 186), (68, 88), (44, 104), (20, 70)],
              fill=CREAM, outline=INK, width=5)
    for y in range(60, 180, 20):
        d.line([102, y, 138, y + 10], fill=(200, 170, 120), width=3)
        d.line([138, y, 102, y + 10], fill=(200, 170, 120), width=3)
    d.line([120, 40, 120, 186], fill=INK, width=3)


def icon_textile(d):
    d.rectangle([30, 20, 210, 180], fill=CREAM, outline=INK, width=5)
    colors = [(200, 40, 40), (30, 30, 30), (250, 190, 40)]
    for row in range(4):
        for col in range(4):
            cx, cy = 52 + col * 46, 40 + row * 40
            c = colors[(row + col) % 3]
            d.polygon([(cx, cy - 16), (cx + 18, cy), (cx, cy + 16), (cx - 18, cy)], fill=c, outline=INK, width=2)
    for x in range(36, 206, 12):
        d.line([x, 182, x, 196], fill=INK, width=3)


def icon_art(d):
    # Okir-style curling scroll.
    d.rectangle([20, 30, 220, 170], fill=CREAM, outline=INK, width=5)
    for cx, flip in ((80, 1), (160, -1)):
        for r in (44, 32, 20, 9):
            d.arc([cx - r, 100 - r, cx + r, 100 + r], 180 if flip == 1 else 0, 360 if flip == 1 else 180,
                  fill=(40, 120, 70), width=6)
    d.line([30, 100, 210, 100], fill=(200, 60, 40), width=5)


def icon_craft(d):
    # Capiz-shell style scallop.
    d.pieslice([20, 30, 220, 230], 200, 340, fill=CREAM, outline=INK, width=5)
    for a in range(205, 340, 15):
        x = 120 + 100 * math.cos(math.radians(a))
        y = 130 + 100 * math.sin(math.radians(a))
        d.line([120, 130, x, y], fill=INK, width=3)
    d.rectangle([92, 128, 148, 176], fill=CREAM, outline=INK, width=5)


def icon_dance(d):
    # Two fans.
    for cx, start in ((80, 200), (160, 250)):
        d.pieslice([cx - 80, 40, cx + 80, 200], start, start + 110, fill=CREAM, outline=INK, width=5)
        for a in range(start, start + 111, 18):
            x = cx + 80 * math.cos(math.radians(a))
            y = 120 + 80 * math.sin(math.radians(a))
            d.line([cx, 120, x, y], fill=(200, 60, 40), width=3)
    d.ellipse([108, 150, 132, 174], fill=(250, 200, 40), outline=INK, width=3)


def icon_music(d):
    # A row of kulintang gongs on a frame.
    d.rectangle([10, 110, 230, 128], fill=(150, 90, 40), outline=INK, width=4)
    for i in range(5):
        cx = 34 + i * 43
        d.ellipse([cx - 20, 70, cx + 20, 110], fill=(230, 180, 60), outline=INK, width=4)
        d.ellipse([cx - 8, 80, cx + 8, 96], fill=(255, 220, 120), outline=INK, width=3)
    d.line([60, 150, 110, 186], fill=INK, width=7)
    d.line([180, 150, 130, 186], fill=INK, width=7)


ICONS = {"landmark": icon_landmark, "heritage": icon_heritage, "festival": icon_festival,
         "food": icon_food, "clothing": icon_clothing, "textile": icon_textile, "art": icon_art,
         "craft": icon_craft, "dance": icon_dance, "music": icon_music}


def draw_card(item):
    dark, light, accent = REGION[item["region_code"]]
    img = background(item["region_code"])
    icon = Image.new("RGBA", (240, 200), (0, 0, 0, 0))
    ICONS.get(item["kind"].lower(), icon_heritage)(ImageDraw.Draw(icon))
    shadow = icon.split()[3].filter(ImageFilter.GaussianBlur(6))
    img.paste(Image.new("RGBA", icon.size, (0, 0, 0, 110)), (W // 2 - 120 + 6, 40 + 8), shadow)
    img.alpha_composite(icon, (W // 2 - 120, 40))

    d = ImageDraw.Draw(img)
    # Kind pill.
    kf = font("LilitaOne-Regular.ttf", 22)
    kind = item["kind"].upper()
    kw = d.textlength(kind, font=kf)
    d.rounded_rectangle([26, 26, 26 + kw + 28, 60], radius=16, fill=accent, outline=INK, width=3)
    d.text((40, 30), kind, font=kf, fill=INK)
    # Title ribbon.
    d.rectangle([16, H - 104, W - 17, H - 30], fill=(30, 14, 6))
    d.line([16, H - 104, W - 17, H - 104], fill=accent, width=3)
    d.line([16, H - 30, W - 17, H - 30], fill=accent, width=3)
    size = 40
    tf = font("Cinzel-Black.ttf", size)
    while d.textlength(item["title"], font=tf) > W - 70 and size > 20:
        size -= 2
        tf = font("Cinzel-Black.ttf", size)
    tw = d.textlength(item["title"], font=tf)
    d.text(((W - tw) / 2, H - 67), item["title"], font=tf, fill=accent, anchor="lm",
           stroke_width=2, stroke_fill=(0, 0, 0))
    return img.convert("RGB")


def main() -> int:
    redraw = "--all" in sys.argv
    with open(os.path.join(ROOT, "database", "seed_data.json"), encoding="utf-8") as f:
        items = json.load(f)["culture_items"]
    os.makedirs(OUT, exist_ok=True)
    made = 0
    for item in items:
        path = os.path.join(OUT, item["image"] + ".png")
        if os.path.exists(path) and not redraw:
            continue
        draw_card(item).save(path, optimize=True)
        made += 1
    print(f"drew {made} cards in {os.path.relpath(OUT, ROOT)} ({len(items) - made} kept)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
