"""
Removes white background from hero sprites using border flood-fill.
Processes all PNG files in assets/raw/split/heroes/{fist,mage,sword}/
Overwrites in-place (keeps original if already RGBA with transparency).
"""

from PIL import Image
import numpy as np
from collections import deque
import os

BASE = 'assets/raw/split/heroes'
PREFIXES = ('fist', 'mage', 'sword')
TOL = 30  # near-white tolerance


def flood_fill_bg(rgb: np.ndarray, tol: int = TOL) -> np.ndarray:
    h, w = rgb.shape[:2]
    visited = np.zeros((h, w), dtype=bool)
    is_bg = np.zeros((h, w), dtype=bool)

    def near_white(y, x):
        return all(int(rgb[y, x, c]) > 255 - tol for c in range(3))

    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not visited[y, x] and near_white(y, x):
                visited[y, x] = is_bg[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if not visited[y, x] and near_white(y, x):
                visited[y, x] = is_bg[y, x] = True
                q.append((y, x))

    while q:
        cy, cx = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                if near_white(ny, nx):
                    visited[ny, nx] = is_bg[ny, nx] = True
                    q.append((ny, nx))
    return is_bg


total = 0
for prefix in PREFIXES:
    folder = os.path.join(BASE, prefix)
    files = [f for f in os.listdir(folder) if f.endswith('.png')]
    for fname in files:
        path = os.path.join(folder, fname)
        img = Image.open(path).convert('RGB')
        arr = np.array(img)
        mask = flood_fill_bg(arr)
        rgba = np.zeros((*arr.shape[:2], 4), dtype=np.uint8)
        rgba[:, :, :3] = arr
        rgba[:, :, 3] = np.where(mask, 0, 255)
        Image.fromarray(rgba, 'RGBA').save(path)
        total += 1
    print(f'{prefix}: processed {len(files)} files')

print(f'\nTotal: {total} files processed.')
