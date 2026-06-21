"""
Generates horizontally-flipped versions of hero sprites for right-to-left facing.
Output: {prefix}_r_{state}{n}.png alongside originals.
"""

from PIL import Image
import os

BASE = 'assets/raw/split/heroes'

for prefix in ('fist', 'mage', 'sword'):
    folder = os.path.join(BASE, prefix)
    for fname in os.listdir(folder):
        if not fname.endswith('.png'):
            continue
        # Skip already-flipped files
        if f'_{prefix}_r_' in fname or fname.startswith(f'{prefix}_r_'):
            continue
        # e.g. fist_idle1.png → fist_r_idle1.png
        new_name = fname.replace(f'{prefix}_', f'{prefix}_r_', 1)
        src = os.path.join(folder, fname)
        dst = os.path.join(folder, new_name)
        img = Image.open(src)
        img.transpose(Image.FLIP_LEFT_RIGHT).save(dst)
    print(f'{prefix}: flipped {len([f for f in os.listdir(folder) if "_r_" in f])} files')

print('Done.')
