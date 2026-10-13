"""Cuts the enemy warrior sprite sheets into transparent animation strips.

The sheets in assets/ui/{luzon,visayas,mindanao}_warrior_enemy are drawn on a
black background with three difficulty columns (EASY / MEDIUM / HARD) and one
labelled row per animation (IDLE, WALK, TALK, ATTACK, HURT, DIE). The Tagalog
sheet stacks the three difficulties instead, with four rows each.

For every language and difficulty this writes
    assets/ui/enemies/<language code>/<difficulty>_<animation>.png
a horizontal strip of square frames (frame count = width / height) with the
black background made transparent. The game (scripts/autoload/ui.gd,
enemy_sprite) plays these strips during the quiz.

Usage (needs Pillow, numpy and scipy):
    python tools/art/extract_enemy_sprites.py <assets/ui folder> [output folder]
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

# Sheet file (relative to assets/ui) for each language code in seed_data.json.
SHEETS = {
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
ROWS_SIX = ["idle", "walk", "talk", "attack", "hurt", "die"]
ROWS_FOUR = ["idle", "walk", "talk", "attack"]
KEEP = ["idle", "attack", "hurt", "die"]
BLACK = 26        # max channel at or below this counts as background black
FG = 60           # max channel above this counts as drawn pixels


def runs(values, threshold, min_len, join=0):
    """(start, end) of the stretches where values > threshold."""
    out, start = [], None
    for i, v in enumerate(list(values) + [0]):
        if v > threshold and start is None:
            start = i
        elif v <= threshold and start is not None:
            out.append([start, i])
            start = None
    merged = []
    for a, b in out:
        if merged and a - merged[-1][1] <= join:
            merged[-1][1] = b
        else:
            merged.append([a, b])
    return [(a, b) for a, b in merged if b - a >= min_len]


def find_pills(lum, x0, x1, y0, y1):
    """Centres (y) of the animation label pills between columns x0..x1."""
    prof = (lum[y0:y1, x0:x1] > FG).sum(axis=1)
    return [y0 + (a + b) // 2 for a, b in runs(prof, (x1 - x0) * 0.6, 22, join=6)]


def layout(lum):
    """Yields (difficulty, rows, pill_centres, frames_x0, frames_x1)."""
    h, w = lum.shape
    # Standard sheets: three columns, pills at the left of each column.
    col_w = w // 3
    found = []
    for d in range(3):
        x0 = d * col_w
        # Big character art can reach down to the first pill; the six
        # animation pills are always the bottom six.
        found.append(find_pills(lum, x0 + 18, x0 + 60, h // 3, h)[-6:])
    if all(len(p) == 6 for p in found):
        for d in range(3):
            yield d + 1, ROWS_SIX, found[d], d * col_w + 104, (d + 1) * col_w, True
        return
    # Tagalog-style sheet: difficulties stacked, pills around x = 0.16 * w.
    pills = find_pills(lum, int(w * 0.17), int(w * 0.195), 0, h)
    if len(pills) != 12:
        raise ValueError("unrecognised sheet layout (%d pills)" % len(pills))
    for d in range(3):
        yield d + 1, ROWS_FOUR, pills[d * 4:d * 4 + 4], int(w * 0.225), w, False


def frame_centres(fg_band, grid, fallback_n=None):
    """x centres of the frames in one animation row.

    grid=False: frames are separated by black gaps (Tagalog sheet).
    grid=True: frames sit on an even grid but glows and slashes can bridge
    the gaps, so the frame count is the largest n whose cell borders all
    fall on (nearly) empty columns.
    """
    prof = fg_band.sum(axis=0)
    segs = runs(prof, 2, 8)
    # Drop specks (stray sparkles, a corner of the next block's art).
    segs = [(a, b) for a, b in segs if b - a >= 20]
    if not segs:
        return []
    if not grid:
        # Slashes can join neighbouring frames: split segments that are
        # much wider than the usual frame.
        widths = sorted(b - a for a, b in segs)
        usual = fallback_n or widths[len(widths) // 2]
        centres = []
        for a, b in segs:
            n = max(1, round((b - a) / (usual * 1.1)))
            centres += [a + (b - a) * (k + 0.5) / n for k in range(n)]
        return centres
    first, last = segs[0][0], segs[-1][1]
    width = last - first
    h = fg_band.shape[0]
    best = None
    for n in (3, 4, 5, 6):
        cell = width / n
        worst = 0.0
        for k in range(1, n):
            x = int(first + k * cell)
            worst = max(worst, prof[max(0, x - 4):x + 5].min() / h)
        if worst < 0.06:
            best = n
    n = best or fallback_n or 4
    cell = width / n
    return [first + cell * (k + 0.5) for k in range(n)]


def clean(cell, half_width):
    """Black background -> transparent; drops bits of neighbouring frames.

    Only drawn parts touching the middle of the cell are kept, and nothing
    further than half_width from the centre line.
    """
    rgb = cell[:, :, :3].astype(int)
    lum = rgb.max(axis=2)
    dark = lum <= BLACK
    labels, _ = ndimage.label(dark)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])))
    border.discard(0)
    bg = np.isin(labels, list(border))
    fg = ~bg
    flab, n = ndimage.label(fg)
    h, w = fg.shape
    keep = np.zeros_like(fg)
    cy0, cy1, cx0, cx1 = int(h * 0.3), int(h * 0.7), int(w * 0.35), int(w * 0.65)
    for i, sl in enumerate(ndimage.find_objects(flab), start=1):
        if sl is None:
            continue
        ys, xs = sl
        if ys.stop > cy0 and ys.start < cy1 and xs.stop > cx0 and xs.start < cx1:
            keep |= flab == i
    lo, hi = int(w / 2 - half_width), int(w / 2 + half_width)
    keep[:, :max(0, lo)] = False
    keep[:, max(0, hi):] = False
    alpha = np.where(keep, 255, 0).astype(np.uint8)
    # Soften the edge against the old black background.
    edge = keep & (lum < BLACK + 30)
    alpha[edge] = np.clip((lum[edge] - BLACK) * 255 // 30, 60, 255)
    return np.dstack([rgb.astype(np.uint8), alpha])


def row_cuts(lum, pills, fx0, fx1):
    """y lines between the animation rows: the emptiest line between pills."""
    prof = (lum[:, fx0:fx1] > BLACK).sum(axis=1)
    spacing = int(np.median(np.diff(pills)))
    cuts = []
    edges = [pills[0] - spacing] + pills + [pills[-1] + spacing]
    for a, b in zip(edges, edges[1:]):
        # Search the middle part only, so a cut never slices through a row;
        # the outer edges stay close to the rows so the big character art
        # above the first row is left out.
        lo, hi = a + (b - a) * 3 // 10, b - (b - a) * 3 // 10
        lo, hi = max(0, lo), min(len(prof) - 1, hi)
        cuts.append(lo + int(np.argmin(prof[lo:hi + 1])))
    return cuts


def extract(sheet_path, out_dir):
    img = np.array(Image.open(sheet_path).convert("RGB"))
    lum = img.max(axis=2)
    os.makedirs(out_dir, exist_ok=True)
    written = []
    blocks = list(layout(lum))
    # The EASY column has no glowing auras, so its gaps between rows are
    # clean. Its row bands (relative to the label pills) are reused for
    # MEDIUM and HARD, whose effects often bridge the gaps.
    ref = blocks[0]
    ref_cuts = row_cuts(lum, ref[2], ref[3], ref[4])
    for diff, rows, pills, fx0, fx1, grid in blocks:
        if grid:
            cuts = [p + c - q for p, c, q in zip(pills + [pills[-1]], ref_cuts, ref[2] + [ref[2][-1]])]
        else:
            cuts = row_cuts(lum, pills, fx0, fx1)
        size = max(b - a for a, b in zip(cuts, cuts[1:]))  # square frames
        half = size // 2
        idle_n = None
        for r, name in enumerate(rows):
            y0, y1 = cuts[r], cuts[r + 1]
            band = img[y0:y1, fx0:fx1]
            fg_band = band.max(axis=2) > FG
            centres = frame_centres(fg_band, grid, idle_n)
            if name == "idle":
                if grid:
                    idle_n = len(centres)
                else:
                    segs = runs(fg_band.sum(axis=0), 2, 8)
                    idle_n = sorted(b - a for a, b in segs)[len(segs) // 2]
            if name not in KEEP or not centres:
                continue
            pitch = (centres[-1] - centres[0]) / (len(centres) - 1) if len(centres) > 1 else size
            reach = pitch * (0.58 if grid else 0.75)
            strip = Image.new("RGBA", (size * len(centres), size))
            for i, cx in enumerate(centres):
                x0 = int(fx0 + cx - half)
                window = np.zeros((y1 - y0, size, 3), np.uint8)
                sx0, sx1 = max(fx0, x0), min(fx1, x0 + size)
                window[:, sx0 - x0:sx1 - x0] = img[y0:y1, sx0:sx1]
                # Feet on the bottom edge of the cell, like the sheet's rows.
                strip.paste(Image.fromarray(clean(window, reach), "RGBA"), (i * size, size - (y1 - y0)))
            path = os.path.join(out_dir, "%d_%s.png" % (diff, name))
            strip.save(path, optimize=True)
            written.append((path, len(centres)))
    return written


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(src, "enemies")
    for code, rel in SHEETS.items():
        for path, frames in extract(os.path.join(src, rel), os.path.join(dst, code)):
            print("%-40s %d frames" % (os.path.relpath(path, dst), frames))


if __name__ == "__main__":
    main()
