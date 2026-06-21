#!/usr/bin/env python3
"""
Generate walk animation frames for hero sprites using split-shear technique.

Instead of shearing both legs the same direction (which looks like a spread),
we split the lower body at the center and shear each half independently:
  - right foot forward: right half goes right (+), left half goes left (-)
  - left foot forward:  right half goes left (-), left half goes right (+)

This creates a realistic stride where one foot leads and the other trails.
"""

from pathlib import Path
import numpy as np
from PIL import Image

HEROES_DIR = Path('assets/raw/split/heroes')


def find_content_bounds(arr: np.ndarray) -> tuple[int, int, int, int]:
    mask = arr[:, :, 3] > 10
    rows = np.where(np.any(mask, axis=1))[0]
    cols = np.where(np.any(mask, axis=0))[0]
    return int(rows[0]), int(rows[-1]), int(cols[0]), int(cols[-1])


def apply_bob(arr: np.ndarray, bob_dy: int) -> np.ndarray:
    """Shift entire image up (bob_dy > 0) or down (bob_dy < 0)."""
    h = arr.shape[0]
    out = np.zeros_like(arr)
    if bob_dy > 0:
        out[:h - bob_dy] = arr[bob_dy:]
    elif bob_dy < 0:
        out[-bob_dy:] = arr[:h + bob_dy]
    else:
        out[:] = arr
    return out


def make_walk_frame(
    idle_arr: np.ndarray,
    forward_shear: float,   # pixels the LEADING foot moves forward (+x)
    back_shear: float,      # pixels the TRAILING foot moves back (-x, pass as positive)
    right_leads: bool,      # True = right foot forward, False = left foot forward
    bob_dy: int,
    waist_ratio: float,
) -> np.ndarray:
    """
    Split-shear walk frame.
    right_leads=True  → right half of sprite goes right, left half goes left
    right_leads=False → left half of sprite goes right, right half goes left
    """
    h, w = idle_arr.shape[:2]

    # 1. Apply vertical bob to whole image first
    bobbed = apply_bob(idle_arr, bob_dy)

    # 2. Find geometry
    top, bot, cleft, cright = find_content_bounds(bobbed)
    content_h = bot - top + 1
    waist_y = top + int(content_h * waist_ratio)
    center_x = (cleft + cright) // 2

    # 3. Extract lower body
    lower = bobbed[waist_y:].copy()
    lower_h = len(lower)

    result = bobbed.copy()
    result[waist_y:] = 0   # clear legs region

    for i in range(lower_h):
        t = i / max(lower_h - 1, 1)   # 0 at waist → 1 at feet

        # Which side leads?
        if right_leads:
            right_shift = int(round(+forward_shear * t))
            left_shift  = int(round(-back_shear   * t))
        else:
            right_shift = int(round(-back_shear   * t))
            left_shift  = int(round(+forward_shear * t))

        dst_y = waist_y + i
        if dst_y >= h:
            break

        row = lower[i]
        result_row = np.zeros((w, 4), dtype=np.uint8)

        # --- Left half ---
        ls = left_shift
        src_left  = row[:center_x]
        if ls > 0:
            dst_start = min(ls, w - 1)
            dst_end   = min(center_x + ls, w)
            result_row[dst_start:dst_end] = src_left[:dst_end - dst_start]
        elif ls < 0:
            dst_start = max(0, center_x + ls)
            result_row[0:dst_start] = src_left[-ls:dst_start - ls]
        else:
            result_row[:center_x] = src_left

        # --- Right half ---
        rs = right_shift
        src_right = row[center_x:]
        n_right = len(src_right)
        if rs > 0:
            dst_start = min(center_x + rs, w - 1)
            copy_len  = min(n_right, w - dst_start)
            result_row[dst_start:dst_start + copy_len] = src_right[:copy_len]
        elif rs < 0:
            dst_start = max(0, center_x + rs)
            src_offset = -rs
            copy_len  = min(n_right - src_offset, w - dst_start)
            if copy_len > 0:
                result_row[dst_start:dst_start + copy_len] = src_right[src_offset:src_offset + copy_len]
        else:
            dst_start = center_x
            copy_len  = min(n_right, w - dst_start)
            result_row[dst_start:dst_start + copy_len] = src_right[:copy_len]

        result[dst_y] = result_row

    return result


def make_hero_walk(
    name: str,
    waist_ratio: float = 0.72,
    forward_shear: float = 22.0,
    back_shear: float = 14.0,
    bob_amount: int = 3,
) -> None:
    idle1 = np.array(Image.open(HEROES_DIR / f'{name}_idle_1.png').convert('RGBA'))
    idle2 = np.array(Image.open(HEROES_DIR / f'{name}_idle_2.png').convert('RGBA'))

    # Normalize canvas size
    h = max(idle1.shape[0], idle2.shape[0])
    w = max(idle1.shape[1], idle2.shape[1])

    def pad(arr):
        out = np.zeros((h, w, 4), dtype=np.uint8)
        out[:arr.shape[0], :arr.shape[1]] = arr
        return out

    idle1, idle2 = pad(idle1), pad(idle2)

    # 4-frame cycle
    # Frame 1: right foot forward, body down (foot plants)
    # Frame 2: passing position, body up (feet cross)
    # Frame 3: left foot forward, body down
    # Frame 4: passing position, body up
    configs = [
        (idle1, True,  0),           # right foot forward
        (idle2, True,  +bob_amount), # mid-stride, body up
        (idle1, False, 0),           # left foot forward
        (idle2, False, +bob_amount), # mid-stride, body up
    ]

    for idx, (base, right_leads, bob) in enumerate(configs, start=1):
        frame = make_walk_frame(
            base,
            forward_shear=forward_shear,
            back_shear=back_shear,
            right_leads=right_leads,
            bob_dy=bob,
            waist_ratio=waist_ratio,
        )
        out = HEROES_DIR / f'{name}_run_{idx}.png'
        Image.fromarray(frame, 'RGBA').save(out)
        print(f'  {out.name}')


# ── per-character tuning ──────────────────────────────────────────────────────
# waist_ratio:   fraction of visible content where hips/thighs start
# forward_shear: how far the leading foot extends (px at bottom of legs)
# back_shear:    how far the trailing foot pulls back
# bob_amount:    upward body lift mid-stride (px)

print('bow …')
make_hero_walk('bow',   waist_ratio=0.72, forward_shear=30, back_shear=18, bob_amount=3)

print('sword …')
make_hero_walk('sword', waist_ratio=0.70, forward_shear=32, back_shear=20, bob_amount=3)

print('fist …')
make_hero_walk('fist',  waist_ratio=0.67, forward_shear=28, back_shear=17, bob_amount=4)

print('Done.')
