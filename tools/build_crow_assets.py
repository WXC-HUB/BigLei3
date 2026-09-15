"""Build the non-frame assets for the carrion crow (小嘴乌鸦) and its unlock page.

    python tools/build_crow_assets.py

The unlock-page easter egg walks the crow down a line of increasingly ill-advised
victims — cat, dog, sheep, horse, deer, fox, panda — so this script draws all seven
in one curled, dozing pose, plus an angry panda for the chase that ends it.

Outputs:
  my_asset/crow_victim_<key>.png   - 900x600 dozing animal, one per victim
  my_asset/crow_victim_panda_angry.png - the panda once it has felt the pluck
  my_asset/crow_fur_tuft.png       - 200x200 clump of yanked fur (tinted per victim in-game)
  my_asset/crow_fur_icon.png       - 256x256 achievement icon of the same clump
  assets/audio/crow_call.wav       - two harsh descending caws, synthesised
  assets/audio/crow_animal_yelp.wav - one indignant yelp, pitched per victim in-game

The bird frames themselves come from tools/cut_bird_sheet.py (prefix `crow`).
"""
import math
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import signal

PROJECT = Path(__file__).resolve().parents[1]

CANVAS = (900, 600)
SS = 3                                  # supersample factor for every drawing
OUTLINE = (44, 36, 40, 255)
OUTLINE_WIDTH = 7
WHITE = (255, 255, 255, 255)

BODY_C, BODY_R = (500, 330), (295, 160)
HEAD_C, HEAD_R = (215, 268), (132, 126)


# --------------------------------------------------------------------------- the roster
def victim(key, label, fur, belly, dark, ears, tail, marks=(), pitch=1.0):
    return {
        "key": key, "label": label, "fur": fur, "belly": belly, "dark": dark,
        "ears": ears, "tail": tail, "marks": marks, "pitch": pitch,
    }


VICTIMS = [
    victim("cat", "小猫", (196, 190, 186), (242, 238, 232), (168, 160, 158), "triangle", "curl", ("whiskers",), 1.0),
    victim("dog", "小狗", (212, 172, 120), (246, 232, 206), (176, 136, 88), "floppy", "stub", ("snout",), 0.82),
    victim("sheep", "小羊", (246, 243, 238), (255, 253, 250), (206, 200, 192), "droop", "puff", ("fleece", "darkface"), 1.16),
    victim("horse", "小马", (162, 116, 78), (222, 196, 168), (112, 76, 48), "tall", "long", ("mane",), 0.72),
    victim("deer", "小鹿", (198, 148, 100), (240, 218, 190), (150, 106, 66), "leaf", "stub", ("antlers", "spots"), 0.96),
    victim("fox", "狐狸", (226, 128, 60), (250, 240, 228), (186, 92, 36), "bigpoint", "bushy", ("whiskers", "foxmask"), 1.08),
    victim("panda", "熊猫", (247, 245, 242), (255, 255, 255), (210, 206, 200), "round", "stub", ("panda",), 0.62),
]


# --------------------------------------------------------------------------- drawing helpers
def _ellipse(draw, centre, radii, fill):
    cx, cy = centre
    rx, ry = radii
    draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=fill)


def _ellipse_points(centre, radii, count, start=0.0, end=math.tau):
    cx, cy = centre
    rx, ry = radii
    return [
        (cx + rx * math.cos(start + (end - start) * i / count), cy + ry * math.sin(start + (end - start) * i / count))
        for i in range(count + 1)
    ]


def _thick_path(draw, points, start_r, end_r, fill=255):
    """A tapering worm of circles — tails, manes and antlers are all built from this."""
    for i, (x, y) in enumerate(points):
        r = start_r + (end_r - start_r) * (i / max(len(points) - 1, 1))
        draw.ellipse((x - r, y - r, x + r, y + r), fill=fill)


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
        self._draw.ellipse(self._xy(xy), **self._scale_width(kw))

    def polygon(self, xy, **kw):
        self._draw.polygon(self._xy(xy), **self._scale_width(kw))

    def line(self, xy, **kw):
        self._draw.line(self._xy(xy), **self._scale_width(kw))

    def arc(self, xy, start, end, **kw):
        self._draw.arc(self._xy(xy), start, end, **self._scale_width(kw))

    def rectangle(self, xy, **kw):
        self._draw.rectangle(self._xy(xy), **self._scale_width(kw))

    def _scale_width(self, kw):
        kw = dict(kw)
        if "width" in kw:
            kw["width"] = max(1, int(kw["width"] * self._s))
        return kw


# --------------------------------------------------------------------------- silhouette
def ears_shape(draw, style):
    if style == "triangle":
        draw.polygon([(118, 176), (98, 62), (212, 140)], fill=255)
        draw.polygon([(252, 132), (330, 52), (334, 176)], fill=255)
    elif style == "bigpoint":
        draw.polygon([(112, 182), (56, 26), (224, 128)], fill=255)
        draw.polygon([(248, 122), (356, 14), (352, 186)], fill=255)
    elif style == "round":
        _ellipse(draw, (122, 150), (56, 56), 255)
        _ellipse(draw, (306, 130), (56, 56), 255)
    elif style == "floppy":
        _ellipse(draw, (60, 338), (44, 94), 255)
        _ellipse(draw, (364, 326), (42, 90), 255)
    elif style == "droop":
        _ellipse(draw, (104, 244), (54, 32), 255)
        _ellipse(draw, (330, 236), (52, 30), 255)
    elif style == "tall":
        draw.polygon([(142, 172), (122, 30), (198, 150)], fill=255)
        draw.polygon([(256, 146), (320, 24), (330, 170)], fill=255)
    elif style == "leaf":
        _ellipse(draw, (116, 168), (40, 70), 255)
        _ellipse(draw, (312, 156), (38, 68), 255)


def tail_shape(draw, style):
    if style == "curl":
        _thick_path(draw, _ellipse_points((520, 386), (292, 182), 60, start=-0.12, end=math.pi * 0.62), 38, 24)
    elif style == "stub":
        _ellipse(draw, (784, 322), (48, 44), 255)
    elif style == "puff":
        for cx, cy, r in ((790, 316, 46), (830, 348, 34), (760, 356, 32)):
            _ellipse(draw, (cx, cy), (r, r), 255)
    elif style == "long":
        _thick_path(draw, _ellipse_points((700, 330), (140, 250), 40, start=-0.35, end=math.pi * 0.42), 34, 16)
    elif style == "bushy":
        _thick_path(draw, _ellipse_points((672, 306), (132, 170), 36, start=-0.62, end=math.pi * 0.34), 66, 30)


def antlers_shape(draw):
    for base_x, flip in ((156, -1), (286, 1)):
        main = [(base_x + flip * i * 9, 172 - i * 26) for i in range(6)]
        _thick_path(draw, main, 17, 9)
        for start, count, spread in ((1, 4, 20), (3, 3, 17)):
            branch = [(main[start][0] + flip * i * spread, main[start][1] - i * 11) for i in range(count)]
            _thick_path(draw, branch, 12, 6)


def animal_silhouette(draw, spec):
    _ellipse(draw, BODY_C, BODY_R, 255)
    _ellipse(draw, HEAD_C, HEAD_R, 255)
    ears_shape(draw, spec["ears"])
    tail_shape(draw, spec["tail"])
    if "antlers" in spec["marks"]:
        antlers_shape(draw)
    if "fleece" in spec["marks"]:
        rng = np.random.default_rng(5)
        edge = (
            _ellipse_points(BODY_C, (BODY_R[0] + 4, BODY_R[1] + 4), 52)
            + _ellipse_points(HEAD_C, (HEAD_R[0] + 2, HEAD_R[1] + 2), 26)
        )
        for x, y in edge:
            r = float(rng.uniform(24, 38))
            draw.ellipse((x - r, y - r, x + r, y + r), fill=255)


# --------------------------------------------------------------------------- markings and face
def animal_details(draw, spec, angry=False):
    fur, belly, dark = spec["fur"], spec["belly"], spec["dark"]
    # Base coat, then the pale underside. The coat is a flood fill: every ear tip, antler
    # and tail tuft has to end up painted, and the silhouette clip trims it back.
    draw.rectangle((0, 0, CANVAS[0], CANVAS[1]), fill=fur)
    _ellipse(draw, (470, 408), (250, 96), belly)
    _ellipse(draw, (206, 322), (104, 74), belly)

    if "panda" in spec["marks"]:
        _ellipse(draw, (122, 150), (58, 58), OUTLINE)
        _ellipse(draw, (306, 130), (58, 58), OUTLINE)
        _ellipse(draw, (560, 256), (210, 120), (38, 34, 36, 255))     # black shoulder band
        _ellipse(draw, (784, 322), (50, 46), OUTLINE)
    else:
        inner = (240, 176, 178, 255)
        if spec["ears"] in ("triangle", "bigpoint"):
            draw.polygon([(130, 168), (112, 84), (196, 142)], fill=inner)
            draw.polygon([(262, 134), (326, 62), (326, 172)], fill=inner)
        elif spec["ears"] == "leaf":
            _ellipse(draw, (116, 170), (24, 46), inner)
            _ellipse(draw, (312, 158), (22, 44), inner)
        elif spec["ears"] == "tall":
            draw.polygon([(148, 170), (132, 60), (186, 152)], fill=inner)
            draw.polygon([(264, 148), (312, 54), (318, 166)], fill=inner)

    if "darkface" in spec["marks"]:
        _ellipse(draw, (196, 296), (92, 82), dark)
    if "foxmask" in spec["marks"]:
        _ellipse(draw, (206, 316), (96, 66), belly)
        _ellipse(draw, (738, 452), (46, 44), belly)          # white tail tip
    if "mane" in spec["marks"]:
        _thick_path(
            draw,
            _ellipse_points(BODY_C, (BODY_R[0] * 0.84, BODY_R[1] * 0.9), 18, start=math.pi * 1.06, end=math.pi * 1.58),
            26, 13, fill=dark,
        )
    if "spots" in spec["marks"]:
        for cx, cy in ((430, 250), (520, 232), (610, 258), (470, 300), (570, 306), (660, 300)):
            _ellipse(draw, (cx, cy), (20, 15), (250, 240, 226, 255))
    if "snout" in spec["marks"]:
        _ellipse(draw, (196, 322), (78, 54), belly)
    # Face.
    if angry:
        _ellipse(draw, (180, 272), (27, 31), OUTLINE)
        _ellipse(draw, (272, 272), (27, 31), OUTLINE)
        _ellipse(draw, (188, 262), (9, 10), WHITE)
        _ellipse(draw, (280, 262), (9, 10), WHITE)
        draw.line([(142, 212), (216, 240)], fill=OUTLINE, width=10)
        draw.line([(310, 212), (236, 240)], fill=OUTLINE, width=10)
        _ellipse(draw, (226, 336), (34, 24), (150, 62, 66, 255))       # open, shouting
    else:
        draw.arc((146, 246, 214, 308), 200, 340, fill=OUTLINE, width=7)
        draw.arc((238, 246, 306, 308), 200, 340, fill=OUTLINE, width=7)
        draw.arc((196, 318, 256, 358), 200, 340, fill=OUTLINE, width=6)
    draw.polygon([(212, 300), (240, 300), (226, 318)], fill=(224, 150, 152, 255))
    if "whiskers" in spec["marks"]:
        for y0, y1 in ((286, 272), (300, 300), (314, 328)):
            draw.line([(150, y0), (54, y1)], fill=OUTLINE, width=5)


def build_animal(spec, angry=False) -> Image.Image:
    big = (CANVAS[0] * SS, CANVAS[1] * SS)
    mask = Image.new("L", big, 0)
    animal_silhouette(_ScaledDraw(ImageDraw.Draw(mask), SS), spec)
    grown = mask.filter(ImageFilter.MaxFilter(OUTLINE_WIDTH * SS * 2 + 1))

    out = Image.new("RGBA", big, (0, 0, 0, 0))
    out.paste(Image.new("RGBA", big, OUTLINE), (0, 0), grown)
    painted = Image.new("RGBA", big, (0, 0, 0, 0))
    animal_details(_ScaledDraw(ImageDraw.Draw(painted), SS), spec, angry)
    painted.putalpha(Image.composite(painted.getchannel("A"), Image.new("L", big, 0), mask))
    out.alpha_composite(painted)
    return out.resize(CANVAS, Image.LANCZOS)


def build_all_animals() -> None:
    for spec in VICTIMS:
        image = build_animal(spec)
        image.save(PROJECT / f"my_asset/crow_victim_{spec['key']}.png")
        print("victim", spec["key"], image.size, "bbox", image.getbbox())
    panda = next(s for s in VICTIMS if s["key"] == "panda")
    angry = build_animal(panda, angry=True)
    angry.save(PROJECT / "my_asset/crow_victim_panda_angry.png")
    print("victim panda_angry", angry.size)


# --------------------------------------------------------------------------- yanked fur
def build_tuft() -> None:
    big = (200 * SS, 200 * SS)
    mask = Image.new("L", big, 0)
    md = _ScaledDraw(ImageDraw.Draw(mask), SS)
    for cx, cy, r in ((100, 112, 46), (66, 92, 34), (136, 94, 32), (82, 138, 30), (124, 140, 28)):
        _ellipse(md, (cx, cy), (r, r), 255)
    grown = mask.filter(ImageFilter.MaxFilter(OUTLINE_WIDTH * SS * 2 + 1))
    out = Image.new("RGBA", big, (0, 0, 0, 0))
    out.paste(Image.new("RGBA", big, OUTLINE), (0, 0), grown)
    # Near-white so the page can tint the clump to whichever animal just lost it.
    out.paste(Image.new("RGBA", big, (250, 248, 245, 255)), (0, 0), mask)
    tuft = out.resize((200, 200), Image.LANCZOS)
    hair = ImageDraw.Draw(tuft)
    for (x0, y0), (x1, y1) in (((58, 76), (24, 40)), ((146, 74), (182, 44)), ((104, 62), (110, 22))):
        hair.line([(x0, y0), (x1, y1)], fill=OUTLINE, width=5)
    tuft.save(PROJECT / "my_asset/crow_fur_tuft.png")
    icon = tuft.resize((216, 216), Image.LANCZOS)
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    canvas.paste(icon, (20, 20), icon)
    canvas.save(PROJECT / "my_asset/crow_fur_icon.png")
    print("fur tuft", tuft.size, "icon", canvas.size)


# --------------------------------------------------------------------------- audio
def build_call(path: Path, rate: int = 44100) -> None:
    """Two harsh descending caws: buzzy band-passed noise with a slow formant sweep."""
    rng = np.random.default_rng(3)
    total = np.zeros(int(rate * 0.72))
    for start, centre in ((0.02, 1250.0), (0.36, 1100.0)):
        length = int(rate * 0.26)
        t = np.arange(length) / rate
        noise = rng.standard_normal(length)
        out = np.zeros(length)
        step = length // 8
        for chunk in range(8):
            lo_hz = centre * (1.0 - 0.045 * chunk) * 0.6
            hi_hz = centre * (1.0 - 0.045 * chunk) * 2.1
            b, a = signal.butter(2, [lo_hz / (rate / 2), min(hi_hz / (rate / 2), 0.98)], btype="band")
            piece = slice(chunk * step, (chunk + 1) * step if chunk < 7 else length)
            out[piece] = signal.lfilter(b, a, noise[piece])
        rasp = 1.0 + 0.75 * np.sign(np.sin(2 * math.pi * 118.0 * t))
        env = np.minimum(1.0, t / 0.012) * np.clip(1.0 - (t / 0.26) ** 1.6, 0.0, 1.0)
        offset = int(start * rate)
        total[offset:offset + length] += out * rasp * env
    total /= np.max(np.abs(total)) + 1e-9
    _write_wav(path, total * 0.82, rate)
    print("call", path.name, f"{len(total) / rate:.2f}s")


def build_yelp(path: Path, rate: int = 44100) -> None:
    """One indignant yelp: a reedy tone that swoops up then sags. Pitched per animal in-game."""
    length = int(rate * 0.46)
    t = np.arange(length) / rate
    glide = t / t[-1]
    f0 = 610.0 + 210.0 * np.sin(math.pi * glide) - 190.0 * glide
    phase = 2 * math.pi * np.cumsum(f0) / rate
    tone = sum(np.sin(phase * n) / n for n in (1, 2, 3, 4, 5))
    tone *= 1.0 + 0.09 * np.sin(2 * math.pi * 22.0 * t)
    voiced = np.zeros(length)
    for centre, weight in ((900.0, 1.0), (2100.0, 0.55)):
        b, a = signal.butter(2, [centre * 0.72 / (rate / 2), centre * 1.38 / (rate / 2)], btype="band")
        voiced += weight * signal.lfilter(b, a, tone)
    voiced *= np.minimum(1.0, t / 0.03) * np.clip(1.0 - (t / 0.46) ** 2.1, 0.0, 1.0)
    voiced /= np.max(np.abs(voiced)) + 1e-9
    _write_wav(path, voiced * 0.78, rate)
    print("yelp", path.name, f"{length / rate:.2f}s")


def _write_wav(path: Path, samples: np.ndarray, rate: int) -> None:
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes((samples * 32767).astype(np.int16).tobytes())


if __name__ == "__main__":
    build_all_animals()
    build_tuft()
    build_call(PROJECT / "assets/audio/crow_call.wav")
    build_yelp(PROJECT / "assets/audio/crow_animal_yelp.wav")
