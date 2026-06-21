"""
The sheet has a checkered transparency background baked in.
Detect the checker pattern and mask it out to find real sprite content.
"""
from pathlib import Path
import numpy as np
from PIL import Image

SHEET = Path(__file__).parent.parent / "assets/raw/hero_sheet.png"
sheet = Image.open(SHEET).convert("RGB")
arr   = np.array(sheet, dtype=float)
H, W  = arr.shape[:2]

# Detect checker pattern: every 2x2 block alternates between two colors.
# Sample the top-left 20x20 empty region to find checker colors.
sample = arr[:20, :20]
unique_colors = np.unique(sample.reshape(-1, 3), axis=0)
print("Unique colors in top-left 20x20 patch:")
for c in unique_colors:
    print(f"  {c.astype(int)}")

# The two checker colors are the two most common colors in the corner area
from collections import Counter
flat = [tuple(p.astype(int)) for p in sample.reshape(-1, 3)]
most_common = Counter(flat).most_common(5)
print("\nMost common (color, count) in top-left patch:")
for color, cnt in most_common:
    print(f"  {color}: {cnt}")

checker_colors = [np.array(c) for c, _ in most_common[:2]]
print(f"\nDetected checker colors: {[c.tolist() for c in checker_colors]}")

# Build mask: pixel is background if it's close to either checker color
TOL = 20
bg_mask = np.zeros((H, W), dtype=bool)
for cc in checker_colors:
    diff = np.abs(arr - cc).max(axis=2)
    bg_mask |= (diff < TOL)

content = ~bg_mask
print(f"\nContent pixels: {content.sum()} / {H*W}")

# Column and row profiles
col_profile = content.sum(axis=0)
row_profile = content.sum(axis=1)

GAP_COL = H * 0.01
GAP_ROW = W * 0.01

def find_bands(profile, gap_thresh):
    bands = []
    in_gap = True
    start = None
    for i, v in enumerate(profile):
        if v >= gap_thresh and in_gap:
            start = i
            in_gap = False
        elif v < gap_thresh and not in_gap:
            bands.append((start, i - 1))
            in_gap = True
    if not in_gap:
        bands.append((start, len(profile) - 1))
    return bands

x_bands = find_bands(col_profile, GAP_COL)
y_bands = find_bands(row_profile, GAP_ROW)

print(f"\nX content bands ({len(x_bands)}):")
for i, (s, e) in enumerate(x_bands):
    print(f"  [{i}] x={s}..{e}  w={e-s+1}")

print(f"\nY content bands ({len(y_bands)}):")
for i, (s, e) in enumerate(y_bands):
    print(f"  [{i}] y={s}..{e}  h={e-s+1}")

# Save a debug visualization
debug = arr.copy().astype(np.uint8)
debug[content] = np.array([255, 0, 0], dtype=np.uint8)
Image.fromarray(debug).save(Path(__file__).parent.parent / "assets/raw/debug_mask.png")
print("\nSaved debug_mask.png (red = detected sprite pixels)")
