"""Stage 1 diorama "青草坡" (grass slope): a terraced orchard homestead.

Composition (viewer at the front-right): a raised back terrace carries the cottage
with its tiled roof, a birdhouse and a vegetable bed under a screen of block trees;
stone steps lead down to the lower orchard terrace where fruit trees stand in loose
rows around a flagstone plaza with a bird bath - the plaza is where the stage badge
anchors. A stream cuts down the right side, crossed by a plank bridge, and spills
over the front edge as a small fall. Palette: sage grass, cream walls, terracotta
tiles - the reference farmstead's colours; the table is warm cream with sand / sage /
clay dots.

Outputs
  assets/dioramas/grass_1/grass_1.glb   the whole piece (terrain, buildings, trees, props)
  assets/dioramas/grass_1/grass_1.json  cell mask + heights + anchors + palette for the Godot side
  artifacts/diorama_grass_1_ground.png  the painted plateau top (also embedded in the GLB)

Run from the project root:
  "D:/Steam/steamapps/common/Blender/blender.exe" -b --python tools/build_diorama_grass_1.py
"""
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from diorama_kit import GroundPainter, Kit, export_glb  # noqa: E402
from diorama_props import (Props, Scene, make_entrance_delay, write_layout, variant_setup, wither_hex, wither_table,  # noqa: E402
                           ANIM_BOUNDS, ENTRANCE_DEFAULTS)

PROJECT = HERE.parent
STAGE = "grass_1"
OUT_DIR = PROJECT / "assets/dioramas" / STAGE
# DIORAMA_WITHERED=1 builds the derelict variant (<stage>_withered.glb/.json) from the same layout.
WITHERED, VARIANT = variant_setup(STAGE)
GROUND_PNG = PROJECT / "artifacts" / f"diorama_{VARIANT}_ground.png"

MASK = [
    "..............................",
    "....UUUUUUUUUUUUU.............",
    "...UUUUUUUUUUUUUUUL...........",
    "...UUUUUUUUUUUUUUULKKKKKKK....",
    "..UUUUUUUUUUUUUUUULKKKKKKKW...",
    "..UUUUUUUUUUUUUUULLKKKKKKKWW..",
    "..UUUUUUUUUUUUUULLLKKKKKLLLWL.",
    "..UUUUUUUUUUUUULLLLLLLLLLLLWL.",
    ".LLUUUUUUUUUUUULLLLLLLLLLLWWL.",
    ".LLLLLLLLLLLLLLLLLLLLLLLLLWLL.",
    ".LLLLLLLLLLLLLLLLLLLLLLLLWWLL.",
    ".LLLLLLLLLLLLLLLLLLLLLLLLWLLL.",
    "...LLLLLLLLLLLLLLLLLLLLLLWLLL.",
    "...LLLLLLLLLLLLLLLLLLLLLWWLL..",
    "..LLLLLLLLLLLLLLLLLLLLLLWLLL..",
    "..LLLLLLLLLLLLLLLLLLLLLLWLL...",
    "...LLLLLLLLLLLLLLLLLLLLWWL....",
    "....LLLLLLLLLLLLLLLLLLLWL.....",
    "......LLLLLLLLLLLLLLLLLW......",
    "........LLLLLLLLLLLL..........",
    "..............................",
    "..............................",
]
HEIGHTS = {"L": 0.0, "U": 0.9, "K": 0.45, "W": -0.45}
WATER_Y = -0.2
BOTTOM = -2.1
SCENE = Scene(MASK, HEIGHTS, BOTTOM, None if WITHERED else WATER_Y)

# Stage 1's palette is the props module's default; only the table/water are stated here.
PALETTE = {}
TABLE = {"far": "#f8f4ea", "near": "#ece3d2", "dots": ["#e6dbc6", "#cfd8bf", "#ecdacd"]}
WATER = {"shallow": "#a9d8d0", "deep": "#78b3a8"}

TREES = [  # (c, r, size, leaf, fruit, tall)
    (5.0, 2.3, 1.15, 0, None, True), (12.9, 1.9, 1.05, 2, None, True), (3.3, 5.6, 1.0, 1, None, True),
    (16.2, 3.3, 1.0, 3, None, True), (15.2, 7.2, 0.95, 0, None, True),
    (3.6, 10.6, 0.9, 2, 0, False), (6.4, 11.7, 0.95, 0, 1, False), (3.7, 13.5, 0.85, 1, 0, False),
    (5.6, 14.5, 0.9, 3, 1, False), (8.3, 13.3, 0.85, 2, 0, False), (4.5, 16.5, 0.85, 0, 0, False),
    (7.6, 17.0, 0.8, 1, 1, False), (17.7, 15.9, 0.9, 2, 0, False), (20.1, 14.6, 0.9, 0, 1, False),
    (16.3, 11.7, 0.85, 3, 0, False),
]
PINES = [(19.6, 3.6, 1.0, False), (22.1, 3.5, 1.15, True), (24.3, 4.6, 0.9, False), (28.3, 9.6, 0.95, True), (27.9, 11.0, 0.8, False)]
BUSHES = [(6.8, 6.6, 0.9), (13.0, 6.5, 0.8), (15.6, 9.7, 1.0), (21.6, 13.6, 0.9), (2.9, 11.6, 0.8), (9.2, 16.7, 0.9),
          (17.3, 17.5, 0.8), (13.6, 8.3, 0.7), (24.8, 7.6, 0.85), (17.4, 7.4, 0.75)]
STONES_AT = [(16.6, 8.5, 0.42, 0), (22.9, 15.7, 0.38, 1), (19.3, 17.3, 0.30, 2), (27.4, 9.4, 0.34, 0), (5.0, 8.4, 0.36, 1),
             (15.9, 17.4, 0.26, 0), (3.3, 15.0, 0.32, 2), (25.9, 14.0, 0.30, 1), (2.2, 9.4, 0.28, 0)]
COTTAGE = (9.8, 4.4)
DOVECOTE = (18.8, 11.0)
HAYSTACKS = [(21.4, 8.9, 1.0), (22.9, 10.1, 0.8)]
PLAZA = (12.5, 14.5)
STEPS_C = 10.3
PATH_UPPER = [(9.8, 6.3), (10.0, 7.6), (10.3, 8.95)]
PATH_MAIN = [(10.3, 9.95), (10.9, 11.6), (12.0, 13.2), (12.5, 14.5), (12.2, 16.4), (12.4, 18.6)]
PATH_BRIDGE = [(12.5, 14.5), (15.4, 14.1), (18.6, 13.8), (21.8, 12.6), (24.1, 11.5)]
FENCE_FRONT_A = [(6.8, 18.55), (11.2, 18.55)]
FENCE_FRONT_B = [(13.7, 18.55), (18.6, 18.55)]
FENCE_BANK = [(26.5, 12.45), (28.4, 12.45)]
FENCE_LEFT = [(1.45, 9.4), (1.45, 11.7)]
FLOWER_SPOTS = [(6.2, 8.1), (12.4, 8.1), (8.2, 6.0), (11.6, 6.4), (3.8, 12.4), (7.4, 14.9), (10.2, 17.3), (14.7, 17.6),
                (16.4, 12.4), (19.4, 16.2), (22.8, 13.6), (27.5, 10.3), (2.4, 10.4), (15.0, 15.2), (20.6, 8.4), (5.6, 3.9)]
TUFT_SPOTS = [(4.2, 9.5), (7.9, 10.3), (9.4, 12.2), (14.4, 10.6), (17.2, 14.2), (19.0, 9.2), (23.3, 9.6), (22.1, 16.4),
              (5.9, 16.0), (4.6, 17.2), (11.2, 15.9), (16.8, 16.9), (20.7, 6.6), (17.9, 5.2), (14.6, 5.4), (6.8, 2.2),
              (2.9, 7.9), (13.0, 11.2), (25.5, 15.6), (26.4, 7.2), (9.1, 18.0), (18.6, 18.0), (22.2, 5.9), (8.6, 9.2)]
LILIES = [(26.5, 5.4), (26.3, 8.3), (25.4, 10.3), (24.5, 13.4), (26.8, 5.9)]


def paint_ground() -> Path:
    gp = GroundPainter(SCENE.cols, SCENE.rows, px=64, seed=11, tint=wither_hex if WITHERED else None)
    gp.checker("#bccb90", "#b0c285")
    if WITHERED:
        # the stream has dried to cracked mud
        gp.paint_cells(MASK, "W", lambda g: g.cobbles("#9a8b74", "#8b7d68", "#6f6354", cell=0.7, joint_width=0.07), feather_cells=0.12)
    gp.path(PATH_UPPER, 1.05)
    gp.path(PATH_MAIN, 1.15)
    gp.path(PATH_BRIDGE, 0.95)
    gp.patch(*PLAZA, 2.45, 1.0)
    gp.patch(COTTAGE[0], COTTAGE[1] + 2.2, 1.2, 0.9)
    gp.patch(DOVECOTE[0], DOVECOTE[1], 1.15, 0.8)
    gp.patch(STEPS_C, 10.3, 1.2, 0.9)
    gp.patch(6.9, 12.3, 0.9, 0.7)
    for r, line in enumerate(MASK):
        for c, t in enumerate(line):
            if t == "W":
                gp.patch(c + 0.5, r + 0.5, 1.15, 0.85)
    for (c, r, size, _leaf, _fruit, _tall) in TREES:
        gp.patch(c, r, 0.95 * size, 0.9, target="ao")
    for (c, r, size, _alt) in PINES:
        gp.patch(c, r, 0.8 * size, 0.7, target="ao")
    for (c, r, size) in BUSHES:
        gp.patch(c, r, 0.55 * size, 0.6, target="ao")
    for (c, r, radius, _tint) in STONES_AT:
        gp.patch(c, r, radius * 1.4, 0.6, target="ao")
    gp.rect_ao(COTTAGE[0] - 2.5, COTTAGE[1] - 1.8, COTTAGE[0] + 2.5, COTTAGE[1] + 1.8, 0.7, 0.9)
    gp.patch(DOVECOTE[0], DOVECOTE[1], 0.95, 0.8, target="ao")
    for (c, r, size) in HAYSTACKS:
        gp.patch(c, r, 0.85 * size, 0.7, target="ao")
    gp.rect_ao(14.2 - 1.2, 4.1 - 0.7, 14.2 + 1.2, 4.1 + 0.7, 0.4, 0.5)
    gp.patch(PLAZA[0], PLAZA[1], 0.7, 0.5, target="ao")
    gp.finish("#e7dab3", "#dccc9f", ao_strength=0.15)
    return gp.save(GROUND_PNG, name=f"ground_{STAGE}")


def build() -> None:
    kit = Kit(seed=7)
    kit.delay_fn = make_entrance_delay(SCENE)
    kit.anim_span = ENTRANCE_DEFAULTS["span"]
    kit.anim_bounds = ANIM_BOUNDS
    p = Props(kit, SCENE, PALETTE, withered=WITHERED)
    ground_img = paint_ground()
    mats = {
        "top": kit.mat("ground", image=ground_img),
        "bed": p.mat("stream_bed"),
        "cap": p.mat("grass_edge"),
        "cliff_up": p.mat("cliff_up"),
        "cliff_low": p.mat("cliff_low"),
    }
    kit.terrain(MASK, HEIGHTS, mats, bottom=BOTTOM, bed_chars="" if WITHERED else "W")

    p.cottage(*COTTAGE)
    p.woodpile(6.3, 4.9)
    p.dovecote(*DOVECOTE)
    for (c, r, size) in HAYSTACKS:
        p.haystack(c, r, size=size)
    p.birdhouse(13.3, 6.7)
    p.veg_bed(14.2, 4.1)
    p.steps(STEPS_C, 9.0)
    p.plaza(*PLAZA)
    p.bench(14.9, 12.9, angle=math.radians(-35))
    p.plank_bridge(25.0, 11.5)
    p.crates(7.5, 12.7)
    p.ladder(7.0, 11.9, angle_to_tree=math.atan2(-(11.7 - 11.9), (6.4 - 7.0)), tilt=0.32)
    for (c, r, size, leaf, fruit, tall) in TREES:
        p.block_tree(c, r, size=size, leaf=leaf, fruit=fruit, tall=tall)
    for (c, r, size, alt) in PINES:
        p.pine(c, r, size=size, alt=alt)
    for (c, r, size) in BUSHES:
        p.bush(c, r, size=size)
    for (c, r, radius, tint) in STONES_AT:
        p.stone(c, r, radius=radius, tint=tint)
    for run in (FENCE_FRONT_A, FENCE_FRONT_B, FENCE_BANK, FENCE_LEFT):
        p.fence(run)
    for spot in FLOWER_SPOTS:
        p.flowers(*spot, count=kit.rng.randint(3, 5))
    for spot in TUFT_SPOTS:
        p.tuft(*spot)
    p.signpost(5.4, 17.6, "green", facing=math.radians(20))
    p.signpost(27.3, 11.3, "orange", facing=math.radians(-25))
    for c, r in LILIES:
        p.lily(c, r)
    p.foam(23.5, 18.92, WATER_Y + 0.02, count=4, spread=0.42)
    p.foam(23.5, 19.55, BOTTOM + 0.08, count=5, spread=0.55)
    p.dove(9.3, 18.55, z_off=0.62, heading=math.radians(200))
    p.dove(12.9, 14.5, z_off=0.74, heading=math.radians(140))
    p.dove(14.4, 16.5, z_off=0.0, heading=math.radians(60))
    p.dove(11.6, COTTAGE[1], z_off=2.3 + 1.6 + 0.2, heading=math.radians(-20))
    p.dove(8.0, COTTAGE[1], z_off=2.3 + 1.6 + 0.2, heading=math.radians(160), size=1.2)
    p.dove(11.4, 14.4, z_off=0.06, heading=math.radians(-110), size=1.2)
    p.dove(16.9, 18.55, z_off=0.62, heading=math.radians(190), size=1.3)
    p.dove(21.5, 8.6, z_off=1.28, heading=math.radians(40), size=1.2)

    p.flying_doves(PLAZA[0], PLAZA[1] - 1.0, height=5.2, radius=3.4, count=3)

    merged = kit.finalize(smooth_angle_deg=35.0)
    export_glb(OUT_DIR / f"{VARIANT}.glb", merged.values())
    write_layout(OUT_DIR / f"{VARIANT}.json", STAGE, SCENE, PLAZA, water_levels=None if WITHERED else {"W": WATER_Y}, water_colors=None if WITHERED else WATER,
                 table=wither_table(TABLE) if WITHERED else TABLE, withered=WITHERED, extra={"fall": {"c": 23.5, "r": 19.0}})
    print("DIORAMA_DONE", OUT_DIR)


build()
