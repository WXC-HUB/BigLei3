"""Clay-maquette placeholder diorama for stages that have no real display piece yet.

A plain rounded plateau in warm clay greys with a few abstract blocks (a house, a shed,
block trees, stones): reads as "未上色的泥胚" on the cabinet shelf, so the five stages
still waiting for their artwork keep their place and their badge without pretending
to be finished. Same kit and same entrance-piece encoding as the real dioramas, so it
builds itself in the same way when focused.

Outputs
  assets/dioramas/placeholder/placeholder.glb
  assets/dioramas/placeholder/placeholder.json

Run from the project root:
  "D:/Steam/steamapps/common/Blender/blender.exe" -b --python tools/build_diorama_placeholder.py
"""
import json
import math
import random
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from diorama_kit import Kit, export_glb  # noqa: E402

PROJECT = HERE.parent
OUT_DIR = PROJECT / "assets/dioramas/placeholder"

COLS, ROWS = 24, 17
BOTTOM = -2.1
HEIGHTS = {"L": 0.0}

CLAY_TOP = "#dfd8cd"
CLAY_EDGE = "#d0c9bd"
CLIFF_UP = "#d6cec2"
CLIFF_LOW = "#c3baae"
BLOCK_A = "#e6e0d6"
BLOCK_B = "#d8d1c6"
TRUNK = "#bdb5a9"
STONE = "#cbc4ba"

ENTRANCE_SPAN = 1.2
ENTRANCE_PIECE_TIME = 0.55
ENTRANCE_RISE_TIME = 0.7
ANIM_BOUNDS = ((-16.0, -3.0, -12.0), (32.0, 10.0, 24.0))
_RNG = random.Random(3)


def make_mask() -> list:
    """Rounded rectangle: corners cut on a radius so the slab reads as a soft tile."""
    rows = []
    radius = 3.2
    for r in range(ROWS):
        line = ""
        for c in range(COLS):
            inside = 1 <= r <= ROWS - 2 and 1 <= c <= COLS - 2
            if inside:
                dx = max(0.0, abs(c + 0.5 - COLS / 2.0) - (COLS / 2.0 - 1 - radius))
                dy = max(0.0, abs(r + 0.5 - ROWS / 2.0) - (ROWS / 2.0 - 1 - radius))
                inside = math.hypot(dx, dy) <= radius
            line += "L" if inside else "."
        rows.append(line)
    return rows


MASK = make_mask()


def xy(c: float, r: float):
    return (c - COLS / 2.0, ROWS / 2.0 - r)


def entrance_delay(kind: str, x: float, y: float, extra: float = 0.0) -> float:
    c, r = x + COLS / 2.0, ROWS / 2.0 - y
    sweep = min(max(0.75 * r / ROWS + 0.25 * c / COLS, 0.0), 1.0)
    base = {"building": 0.40, "tree": 0.50, "ground": 0.30}.get(kind, 0.5)
    return base + 0.22 * sweep + extra + _RNG.uniform(0.0, 0.05)


def block_house(kit: Kit, c, r, w, d, h, mat):
    x, y = xy(c, r)
    kit.piece("building", x, y, 0.0)
    kit.box("buildings", (w, d, h), (x, y, h / 2), mat, bevel=0.06, segments=2)
    rise = d * 0.42
    profile = [(y - d / 2 - 0.15, h - 0.02), (y + d / 2 + 0.15, h - 0.02), (y, h + rise)]
    kit.prism("buildings", profile, x - w / 2 - 0.12, x + w / 2 + 0.12, mat)


def block_tree(kit: Kit, c, r, size, mat):
    x, y = xy(c, r)
    kit.piece("tree", x, y, 0.0)
    kit.cyl("trees", 0.16 * size, 0.9 * size, (x, y, 0.45 * size), kit.mat("trunk", TRUNK), verts=8)
    kit.box("trees", (1.4 * size, 1.3 * size, 1.2 * size), (x, y, 0.9 * size + 0.55 * size), mat,
            bevel=0.32 * size, segments=3)


def stone(kit: Kit, c, r, radius):
    x, y = xy(c, r)
    kit.piece("ground", x, y, 0.0)
    kit.rock("props", radius, (x, y, radius * 0.4), kit.mat("stone", STONE), scale=(1.0, 0.85, 0.6),
             rot=(0.0, 0.0, _RNG.uniform(0.0, math.pi)))


def build() -> None:
    kit = Kit(seed=11)
    kit.delay_fn = entrance_delay
    kit.anim_span = ENTRANCE_SPAN
    kit.anim_bounds = ANIM_BOUNDS
    mats = {
        "top": kit.mat("clay_top", CLAY_TOP),
        "bed": kit.mat("clay_top", CLAY_TOP),
        "cap": kit.mat("clay_edge", CLAY_EDGE),
        "cliff_up": kit.mat("cliff_up", CLIFF_UP),
        "cliff_low": kit.mat("cliff_low", CLIFF_LOW),
    }
    kit.terrain(MASK, HEIGHTS, mats, bottom=BOTTOM, seam=-1.1)
    block_a = kit.mat("block_a", BLOCK_A)
    block_b = kit.mat("block_b", BLOCK_B)
    block_house(kit, 8.5, 5.5, 4.4, 3.2, 2.3, block_a)
    block_house(kit, 15.5, 10.5, 2.8, 2.4, 1.7, block_b)
    for (c, r, size) in ((4.0, 4.0, 1.05), (18.5, 4.5, 1.15), (5.0, 11.5, 0.9), (20.0, 12.0, 0.95), (12.5, 3.2, 0.85)):
        block_tree(kit, c, r, size, block_a if size > 1.0 else block_b)
    for (c, r, radius) in ((11.0, 12.8, 0.5), (3.5, 8.5, 0.38), (20.5, 8.0, 0.42)):
        stone(kit, c, r, radius)
    # A flat disc where the badge anchors, so the "plaza" spot reads even on clay.
    x, y = xy(12.0, 9.0)
    kit.piece("ground", x, y, 0.0)
    kit.cyl("props", 1.6, 0.08, (x, y, 0.04), kit.mat("clay_edge", CLAY_EDGE), verts=20)

    merged = kit.finalize(smooth_angle_deg=35.0)
    export_glb(OUT_DIR / "placeholder.glb", merged.values())
    layout = {
        "stage_id": "placeholder",
        "cell": 1.0,
        "cols": COLS,
        "rows": ROWS,
        "mask": MASK,
        "heights": HEIGHTS,
        "bottom": BOTTOM,
        "marker": {"c": 12.0, "r": 9.0},
        "entrance": {
            "span": ENTRANCE_SPAN,
            "piece_time": ENTRANCE_PIECE_TIME,
            "rise_time": ENTRANCE_RISE_TIME,
            "pivot_min": list(ANIM_BOUNDS[0]),
            "pivot_size": list(ANIM_BOUNDS[1]),
        },
    }
    (OUT_DIR / "placeholder.json").write_text(json.dumps(layout, indent=1), encoding="utf-8")
    print("PLACEHOLDER_DONE", OUT_DIR)


build()
