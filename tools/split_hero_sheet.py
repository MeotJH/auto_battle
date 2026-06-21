"""
Split hero_sheet.png with precise per-frame boundaries.

For each row:
  1. Find all left-edge transitions (bg→content).
  2. Compute median spacing from consecutive edges that are ~1-frame apart.
  3. Keep only edges that fit the regular grid (discard projectile sub-islands).
  4. If fewer than 7 edges remain, interpolate missing ones.
  5. Frame i = [start[i], start[i+1]-1]. Last frame extends to content end.
"""
from pathlib import Path
import numpy as np
from PIL import Image

SHEET = Path(__file__).parent.parent / "assets/raw/hero_sheet.png"
OUT   = Path(__file__).parent.parent / "assets/raw/split/heroes"
OUT.mkdir(parents=True, exist_ok=True)

sheet = Image.open(SHEET).convert("RGBA")
arr   = np.array(sheet, dtype=float)
H, W  = arr.shape[:2]

r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
sat     = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
is_bg   = (sat < 20) & (np.maximum(np.maximum(r, g), b) > 180)
content = ~is_bg

def find_bands(profile, gap_thresh):
    bands, in_gap, start = [], True, None
    for i, v in enumerate(profile):
        if v >= gap_thresh and in_gap:
            start, in_gap = i, False
        elif v < gap_thresh and not in_gap:
            bands.append((start, i - 1))
            in_gap = True
    if not in_gap:
        bands.append((start, len(profile) - 1))
    return bands

y_bands = [b for b in find_bands(content.sum(axis=1), W * 0.01) if (b[1]-b[0]) > 50]

def resolve_7_starts(y0, y1):
    strip   = content[y0:y1+1, :]
    col_p   = strip.sum(axis=0)
    GAP     = (y1 - y0 + 1) * 0.015

    # All left-edge transitions
    edges = []
    prev = col_p[0] >= GAP
    for x in range(1, W):
        cur = col_p[x] >= GAP
        if cur and not prev:
            edges.append(x)
        prev = cur

    if not edges:
        return None, None

    # Content end (rightmost active column)
    active = np.where(col_p >= GAP)[0]
    x_end  = int(active[-1])

    # Compute spacing between consecutive edges
    gaps = np.diff(edges)
    if len(gaps) == 0:
        return None, None

    # Median spacing (exclude very small gaps < 80px which are sub-islands)
    valid_gaps = gaps[gaps >= 80]
    if len(valid_gaps) == 0:
        valid_gaps = gaps
    spacing = int(np.median(valid_gaps))
    print(f"  Edges: {edges}  spacing={spacing}")

    # Keep only edges that fit a regular grid (within ±35% of spacing)
    tol = spacing * 0.35
    main = [edges[0]]
    for e in edges[1:]:
        if e - main[-1] >= spacing - tol:
            main.append(e)

    print(f"  Grid-filtered edges ({len(main)}): {main}")

    # Fill missing frames by interpolation
    while len(main) < 7:
        # Find the largest gap and insert a frame there
        diffs = np.diff(main)
        idx   = int(np.argmax(diffs))
        insert_x = main[idx] + spacing
        main.insert(idx + 1, insert_x)
        print(f"  Inserted frame at x={insert_x}")

    starts = sorted(main[:7])
    return starts, x_end

HEROES = [
    ("bow",   {"idle": [0,1], "run": [2,3,4], "attack": [2,3,4,5]}),
    ("sword", {"idle": [0,1], "run": [2,3,4], "attack": [3,4,5,6]}),
    ("fist",  {"idle": [0,1], "run": [2,3,4], "attack": [3,4,5,6]}),
]

for row_i, (y0, y1) in enumerate(y_bands):
    print(f"\n=== Row {row_i} (y={y0}..{y1}) ===")
    starts, x_end = resolve_7_starts(y0, y1)
    if starts is None:
        print("  SKIP — no content found")
        continue

    # Frame boundaries: end[i] = start[i+1]-1; last frame → x_end
    ends = [s - 1 for s in starts[1:]] + [x_end]
    print(f"  Final starts: {starts}")
    print(f"  Final ends:   {ends}")

    name, layout = HEROES[row_i]
    for state, cols in layout.items():
        for frame_i, col in enumerate(cols, start=1):
            xs, xe = starts[col], ends[col]
            crop_a = np.array(sheet.crop((xs, y0, xe + 1, y1 + 1)), dtype=float)
            cr2, cg2, cb2 = crop_a[...,0], crop_a[...,1], crop_a[...,2]
            cs2 = np.maximum(np.maximum(cr2,cg2),cb2) - np.minimum(np.minimum(cr2,cg2),cb2)
            bg  = (cs2 < 20) & (np.maximum(np.maximum(cr2,cg2),cb2) > 180)
            crop_a[bg, 3] = 0
            result = Image.fromarray(crop_a.astype(np.uint8), "RGBA")
            out_path = OUT / f"{name}_{state}_{frame_i}.png"
            result.save(out_path)
            print(f"  {out_path.name}  x={xs}..{xe}  w={xe-xs+1}")

print("\nDone.")
