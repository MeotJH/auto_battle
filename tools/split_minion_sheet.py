"""
Split minion_sheet.png into individual frame PNGs.

Sheet: 4 rows × 7 columns (same 1448×1086 as hero sheet)
  Row 0: blue_melee
  Row 1: red_melee
  Row 2: blue_ranged
  Row 3: red_ranged

Frame assignments (from SpriteCatalog):
  idle:   cols [0,1,2]     → 3 frames
  run:    cols [3,4,5,6]   → 4 frames
  attack: melee=[4,5,6]    → 3 frames
          ranged=[3,4,5]   → 3 frames
"""
from pathlib import Path
import numpy as np
from PIL import Image

SHEET = Path(__file__).parent.parent / "assets/raw/minion_sheet.png"
OUT   = Path(__file__).parent.parent / "assets/raw/split/minions"
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

y_bands = [b for b in find_bands(content.sum(axis=1), W * 0.01) if (b[1]-b[0]) > 30]
print(f"Y bands ({len(y_bands)}): {y_bands}")

NUM_COLS = 7

def resolve_7_starts(y0, y1):
    strip   = content[y0:y1+1, :]
    col_p   = strip.sum(axis=0)
    GAP     = (y1 - y0 + 1) * 0.015

    edges = []
    prev = col_p[0] >= GAP
    for x in range(1, W):
        cur = col_p[x] >= GAP
        if cur and not prev:
            edges.append(x)
        prev = cur

    active = np.where(col_p >= GAP)[0]
    x_end  = int(active[-1])

    gaps = np.diff(edges) if len(edges) > 1 else np.array([])
    valid_gaps = gaps[gaps >= 80] if len(gaps) > 0 else gaps
    if len(valid_gaps) == 0:
        valid_gaps = gaps
    spacing = int(np.median(valid_gaps)) if len(valid_gaps) > 0 else 180

    print(f"  Raw edges ({len(edges)}): {edges}  spacing={spacing}")

    tol = spacing * 0.35
    main = [edges[0]] if edges else []
    for e in edges[1:]:
        if e - main[-1] >= spacing - tol:
            main.append(e)

    print(f"  Grid-filtered ({len(main)}): {main}")

    while len(main) < NUM_COLS:
        diffs = np.diff(main)
        idx   = int(np.argmax(diffs))
        main.insert(idx + 1, main[idx] + spacing)
        print(f"  Inserted at x={main[idx+1]}")

    starts = sorted(main[:NUM_COLS])
    return starts, x_end

MINIONS = [
    ("blue_melee",  {"idle": [0,1,2], "run": [3,4,5,6], "attack": [4,5,6]}),
    ("red_melee",   {"idle": [0,1,2], "run": [3,4,5,6], "attack": [4,5,6]}),
    ("blue_ranged", {"idle": [0,1,2], "run": [3,4,5,6], "attack": [3,4,5]}),
    ("red_ranged",  {"idle": [0,1,2], "run": [3,4,5,6], "attack": [3,4,5]}),
]

for row_i, (y0, y1) in enumerate(y_bands):
    print(f"\n=== Row {row_i} (y={y0}..{y1}) ===")
    starts, x_end = resolve_7_starts(y0, y1)
    ends = [s - 1 for s in starts[1:]] + [x_end]

    name, layout = MINIONS[row_i]
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
