"""Make the tap areas of the three islands on the Main Island map.

A finger is much bigger than the small islands and the narrow sea between
them, so tapping only the painted pixels is hard. This writes
assets/ui/map_<island>_tap.png: opaque where a tap opens that island.

- Each island's own land counts, plus the sea up to MARGIN pixels around it.
- Where two islands' areas meet, each pixel goes to the island with the
  nearest land.
- Small islands count when they are part of the island group: reachable
  from its main island hopping at most LINK pixels from island to island.
  Specks far from their own group (stray pixels in the art, e.g. bits of the
  Mindanao picture near Luzon) are ignored, so they cannot steal taps.

Run from the project root after changing assets/ui/map_*.png:
    python tools/art/make_island_tap_masks.py
Needs: pip install pillow numpy scipy
"""

import os

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UI = os.path.join(ROOT, "assets", "ui")
ISLANDS = ["luzon", "visayas", "mindanao"]
ALPHA = 76        # same threshold as the game's click mask (0.3)
MARGIN = 24       # pixels of sea around the land that still count
LINK = 45         # largest sea gap between islands of the same group


def main() -> None:
    land = {r: np.array(Image.open(os.path.join(UI, f"map_{r}.png")).getchannel("A")) > ALPHA for r in ISLANDS}
    clean = {}
    for r in ISLANDS:
        labels, n = ndimage.label(land[r])
        sizes = ndimage.sum(land[r], labels, range(1, n + 1))
        keep = labels == (int(np.argmax(sizes)) + 1)
        while True:  # add every piece within LINK of what is already kept
            reach = ndimage.distance_transform_edt(~keep) <= LINK
            more = np.isin(labels, np.unique(labels[reach & land[r] & ~keep]))
            more &= labels > 0
            if not (more & ~keep).any():
                break
            keep |= more
        clean[r] = keep
    dist = np.stack([ndimage.distance_transform_edt(~clean[r]) for r in ISLANDS])
    nearest = dist.argmin(axis=0)
    for i, r in enumerate(ISLANDS):
        tap = (nearest == i) & (dist[i] <= MARGIN)
        a = (tap * 255).astype("uint8")
        Image.fromarray(np.dstack([a, a]), "LA").save(os.path.join(UI, f"map_{r}_tap.png"), optimize=True)
        print(f"map_{r}_tap.png: {int(tap.sum())} px tappable (land {int(land[r].sum())} px)")


if __name__ == "__main__":
    main()
