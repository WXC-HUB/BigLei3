"""Stage 2 diorama "麦垄" (wheat ridges): a harvest-time farm.

Theme: late-summer wheat country. Two striped wheat fields flank a dirt road; a
windmill stands on a knoll at the back-left, a red barn with a charcoal roof at the
back-right, haystacks, bales and standing sheaves fill the yard, a scarecrow guards the
field edge, poplars line the horizon. The round threshing floor (flagstones with a
haystack) is the badge anchor. No water.

Palette: straw gold and ochre earth against olive-yellow grass; the barn red is the
single strong accent, the roof is charcoal so the gold reads warm rather than muddy.
Table: warm wheat cream with gold / ochre / rust dots.

Run from the project root:
  "D:/Steam/steamapps/common/Blender/blender.exe" -b --python tools/build_diorama_grass_2.py
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
STAGE = "grass_2"
OUT_DIR = PROJECT / "assets/dioramas" / STAGE
# DIORAMA_WITHERED=1 builds the derelict variant (<stage>_withered.glb/.json) from the same layout.
WITHERED, VARIANT = variant_setup(STAGE)
GROUND_PNG = PROJECT / "artifacts" / f"diorama_{VARIANT}_ground.png"

# L grass, U knoll (windmill), F wheat field, Y farmyard (packed earth).
MASK = [
    "..............................",
    "...UUUUUUU....................",
    "..UUUUUUUUULLLLLLLLLLLLLLL....",
    "..UUUUUUUUULLLLLLYYYYYYYLLLL..",
    ".LUUUUUUUULLLLLLLYYYYYYYLLLLL.",
    ".LLUUUUUUULLLLLLLYYYYYYYLLLLL.",
    ".LLLLLLLLLLLLLLLLYYYYYYYLLLLL.",
    ".LFFFFFFFFLLLLLLLLLLLLLLLLLLL.",
    ".LFFFFFFFFLLLLLLLFFFFFFFFFLLL.",
    ".LFFFFFFFFLLLLLLLFFFFFFFFFLLL.",
    ".LFFFFFFFFLLLLLLLFFFFFFFFFLLL.",
    ".LFFFFFFFFLLLLLLLFFFFFFFFFLLL.",
    "..LFFFFFFFLLLLLLLFFFFFFFFFLL..",
    "..LFFFFFFFLLLLLLLFFFFFFFFFLL..",
    "..LLLLLLLLLLLLLLLLFFFFFFFFLL..",
    "...LLLLLLLLLLLLLLLLLLLLLLLL...",
    "...LLLLLLLLLLLLLLLLLLLLLLL....",
    "....LLLLLLLLLLLLLLLLLLLL......",
    "......LLLLLLLLLLLLLLL.........",
    "..............................",
    "..............................",
    "..............................",
]
HEIGHTS = {"L": 0.0, "U": 0.9, "F": 0.0, "Y": 0.0}
BOTTOM = -2.1
SCENE = Scene(MASK, HEIGHTS, BOTTOM)

PALETTE = {
    "grass_a": "#cbc98c", "grass_b": "#c0bf80", "grass_edge": "#b3ae74",
    "sand": "#ddc39b", "sand_dark": "#cdae84",
    "cliff_up": "#d3b78c", "cliff_low": "#b99569",
    "wall": "#efe5d0", "trim": "#f7f2e6", "door": "#8a5a3c", "shutter": "#7a6a55", "glass": "#d8dcd6",
    "slate": "#5f6266", "slate_dark": "#4f5256",
    "barn": "#b7543f", "barn_trim": "#f4efe4",
    "trunk": "#8f7050", "leaves": ["#a3ad6b", "#93a05e", "#b0b876", "#8a9657"], "bush": "#9caa6a",
    "stones": ["#c9c1ad", "#b8ae98", "#a49b87"], "flag_a": "#cfc4aa", "flag_b": "#c1b59a",
    "wood": "#d2b98e", "wood_dark": "#a8845f", "timber": "#6e5643",
    "hay": "#e8d59d", "wheat": "#e2c77e", "wheat_dark": "#cfae5c", "rope": "#d8c7a4",
    "flowers": ["#e8635a", "#f2c14e", "#ffffff", "#f0a35e"],
    "sign_orange": "#e5a35a", "sign_green": "#8fb07f",
    "beak": "#e3a558",
}
TABLE = {"far": "#f8f0dc", "near": "#eddbbb", "dots": ["#e9d29a", "#d9bc86", "#e0a67c"]}

WINDMILL = (6.0, 3.6)
BARN = (20.5, 4.6)
THRESHING = (14.5, 10.5)
STEPS = (7.0, 6.0)
ROAD = [(13.0, 18.4), (13.6, 15.5), (14.5, 12.6), (15.5, 9.0), (17.5, 7.4), (20.5, 7.0)]
LANE = [(15.0, 9.5), (11.5, 7.8), (8.5, 7.2), (7.0, 6.9)]
POPLARS = [(13.5, 2.6, 1.0, 0), (15.3, 2.4, 1.15, 1), (27.0, 3.4, 1.05, 2), (28.0, 5.6, 0.9, 1), (1.6, 8.0, 0.95, 0)]
TREES = [(2.4, 6.2, 1.0, 1), (11.0, 5.4, 0.9, 3), (26.4, 14.2, 1.0, 0), (24.8, 16.6, 0.85, 2)]
BUSHES = [(10.6, 8.2, 0.85), (10.4, 13.6, 0.8), (16.2, 12.2, 0.75), (25.6, 7.6, 0.8), (4.2, 15.4, 0.9), (22.6, 15.9, 0.7)]
HAYSTACKS = [(24.6, 8.6, 1.05), (26.2, 10.0, 0.8), (11.8, 15.6, 0.95)]
BALES = [(13.4, 9.1, 0.35), (14.7, 10.0, -0.4), (13.1, 11.7, 0.15)]
SHEAVES = [(3.5, 8.6), (5.5, 8.6), (7.5, 8.6), (3.5, 11.5), (5.5, 11.5), (7.5, 11.5),
           (19.0, 9.2), (21.0, 9.2), (23.0, 9.2), (19.0, 12.2), (21.0, 12.2), (23.0, 12.2)]
STONES_AT = [(3.8, 15.4, 0.34, 0), (25.4, 16.2, 0.3, 1), (9.5, 17.2, 0.28, 2), (16.6, 6.2, 0.3, 1)]
FLOWER_SPOTS = [(9.6, 15.0), (16.8, 15.6), (20.8, 16.2), (4.4, 6.8), (10.2, 6.6), (26.6, 12.2), (2.6, 13.0), (17.6, 17.2)]
TUFT_SPOTS = [(11.4, 9.6), (12.2, 13.0), (16.4, 14.6), (18.8, 15.0), (24.2, 14.0), (27.2, 8.4), (3.6, 4.6), (9.0, 5.0),
              (12.6, 4.2), (16.9, 4.0), (25.8, 4.8), (6.6, 16.2), (8.4, 15.6), (19.8, 17.0), (14.4, 17.6)]


def paint_ground() -> Path:
    gp = GroundPainter(SCENE.cols, SCENE.rows, px=64, seed=21, tint=wither_hex if WITHERED else None)
    gp.checker(PALETTE["grass_a"], PALETTE["grass_b"])
    # Wheat rows across the two fields, furrows between them.
    gp.paint_cells(MASK, "F", lambda g: g.stripes("#e2c77e", "#d6b86a", "#a9885a", period=1.0, furrow_width=0.18, along="x"))
    # The farmyard is packed earth.
    gp.paint_cells(MASK, "Y", lambda g: g.checker("#d6bd97", "#d0b58d", noise=0.014))
    gp.path(ROAD, 1.3, wobble=0.15)
    gp.path(LANE, 0.9)
    gp.patch(*THRESHING, 2.1, 1.0)
    gp.patch(BARN[0], BARN[1] + 2.6, 1.6, 0.8)
    gp.patch(WINDMILL[0], WINDMILL[1] + 1.4, 0.9, 0.7)
    for (c, r, size, _leaf) in POPLARS + TREES:
        gp.patch(c, r, 0.8 * size, 0.8, target="ao")
    for (c, r, size) in HAYSTACKS:
        gp.patch(c, r, 0.9 * size, 0.7, target="ao")
    for (c, r, size) in BUSHES:
        gp.patch(c, r, 0.55 * size, 0.6, target="ao")
    gp.rect_ao(BARN[0] - 3.0, BARN[1] - 2.1, BARN[0] + 3.0, BARN[1] + 2.1, 0.8, 0.9)
    gp.patch(WINDMILL[0], WINDMILL[1], 1.4, 0.9, target="ao")
    gp.patch(THRESHING[0], THRESHING[1], 0.9, 0.5, target="ao")
    gp.finish(PALETTE["sand"], PALETTE["sand_dark"], ao_strength=0.15)
    return gp.save(GROUND_PNG, name=f"ground_{STAGE}")


def build() -> None:
    kit = Kit(seed=8)
    kit.delay_fn = make_entrance_delay(SCENE, seed=6)
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

    p.windmill(*WINDMILL)
    p.barn(*BARN)
    p.steps(STEPS[0], STEPS[1], width=1.6)
    p.plaza(*THRESHING, radius=1.9, with_bath=False)
    p.haystack(THRESHING[0], THRESHING[1], size=1.15)
    for (c, r, size) in HAYSTACKS:
        p.haystack(c, r, size=size)
    for (c, r, ang) in BALES:
        p.hay_bale(c, r, angle=ang)
    for (c, r) in SHEAVES:
        p.sheaf(c, r)
    p.scarecrow(11.6, 12.6, heading=0.35)
    p.cart(17.2, 8.4, angle=0.45, load="hay")
    p.crates(23.6, 6.8, count=2, fruit=False)
    p.barrels(17.4, 3.4, count=2)
    for (c, r, size, leaf) in POPLARS:
        p.poplar(c, r, size=size, leaf=leaf)
    for (c, r, size, leaf) in TREES:
        p.block_tree(c, r, size=size, leaf=leaf)
    for (c, r, size) in BUSHES:
        p.bush(c, r, size=size)
    for (c, r, radius, tint) in STONES_AT:
        p.stone(c, r, radius=radius, tint=tint)
    p.fence([(17.0, 7.1), (19.6, 7.1)])
    p.fence([(21.6, 7.1), (24.2, 7.1)])
    p.fence([(7.2, 17.5), (12.2, 17.5)])
    p.fence([(14.2, 17.5), (19.0, 17.5)])
    p.fence([(1.6, 7.0), (1.6, 12.0), (1.6, 14.0)], post_every=1.2)
    for spot in FLOWER_SPOTS:
        p.flowers(*spot, count=kit.rng.randint(3, 5))
    for spot in TUFT_SPOTS:
        p.tuft(*spot)
    p.signpost(9.6, 16.6, "orange", facing=math.radians(15))
    p.dove(BARN[0] - 1.6, BARN[1], z_off=2.6 + 1.7 + 0.2, heading=math.radians(-30))
    p.dove(18.4, 7.1, z_off=0.62, heading=math.radians(200), size=1.2)
    p.dove(15.2, 15.4, z_off=0.0, heading=math.radians(70))
    p.dove(THRESHING[0] + 0.5, THRESHING[1] + 0.3, z_off=1.6, heading=math.radians(120), size=1.2)

    p.flying_doves(THRESHING[0], THRESHING[1], height=5.0, radius=3.0, count=3)

    merged = kit.finalize(smooth_angle_deg=35.0)
    export_glb(OUT_DIR / f"{VARIANT}.glb", merged.values())
    write_layout(OUT_DIR / f"{VARIANT}.json", STAGE, SCENE, THRESHING, table=wither_table(TABLE) if WITHERED else TABLE, withered=WITHERED)
    print("DIORAMA_DONE", OUT_DIR)


build()
