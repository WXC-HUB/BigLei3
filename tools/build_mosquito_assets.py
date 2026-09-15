"""Build the world-map mosquito assets.

Usage:
    python tools/build_mosquito_assets.py

Input:
    my_asset/source/mosquito_sheet.png
        White-background sprite sheet, 4 columns x 2 rows of the same mosquito
        (1536x768, i.e. 384px cells). All poses face left.

Output:
    assets/sprites/generated/mosquito/mosquito_sheet.png
        Same 4x2 layout, background removed, downscaled to 192px cells
        (768x384). The white of the eyes is kept: the background is removed by
        flood-filling near-white pixels from the image border, so enclosed
        whites survive, then a 2px ring around the fill gets a soft alpha and
        its colours are un-blended from white.
    assets/audio/mosquito_buzz.wav   - seamless 1.6s whine loop, synthesised
    assets/audio/mosquito_swat.wav   - short slap, synthesised
"""
import math
import wave
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

PROJECT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT / "my_asset/source/mosquito_sheet.png"
SHEET_OUT = PROJECT / "assets/sprites/generated/mosquito/mosquito_sheet.png"
BUZZ_OUT = PROJECT / "assets/audio/mosquito_buzz.wav"
SWAT_OUT = PROJECT / "assets/audio/mosquito_swat.wav"
ICON_OUT = PROJECT / "assets/sprites/generated/mosquito/mosquito_icon.png"

COLS, ROWS = 4, 2
CELL_OUT = 192
NEAR_WHITE = 250          # min(R,G,B) above this counts as background candidate
# The eye whites are enclosed by a thin dark ring; an anti-aliased hairline gap in that
# ring would let the flood leak inside. Eroding the candidate mask by this many pixels
# before flooding closes such gaps; the fill is grown back afterwards within the mask.
LEAK_GUARD = 1
EDGE_RING = 2             # px around the background that get a soft alpha
EDGE_SOFTNESS = 40.0      # 255 - min channel over this many levels -> alpha 1


def cut_sheet() -> None:
    im = np.array(Image.open(SOURCE).convert("RGB")).astype(np.float32)
    h, w, _ = im.shape
    lum = im.min(axis=2)
    near_full = lum > NEAR_WHITE
    near = ndimage.binary_erosion(near_full, iterations=LEAK_GUARD, border_value=1)

    # Flood fill from every border pixel: only background connected to the edge goes.
    bg = np.zeros((h, w), bool)
    queue: deque = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near[y, x] and not bg[y, x]:
                bg[y, x] = True
                queue.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if near[y, x] and not bg[y, x]:
                bg[y, x] = True
                queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and near[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True
                queue.append((ny, nx))

    # Grow the fill back out to the un-eroded candidates, but only where it touches itself.
    bg = ndimage.binary_dilation(bg, iterations=LEAK_GUARD, mask=near_full)

    alpha = np.ones((h, w), np.float32)
    alpha[bg] = 0.0
    ring = ndimage.binary_dilation(bg, iterations=EDGE_RING) & ~bg
    alpha[ring] = np.clip((255.0 - lum[ring]) / EDGE_SOFTNESS, 0.0, 1.0)

    # Edge pixels were blended over white; recover the foreground colour.
    a = alpha[..., None]
    unblended = (im - (1.0 - a) * 255.0) / np.maximum(a, 0.05)
    rgb = np.where(a < 1.0, np.clip(unblended, 0.0, 255.0), im)
    rgb[alpha == 0.0] = 0.0

    # Alpha-aware downscale: premultiply, resize, un-premultiply.
    premul = np.dstack([rgb * a, alpha * 255.0]).astype(np.float32)
    small = Image.fromarray(premul.astype(np.uint8), "RGBA").resize(
        (COLS * CELL_OUT, ROWS * CELL_OUT), Image.LANCZOS
    )
    arr = np.array(small).astype(np.float32)
    a2 = arr[..., 3:4] / 255.0
    arr[..., :3] = np.clip(arr[..., :3] / np.maximum(a2, 1e-3), 0.0, 255.0)
    arr[..., :3][arr[..., 3] == 0] = 0.0
    SHEET_OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr.astype(np.uint8), "RGBA").save(SHEET_OUT)
    print(f"sheet -> {SHEET_OUT.relative_to(PROJECT)} {small.size}")


def write_wav(path: Path, samples: np.ndarray, rate: int) -> None:
    pcm = (np.clip(samples, -1.0, 1.0) * 32767.0).astype(np.int16)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(pcm.tobytes())


def build_buzz(rate: int = 44100, seconds: float = 1.6) -> None:
    """Mosquito whine: ~540 Hz buzzy tone with slow vibrato, wrapped into a seamless loop."""
    n = int(rate * seconds)
    t = np.arange(n) / rate
    f0 = 540.0
    freq = f0 * (1.0 + 0.035 * np.sin(2 * math.pi * 5.5 * t) + 0.012 * np.sin(2 * math.pi * 0.7 * t))
    phase = np.cumsum(2 * math.pi * freq / rate)
    tone = np.zeros(n)
    for k in range(1, 8):
        tone += np.sin(k * phase) / (k ** 1.2)
    tone = np.tanh(tone * 1.4)                                   # buzzy edge
    tone *= 1.0 + 0.15 * np.sin(2 * math.pi * 11.0 * t)          # wing-beat tremolo
    # Crossfade the tail into the head so the loop point is inaudible.
    fade = int(rate * 0.06)
    ramp = np.linspace(0.0, 1.0, fade)
    tone[:fade] = tone[:fade] * ramp + tone[-fade:] * (1.0 - ramp)
    tone = tone[:-fade]
    tone *= 0.6 / np.max(np.abs(tone))
    write_wav(BUZZ_OUT, tone, rate)
    print(f"buzz  -> {BUZZ_OUT.relative_to(PROJECT)} {len(tone) / rate:.2f}s")


def build_swat(rate: int = 44100, seconds: float = 0.3) -> None:
    """Slap: a low-passed noise crack plus a short low thump."""
    rng = np.random.default_rng(20260910)
    n = int(rate * seconds)
    t = np.arange(n) / rate
    noise = rng.standard_normal(n) * np.exp(-t / 0.022)
    lowpassed = np.zeros(n)
    acc = 0.0
    for i in range(n):                                            # one-pole low-pass
        acc += 0.28 * (noise[i] - acc)
        lowpassed[i] = acc
    thump_freq = 85.0 + 70.0 * np.exp(-t / 0.03)
    thump = np.sin(np.cumsum(2 * math.pi * thump_freq / rate)) * np.exp(-t / 0.07)
    slap = lowpassed * 1.6 + thump * 0.9
    attack = int(rate * 0.002)
    slap[:attack] *= np.linspace(0.0, 1.0, attack)
    slap *= 0.85 / np.max(np.abs(slap))
    write_wav(SWAT_OUT, slap, rate)
    print(f"swat  -> {SWAT_OUT.relative_to(PROJECT)} {seconds:.2f}s")



def build_icon(size: int = 192) -> None:
    """成就页用的单帧图标：从切好的图集里挑翅膀张得最开的那一格（不透明像素最多），
    贴边裁掉四周空白再摆正到正方形中间。挑格子而不是写死帧号，改图集也不用跟着改。"""
    sheet = np.asarray(Image.open(SHEET_OUT).convert("RGBA"))
    cell_h, cell_w = sheet.shape[0] // ROWS, sheet.shape[1] // COLS
    best, best_ink = None, -1
    for row in range(ROWS):
        for col in range(COLS):
            cell = sheet[row * cell_h:(row + 1) * cell_h, col * cell_w:(col + 1) * cell_w]
            ink = int((cell[..., 3] > 24).sum())
            if ink > best_ink:
                best, best_ink = cell, ink
    ys, xs = np.nonzero(best[..., 3] > 8)
    crop = best[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    side = max(crop.shape[0], crop.shape[1])
    square = np.zeros((side, side, 4), np.uint8)
    top, left = (side - crop.shape[0]) // 2, (side - crop.shape[1]) // 2
    square[top:top + crop.shape[0], left:left + crop.shape[1]] = crop
    icon = Image.fromarray(square, "RGBA").resize((size, size), Image.LANCZOS)
    ICON_OUT.parent.mkdir(parents=True, exist_ok=True)
    icon.save(ICON_OUT)
    print(f"icon  -> {ICON_OUT.relative_to(PROJECT)} {icon.size}")


if __name__ == "__main__":
    cut_sheet()
    build_buzz()
    build_swat()
    build_icon()
