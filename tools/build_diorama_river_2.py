"""Stage 5 diorama "深潭" (deep pool): a mossy gorge at dusk.

Theme: a dark, still pool under a high rock terrace. A stream runs across the terrace
and drops into the pool as a fall; pines crowd the rim, boulders capped with moss sit in
the shallows, a plank pier reaches out over the water, a fisherman's hut on stilts
stands at the east shore with a lit lantern, koi glide beneath the surface. The small
flagstone circle with its stone lantern on the east bank is the badge anchor.

Palette: deep teal water, dark moss greens, slate grey rock; the warm lantern glass and
the koi are the only warm notes. Table: dusk grey-lavender with teal / indigo / moss dots.

Run from the project root:
  "D:/Steam/steamapps/common/Blender/blender.exe" -b --python tools/build_diorama_river_2.py
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
STAGE = "river_2"
OUT_DIR = PROJECT / "assets/dioramas" / STAGE
# DIORAMA_WITHERED=1 builds the derelict variant (<stage>_withered.glb/.json) from the same layout.
WITHERED, VARIANT = variant_setup(STAGE)
GROUND_PNG = PROJECT / "artifacts" / f"diorama_{VARIANT}_ground.png"

# L shore, U high terrace, V stream on the terrace (water), W the pool (water).
MASK = [
    "..............................",
    "....UUUUUUUVVVUUUUUUUUUU......",
    "...UUUUUUUUVVVUUUUUUUUUUUL....",
    "..UUUUUUUUUVVVUUUUUUUUUUULL...",
    "..UUUUUUUUUVVVUUUUUUUUUUULLL..",
    "..LLUUUUUUUVVVUUUUUUUUULLLLL..",
    ".LLLLLLLLLWWWWWLLLLLLLLLLLLLL.",
    ".LLLLLLLLWWWWWWWWLLLLLLLLLLLL.",
    ".LLLLLLLWWWWWWWWWWLLLLLLLLLLL.",
    ".LLLLLLWWWWWWWWWWWWLLLLLLLLLL.",
    ".LLLLLLWWWWWWWWWWWWWLLLLLLLLL.",
    ".LLLLLLWWWWWWWWWWWWWLLLLLLLLL.",
    "..LLLLLWWWWWWWWWWWWLLLLLLLLL..",
    "..LLLLLLWWWWWWWWWWLLLLLLLLLL..",
    "..LLLLLLLWWWWWWWWLLLLLLLLLLL..",
    "...LLLLLLLLWWWWLLLLLLLLLLLL...",
    "....LLLLLLLLLLLLLLLLLLLLLL....",
    ".....LLLLLLLLLLLLLLLLLLLL.....",
    ".......LLLLLLLLLLLLLLLL.......",
    "..............................",
    "..............................",
    "..............................",
]
HEIGHTS = {"L": 0.0, "U": 1.4, "V": 0.95, "W": -0.6}
WATER_Y = -0.5 if WITHERED else -0.25   # withered: the pool has drained almost to its bed
STREAM_Y = 1.2
BOTTOM = -2.1
SCENE = Scene(MASK, HEIGHTS, BOTTOM, WATER_Y)

PALETTE = {
    "grass_a": "#7f9a6c", "grass_b": "#738e62", "grass_edge": "#66805a",
    "sand": "#9a8a6e", "sand_dark": "#8a7a5e",
    "cliff_up": "#8a8577", "cliff_low": "#6e6a5f", "stream_bed": "#4c6e72",
    "timber": "#5a4636", "wood": "#a88b62", "wood_dark": "#7d6548", "thatch": "#b89a6a", "thatch_dark": "#9e8256",
    "trunk": "#5f4b3a", "leaves": ["#587a5f", "#4f7055", "#628a68", "#476350"], "pine_a": "#4f7460", "pine_b": "#446657",
    "bush": "#5f8a6a", "moss": "#7f9a6c", "reed": "#6f8f5c",
    "stones": ["#8f8a80", "#7b776e", "#6a665e"], "boulder": "#8f8a80", "boulder_dark": "#6e6a61",
    "flag_a": "#a9a496", "flag_b": "#98938a",
    "iron": "#3a3633", "lantern": "#f2b95a", "hull": "#d9d2c4", "hull_trim": "#5a4636", "koi": "#f0894f", "foam": "#e6f2f2",
    "flowers": ["#c9d1e8", "#ffffff", "#e8c8a0"], "dove": "#ecebe6",
    "sign_green": "#6f8f6c", "sign_orange": "#c99456", "sign_face": "#e9e4d8",
}
TABLE = {"far": "#e4e6ea", "near": "#d2d4dc", "dots": ["#b6cfd0", "#c4c4d8", "#bfcbb4"]}
WATER = {"shallow": "#7d8a80", "deep": "#4f5c57"} if WITHERED else {"shallow": "#5c9aa3", "deep": "#2f6b78"}

HUT = (21.0, 9.6)
PIER = (5.6, 11.5)
CIRCLE = (23.4, 10.6)
STEPS = (24.0, 5.0)
PATH = [(24.0, 6.4), (23.6, 8.6), (23.4, 10.6), (22.6, 13.6), (19.0, 15.8), (13.0, 16.4), (8.0, 15.0), (6.0, 12.6)]
PINES_TOP = [(5.4, 2.6, 1.15, False), (8.0, 3.6, 1.0, True), (16.6, 2.4, 1.25, False), (19.4, 3.8, 1.05, True),
             (22.6, 2.8, 1.1, False), (14.0, 4.6, 0.85, True), (8.8, 1.9, 0.9, False)]
PINES_LOW = [(3.0, 8.6, 1.0, True), (26.6, 8.0, 1.1, False), (25.2, 15.6, 0.95, True), (3.6, 15.0, 0.9, False), (27.4, 12.6, 0.8, True)]
BOULDERS = [(7.2, 6.6, 0.9, False), (16.8, 6.2, 1.0, True), (19.8, 14.4, 0.85, False), (24.4, 13.6, 0.7, True),
            (4.4, 12.6, 0.8, True), (10.2, 15.4, 0.7, False), (26.0, 5.8, 0.75, False)]
BUSHES = [(9.6, 5.6, 0.8), (18.6, 6.4, 0.75), (22.2, 16.2, 0.8), (6.4, 14.6, 0.7), (12.6, 16.6, 0.75), (25.6, 3.4, 0.7), (11.4, 3.2, 0.7)]
REEDS = [(8.6, 14.6), (17.6, 13.8), (7.0, 8.4), (18.4, 8.0), (11.6, 15.6)]
LILIES = [(9.5, 13.4), (16.5, 8.6), (13.5, 14.4), (8.5, 9.6)]
LANTERNS = [(6.2, 13.6), (21.4, 13.2), (CIRCLE[0], CIRCLE[1])]
STONES_AT = [(2.6, 10.2, 0.3, 0), (26.2, 15.2, 0.32, 1), (15.6, 17.4, 0.28, 2), (5.0, 6.0, 0.3, 1), (23.8, 16.6, 0.26, 0)]
FLOWER_SPOTS = [(4.6, 9.8), (24.6, 8.8), (17.0, 16.6), (9.2, 16.4), (20.6, 12.6), (13.2, 2.6), (20.8, 5.0)]
TUFT_SPOTS = [(3.8, 7.2), (6.0, 10.0), (19.6, 12.2), (22.0, 7.4), (25.8, 10.4), (26.4, 14.0), (11.0, 17.2), (15.2, 15.8),
              (6.6, 3.6), (11.6, 2.4), (17.8, 4.4), (21.6, 2.0), (24.6, 3.6), (4.6, 4.2), (9.4, 4.4)]


def paint_ground() -> Path:
    gp = GroundPainter(SCENE.cols, SCENE.rows, px=64, seed=51, tint=wither_hex if WITHERED else None)
    gp.checker(PALETTE["grass_a"], PALETTE["grass_b"], noise=0.012)
    if WITHERED:
        # the terrace stream is a dry cracked gully
        gp.paint_cells(MASK, "V", lambda g: g.cobbles("#9a8b74", "#8b7d68", "#6f6354", cell=0.7, joint_width=0.07), feather_cells=0.12)
    gp.path(PATH, 1.0, wobble=0.12)
    gp.patch(*CIRCLE, 1.8, 1.0)
    gp.patch(HUT[0], HUT[1] + 2.0, 1.1, 0.7)
    gp.patch(PIER[0], PIER[1], 1.0, 0.7)
    for r, line in enumerate(MASK):
        for c, t in enumerate(line):
            if t in "WV":
                gp.patch(c + 0.5, r + 0.5, 1.15, 0.7)
    for (c, r, size, _alt) in PINES_TOP + PINES_LOW:
        gp.patch(c, r, 0.9 * size, 0.85, target="ao")
    for (c, r, radius, _dark) in BOULDERS:
        gp.patch(c, r, radius * 1.3, 0.8, target="ao")
    for (c, r, size) in BUSHES:
        gp.patch(c, r, 0.55 * size, 0.6, target="ao")
    gp.rect_ao(HUT[0] - 1.9, HUT[1] - 1.7, HUT[0] + 1.9, HUT[1] + 1.7, 0.7, 0.8)
    gp.patch(CIRCLE[0], CIRCLE[1], 0.7, 0.5, target="ao")
    gp.finish(PALETTE["sand"], PALETTE["sand_dark"], ao_strength=0.18)
    return gp.save(GROUND_PNG, name=f"ground_{STAGE}")


def build() -> None:
    kit = Kit(seed=12)
    kit.delay_fn = make_entrance_delay(SCENE, seed=9)
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
    kit.terrain(MASK, HEIGHTS, mats, bottom=BOTTOM, seam=-1.1, bed_chars="W" if WITHERED else "WV")

    p.stilt_hut(HUT[0], HUT[1])
    p.dock(PIER[0], PIER[1], length=4.6, width=1.3, along_x=True, deck_z=0.3)
    p.boat(11.8, 12.2, heading=math.radians(25), sail=False, length=2.3)
    p.steps(STEPS[0], STEPS[1], width=1.6, top_z=1.4)
    p.plaza(*CIRCLE, radius=1.5, with_bath=False)
    for (c, r) in LANTERNS:
        p.lantern_post(c, r, height=1.7)
    for (c, r, size, alt) in PINES_TOP + PINES_LOW:
        p.pine(c, r, size=size, alt=alt)
    for (c, r, radius, dark) in BOULDERS:
        p.boulder(c, r, radius=radius, dark=dark)
    for (c, r, size) in BUSHES:
        p.bush(c, r, size=size)
    for (c, r) in REEDS:
        p.reeds(c, r, count=6)
    for (c, r) in LILIES:
        p.lily(c, r)
    p.koi(10.5, 9.5, count=4)
    p.koi(15.0, 11.6, count=3)
    for (c, r, radius, tint) in STONES_AT:
        p.stone(c, r, radius=radius, tint=tint)
    for spot in FLOWER_SPOTS:
        p.flowers(*spot, count=kit.rng.randint(2, 4))
    for spot in TUFT_SPOTS:
        p.tuft(*spot)
    p.signpost(8.4, 16.8, "green", facing=math.radians(30))
    # The fall: foam at the lip of the terrace stream and where it lands, plus a pale water sheet.
    if not WITHERED:
        p.foam(12.5, 5.92, STREAM_Y + 0.02, count=4, spread=0.6)
        p.foam(12.5, 6.5, WATER_Y + 0.02, count=6, spread=1.0)
        x, y = SCENE.xy(12.5, 6.0)
        kit.piece("foam", x, y, WATER_Y)
        kit.box("props", (2.7, 0.14, STREAM_Y - WATER_Y + 0.1), (x, y + 0.02, (STREAM_Y + WATER_Y) / 2), p.mat("fall", "#d2e6ea"),
                bevel=0.05, segments=2)
    p.dove(PIER[0] + 4.2, PIER[1], z_off=0.42, heading=math.radians(-160), size=1.2)
    p.dove(HUT[0] + 0.6, HUT[1] + 0.3, z_off=0.55 + 1.7 + 0.2 + 0.7, heading=math.radians(210), size=1.2)
    p.dove(CIRCLE[0] - 0.8, CIRCLE[1] + 0.6, z_off=0.06, heading=math.radians(40))

    p.flying_doves(12.5, 10.5, height=4.6, radius=3.4, count=3)

    merged = kit.finalize(smooth_angle_deg=35.0)
    export_glb(OUT_DIR / f"{VARIANT}.glb", merged.values())
    write_layout(OUT_DIR / f"{VARIANT}.json", STAGE, SCENE, CIRCLE, water_levels={"W": WATER_Y} if WITHERED else {"W": WATER_Y, "V": STREAM_Y},
                 water_colors=WATER, table=wither_table(TABLE) if WITHERED else TABLE, withered=WITHERED)
    print("DIORAMA_DONE", OUT_DIR)


build()
