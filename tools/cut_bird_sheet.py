"""Cut a green-screen bird sprite sheet into BirdPerch-standard frames.

Usage:
    python tools/cut_bird_sheet.py my_asset/birds/source/tit_sheet.png tit

Sheet layout: 2 rows x 4 columns of birds, each labelled with a frame number
(a circled digit under the bird, or a bare digit in the cell's top corner).
Row 1 (frames 1-4) is the idle loop, row 2 (frames 5-8) the action sequence.
Birds are found as connected blobs (so tails that cross the grid lines stay
with their own bird); loose bits such as speed lines, puffs, sweat drops and
crumbs attach to the nearest bird; the frame numbers are dropped.

Output follows docs/BIRD_PREFAB_STANDARD.md: 220x220 transparent PNGs in
my_asset/birds/<prefix>_idle_N.png and <prefix>_action_N.png, plus a 256x256
item icon in assets/sprites/generated/bird_items/item_bird_<prefix>.png.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

CANVAS = 220
CONTENT_MAX = 208          # ~6px transparent margin, like the existing birds
ICON_CANVAS = 256
ICON_CONTENT = 196
COLS, ROWS = 4, 2
BIRD_MIN_AREA = 4000       # px; anything smaller is a label or a loose detail
LABEL_MAX_SIZE = 90        # a frame number is ~30x40 (bare) or ~45px square (circled)
ATTACH_MAX_DIST = 150      # loose detail must be this close to a bird's box to belong to it
LABEL_MIN_ISOLATION = 45   # a frame number floats this far from every bird; real details hug theirs
PROJECT = Path(__file__).resolve().parents[1]


def chroma_alpha(rgb: np.ndarray, bg: np.ndarray) -> np.ndarray:
    """Alpha from green dominance, linear between 'no green' and 'as green as the backdrop'."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    greenness = g - np.maximum(r, b)
    bg_greenness = float(bg[1] - max(bg[0], bg[2]))
    lo, hi = 12.0, bg_greenness * 0.92
    alpha = 1.0 - np.clip((greenness - lo) / (hi - lo), 0.0, 1.0)
    dist = np.linalg.norm(rgb - bg, axis=-1)
    alpha[dist < 28.0] = 0.0
    return alpha


def despill(rgb: np.ndarray, alpha: np.ndarray, bg: np.ndarray) -> np.ndarray:
    """Un-mix the backdrop out of semi-transparent edge pixels."""
    a = alpha[..., None]
    safe = np.where(a > 0.02, a, 1.0)
    fg = (rgb - (1.0 - a) * bg) / safe
    fg = np.where(a > 0.02, fg, rgb)
    cap = np.maximum(fg[..., 0], fg[..., 2]) + 6.0
    fg[..., 1] = np.minimum(fg[..., 1], cap)
    return np.clip(fg, 0, 255)


def box_distance(box, point) -> float:
    x0, y0, x1, y1 = box
    dx = max(x0 - point[0], 0.0, point[0] - x1)
    dy = max(y0 - point[1], 0.0, point[1] - y1)
    return float(np.hypot(dx, dy))


def segment(alpha: np.ndarray):
    """Return one pixel mask per frame, ordered row-major like the sheet."""
    labels, count = ndimage.label(alpha > 0.15)
    slices = ndimage.find_objects(labels)
    areas = ndimage.sum(np.ones_like(labels), labels, index=range(1, count + 1))
    birds, loose = [], []
    for idx in range(count):
        sl = slices[idx]
        box = (sl[1].start, sl[0].start, sl[1].stop, sl[0].stop)
        if areas[idx] >= BIRD_MIN_AREA:
            birds.append({"id": idx + 1, "box": box})
        else:
            loose.append({"id": idx + 1, "box": box, "area": areas[idx]})
    assert len(birds) == COLS * ROWS, f"expected {COLS * ROWS} birds, found {len(birds)}"
    birds.sort(key=lambda b: (b["box"][1] + b["box"][3]) / 2)
    rows = [sorted(birds[i * COLS:(i + 1) * COLS], key=lambda b: b["box"][0]) for i in range(ROWS)]
    birds = [b for row in rows for b in row]
    for bird in birds:
        bird["ids"] = [bird["id"]]

    # Pass 1: find the frame numbers. Two layouts show up in practice — a circled digit
    # sitting under its bird, and a bare digit parked in the cell's top corner. Both are
    # small; what really sets them apart from speed lines, crumbs and sweat drops is that
    # they float clear of every bird, while a real detail hugs the bird it belongs to.
    label_boxes = []
    for part in loose:
        x0, y0, x1, y1 = part["box"]
        w, h = x1 - x0, y1 - y0
        if w > LABEL_MAX_SIZE or h > LABEL_MAX_SIZE:
            continue
        centre = ((x0 + x1) / 2, (y0 + y1) / 2)
        isolation = min(box_distance(b["box"], centre) for b in birds)
        below_a_bird = any(
            b["box"][3] <= y0 and b["box"][0] - 40 <= centre[0] <= b["box"][2] + 40 for b in birds
        )
        circled_under_a_bird = abs(w - h) < 30 and below_a_bird and part["area"] > 250
        if circled_under_a_bird or isolation >= LABEL_MIN_ISOLATION:
            label_boxes.append((x0 - 4, y0 - 4, x1 + 4, y1 + 4))
    # Pass 2: everything else (speed lines, puffs, sweat drops, crumbs) belongs to the
    # nearest bird, except the digits sitting inside a label ring.
    for part in loose:
        x0, y0, x1, y1 = part["box"]
        centre = ((x0 + x1) / 2, (y0 + y1) / 2)
        if any(lx0 <= centre[0] <= lx1 and ly0 <= centre[1] <= ly1 for lx0, ly0, lx1, ly1 in label_boxes):
            continue
        nearest = min(birds, key=lambda b: box_distance(b["box"], centre))
        if box_distance(nearest["box"], centre) <= ATTACH_MAX_DIST:
            nearest["ids"].append(part["id"])
    return [np.isin(labels, bird["ids"]) for bird in birds]


def frame_image(rgb: np.ndarray, alpha: np.ndarray, mask: np.ndarray) -> Image.Image:
    # Grow the hard mask a little so the anti-aliased rim survives.
    rim = ndimage.binary_dilation(mask, iterations=2)
    a = np.where(rim, alpha, 0.0)
    rgba = np.dstack([rgb, a * 255.0]).round().astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def head_anchor_x(alpha: np.ndarray, box) -> float:
    """Horizontal centre of the upper part of the bird (the round body, not the tail)."""
    x0, y0, x1, y1 = box
    top = alpha[y0:y0 + int((y1 - y0) * 0.45), x0:x1]
    xs = np.arange(x0, x1)
    weights = top.sum(axis=0)
    return float((xs * weights).sum() / max(weights.sum(), 1e-6))


def place(img: Image.Image, scale: float, canvas: int, anchor_src, anchor_dst) -> Image.Image:
    """Scale the frame uniformly and paste so anchor_src (sheet px) lands on anchor_dst (canvas px)."""
    box = img.getbbox()
    crop = img.crop(box)
    size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    crop = crop.resize(size, Image.LANCZOS)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    x = round(anchor_dst[0] - (anchor_src[0] - box[0]) * scale)
    y = round(anchor_dst[1] - (anchor_src[1] - box[1]) * scale)
    out.paste(crop, (x, y), crop)
    return out


def main() -> None:
    sheet_path = Path(sys.argv[1])
    prefix = sys.argv[2]
    sheet = np.asarray(Image.open(sheet_path).convert("RGB")).astype(np.float64)
    h, w, _ = sheet.shape
    corners = np.stack([sheet[4, 4], sheet[4, w - 5], sheet[h - 5, 4], sheet[h - 5, w - 5]])
    bg = corners.mean(axis=0)
    print(f"backdrop colour {bg.round().astype(int)}")

    alpha = chroma_alpha(sheet, bg)
    rgb = despill(sheet, alpha, bg)
    masks = segment(alpha)
    frames = [frame_image(rgb, alpha, m) for m in masks]
    boxes = [f.getbbox() for f in frames]
    for i, b in enumerate(boxes):
        print(f"frame {i + 1}: sheet box {b} size {b[2] - b[0]}x{b[3] - b[1]}")

    # One shared scale for all eight frames so the bird's body never pops between frames.
    largest = max(max(b[2] - b[0], b[3] - b[1]) for b in boxes)
    scale = CONTENT_MAX / largest
    print(f"largest extent {largest}px -> scale {scale:.3f}")

    out_dir = PROJECT / "my_asset" / "birds"

    # Idle frames: feet on a shared baseline, body centred on a shared vertical line.
    idle = list(range(COLS))
    anchors = [(head_anchor_x(alpha, boxes[i]), boxes[i][3]) for i in idle]
    left = max((anchors[i][0] - boxes[i][0]) for i in idle) * scale
    right = max((boxes[i][2] - anchors[i][0]) for i in idle) * scale
    height = max((boxes[i][3] - boxes[i][1]) for i in idle) * scale
    assert left + right <= CANVAS and height <= CANVAS, "idle frames do not fit the canvas at the shared scale"
    dst = ((CANVAS - (left + right)) / 2 + left, CANVAS - (CANVAS - height) / 2)
    for i in idle:
        img = place(frames[i], scale, CANVAS, anchors[i], dst)
        path = out_dir / f"{prefix}_idle_{i + 1}.png"
        img.save(path)
        print("wrote", path.relative_to(PROJECT), img.getbbox())

    # Action frames: each centred on its own extent.
    for i in range(COLS, COLS * ROWS):
        b = boxes[i]
        centre = ((b[0] + b[2]) / 2, (b[1] + b[3]) / 2)
        img = place(frames[i], scale, CANVAS, centre, (CANVAS / 2, CANVAS / 2))
        path = out_dir / f"{prefix}_action_{i - COLS + 1}.png"
        img.save(path)
        print("wrote", path.relative_to(PROJECT), img.getbbox())

    b = boxes[0]
    icon_scale = ICON_CONTENT / max(b[2] - b[0], b[3] - b[1])
    icon = place(
        frames[0], icon_scale, ICON_CANVAS,
        ((b[0] + b[2]) / 2, (b[1] + b[3]) / 2), (ICON_CANVAS / 2, ICON_CANVAS / 2),
    )
    icon_path = PROJECT / "assets" / "sprites" / "generated" / "bird_items" / f"item_bird_{prefix}.png"
    icon.save(icon_path)
    print("wrote", icon_path.relative_to(PROJECT), icon.getbbox())


if __name__ == "__main__":
    main()
