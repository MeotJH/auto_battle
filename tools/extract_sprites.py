"""
Content-aware sprite sheet extractor.
Detects actual frame boundaries per row using character center peaks.
Removes white background via border flood-fill.
Normalizes all frames to a shared canvas (bottom-aligned, center-aligned).
"""

from PIL import Image
import numpy as np
from collections import deque
import os

SHEET_FILES = {
    'fist':  'assets/ChatGPT Image 2026년 6월 20일 오전 09_12_34 (1).png',
    'sword': 'assets/ChatGPT Image 2026년 6월 20일 오전 09_12_34 (2).png',
    'mage':  'assets/ChatGPT Image 2026년 6월 20일 오전 09_12_34 (3).png',
}

ROWS = 7
OPAQUE_THRESHOLD = 2000   # min opaque px after bg removal to keep a frame

# (anim_name, row_index, expected_frames)  – expected used as sanity cap only
ANIMS = [
    ('idle',   0),
    ('run',    1),
    ('attack', 2),
    ('skill',  3),
    ('hurt',   4),
    ('death',  5),
]

OUT_DIR = 'assets/raw/split/heroes'
os.makedirs(OUT_DIR, exist_ok=True)


# ── background removal ──────────────────────────────────────────────────────

def flood_fill_bg(rgb: np.ndarray, tol: int = 28) -> np.ndarray:
    h, w = rgb.shape[:2]
    visited = np.zeros((h, w), dtype=bool)
    is_bg = np.zeros((h, w), dtype=bool)

    def near_white(y, x):
        return all(int(rgb[y, x, c]) > 255 - tol for c in range(3))

    q = deque()
    for x in range(w):
        for y in [0, h-1]:
            if not visited[y, x] and near_white(y, x):
                visited[y, x] = is_bg[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in [0, w-1]:
            if not visited[y, x] and near_white(y, x):
                visited[y, x] = is_bg[y, x] = True
                q.append((y, x))

    while q:
        cy, cx = q.popleft()
        for dy, dx in [(-1,0),(1,0),(0,-1),(0,1)]:
            ny, nx = cy+dy, cx+dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                if near_white(ny, nx):
                    visited[ny, nx] = is_bg[ny, nx] = True
                    q.append((ny, nx))
    return is_bg


def remove_bg(cell_rgb: Image.Image) -> Image.Image:
    arr = np.array(cell_rgb.convert('RGB'))
    mask = flood_fill_bg(arr)
    rgba = np.zeros((*arr.shape[:2], 4), dtype=np.uint8)
    rgba[:, :, :3] = arr
    rgba[:, :, 3] = np.where(mask, 0, 255)
    return Image.fromarray(rgba, 'RGBA')


# ── frame boundary detection ────────────────────────────────────────────────

def detect_boundaries(row_rgb: np.ndarray, expected: int = 8) -> tuple[list[int], list[int]]:
    """
    Return (boundaries, peaks).
    boundaries = [x0, x1, ..., xN] splitting N frames.
    Last boundary is capped at peaks[-1] + avg_frame_width, NOT image edge.
    """
    W = row_rgb.shape[1]
    bg = (row_rgb[:,:,0]>240) & (row_rgb[:,:,1]>240) & (row_rgb[:,:,2]>240)
    density = (~bg).astype(float).sum(axis=0)

    k = max(10, W // (expected * 3))
    smooth = np.convolve(density, np.ones(k)/k, mode='same')
    threshold = smooth.mean() * 0.65

    min_gap = W // (expected + 2)
    peaks = []
    for x in range(k, W - k):
        window = smooth[max(0,x-min_gap):x+min_gap+1]
        if smooth[x] == window.max() and smooth[x] > threshold:
            if not peaks or x - peaks[-1] > min_gap:
                peaks.append(x)

    if len(peaks) < 2:
        fw = W // expected
        bounds = [i * fw for i in range(expected)] + [min(W, expected * fw)]
        return bounds, peaks

    # Average spacing between detected peaks
    avg_fw = (peaks[-1] - peaks[0]) / (len(peaks) - 1)

    mids = [max(0, peaks[0] - int(avg_fw * 0.5))]
    for i in range(1, len(peaks)):
        mids.append((peaks[i-1] + peaks[i]) // 2)
    # Cap last boundary — do NOT extend to full image width
    mids.append(min(W, int(peaks[-1] + avg_fw * 0.55)))
    return mids, peaks


# ── canvas normalization ────────────────────────────────────────────────────

def tight_bbox(frame: Image.Image):
    arr = np.array(frame)
    alpha = arr[:, :, 3]
    rows = np.where(alpha.any(axis=1))[0]
    cols = np.where(alpha.any(axis=0))[0]
    if not len(rows) or not len(cols):
        return None
    return int(cols[0]), int(rows[0]), int(cols[-1]), int(rows[-1])


def normalize_all(frames_by_anim: dict) -> dict:
    """Crop to content, align to shared max-size canvas (bottom+center)."""
    cropped = {}
    max_cw = max_ch = 0
    for anim, frames in frames_by_anim.items():
        crops = []
        for f in frames:
            bb = tight_bbox(f)
            if bb is None:
                crops.append(None)
                continue
            x1, y1, x2, y2 = bb
            c = f.crop((x1, y1, x2+1, y2+1))
            max_cw = max(max_cw, c.size[0])
            max_ch = max(max_ch, c.size[1])
            crops.append(c)
        cropped[anim] = crops

    out = {}
    for anim, crops in cropped.items():
        norm = []
        for c in crops:
            canvas = Image.new('RGBA', (max_cw, max_ch), (0,0,0,0))
            if c:
                cw, ch = c.size
                canvas.paste(c, ((max_cw-cw)//2, max_ch-ch), c)
            norm.append(canvas)
        out[anim] = norm
    return out


# ── main extraction ─────────────────────────────────────────────────────────

def extract_sheet(path: str, prefix: str):
    img = Image.open(path).convert('RGB')
    W, H = img.size
    fh = H // ROWS
    arr = np.array(img)

    print(f'\n{prefix}  ({W}x{H})')

    # Detect frame count + boundaries from idle row (cleanest)
    idle_row = arr[:fh, :, :]
    idle_bounds, _ = detect_boundaries(idle_row, expected=8)
    n_frames = len(idle_bounds) - 1
    print(f'  Detected {n_frames} frames per row from idle, bounds={idle_bounds}')

    all_frames: dict[str, list] = {}

    for anim_name, row_idx in ANIMS:
        y1 = row_idx * fh
        y2 = min(y1 + fh, H)

        # Always use idle boundaries — prevents last-frame expanding to image edge
        bounds = idle_bounds

        frames = []
        for i in range(len(bounds) - 1):
            x1, x2 = bounds[i], bounds[i+1]
            cell = img.crop((x1, y1, x2, y2))
            frame = remove_bg(cell)
            opaque = int((np.array(frame)[:,:,3] > 0).sum())
            if opaque < OPAQUE_THRESHOLD:
                print(f'  {anim_name} frame {i+1}: skipped ({opaque} px)')
                break
            frames.append(frame)

        all_frames[anim_name] = frames

    normalized = normalize_all(all_frames)
    canvas_size = next(iter(normalized.values()))[0].size
    print(f'  Shared canvas: {canvas_size}')

    for anim_name, frames in normalized.items():
        for i, frame in enumerate(frames):
            frame.save(f'{OUT_DIR}/{prefix}_{anim_name}_{i+1}.png')
        print(f'  {anim_name}: {len(frames)} frames')


for prefix, path in SHEET_FILES.items():
    extract_sheet(path, prefix)

print('\nDone.')
