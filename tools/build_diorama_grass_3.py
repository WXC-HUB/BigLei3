"""Stage 3 diorama "老井村" (old-well village): a stone hill village on three terraces.

Theme: stone, not cottages. The island climbs in three terraces from the front-right to
the back-left, every terrace edged with dry-stone walls and joined by stone steps. Down on
the lowest terrace a cobbled square holds the roofed well (井亭, the badge anchor) in the
shade of the village's ancient tree - a huge many-lobed crown with red wish ribbons
hanging from its branches. Long, low farmhouses of rubble stone with slate roofs sit on
the terraces, a square watch tower stands on the top one, kitchen-garden beds fill the
small upper terrace on the right, iron lanterns light the square.

Palette: cool greens, grey stone and slate; the warm lantern glass, the red ribbons and the
teal-grey water in the well are the accents. Table: cool blue-grey with slate / moss /
stone dots.

Run from the project root:
  "D:/Steam/steamapps/common/Blender/blender.exe" -b --python tools/build_diorama_grass_3.py
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
STAGE = "grass_3"
OUT_DIR = PROJECT / "assets/dioramas" / STAGE
# DIORAMA_WITHERED=1 builds the derelict variant (<stage>_withered.glb/.json) from the same layout.
WITHERED, VARIANT = variant_setup(STAGE)
GROUND_PNG = PROJECT / "artifacts" / f"diorama_{VARIANT}_ground.png"

# T top terrace (1.4), U middle terrace (0.7), L low ground, P the cobbled well square.
MASK = [
    "..............................",
    "....TTTTTTTTTTTTUUUUUUL.......",
    "...TTTTTTTTTTTTTUUUUUULLL.....",
    "..TTTTTTTTTTTTTTUUUUUULLLLL...",
    "..TTTTTTTTTTTTTTUUUUUULLLLLL..",
    ".TTTTTTTTTTTTTTTUUUUUULLLLLLL.",
    ".UUUUUUUUUUUUUUUUUUUUULLLLLLL.",
    ".UUUUUUUUUUUUUUUUUUUULLLLLLLL.",
    ".UUUUUUUUUUUUUUUULLLLPPPPPLLL.",
    ".UUUUUUUUUUUUUUUULLLPPPPPPPLL.",
    ".UUUUUUUUUUUUUUUULLLPPPPPPPLL.",
    ".UUUUUUUUUUUUUUULLLLPPPPPPPLL.",
    "..LLLLLLLLLLLLLLLLLLLPPPPPLLL.",
    "..LLLLLLLLLLLLLLLLLLLLLLLLLL..",
    "..LLLLLLLLLLLLLLLLLLLLLLLLLL..",
    "...LLLLLLLLLLLLLLLLLLLLLLLL...",
    "....LLLLLLLLLLLLLLLLLLLLLL....",
    ".....LLLLLLLLLLLLLLLLLLL......",
    ".......LLLLLLLLLLLLLLL........",
    "..............................",
    "..............................",
    "..............................",
]
HEIGHTS = {"T": 1.4, "U": 0.7, "L": 0.0, "P": 0.0}
BOTTOM = -2.1
SCENE = Scene(MASK, HEIGHTS, BOTTOM)

PALETTE = {
    "grass_a": "#a3b993", "grass_b": "#98ae88", "grass_edge": "#88a07a",
    "sand": "#c8c1b1", "sand_dark": "#b8b0a0",
    "cliff_up": "#b9b3a6", "cliff_low": "#958e82",
    "stone_wall": "#cdc6b8", "stone_trim": "#e4dfd3", "trim": "#e4dfd3", "wall": "#e9e3d6", "glass": "#b8c6cc",
    "slate": "#66737f", "slate_dark": "#55606b", "chimney": "#b5aea1", "chimney_cap": "#8c857a", "timber": "#5f4f42",
    "trunk": "#6f5b48", "leaves": ["#7f9d6d", "#71906a", "#8aa878", "#688562"], "bush": "#7f9c6e",
    "stones": ["#bdb7aa", "#aaa497", "#96908a"], "flag_a": "#c4bfb3", "flag_b": "#b4aea1",
    "wood": "#c9b48c", "wood_dark": "#9a8262", "iron": "#4a4642", "lantern": "#f3c56b", "gold": "#e0b458", "rope": "#d8c7a4",
    "ribbon": "#c9573f", "flowers": ["#e07a6b", "#f2d16b", "#ffffff", "#d98fb5"], "sprout": "#8fb56e", "soil": "#8f7a62",
    "still_water": "#8fb3bd", "door": "#4f7a8a",
}
TABLE = {"far": "#eaeef1", "near": "#d6dde3", "dots": ["#b3c1cd", "#bccab2", "#d6cec2"]}

WELL = (23.0, 10.0)
TREE = (18.0, 12.6)
TOWER = (5.6, 4.4)
HOUSES = [  # (c, r, w, d, chimney)
    (10.6, 3.4, 4.8, 2.8, True),
    (5.4, 8.8, 4.4, 2.8, True),
    (25.6, 5.0, 3.0, 2.2, False),
]
PADDOCK = [(11.0, 8.0), (14.6, 8.0), (14.6, 10.6), (11.0, 10.6), (11.0, 8.0)]
TROUGH = (12.8, 9.3)
VEG = [(17.6, 2.7), (20.2, 2.7), (17.6, 4.5), (20.2, 4.5)]
STEPS_TU = (7.6, 6.0)      # top terrace -> middle, along row 6
STEPS_UL = (9.0, 12.0)     # middle -> low ground, along row 12
STEPS_UL_E = (17.0, 9.5)   # middle -> square, down the column-17 wall
STEPS_LR = (22.0, 6.0)     # right-hand middle block -> low ground, down the column-22 wall
WALLS = [
    [(1.8, 5.5), (6.5, 5.5)], [(8.7, 5.5), (15.3, 5.5)],
    [(1.6, 11.5), (7.8, 11.5)], [(10.2, 11.5), (15.4, 11.5)],
    [(16.5, 7.7), (16.5, 8.6)], [(16.5, 10.4), (16.5, 11.4)],
    [(4.6, 14.4), (4.6, 16.4), (9.6, 16.4)],
    [(24.0, 13.6), (27.4, 13.6)],
]
LANTERNS = [(21.0, 8.6), (25.2, 11.8), (16.8, 13.4)]
LANE_T = [(7.6, 5.7), (7.7, 5.0), (10.6, 5.0), (13.0, 5.0)]
LANE_U = [(5.4, 10.5), (9.0, 10.9), (10.6, 11.0), (15.0, 11.0), (15.6, 10.0), (16.6, 9.5)]
LANE_U_DOWN = [(9.0, 10.9), (9.0, 11.9)]
LANE_E = [(17.6, 9.5), (19.8, 9.8)]
LANE_LOW = [(9.0, 12.9), (12.5, 14.0), (15.5, 14.4), (19.0, 14.6), (21.5, 12.6)]
LANE_FRONT = [(23.0, 12.8), (22.6, 15.4), (21.6, 18.2)]
LANE_SHED = [(25.6, 6.3), (24.6, 8.2)]
TREES = [(2.4, 7.6, 0.85, 0), (14.6, 2.0, 0.9, 1), (26.8, 8.6, 0.9, 2), (27.2, 12.4, 0.8, 0), (13.2, 16.2, 0.9, 3),
         (7.0, 13.6, 0.8, 1), (1.9, 9.8, 0.75, 2), (23.8, 16.6, 0.85, 0)]
BUSHES = [(3.0, 12.8, 0.8), (14.2, 11.0, 0.7), (20.4, 6.4, 0.7), (27.4, 6.8, 0.75), (10.4, 14.8, 0.7), (18.6, 16.6, 0.75),
          (2.2, 3.6, 0.7), (24.6, 2.6, 0.7), (6.2, 17.2, 0.65)]
STONES_AT = [(2.6, 14.4, 0.3, 0), (25.4, 15.6, 0.32, 1), (11.8, 17.4, 0.26, 2), (14.6, 6.6, 0.28, 1), (26.2, 3.8, 0.3, 0)]
FLOWER_SPOTS = [(8.6, 8.0), (20.6, 12.4), (3.6, 13.8), (26.0, 10.4), (11.6, 13.4), (16.4, 16.0), (7.8, 15.4), (21.4, 16.4),
                (13.6, 3.6), (18.6, 6.4), (3.8, 6.6), (24.4, 3.8)]
TUFT_SPOTS = [(3.2, 8.0), (6.0, 10.9), (9.6, 13.6), (20.0, 15.6), (24.6, 12.6), (26.4, 7.6), (5.0, 5.0), (24.2, 4.6),
              (12.4, 4.6), (16.8, 6.6), (7.6, 3.2), (22.4, 3.0), (13.6, 17.4), (16.2, 17.6), (10.6, 18.0), (2.4, 11.0), (14.6, 12.6)]


def paint_ground() -> Path:
    gp = GroundPainter(SCENE.cols, SCENE.rows, px=64, seed=31, tint=wither_hex if WITHERED else None)
    gp.checker(PALETTE["grass_a"], PALETTE["grass_b"])
    # The top terrace is a touch drier and paler, the square is cobbled.
    gp.paint_cells(MASK, "T", lambda g: g.checker("#aebd93", "#a3b288"), feather_cells=0.25)
    gp.paint_cells(MASK, "P", lambda g: g.cobbles("#c8c2b5", "#b9b2a4", "#9c958b", cell=0.5, joint_width=0.045), feather_cells=0.2)
    for lane in (LANE_T, LANE_U, LANE_U_DOWN, LANE_E, LANE_LOW, LANE_FRONT, LANE_SHED):
        gp.path(lane, 0.95, wobble=0.1)
    for (c, r, w, d, _ch) in HOUSES:
        gp.patch(c - w * 0.2, r + d / 2 + 0.55, 0.9, 0.7)
        gp.rect_ao(c - w / 2 - 0.1, r - d / 2 - 0.1, c + w / 2 + 0.1, r + d / 2 + 0.1, 0.7, 0.9)
    gp.rect_ao(TOWER[0] - 1.2, TOWER[1] - 1.2, TOWER[0] + 1.2, TOWER[1] + 1.2, 0.7, 0.9)
    gp.patch(TOWER[0], TOWER[1] + 1.6, 0.9, 0.7)
    gp.patch(TROUGH[0], TROUGH[1], 1.6, 0.55, target="ao")
    gp.patch(WELL[0], WELL[1], 1.9, 0.75, target="ao")
    gp.patch(TREE[0], TREE[1], 2.6, 0.9, target="ao")
    for (c, r, size, _leaf) in TREES:
        gp.patch(c, r, 0.9 * size, 0.85, target="ao")
    for (c, r, size) in BUSHES:
        gp.patch(c, r, 0.55 * size, 0.6, target="ao")
    for (c, r) in VEG:
        gp.rect_ao(c - 1.2, r - 0.75, c + 1.2, r + 0.75, 0.4, 0.6)
    gp.finish(PALETTE["sand"], PALETTE["sand_dark"], ao_strength=0.16)
    return gp.save(GROUND_PNG, name=f"ground_{STAGE}")


def build() -> None:
    kit = Kit(seed=9)
    kit.delay_fn = make_entrance_delay(SCENE, seed=7)
    kit.anim_span = ENTRANCE_DEFAULTS["span"]
    kit.anim_bounds = ANIM_BOUNDS
    p = Props(kit, SCENE, PALETTE, withered=WITHERED)
    ground_img = paint_ground()
    mats = {
        "top": kit.mat("ground", image=ground_img),
        "bed": p.mat("sand_dark"),
        "cap": p.mat("grass_edge"),
        "cliff_up": p.mat("cliff_up"),
        "cliff_low": p.mat("cliff_low"),
    }
    kit.terrain(MASK, HEIGHTS, mats, bottom=BOTTOM)

    p.well_pavilion(*WELL)
    p.ancient_tree(TREE[0], TREE[1], size=1.05)
    p.stone_tower(TOWER[0], TOWER[1], side=2.1, height=3.0)
    for (c, r, w, d, chimney) in HOUSES:
        p.stone_house(c, r, w=w, d=d, chimney=chimney)
    p.steps(STEPS_TU[0], STEPS_TU[1], width=1.7, top_z=1.4, base_z=0.7)
    p.steps(STEPS_UL[0], STEPS_UL[1], width=1.7, top_z=0.7, base_z=0.0)
    p.steps(STEPS_UL_E[0], STEPS_UL_E[1], width=1.6, top_z=0.7, base_z=0.0, axis="c")
    p.steps(STEPS_LR[0], STEPS_LR[1], width=1.6, top_z=0.7, base_z=0.0, axis="c")
    for wall in WALLS:
        p.dry_wall(wall)
    p.dry_wall(PADDOCK, height=0.42)
    tx, ty, tz = SCENE.xy(*TROUGH) + (SCENE.ground_z(*TROUGH),)
    kit.piece("prop", tx, ty, tz)
    kit.box("props", (1.1, 0.46, 0.4), (tx, ty, tz + 0.2), p.stone_mat(1), bevel=0.03, segments=1)
    kit.box("props", (0.94, 0.32, 0.04), (tx, ty, tz + 0.39), p.mat("still_water"))
    p.dove(TROUGH[0] - 0.9, TROUGH[1] + 0.5, z_off=0.0, heading=math.radians(60), size=1.2)
    p.dove(TROUGH[0] + 0.6, TROUGH[1] - 0.6, z_off=0.0, heading=math.radians(-110), size=1.1)
    for (c, r) in LANTERNS:
        p.lantern_post(c, r)
    for (c, r) in VEG:
        p.veg_bed(c, r, w=2.2, d=1.3)
    p.cart(21.6, 13.8, angle=0.4, load="crates")
    p.barrels(8.6, 7.4, count=2)
    p.crates(12.8, 6.4, count=2, fruit=False)
    p.woodpile(3.2, 10.7)
    p.bench(20.2, 13.4, angle=math.radians(70))
    for (c, r, size, leaf) in TREES:
        p.block_tree(c, r, size=size, leaf=leaf)
    for (c, r, size) in BUSHES:
        p.bush(c, r, size=size)
    for (c, r, radius, tint) in STONES_AT:
        p.stone(c, r, radius=radius, tint=tint)
    for spot in FLOWER_SPOTS:
        p.flowers(*spot, count=kit.rng.randint(3, 5))
    for spot in TUFT_SPOTS:
        p.tuft(*spot)
    p.signpost(20.4, 16.6, "green", facing=math.radians(25))
    p.dove(WELL[0] - 1.35, WELL[1] + 0.2, z_off=2.4 + 0.55, heading=math.radians(-150), size=1.1)
    p.dove(5.0, 5.5, z_off=0.62, heading=math.radians(20), size=1.15)
    p.dove(24.4, 11.2, z_off=0.0, heading=math.radians(200))
    p.dove(HOUSES[0][0] - 1.0, HOUSES[0][1], z_off=1.75 + 0.95 + 0.15, heading=math.radians(40), size=1.1)
    p.dove(TREE[0] + 0.8, TREE[1] - 0.6, z_off=0.0, heading=math.radians(120))

    p.flying_doves(WELL[0] - 1.0, WELL[1], height=5.6, radius=3.0, count=3)

    merged = kit.finalize(smooth_angle_deg=35.0)
    export_glb(OUT_DIR / f"{VARIANT}.glb", merged.values())
    write_layout(OUT_DIR / f"{VARIANT}.json", STAGE, SCENE, WELL, table=wither_table(TABLE) if WITHERED else TABLE, withered=WITHERED)
    print("DIORAMA_DONE", OUT_DIR)


build()
