"""Stage 4 diorama "双桥" (twin bridges): a water garden with no houses at all.

Theme: a clear river runs from the back edge to the front and widens in the middle into a
pond around a small islet. An open hexagonal pavilion (the badge anchor) stands on the
islet, reached by two vermilion arched bridges - one from each bank, offset so they read
as two. Weeping willows lean over the banks, stone lanterns mark the bridge heads, irises
and reeds grow at the water's edge, lilies and koi fill the pond, a wooden viewing deck
juts over the front-left shore, stepping stones cross the narrow front stream. The one
building besides the pavilion is the old watermill up at the back, its wheel in the river.

Palette: bright spring green and pale sand banks, clear blue-green water; vermilion bridges
and columns are the one hot accent, roofs are green-grey slate. Table: pale mint cream
with aqua / leaf / vermilion-pink dots.

Run from the project root:
  "D:/Steam/steamapps/common/Blender/blender.exe" -b --python tools/build_diorama_river_1.py
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
STAGE = "river_1"
OUT_DIR = PROJECT / "assets/dioramas" / STAGE
# DIORAMA_WITHERED=1 builds the derelict variant (<stage>_withered.glb/.json) from the same layout.
WITHERED, VARIANT = variant_setup(STAGE)
GROUND_PNG = PROJECT / "artifacts" / f"diorama_{VARIANT}_ground.png"

# L banks, I the pavilion islet, W the river and pond.
MASK = [
    "..............................",
    ".....LLLLLLLLWWWLLLLLLLLL.....",
    "...LLLLLLLLLLWWWLLLLLLLLLLL...",
    "..LLLLLLLLLLLWWWLLLLLLLLLLLL..",
    "..LLLLLLLLLLLWWWWLLLLLLLLLLLL.",
    ".LLLLLLLLLLLWWWWWWLLLLLLLLLLL.",
    ".LLLLLLLLLLWWWWWWWWLLLLLLLLLL.",
    ".LLLLLLLLLWWWWIIIWWWWLLLLLLLL.",
    ".LLLLLLLLLWWWIIIIIWWWLLLLLLLL.",
    ".LLLLLLLLLWWWIIIIIWWWLLLLLLLL.",
    ".LLLLLLLLLWWWIIIIIWWWLLLLLLLL.",
    ".LLLLLLLLLWWWWIIIWWWWLLLLLLLL.",
    "..LLLLLLLLLWWWWWWWWWLLLLLLLL..",
    "..LLLLLLLLLLWWWWWWWLLLLLLLLL..",
    "..LLLLLLLLLLLWWWWWLLLLLLLLLL..",
    "...LLLLLLLLLLLWWWWLLLLLLLLL...",
    "...LLLLLLLLLLLLWWWLLLLLLLLL...",
    "....LLLLLLLLLLLWWWLLLLLLLL....",
    "......LLLLLLLLLWWWLLLLLLL.....",
    "..............................",
    "..............................",
    "..............................",
]
HEIGHTS = {"L": 0.0, "I": 0.0, "W": -0.5}
WATER_Y = -0.42 if WITHERED else -0.2   # withered: the pond has sunk to a murky film
BOTTOM = -2.1
SCENE = Scene(MASK, HEIGHTS, BOTTOM, WATER_Y)

PALETTE = {
    "grass_a": "#b5d39a", "grass_b": "#a8c88d", "grass_edge": "#96b57f",
    "sand": "#e7dcb6", "sand_dark": "#d8c99c",
    "cliff_up": "#dbcfae", "cliff_low": "#c1af88", "stream_bed": "#c4b895",
    "wall": "#f0e8d8", "trim": "#faf6ee", "door": "#6d8b6a", "shutter": "#7c9a78", "glass": "#cfe2e6",
    "slate": "#7d8f7a", "slate_dark": "#6a7c68", "ridge": "#7a3b2e", "chimney": "#c9c2b3", "chimney_cap": "#a39b8c",
    "trunk": "#8e7351", "leaves": ["#9fc07f", "#8fb572", "#b1cf8e", "#86ad6c"], "willow": "#a4c785", "bush": "#9cbb7d",
    "reed": "#8aa86a", "iris": "#7e8fc9",
    "stones": ["#c8c4b6", "#b8b3a3", "#a5a093"], "flag_a": "#cfc9bb", "flag_b": "#c0b9a9",
    "wood": "#d6c09a", "wood_dark": "#a88a66", "timber": "#6b5a4b",
    "beacon": "#c8503c", "hull": "#d9c8a6", "hull_trim": "#9a7a55", "lantern": "#f3c56b", "gold": "#e0b458", "iron": "#4a4642",
    "flowers": ["#f2c4bf", "#f5e1a0", "#ffffff", "#a9b4e8"], "still_water": "#a6dbe0", "koi": "#f0894f",
    "foam": "#ffffff",
}
TABLE = {"far": "#eef5ee", "near": "#dde9dc", "dots": ["#c1e0dc", "#c9dcb4", "#efc9be"]}
WATER = {"shallow": "#8e9a86", "deep": "#5f6d5e"} if WITHERED else {"shallow": "#a6dbe0", "deep": "#6db4c4"}

PAVILION = (15.5, 9.5)
MILL = (10.4, 3.4)
BRIDGE_A = (11.5, 8.6)
BRIDGE_B = (19.5, 10.4)
DECK = (11.0, 12.8)
STEPPING = [(13.6, 15.6), (14.4, 15.4), (15.2, 15.6), (16.0, 15.4), (16.8, 15.6), (17.6, 15.4), (18.4, 15.6)]
PATH_LEFT = [(5.0, 12.0), (7.6, 10.4), (9.4, 8.7)]
PATH_RIGHT = [(21.6, 10.4), (24.0, 9.4), (26.4, 7.6)]
PATH_MILL = [(10.4, 5.6), (9.2, 7.6)]
PATH_FRONT_L = [(12.8, 15.6), (10.0, 16.8), (7.6, 18.2)]
PATH_FRONT_R = [(19.0, 15.6), (21.2, 16.8), (23.4, 17.8)]
WILLOWS = [(6.5, 6.5, 1.0), (22.5, 5.5, 1.05), (7.5, 13.5, 0.95), (23.5, 13.5, 1.0), (11.5, 16.5, 0.9), (19.0, 16.0, 0.9)]
TREES = [(4.5, 3.0, 0.95, 0), (25.5, 2.5, 1.0, 2), (20.5, 3.6, 0.85, 1), (3.5, 10.5, 0.9, 3)]
BUSHES = [(3.4, 6.4, 0.8), (26.6, 6.6, 0.75), (5.0, 15.6, 0.7), (25.4, 15.4, 0.75), (8.4, 2.4, 0.7), (23.0, 3.0, 0.7),
          (13.0, 17.6, 0.7), (20.2, 17.4, 0.7)]
STONE_LANTERNS = [(9.2, 7.8), (21.8, 11.2), (6.0, 9.6), (24.4, 8.4), (9.6, 13.8)]
REEDS = [(9.4, 6.2), (20.4, 6.0), (9.0, 12.4), (21.0, 12.6), (12.4, 14.5), (18.6, 14.6), (12.6, 2.4), (16.4, 2.6)]
IRISES = [(9.6, 10.6), (21.4, 8.0), (14.0, 17.2), (18.4, 17.0), (11.4, 4.6), (17.4, 4.5)]
LILIES = [(11.5, 9.5), (18.5, 8.6), (12.6, 12.4), (17.4, 12.6), (14.5, 5.6), (16.4, 13.5), (15.6, 6.4)]
STONES_AT = [(4.6, 12.6, 0.3, 0), (26.0, 11.4, 0.28, 1), (7.4, 17.4, 0.26, 2), (24.0, 17.2, 0.3, 0), (2.6, 8.4, 0.3, 1)]
FLOWER_SPOTS = [(5.4, 8.4), (8.6, 9.6), (3.4, 12.6), (16.4, 3.6), (22.0, 7.4), (24.6, 11.4), (20.6, 16.4), (27.0, 9.6),
                (7.4, 15.6), (11.2, 5.8), (26.4, 3.6), (20.4, 12.2)]
TUFT_SPOTS = [(6.6, 8.6), (4.4, 13.6), (8.8, 15.2), (16.6, 3.8), (19.6, 6.2), (21.8, 8.6), (19.6, 14.4), (26.8, 6.8),
              (26.0, 14.6), (5.0, 17.4), (18.8, 17.6), (8.6, 7.4), (22.6, 12.6), (10.6, 14.6)]


def paint_ground() -> Path:
    gp = GroundPainter(SCENE.cols, SCENE.rows, px=64, seed=41, tint=wither_hex if WITHERED else None)
    gp.checker(PALETTE["grass_a"], PALETTE["grass_b"])
    for path in (PATH_LEFT, PATH_RIGHT, PATH_MILL, PATH_FRONT_L, PATH_FRONT_R):
        gp.path(path, 1.0, wobble=0.1)
    gp.patch(PAVILION[0], PAVILION[1], 2.3, 1.0)
    gp.patch(MILL[0], MILL[1] + 2.0, 1.0, 0.7)
    for r, line in enumerate(MASK):
        for c, t in enumerate(line):
            if t == "W":
                gp.patch(c + 0.5, r + 0.5, 1.2, 0.9)
    for (c, r, size) in WILLOWS:
        gp.patch(c, r, 1.0 * size, 0.85, target="ao")
    for (c, r, size, _leaf) in TREES:
        gp.patch(c, r, 0.9 * size, 0.85, target="ao")
    for (c, r, size) in BUSHES:
        gp.patch(c, r, 0.55 * size, 0.6, target="ao")
    gp.rect_ao(MILL[0] - 2.2, MILL[1] - 1.7, MILL[0] + 2.2, MILL[1] + 1.7, 0.7, 0.9)
    gp.patch(PAVILION[0], PAVILION[1], 1.6, 0.6, target="ao")
    gp.finish(PALETTE["sand"], PALETTE["sand_dark"], ao_strength=0.14)
    return gp.save(GROUND_PNG, name=f"ground_{STAGE}")


def build() -> None:
    kit = Kit(seed=10)
    kit.delay_fn = make_entrance_delay(SCENE, seed=8)
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
    kit.terrain(MASK, HEIGHTS, mats, bottom=BOTTOM)

    p.pavilion(PAVILION[0], PAVILION[1], radius=1.35, col_h=2.2)
    p.watermill(MILL[0], MILL[1], wheel_side=1.0)
    p.arch_bridge(BRIDGE_A[0], BRIDGE_A[1], length=3.8, width=1.3, along_x=True)
    p.arch_bridge(BRIDGE_B[0], BRIDGE_B[1], length=3.8, width=1.3, along_x=True)
    p.deck(DECK[0], DECK[1], w=2.4, d=1.8, rails=("+x", "-y"))
    p.stepping_stones(STEPPING)
    p.boat(12.0, 6.2, heading=math.radians(30), sail=False, length=2.2)
    for (c, r) in STONE_LANTERNS:
        p.stone_lantern(c, r)
    for (c, r, size) in WILLOWS:
        p.willow(c, r, size=size)
    for (c, r, size, leaf) in TREES:
        p.block_tree(c, r, size=size, leaf=leaf)
    for (c, r, size) in BUSHES:
        p.bush(c, r, size=size)
    for (c, r) in REEDS:
        p.reeds(c, r, count=6)
    for (c, r) in IRISES:
        p.iris(c, r)
    for (c, r) in LILIES:
        p.lily(c, r)
    p.koi(11.6, 10.5, count=4)
    p.koi(18.8, 9.3, count=3)
    p.koi(15.5, 14.2, count=3)
    for (c, r, radius, tint) in STONES_AT:
        p.stone(c, r, radius=radius, tint=tint)
    p.fence([(3.0, 13.6), (3.0, 16.4)])
    p.fence([(21.0, 18.4), (24.4, 18.4)])
    for spot in FLOWER_SPOTS:
        p.flowers(*spot, count=kit.rng.randint(3, 5))
    for spot in TUFT_SPOTS:
        p.tuft(*spot)
    p.signpost(9.0, 16.4, "green", facing=math.radians(20))
    p.foam(16.5, 18.9, WATER_Y + 0.02, count=3, spread=0.4)
    p.foam(14.5, 1.1, WATER_Y + 0.02, count=3, spread=0.4)
    p.dove(BRIDGE_A[0], BRIDGE_A[1] - 0.73, z_off=1.63, heading=math.radians(-40), size=1.1)
    p.dove(DECK[0] + 1.1, DECK[1], z_off=1.13, heading=math.radians(160), size=1.1)
    p.dove(18.9, 15.9, z_off=0.0, heading=math.radians(100), size=1.2)
    p.dove(MILL[0] - 1.2, MILL[1], z_off=2.4 + 1.5 + 0.2, heading=math.radians(30), size=1.2)

    p.flying_doves(PAVILION[0], PAVILION[1], height=5.4, radius=3.2, count=3)

    merged = kit.finalize(smooth_angle_deg=35.0)
    export_glb(OUT_DIR / f"{VARIANT}.glb", merged.values())
    write_layout(OUT_DIR / f"{VARIANT}.json", STAGE, SCENE, PAVILION, water_levels={"W": WATER_Y}, water_colors=WATER, table=wither_table(TABLE) if WITHERED else TABLE, withered=WITHERED)
    print("DIORAMA_DONE", OUT_DIR)


build()
