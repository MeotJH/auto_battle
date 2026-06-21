#!/usr/bin/env python3
"""
Split hero idle sprites into upper body and lower body (legs).
Upper body: head + torso + arms.  Lower body: hips + legs + feet.
The hip split point uses the first idle frame for each character.
"""

from pathlib import Path
import numpy as np
from PIL import Image

SRC = Path('assets/raw/split/heroes')
OUT = Path('assets/raw/split/heroes')

# (name, hip_ratio) — fraction of visible content height where the hip line sits
HEROES = [
    ('bow',   0.62),
    ('sword', 0.62),
    ('fist',  0.58),
]

def split_hero(name: str, hip_ratio: float) -> None:
    img = Image.open(SRC / f'{name}_idle_1.png').convert('RGBA')
    arr = np.array(img)
    h, w = arr.shape[:2]

    # Find visible content bounds
    mask = arr[:, :, 3] > 10
    rows = np.where(np.any(mask, axis=1))[0]
    top, bot = int(rows[0]), int(rows[-1])
    hip_y = top + int((bot - top) * hip_ratio)

    # Upper body: rows 0 .. hip_y  (keep original canvas width)
    upper = arr[:hip_y, :, :]
    Image.fromarray(upper.astype(np.uint8), 'RGBA').save(OUT / f'{name}_upper.png')
    print(f'  {name}_upper.png  ({w}x{hip_y})')

    # Lower body: rows hip_y .. h
    lower = arr[hip_y:, :, :]
    # Trim empty rows at bottom
    lower_mask = lower[:, :, 3] > 10
    content_rows = np.where(np.any(lower_mask, axis=1))[0]
    if len(content_rows):
        lower = lower[:int(content_rows[-1]) + 2, :]   # +2 px padding
    Image.fromarray(lower.astype(np.uint8), 'RGBA').save(OUT / f'{name}_lower.png')
    print(f'  {name}_lower.png  ({w}x{lower.shape[0]})')

for name, ratio in HEROES:
    print(f'{name} …')
    split_hero(name, ratio)

print('Done.')
