"""Build the non-frame assets for the azure-winged magpie (灰喜鹊) and its unlock page.

    python tools/build_magpie_assets.py

Outputs:
  my_asset/magpie_senpai.png        - 黑长直学姐 cut out of her green screen (full figure)
  my_asset/magpie_senpai_lens.png   - 760x300 crop of her hair + face, framed for the glasses lenses
  my_asset/magpie_glasses.png       - 760x300 round black glasses with transparent lenses
  my_asset/magpie_glasses_icon.png  - 256x256 achievement icon of the same glasses
  assets/audio/magpie_call.wav      - two harsh "chack" notes, synthesised

The bird frames themselves come from tools/cut_bird_sheet.py (prefix `magpie`).
"""
import math
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage, signal

PROJECT = Path(__file__).resolve().parents[1]
LENS_SIZE = (760, 300)
LENS_CENTRES = ((200, 150), (560, 150))
LENS_RADIUS = 128
RIM = 14
RIM_COLOUR = (34, 30, 38, 255)


# --------------------------------------------------------------------------- green screen
def chroma_cut(sheet: np.ndarray) -> np.ndarray:
    """Return an RGBA array: everything that is not backdrop-green keeps its colour."""
    h, w, _ = sheet.shape
    corners = np.stack([sheet[4, 4], sheet[4, w - 5], sheet[h - 5, 4], sheet[h - 5, w - 5]])
    bg = corners.mean(axis=0)
    r, g, b = sheet[..., 0], sheet[..., 1], sheet[..., 2]
    greenness = g - np.maximum(r, b)
    hi = float(bg[1] - max(bg[0], bg[2])) * 0.92
    alpha = 1.0 - np.clip((greenness - 12.0) / (hi - 12.0), 0.0, 1.0)
    alpha[np.linalg.norm(sheet - bg, axis=-1) < 28.0] = 0.0
    a = alpha[..., None]
    safe = np.where(a > 0.02, a, 1.0)
    fg = np.where(a > 0.02, (sheet - (1.0 - a) * bg) / safe, sheet)
    fg[..., 1] = np.minimum(fg[..., 1], np.maximum(fg[..., 0], fg[..., 2]) + 6.0)
    # Keep the main figure plus any loose detail close to it (speed lines), drop stray specks.
    labels, count = ndimage.label(alpha > 0.15)
    if count > 1:
        areas = ndimage.sum(np.ones_like(labels), labels, index=range(1, count + 1))
        main = int(np.argmax(areas)) + 1
        main_slice = ndimage.find_objects(labels)[main - 1]
        box = (main_slice[1].start - 220, main_slice[0].start - 220, main_slice[1].stop + 220, main_slice[0].stop + 220)
        keep = np.zeros_like(alpha, dtype=bool)
        for idx, sl in enumerate(ndimage.find_objects(labels), start=1):
            cx = (sl[1].start + sl[1].stop) / 2
            cy = (sl[0].start + sl[0].stop) / 2
            if idx == main or (box[0] <= cx <= box[2] and box[1] <= cy <= box[3]):
                keep |= labels == idx
        keep = ndimage.binary_dilation(keep, iterations=2)
        alpha = np.where(keep, alpha, 0.0)
    return np.dstack([np.clip(fg, 0, 255), alpha * 255.0]).round().astype(np.uint8)


def build_senpai() -> None:
    src = np.asarray(Image.open(PROJECT / "my_asset/birds/source/senpai_sheet.png").convert("RGB")).astype(np.float64)
    rgba = Image.fromarray(chroma_cut(src), "RGBA")
    figure = rgba.crop(rgba.getbbox())
    figure.save(PROJECT / "my_asset/magpie_senpai.png")
    print("senpai figure", figure.size)

    # Lens crop: hair streaming across the left lens, face in the right lens.
    # Source coordinates are in the 1792x1024 sheet; the face sits around (1060, 560).
    region = rgba.crop((330, 250, 1300, 720))            # 970 x 470
    scale = LENS_SIZE[0] / region.width
    region = region.resize((LENS_SIZE[0], round(region.height * scale)), Image.LANCZOS)
    top = max(0, (region.height - LENS_SIZE[1]) // 2 + 10)
    lens = Image.new("RGBA", LENS_SIZE, (0, 0, 0, 0))
    lens.paste(region.crop((0, top, LENS_SIZE[0], top + LENS_SIZE[1])), (0, 0))
    lens.save(PROJECT / "my_asset/magpie_senpai_lens.png")
    print("senpai lens crop", lens.size)


# --------------------------------------------------------------------------- glasses
def draw_glasses(size, centres, radius, rim, with_temples=True) -> Image.Image:
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for cx, cy in centres:
        # Faint lens tint so the glass reads as glass even over dark backgrounds.
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=(200, 220, 255, 26))
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=RIM_COLOUR, width=rim)
        # Highlight arc on the upper-left of each lens.
        draw.arc((cx - radius + rim * 1.6, cy - radius + rim * 1.6, cx + radius - rim * 1.6, cy + radius - rim * 1.6),
                 start=200, end=250, fill=(255, 255, 255, 150), width=max(2, rim // 3))
    (ax, ay), (bx, by) = centres
    # Bridge: a shallow arch between the inner rims.
    bridge_left = ax + radius - rim // 2
    bridge_right = bx - radius + rim // 2
    draw.arc((bridge_left, ay - radius * 0.35, bridge_right, ay + radius * 0.35), start=200, end=340, fill=RIM_COLOUR, width=rim)
    if with_temples:
        draw.line((ax - radius + rim // 2, ay - radius * 0.1, 0, ay - radius * 0.45), fill=RIM_COLOUR, width=rim)
        draw.line((bx + radius - rim // 2, by - radius * 0.1, size[0], by - radius * 0.45), fill=RIM_COLOUR, width=rim)
    return img


def draw_glasses_aa(size, centres, radius, rim, with_temples=True, supersample=2, upscale=1) -> Image.Image:
    """Draw at `upscale * supersample` resolution and shrink by `supersample` for antialiased rims.

    The unlock page blows the glasses up 4.5x so only one lens fits on screen; `upscale=4`
    gives the PNG enough pixels to stay crisp at that size while the rig keeps 760x300 units.
    """
    factor = supersample * upscale
    big = draw_glasses(
        (size[0] * factor, size[1] * factor),
        [(cx * factor, cy * factor) for cx, cy in centres],
        radius * factor,
        rim * factor,
        with_temples,
    )
    return big.resize((size[0] * upscale, size[1] * upscale), Image.LANCZOS)


def build_glasses() -> None:
    glasses = draw_glasses_aa(LENS_SIZE, LENS_CENTRES, LENS_RADIUS, RIM, upscale=4)
    glasses.save(PROJECT / "my_asset/magpie_glasses.png")
    icon = draw_glasses_aa((256, 256), ((78, 132), (178, 132)), 46, 8, with_temples=False)
    icon.save(PROJECT / "my_asset/magpie_glasses_icon.png")
    print("glasses", glasses.size, "icon", icon.size)


# --------------------------------------------------------------------------- call
def build_call(path: Path, rate: int = 44100) -> None:
    """Two harsh, slightly rising 'chack' notes: band-passed noise with a sharp attack."""
    rng = np.random.default_rng(7)
    total = np.zeros(int(rate * 0.5))
    for start, centre in ((0.02, 1900.0), (0.20, 2200.0)):
        length = int(rate * 0.11)
        noise = rng.standard_normal(length)
        low, high = centre * 0.55, centre * 1.7
        b, a = signal.butter(2, [low / (rate / 2), high / (rate / 2)], btype="band")
        tone = signal.lfilter(b, a, noise)
        t = np.arange(length) / rate
        rasp = 1.0 + 0.6 * np.sign(np.sin(2 * math.pi * 95.0 * t))   # buzzy 95 Hz pulse train
        env = np.minimum(1.0, t / 0.004) * np.exp(-t * 28.0)
        note = tone * rasp * env
        offset = int(start * rate)
        total[offset:offset + length] += note
    total /= np.max(np.abs(total)) + 1e-9
    total *= 0.8
    pcm = (total * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(pcm.tobytes())
    print("call", path.name, f"{len(total) / rate:.2f}s")


if __name__ == "__main__":
    build_senpai()
    build_glasses()
    build_call(PROJECT / "assets/audio/magpie_call.wav")
