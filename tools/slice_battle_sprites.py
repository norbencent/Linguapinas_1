"""Find the animation frames on the hero and warrior sprite sheets.

Writes scripts/battle/sprite_frames.gd with the frame rectangles the quiz
battle uses. Run from the project root after changing a sheet:

    python3 tools/slice_battle_sprites.py <folder holding the sheets>

The folder is the one with "Luzon Heroes boy and girl.png" and the
*_warrior_enemy folders (assets/ui in the Godot project).
"""
import os
import sys

import numpy as np
from PIL import Image

HEROES = {
    "luzon": ("Luzon Heroes boy and girl.png", 395),
    "visayas": ("Visayan Heroes boy and girl.png", 425),
    "mindanao": ("Mindanao Heroes boy and girl.png", 392),
}
# [y0, y1) of the rows used, measured on each sheet (the hero sheets have no
# separable label plates, and their rows touch the "DOWN/LEFT..." captions)
HERO_ROWS = {
    "luzon": {"boy": {"idle": (4, 100), "attack": (227, 353)},
              "girl": {"idle": (501, 600), "attack": (744, 880)}},
    "visayas": {"boy": {"idle": (10, 116), "attack": (229, 371)},
                "girl": {"idle": (492, 594), "attack": (702, 816)}},
    "mindanao": {"boy": {"idle": (11, 129), "attack": (250, 383)},
                 "girl": {"idle": (509, 626), "attack": (740, 884)}},
}
# The attack rows overlap (sword trails run into the next frame), so their
# frames are cut at hand-picked x positions, relative to the row start above.
HERO_ATTACK_CUTS = {
    "luzon": {"boy": [0, 118, 245, 370, 560, 690, 805, 940, 1070],
              "girl": [0, 95, 185, 360, 530, 720, 840, 990, 1140]},
    "visayas": {"boy": [0, 150, 290, 395, 670, 800, 940, 1110, 1290],
                "girl": [0, 100, 205, 430, 545, 715, 820, 915, 1045, 1150, 1300]},
    "mindanao": {"boy": [0, 190, 300, 430, 680, 830, 990, 1150, 1300],
                 "girl": [0, 100, 200, 300, 480, 600, 740, 850, 960, 1085, 1190, 1300]},
}

# language code -> sheet (relative to the sheet folder)
ENEMIES = {
    "tl": "luzon_warrior_enemy/Tagalog_animation.png",
    "ilo": "luzon_warrior_enemy/Ilocano Warrior_animation.png",
    "pag": "luzon_warrior_enemy/Pangasinan_warrior_animation.png",
    "pam": "luzon_warrior_enemy/Kapampangan_warrior_animation.png",
    "bcl": "luzon_warrior_enemy/Bikolano_Warrior_animation.png",
    "ibg": "luzon_warrior_enemy/Ibanag_Warrior_animation.png",
    "kne": "luzon_warrior_enemy/Kankanaey_warrior_animation.png",
    "ivv": "luzon_warrior_enemy/Ivatan_warrior_animation.png",
    "ifk": "luzon_warrior_enemy/Ifugao_Warrioanimation.png",
    "kal": "luzon_warrior_enemy/Kalinga_Warrior_animation.png",
    "ceb": "visayas_warrior_enemy/Cebuano_Warrior_animation.png",
    "hil": "visayas_warrior_enemy/Hiligaynon_warrior_animation.png",
    "war": "visayas_warrior_enemy/Waray-Waray_Warrior_animation.png",
    "akl": "visayas_warrior_enemy/Aklanon_warrior_animation.png",
    "cps": "visayas_warrior_enemy/Capiznon_warrior_animation.png",
    "msb": "visayas_warrior_enemy/Masbateño _warrior_animation.png",
    "rol": "visayas_warrior_enemy/Rombolomanon_warriror_animation.png",
    "cyo": "visayas_warrior_enemy/Cuyonon_warrior_animation.png",
    "prh": "visayas_warrior_enemy/Porohanon_Warrior_animation.png",
    "bis": "mindanao_warrior_enemy/Bisaya_Warrior_animation.png",
    "tsg": "mindanao_warrior_enemy/Tausug_warrior_animation.png",
    "mdh": "mindanao_warrior_enemy/Maguindanaon_Warrior_animation.png",
    "mrw": "mindanao_warrior_enemy/Maranao_Warrior_animation.png",
    "mba": "mindanao_warrior_enemy/Higaonon_Warrior_animation.png",
    "sgd": "mindanao_warrior_enemy/Surigaonon_warrior_animation.png",
    "bla": "mindanao_warrior_enemy/Blaan_Warrior_animation.png",
    "cbk": "mindanao_warrior_enemy/Chavacano_Warrior_animation.png",
    "yka": "mindanao_warrior_enemy/Yakan_Warrior_animation.png",
}
# Sheets laid out differently from the 3-column EASY/MEDIUM/HARD template:
# per level, (x_start, [y centre of the idle, walk, talk, attack rows],
# {row: frame count}). Its frames touch, so they are cut by count.
ENEMY_LAYOUTS = {
    "tl": [(335, [50, 120, 196, 271], {"idle": 10, "attack": 12}),
           (335, [367, 439, 512, 600], {"idle": 11, "attack": 10}),
           (335, [705, 785, 865, 956], {"idle": 13, "attack": 13})],
}
ENEMY_ROWS = ["idle", "walk", "talk", "attack", "hurt", "die"]


def runs(flags, min_gap=1):
    """[start, end) runs of True, joining runs split by gaps < min_gap."""
    out = []
    start = None
    for i, f in enumerate(flags):
        if f and start is None:
            start = i
        elif not f and start is not None:
            out.append([start, i])
            start = None
    if start is not None:
        out.append([start, len(flags)])
    joined = []
    for r in out:
        if joined and r[0] - joined[-1][1] < min_gap:
            joined[-1][1] = r[1]
        else:
            joined.append(r)
    return joined


def frames_in_band(mask, x0, x1, y0, y1, expected_w):
    """Frame rects [x, y, w, h] for the sprites in one animation row."""
    band = mask[y0:y1, x0:x1]
    pieces = runs(band.sum(axis=0) > 1, 3)
    pieces = [p for p in pieces if p[1] - p[0] >= 6]
    # drop thin specks, keep the rest
    pieces = [p for p in pieces if band[:, p[0]:p[1]].sum() > 150]
    cols = band.sum(axis=0)
    out = []
    for a, b in pieces:
        w = b - a
        n = max(1, int(round(w / expected_w))) if w > expected_w * 1.6 else 1
        # touching sprites: cut at the emptiest column near each even split
        cuts = [a]
        for k in range(1, n):
            guess = a + w * k // n
            span = int(w / n * 0.3)
            cuts.append(guess - span + int(np.argmin(cols[guess - span:guess + span])))
        cuts.append(b)
        for pa, pb in zip(cuts, cuts[1:]):
            rect = trim(mask, [x0 + pa, y0, pb - pa, y1 - y0])
            if rect:
                out.append(rect)
    return out


def trim(mask, rect):
    """Shrink rect to its main sprite, dropping bits of the neighbours."""
    from scipy import ndimage
    x, y, w, h = rect
    cell = mask[y:y + h, x:x + w]
    lab, n = ndimage.label(cell, structure=np.ones((3, 3)))
    if n == 0:
        return None
    areas = ndimage.sum(cell, lab, range(1, n + 1))
    keep = np.isin(lab, [i + 1 for i, a in enumerate(areas) if a >= areas.max() * 0.12])
    ys = np.nonzero(keep.any(axis=1))[0]
    xs = np.nonzero(keep.any(axis=0))[0]
    return [x + int(xs[0]), y + int(ys[0]), int(xs[-1] - xs[0]) + 1, int(ys[-1] - ys[0]) + 1]


def frames_between(mask, cuts, y0, y1):
    """Frames between consecutive x cut positions, trimmed to their pixels."""
    out = []
    for a, b in zip(cuts, cuts[1:]):
        out.append(trim(mask, [a, y0, b - a, y1 - y0]))
    return out


def frames_by_count(mask, x0, x1, y0, y1, count):
    """Cut a row of touching frames into `count` frames at the emptiest columns."""
    band = mask[y0:y1, x0:x1]
    cols = band.sum(axis=0)
    xs = np.nonzero(cols > 1)[0]
    a, b = int(xs[0]), int(xs[-1]) + 1
    pitch = (b - a) / count
    cuts = [a]
    for k in range(1, count):
        guess = int(a + pitch * k)
        lo, hi = guess - int(pitch * 0.3), guess + int(pitch * 0.3)
        cuts.append(lo + int(np.argmin(cols[lo:hi])))
    cuts.append(b)
    out = []
    for pa, pb in zip(cuts, cuts[1:]):
        out.append(trim(mask, [x0 + pa, y0, pb - pa, y1 - y0]))
    return out


def hero_frames(folder):
    result = {}
    for region, (name, x_start) in HEROES.items():
        a = np.asarray(Image.open(os.path.join(folder, name)).convert("RGBA")).astype(int)
        mask = a[:, :, 3] > 128
        w = mask.shape[1]
        result[region] = {}
        for avatar, anims in HERO_ROWS[region].items():
            result[region][avatar] = {}
            for anim, (y0, y1) in anims.items():
                if anim == "attack":
                    cuts = [x_start + c for c in HERO_ATTACK_CUTS[region][avatar]]
                    frames = frames_between(mask, cuts, y0, y1)
                else:
                    frames = frames_in_band(mask, x_start, w, y0, y1, (y1 - y0) * 0.75)
                if anim == "idle":
                    # first group (facing the player / "down")
                    group = [frames[0]]
                    for f in frames[1:]:
                        prev = group[-1]
                        if f[0] - (prev[0] + prev[2]) > 40:
                            break
                        group.append(f)
                    frames = group
                result[region][avatar][anim] = frames
    return result


def find_labels(rgb):
    """Bounding boxes of the IDLE/WALK/... label plates (solid red or blue)."""
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    fill = ((r > 85) & (r < 160) & (g < 25) & (b < 25)) | ((b > 90) & (r < 30) & (g < 40) & (b > g * 3))
    from scipy import ndimage
    lab, n = ndimage.label(fill)
    boxes = []
    for sl in ndimage.find_objects(lab):
        ys, xs = sl
        bw, bh = xs.stop - xs.start, ys.stop - ys.start
        area = fill[sl].sum()
        if 60 <= bw <= 120 and 20 <= bh <= 50 and area > bw * bh * 0.45:
            # the EASY/MEDIUM/HARD title banners sit at the top
            if ys.start > 350:
                boxes.append((xs.start, ys.start, xs.stop, ys.stop))
    return boxes


def enemy_frames(folder):
    result = {}
    for code, rel in ENEMIES.items():
        rgb = np.asarray(Image.open(os.path.join(folder, rel)).convert("RGB")).astype(int)
        mask = rgb.max(axis=2) > 45
        h, w = mask.shape
        entry = {"sheet": rel, "levels": []}
        if code in ENEMY_LAYOUTS:
            for x_start, centers, counts in ENEMY_LAYOUTS[code]:
                spacing = (centers[-1] - centers[0]) / (len(centers) - 1)
                level = {}
                for name, c in (("idle", centers[0]), ("attack", centers[3])):
                    y0 = int(c - spacing * 0.5)
                    y1 = int(c + spacing * (0.62 if name == "attack" else 0.45))
                    level[name] = frames_by_count(mask, x_start, w, y0, min(h, y1), counts[name])
                entry["levels"].append(level)
            result[code] = entry
            continue
        labels = find_labels(rgb)
        # group plates into columns by x
        labels.sort(key=lambda bx: bx[0])
        columns = []
        for bx in labels:
            if columns and abs(bx[0] - columns[-1][0][0]) < 40:
                columns[-1].append(bx)
            else:
                columns.append([bx])
        columns = [sorted(c, key=lambda bx: bx[1]) for c in columns]
        columns = [c for c in columns if len(c) >= 3]
        assert len(columns) == 3, (rel, [len(c) for c in columns])
        full = [c for c in columns if len(c) == 6]
        assert full, rel
        for i, col in enumerate(columns):
            x_end = columns[i + 1][0][0] - 4 if i + 1 < len(columns) else w
            x_start = max(bx[2] for bx in col) + 4
            names = ENEMY_ROWS
            # a column with a plate the detector missed uses another column's rows
            centers = [(bx[1] + bx[3]) / 2 for bx in (col if len(col) == 6 else full[0])]
            spacing = (centers[-1] - centers[0]) / (len(centers) - 1)
            level = {}
            for name, c in zip(names, centers):
                if name not in ("idle", "attack", "hurt"):
                    continue
                y0 = int(c - spacing * 0.5)
                y1 = int(c + spacing * 0.5)
                # every row of the template has 4 frames (the hard attack's
                # closing burst rides along with its last frame)
                level[name] = frames_by_count(mask, x_start, x_end, max(0, y0), min(h, y1), 4)
            entry["levels"].append(level)
        result[code] = entry
    return result


def gd_value(v, indent=1):
    tab = "\t" * indent
    if isinstance(v, dict):
        items = ",\n".join("%s%s: %s" % (tab, '"%s"' % k, gd_value(x, indent + 1)) for k, x in v.items())
        return "{\n%s,\n%s}" % (items, "\t" * (indent - 1))
    if isinstance(v, list):
        if v and isinstance(v[0], list) and isinstance(v[0][0], int):
            return "[%s]" % ", ".join("Rect2(%d, %d, %d, %d)" % tuple(r) for r in v)
        items = ",\n".join(tab + gd_value(x, indent + 1) for x in v)
        return "[\n%s,\n%s]" % (items, "\t" * (indent - 1))
    if isinstance(v, str):
        return '"%s"' % v
    return str(v)


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "assets/ui"
    heroes = hero_frames(folder)
    enemies = enemy_frames(folder)
    out = os.path.join(os.path.dirname(__file__), "..", "scripts", "battle", "sprite_frames.gd")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        f.write("## Frame rectangles on the hero and warrior sprite sheets.\n")
        f.write("## Generated by tools/slice_battle_sprites.py - do not edit by hand.\n\n")
        f.write('const HERO_SHEETS := {\n%s}\n\n' % "".join(
            '\t"%s": "res://assets/ui/%s",\n' % (r, HEROES[r][0]) for r in HEROES))
        f.write("const HEROES := %s\n\n" % gd_value(heroes))
        f.write("const ENEMIES := %s\n" % gd_value(enemies))
    print("wrote", os.path.normpath(out))
    return heroes, enemies


if __name__ == "__main__":
    main()
