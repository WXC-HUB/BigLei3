"""Build the non-frame assets for the turtle dove (斑鸠) and its unlock page.

    python tools/build_dove_assets.py

斑鸠 are famously slapdash nest builders — a few sticks thrown across each other and
that is the nest. The unlock-page easter egg leans on that, so the only prop it needs
is one twig, dropped over and over at random angles until the pile passes for a nest.

Outputs:
  my_asset/dove_twig.png       - 180x120 sprig, the twig it keeps fetching
  my_asset/dove_nest_icon.png  - 256x256 achievement icon: the finished scruffy nest
  assets/audio/dove_coo.wav    - two soft coos, synthesised

The bird frames themselves come from tools/cut_bird_sheet.py (prefix `dove`).
"""
import math
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import signal

PROJECT = Path(__file__).resolve().parents[1]

SS = 3                                   # supersample factor
OUTLINE = (58, 46, 36, 255)
OUTLINE_WIDTH = 4
WOOD = (150, 112, 74, 255)
LEAF = (146, 176, 108, 255)
LEAF_DARK = (118, 148, 86, 255)

TWIG_SIZE = (180, 120)


class _ScaledDraw:
    """Lets the drawing code work in final pixels while rendering supersampled."""

    def __init__(self, draw, scale):
        self._draw = draw
        self._s = scale

    def _xy(self, xy):
        if isinstance(xy[0], (int, float)):
            return [v * self._s for v in xy]
        return [(x * self._s, y * self._s) for x, y in xy]

    def ellipse(self, xy, **kw):
        self._draw.ellipse(self._xy(xy), **kw)

    def polygon(self, xy, **kw):
        self._draw.polygon(self._xy(xy), **kw)

    def line(self, xy, **kw):
        kw = dict(kw)
        if "width" in kw:
            kw["width"] = max(1, int(kw["width"] * self._s))
        self._draw.line(self._xy(xy), **kw)


def _ellipse(draw, centre, radii, fill):
    cx, cy = centre
    rx, ry = radii
    draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=fill)


def _thick_path(draw, points, start_r, end_r, fill=255):
    for i, (x, y) in enumerate(points):
        r = start_r + (end_r - start_r) * (i / max(len(points) - 1, 1))
        draw.ellipse((x - r, y - r, x + r, y + r), fill=fill)


def _leaf(draw, base, tip, width, fill) -> None:
    """A pointed leaf: two arcs bulging off the base→tip line, pinched to a point at both ends."""
    bx, by = base
    tx, ty = tip
    dx, dy = tx - bx, ty - by
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    points = []
    for side in (1, -1):
        for step in range(13):
            along = step / 12 if side == 1 else 1.0 - step / 12
            swell = width * math.sin(math.pi * along) * 0.5 * side
            points.append((bx + ux * length * along + nx * swell, by + uy * length * along + ny * swell))
    draw.polygon(points, fill=fill)


def twig_shapes(draw, fill_wood, fill_leaf, fill_leaf_dark) -> None:
    """One sprig: a thin stick running left to right, three narrow leaves angled off it."""
    # 圆点要叠起来才看着是一根枝：步长必须小于半径，不然会画成一串珠子。
    stem = [(16 + i * 4.1, 94 - i * 1.15 + 0.0028 * i * i) for i in range(40)]
    _thick_path(draw, stem, 7, 4, fill=fill_wood)
    # base on the stem -> tip out in the air; alternating sides so it reads as a sprig.
    for base, tip, width, dark in (
        ((52, 80), (26, 40), 26, True),
        ((92, 66), (104, 24), 24, False),
        ((132, 56), (166, 26), 22, True),
    ):
        _leaf(draw, base, tip, width, fill_leaf_dark if dark else fill_leaf)


def outlined(size, paint) -> Image.Image:
    """Flat cartoon shape: solid fills with one uniform dark outline around the silhouette."""
    big = (size[0] * SS, size[1] * SS)
    mask = Image.new("L", big, 0)
    paint(_ScaledDraw(ImageDraw.Draw(mask), SS), 255, 255, 255)
    grown = mask.filter(ImageFilter.MaxFilter(OUTLINE_WIDTH * SS * 2 + 1))
    out = Image.new("RGBA", big, (0, 0, 0, 0))
    out.paste(Image.new("RGBA", big, OUTLINE), (0, 0), grown)
    body = Image.new("RGBA", big, (0, 0, 0, 0))
    paint(_ScaledDraw(ImageDraw.Draw(body), SS), WOOD, LEAF, LEAF_DARK)
    body.putalpha(Image.composite(body.getchannel("A"), Image.new("L", big, 0), mask))
    out.alpha_composite(body)
    return out.resize(size, Image.LANCZOS)


def build_twig() -> Image.Image:
    twig = outlined(TWIG_SIZE, twig_shapes)
    twig.save(PROJECT / "my_asset/dove_twig.png")
    print("twig", twig.size, "bbox", twig.getbbox())
    return twig


def build_nest_icon(twig: Image.Image) -> None:
    """The 'nest': the same twig thrown down a few times at whatever angle. That is the joke."""
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    rng = np.random.default_rng(4)
    for i in range(6):
        piece = twig.resize((150, 100), Image.LANCZOS).rotate(
            float(rng.uniform(-70, 70)), resample=Image.BICUBIC, expand=True
        )
        x = int(58 + rng.uniform(-38, 38) - piece.width * 0.5)
        y = int(150 + rng.uniform(-26, 26) - piece.height * 0.5)
        canvas.alpha_composite(piece, (max(x, 0), max(y, 0)))
    canvas.save(PROJECT / "my_asset/dove_nest_icon.png")
    print("nest icon", canvas.size, "bbox", canvas.getbbox())


def build_coo(path: Path, rate: int = 44100) -> None:
    """Two soft coos: a low breathy tone that dips in the middle, like 咕—咕."""
    total = np.zeros(int(rate * 0.95))
    for start, base in ((0.02, 430.0), (0.46, 400.0)):
        length = int(rate * 0.36)
        t = np.arange(length) / rate
        shape = t / t[-1]
        f0 = base * (1.0 + 0.12 * np.sin(math.pi * shape) - 0.06 * shape)
        phase = 2 * math.pi * np.cumsum(f0) / rate
        # Mostly fundamental with a soft second harmonic: round and breathy, not reedy.
        tone = np.sin(phase) + 0.28 * np.sin(phase * 2.0) + 0.08 * np.sin(phase * 3.0)
        b, a = signal.butter(2, 1400.0 / (rate / 2), btype="low")
        tone = signal.lfilter(b, a, tone)
        env = np.minimum(1.0, t / 0.06) * np.clip(1.0 - (t / 0.36) ** 1.8, 0.0, 1.0)
        offset = int(start * rate)
        total[offset:offset + length] += tone * env
    total /= np.max(np.abs(total)) + 1e-9
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes((total * 0.72 * 32767).astype(np.int16).tobytes())
    print("coo", path.name, f"{len(total) / rate:.2f}s")


if __name__ == "__main__":
    build_nest_icon(build_twig())
    build_coo(PROJECT / "assets/audio/dove_coo.wav")
