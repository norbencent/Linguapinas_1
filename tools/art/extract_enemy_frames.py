"""Cut the warrior sprite sheets in assets/enemies/<region>/ into animation strips.

Each sheet shows one language's warrior at three levels (EASY / MEDIUM / HARD)
with rows labelled IDLE, WALK, TALK, ATTACK (and on most sheets HURT, DIE).
This finds the row labels, cuts every frame out of the IDLE, ATTACK and HURT
rows, removes the black background and writes one horizontal strip per
animation:

    assets/enemies/frames/<language code>_<level 1-3>_<idle|attack|hurt>.png

Every strip is a row of square frames, so frames = width / height.

Run from the project root:  python tools/art/extract_enemy_frames.py
Needs: pip install pillow numpy scipy
"""

import json
import os
import re
import sys
import unicodedata

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "enemies")
OUT = os.path.join(SRC, "frames")
SEED = os.path.join(ROOT, "database", "seed_data.json")

WANTED = ("idle", "attack", "hurt")
ROWS_SIDE_BY_SIDE = ["idle", "walk", "talk", "attack", "hurt", "die"]
ROWS_STACKED = ["idle", "walk", "talk", "attack"]
BG_LEVEL = 30          # max(r, g, b) below this is background
CELL_PAD = 4
GRID_FRAMES = 4        # frames per IDLE / ATTACK / HURT row on side-by-side sheets
FALLBACK_FIRST_ROW = 416
FALLBACK_PITCH = 101


def simple(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z]", "", s.lower())


def language_codes() -> dict:
    with open(SEED, encoding="utf-8") as f:
        langs = json.load(f)["languages"]
    codes = {simple(l["name"]): l["code"] for l in langs}
    codes["rombolomanon"] = codes.get("romblomanon")  # spelling on the sheet
    return codes


def sheet_language(filename: str, codes: dict):
    word = simple(re.split(r"[_ ]", os.path.basename(filename))[0])
    return codes.get(word)


def runs(flags, min_len=1):
    out, start = [], None
    for i, v in enumerate(flags):
        if v and start is None:
            start = i
        elif not v and start is not None:
            if i - start >= min_len:
                out.append((start, i))
            start = None
    if start is not None and len(flags) - start >= min_len:
        out.append((start, len(flags)))
    return out


def label_rows(fg: np.ndarray, x0: int, x1: int, count: int):
    """Vertical centres of the row labels in the strip x0..x1 (bottom-most `count`)."""
    flags = fg[:, x0:x1].sum(axis=1) > (x1 - x0) * 0.35
    found = [r for r in runs(flags, 12) if r[1] - r[0] <= 50]
    found = found[-count:]
    return [(a + b) // 2 for a, b in found]


def frame_spans(fg: np.ndarray, y0: int, y1: int, x0: int, x1: int, expect_w: float):
    cols = fg[y0:y1, x0:x1].sum(axis=0) > 2
    spans = [(a + x0, b + x0) for a, b in runs(cols, 6)]
    # Merge slivers into the nearest neighbour, split frames joined by effects.
    merged = []
    for a, b in spans:
        if merged and (b - a < expect_w * 0.3 or a - merged[-1][1] < 3) and (b - merged[-1][0]) < expect_w * 1.5:
            merged[-1] = (merged[-1][0], b)
        else:
            merged.append((a, b))
    out = []
    for a, b in merged:
        n = max(1, round((b - a) / expect_w))
        if (b - a) < expect_w * 0.35:
            continue
        step = (b - a) / n
        out += [(int(a + i * step), int(a + (i + 1) * step)) for i in range(n)]
    return out


def cut_frame(rgb: np.ndarray, y0, y1, x0, x1) -> Image.Image:
    crop = rgb[y0:y1, x0:x1]
    fg = crop.max(axis=2) > BG_LEVEL
    lab, n = ndi.label(ndi.binary_dilation(fg, iterations=1))
    if n == 0:
        return None
    h = crop.shape[0]
    idx = range(1, n + 1)
    sizes = np.array(ndi.sum(np.ones_like(lab), lab, idx))
    boxes = ndi.find_objects(lab)
    # The figure is the biggest piece crossing the middle of the cell; pieces of
    # the rows above and below only touch the top or bottom edge.
    middle = [i for i, b in enumerate(boxes) if b[0].start < h * 0.6 and b[0].stop > h * 0.4]
    if not middle:
        return None
    main = max(middle, key=lambda i: sizes[i])
    my0, my1 = boxes[main][0].start, boxes[main][0].stop
    keep_ids = [i + 1 for i, b in enumerate(boxes)
                if i == main or (sizes[i] >= sizes[main] * 0.04
                and my0 - 4 <= (b[0].start + b[0].stop) / 2 <= my1 + 4
                and not (b[0].start == 0 or b[0].stop == h))]
    keep = np.isin(lab, keep_ids) & fg
    # Dark pixels connected to the crop border are background.
    bg_lab, _ = ndi.label(~fg)
    border = set(np.unique(np.concatenate([bg_lab[0], bg_lab[-1], bg_lab[:, 0], bg_lab[:, -1]]))) - {0}
    keep &= ~np.isin(bg_lab, list(border))
    alpha = keep.astype(np.uint8) * 255
    img = Image.fromarray(np.dstack([crop.astype(np.uint8), alpha]), "RGBA")
    box = img.getbbox()
    return img.crop(box) if box else None


def write_strip(frames, path):
    frames = [f for f in frames if f is not None]
    if not frames:
        return False
    cell = max(max(f.width, f.height) for f in frames) + CELL_PAD * 2
    strip = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        # Feet on the bottom of the cell, centred horizontally.
        strip.paste(f, (i * cell + (cell - f.width) // 2, cell - CELL_PAD - f.height), f)
    strip.save(path, optimize=True)
    return True


def detected_side_rows(fg: np.ndarray, cx: int):
    """Label centres of the 6 rows in one level column, or None if not evenly spaced."""
    ys = label_rows(fg, cx + 14, cx + 100, 6)
    if len(ys) == 6:
        gaps = np.diff(ys)
        if gaps.min() > 85 and gaps.max() < 120:
            return ys
    return None


def side_by_side_rows(fg: np.ndarray, cx: int):
    return detected_side_rows(fg, cx) or [FALLBACK_FIRST_ROW + i * FALLBACK_PITCH for i in range(6)]


def stacked_rows(fg: np.ndarray):
    ys = label_rows(fg, 240, 330, 12)
    return ys if len(ys) == 12 else None


def grid_frames(rgb, fg, y, pitch, x0, x1):
    """Frames of a side-by-side row: the drawn extent split into equal cells."""
    y0, y1 = max(0, y - pitch // 2), min(rgb.shape[0], y + pitch // 2)
    cols = np.nonzero(fg[y0:y1, x0:x1].sum(axis=0) > 2)[0]
    if cols.size == 0:
        return []
    a, b = x0 + cols[0], x0 + cols[-1] + 1
    n = GRID_FRAMES
    step = (b - a) / n
    return [cut_frame(rgb, y0, y1, int(a + i * step), int(a + (i + 1) * step)) for i in range(n)]


def gap_frames(rgb, fg, y, pitch, x0, x1, expect):
    """Frames of a stacked-layout row, which has clear gaps between frames."""
    y0, y1 = max(0, y - pitch // 2), min(rgb.shape[0], y + pitch // 2)
    return [cut_frame(rgb, y0, y1, a, b) for a, b in frame_spans(fg, y0, y1, x0, x1, expect)]


def sheet_animations(rgb: np.ndarray):
    """{(level, anim): [frames]} for one sheet."""
    h, w, _ = rgb.shape
    labels = rgb.max(axis=2) > 60
    fg = rgb.max(axis=2) > BG_LEVEL
    out = {}
    ys = stacked_rows(labels)
    side = [detected_side_rows(labels, c * (w // 3)) for c in range(3)]
    if ys is not None and not any(side):
        pitch = int(np.median(np.diff(ys)))
        for level in (1, 2, 3):
            rows = dict(zip(ROWS_STACKED, ys[(level - 1) * 4:level * 4]))
            y0 = rows["idle"] - pitch // 2
            cols = fg[y0:y0 + pitch, 340:w].sum(axis=0) > 2
            widths = sorted(b - a for a, b in runs(cols, 20)) or [pitch]
            expect = widths[len(widths) // 2] * 1.15
            for anim in WANTED:
                if anim in rows:
                    out[(level, anim)] = gap_frames(rgb, fg, rows[anim], pitch, 340, w, expect)
        return out
    col_w = w // 3
    for c in range(3):
        cx = c * col_w
        ys = side_by_side_rows(labels, cx)
        pitch = min(int(np.median(np.diff(ys))), 110)
        rows = dict(zip(ROWS_SIDE_BY_SIDE, ys))
        for anim in WANTED:
            out[(c + 1, anim)] = grid_frames(rgb, fg, rows[anim], pitch, cx + 112, cx + col_w - 6)
    return out


def main() -> int:
    codes = language_codes()
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        if old.endswith(".png"):
            os.remove(os.path.join(OUT, old))
    made, problems = 0, []
    for region in ("luzon", "visayas", "mindanao"):
        folder = os.path.join(SRC, region)
        for name in sorted(os.listdir(folder)):
            if not name.endswith(".png"):
                continue
            code = sheet_language(name, codes)
            if not code:
                problems.append(f"{name}: no matching language")
                continue
            rgb = np.array(Image.open(os.path.join(folder, name)).convert("RGB")).astype(int)
            for (level, anim), frames in sorted(sheet_animations(rgb).items()):
                if write_strip(frames, os.path.join(OUT, f"{code}_{level}_{anim}.png")):
                    made += 1
                else:
                    problems.append(f"{name}: no frames for level {level} {anim}")
    print(f"wrote {made} strips to {os.path.relpath(OUT, ROOT)}")
    for p in problems:
        print("  !", p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
