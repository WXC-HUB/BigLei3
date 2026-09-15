"""Stage 6 diorama "尽头港" (port at the end): a working harbour, not a row of houses.

Theme: the land ends here. A stone breakwater arm curls out of the right-hand shore and
encloses the harbour basin, the red-and-white lighthouse standing on the rock at its tip.
Behind the cobbled quay there is exactly one long boathouse with big navy doors and one
tall narrow harbour master's tower with a balcony and a pennant. Two wooden docks reach
into the basin with boats tied up, a hoist crane and stacked traps, crates and barrels
work the quay, nets dry on racks by the beach, buoys bob at the mouth, a rowing boat is
pulled up on the sand at the front-left. The quay in front of the boathouse doors is the
badge anchor.

Palette: sea blue water, pale limestone quay and cliffs, weathered grey-blue planks, navy
roofs and doors; the red lighthouse, the pennant and the coral buoys are the accents.
Table: pale sky-white with sea / navy-grey / coral dots.

Run from the project root:
  "D:/Steam/steamapps/common/Blender/blender.exe" -b --python tools/build_diorama_coast_1.py
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
STAGE = "coast_1"
OUT_DIR = PROJECT / "assets/dioramas" / STAGE
# DIORAMA_WITHERED=1 builds the derelict variant (<stage>_withered.glb/.json) from the same layout.
WITHERED, VARIANT = variant_setup(STAGE)
GROUND_PNG = PROJECT / "artifacts" / f"diorama_{VARIANT}_ground.png"

# L grass, Q stone quay, B the breakwater arm, S beach sand, U lighthouse rock, W sea.
MASK = [
    "..............................",
    "...LLLLLLLLLLLLLLLLLLLL.......",
    "..LLLLLLLLLLLLLLLLLLLLLLL.....",
    ".LLLLLLLLLLLLLLLLLLLLLLLLL....",
    ".LLLLLLLLLLLLLLLLLLLLLLLLLL...",
    ".LLLLLLLLLLLLLQQQQQQQLLLLLLL..",
    ".LLLLLLLLLLLQQQQQQQQQQQLLLLL..",
    ".LLLLLLLLLQQQQWWWWWWWQQQQLLL..",
    ".LLLLLLLLQQQWWWWWWWWWWWQQBBB..",
    ".LLLLLLLQQQWWWWWWWWWWWWWWWBB..",
    ".LLLLLLQQQWWWWWWWWWWWWWWWWBB..",
    "..SSLLLQQWWWWWWWWWWWWWWWWWBB..",
    "..SSSSLQQWWWWWWWWWWWWWWWWBBB..",
    "..SSSSSSQWWWWWWWWWWWWWWWBBB...",
    "...SSSSSWWWWWWWWWWWWWWWBBUU...",
    "....SSSSWWWWWWWWWWWWWWBBBUU...",
    ".....SSSWWWWWWWWWWWWWWBB......",
    "......SSWWWWWWWWWWWWWW........",
    ".......SWWWWWWWWWWWWW.........",
    "..............................",
    "..............................",
    "..............................",
]
HEIGHTS = {"L": 0.0, "Q": 0.0, "S": 0.0, "B": 0.35, "U": 1.0, "W": -0.7}
WATER_Y = -0.3
BOTTOM = -2.1
SCENE = Scene(MASK, HEIGHTS, BOTTOM, WATER_Y)

PALETTE = {
    "grass_a": "#c2cf95", "grass_b": "#b7c58b", "grass_edge": "#a6b57f",
    "sand": "#efe3c0", "sand_dark": "#e3d3a6",
    "cliff_up": "#e0d6bf", "cliff_low": "#c9bb9c", "stream_bed": "#b7a98a",
    "wall": "#f6f2ea", "trim": "#ffffff", "door": "#2f4a6b", "shutter": "#2f4a6b", "glass": "#cfe4ee",
    "plank": "#b4c1c6", "plank_dark": "#96a4aa", "net": "#8fa8a6",
    "hull": "#f5f2ec", "hull_trim": "#2f4a6b", "sail": "#f4eee0", "beacon": "#d9463a", "buoy": "#f08a5b", "lantern": "#f3c56b",
    "trunk": "#8b7355", "leaves": ["#9fae7a", "#8f9f6c", "#adbb86", "#849560"], "bush": "#9aa972",
    "stones": ["#d1cbbd", "#c1bbad", "#aca69a"], "flag_a": "#d5cfc1", "flag_b": "#c8c1b1",
    "wood": "#dccaa3", "wood_dark": "#b09873", "timber": "#6b5a4b", "iron": "#4a4642", "rope": "#e6d9b8",
    "flowers": ["#f0a7b5", "#ffffff", "#f5e1a0"], "dove": "#f7f5f0", "beak": "#e3a558",
    "fruit_a": "#f08a5b", "sign_orange": "#e5a35a", "sign_green": "#8fb07f", "foam": "#ffffff",
}
TABLE = {"far": "#eef6f9", "near": "#d9e8ef", "dots": ["#a9d3e8", "#c3ccd9", "#f4cbb9"]}
WATER = {"shallow": "#94a5a3", "deep": "#5c6f70"} if WITHERED else {"shallow": "#8fcbe0", "deep": "#4f97bd"}

LIGHTHOUSE = (25.8, 14.6)
BOATHOUSE = (16.0, 3.4)
TOWER = (7.6, 3.2)
SQUARE = (14.6, 6.2)
DOCK_A = (11.0, 8.3)
DOCK_B = (17.5, 6.9)
CRANE = (21.6, 6.4)
PATH_TOWER = [(7.6, 4.8), (9.6, 5.8), (11.6, 6.4)]
PATH_QUAY = [(9.0, 5.6), (13.0, 5.8), (17.0, 5.9), (21.0, 5.6), (24.0, 4.6)]
PATH_BEACH = [(7.4, 7.6), (6.0, 9.6), (5.2, 11.6)]
TREES = [(3.6, 2.2, 0.95, 0), (10.6, 1.8, 0.9, 2), (21.4, 2.0, 0.9, 3), (25.6, 3.4, 1.0, 1), (3.2, 6.2, 0.9, 0), (26.8, 5.8, 0.85, 2)]
BUSHES = [(5.6, 5.4, 0.8), (12.4, 1.6, 0.7), (19.6, 1.4, 0.75), (23.6, 2.4, 0.7), (2.6, 9.4, 0.75), (26.2, 7.4, 0.7), (4.4, 11.6, 0.7)]
STONES_AT = [(3.0, 12.4, 0.3, 0), (6.6, 15.8, 0.28, 1), (4.2, 14.6, 0.26, 2), (26.4, 4.6, 0.3, 1), (24.8, 3.0, 0.26, 0)]
BOLLARDS = [(14.5, 6.7), (16.5, 6.7), (19.5, 6.7), (10.4, 7.7), (9.4, 8.7), (8.4, 9.7), (7.4, 10.7), (22.6, 7.6), (23.6, 8.6),
            (26.5, 9.4), (26.5, 11.4), (25.4, 12.6), (24.4, 13.5), (23.4, 15.4)]
NET_RACKS = [(4.6, 8.6, 20.0), (5.8, 10.2, 20.0), (23.4, 4.4, -10.0)]
FLOWER_SPOTS = [(5.6, 6.8), (9.6, 4.6), (22.8, 4.8), (3.4, 4.6), (25.2, 6.8), (12.2, 4.8)]
TUFT_SPOTS = [(6.4, 1.6), (14.6, 1.4), (18.4, 1.6), (22.6, 3.6), (3.2, 10.6), (5.4, 12.6), (6.8, 14.4), (25.0, 4.0), (2.6, 5.8),
              (10.2, 3.6), (4.6, 4.2), (20.4, 1.2)]


def paint_ground() -> Path:
    gp = GroundPainter(SCENE.cols, SCENE.rows, px=64, seed=61, tint=wither_hex if WITHERED else None)
    gp.checker(PALETTE["grass_a"], PALETTE["grass_b"])
    gp.paint_cells(MASK, "QB", lambda g: g.cobbles("#d5cfc1", "#c8c1b1", "#b3ac9d", cell=0.5, joint_width=0.045), feather_cells=0.18)
    gp.paint_cells(MASK, "S", lambda g: g.checker("#f0dfb4", "#e8d3a2", noise=0.014), feather_cells=0.4)
    for path in (PATH_TOWER, PATH_QUAY, PATH_BEACH):
        gp.path(path, 1.0, wobble=0.1)
    gp.rect_ao(BOATHOUSE[0] - 3.6, BOATHOUSE[1] - 1.8, BOATHOUSE[0] + 3.6, BOATHOUSE[1] + 1.8, 0.7, 0.9)
    gp.rect_ao(TOWER[0] - 1.4, TOWER[1] - 1.4, TOWER[0] + 1.4, TOWER[1] + 1.4, 0.7, 0.9)
    gp.patch(LIGHTHOUSE[0], LIGHTHOUSE[1], 1.5, 0.8, target="ao")
    for (c, r, size, _leaf) in TREES:
        gp.patch(c, r, 0.9 * size, 0.85, target="ao")
    for (c, r, size) in BUSHES:
        gp.patch(c, r, 0.55 * size, 0.6, target="ao")
    gp.finish(PALETTE["sand_dark"], "#d6c496", ao_strength=0.14)
    return gp.save(GROUND_PNG, name=f"ground_{STAGE}")


def build() -> None:
    kit = Kit(seed=13)
    kit.delay_fn = make_entrance_delay(SCENE, seed=10)
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

    p.lighthouse(LIGHTHOUSE[0], LIGHTHOUSE[1], height=4.4)
    p.boathouse(BOATHOUSE[0], BOATHOUSE[1], w=7.0, d=3.4)
    p.harbor_tower(TOWER[0], TOWER[1], side=2.6, height=4.2)
    p.dock(DOCK_A[0], DOCK_A[1], length=4.6, width=1.4, along_x=False, deck_z=0.32)
    p.dock(DOCK_B[0], DOCK_B[1], length=4.2, width=1.3, along_x=False, deck_z=0.32)
    p.crane(CRANE[0], CRANE[1], angle=math.radians(-135))
    p.boat(14.6, 13.4, heading=math.radians(25), sail=True, length=2.6)
    p.boat(19.6, 10.8, heading=math.radians(70), sail=False, length=2.2)
    p.boat(12.6, 16.6, heading=math.radians(-20), sail=True, length=2.4)
    p.boat(5.2, 13.6, heading=math.radians(15), sail=False, length=2.0, ground=True)
    p.buoy(10.2, 15.6)
    p.buoy(17.8, 16.4)
    p.buoy(23.0, 10.4)
    p.bollards(BOLLARDS)
    for (c, r, deg) in NET_RACKS:
        p.net_rack(c, r, angle=math.radians(deg))
    p.awning_stall(11.4, 6.6, angle=math.radians(-15))
    p.traps(9.8, 6.4, count=2, angle=0.3)
    p.traps(23.0, 7.6, count=3, angle=-0.4)
    p.crates(13.0, 5.8, count=3, fruit=False)
    p.barrels(18.8, 5.7, count=3)
    p.lantern_post(12.2, 7.2, height=1.8)
    p.lantern_post(20.4, 6.0, height=1.8)
    p.lantern_post(25.6, 12.2, height=1.6)
    for (c, r, size, leaf) in TREES:
        p.block_tree(c, r, size=size, leaf=leaf)
    for (c, r, size) in BUSHES:
        p.bush(c, r, size=size)
    for (c, r, radius, tint) in STONES_AT:
        p.stone(c, r, radius=radius, tint=tint)
    p.fence([(2.4, 3.4), (2.4, 7.6)])
    for spot in FLOWER_SPOTS:
        p.flowers(*spot, count=kit.rng.randint(3, 5))
    for spot in TUFT_SPOTS:
        p.tuft(*spot)
    p.signpost(8.6, 12.0, "orange", facing=math.radians(-15))
    for (c, r) in ((8.6, 15.8), (14.4, 17.6), (19.8, 16.6), (21.4, 17.2), (27.2, 10.6)):
        p.foam(c, r, WATER_Y + 0.02, count=3, spread=0.4)
    p.dove(LIGHTHOUSE[0] + 0.5, LIGHTHOUSE[1] - 0.6, z_off=1.0 + 4.4 + 0.42, heading=math.radians(-120), size=1.2)
    p.dove(14.5, 6.7, z_off=0.56, heading=math.radians(160), size=1.1)
    p.dove(BOATHOUSE[0] - 2.0, BOATHOUSE[1], z_off=2.3 + 1.2 + 0.15, heading=math.radians(210), size=1.2)
    p.dove(5.2 + 0.4, 13.6 - 0.2, z_off=0.44, heading=math.radians(70))

    p.flying_doves(16.0, 11.0, height=4.8, radius=3.6, count=4, size=1.2)

    merged = kit.finalize(smooth_angle_deg=35.0)
    export_glb(OUT_DIR / f"{VARIANT}.glb", merged.values())
    write_layout(OUT_DIR / f"{VARIANT}.json", STAGE, SCENE, SQUARE, water_levels={"W": WATER_Y}, water_colors=WATER, table=wither_table(TABLE) if WITHERED else TABLE, withered=WITHERED)
    print("DIORAMA_DONE", OUT_DIR)


build()
