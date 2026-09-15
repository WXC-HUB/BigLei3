"""Palette-driven prop generators shared by all stage dioramas.

Every stage script builds a `Scene` (mask + heights), a palette (a dict of sRGB hexes,
see DEFAULT_PALETTE for the keys) and a `Props` bound to both, then places props with
cell coordinates. Each generator opens one entrance "piece" (kit.piece) so the prop pops
as a unit during the build-up animation; multi-part props (cottage walls then roof) open
several. Colours never appear inline here: everything goes through the palette so a stage
can restyle a prop just by overriding keys.

Two things ride along with every piece:

* an idle **motion** kind + phase (the `M_*` constants below; the Godot shader animates the
  piece around its pivot: leaves sway, perched birds nod, boats rock, sails and wheels turn,
  hung things swing, smoke rises, flags flutter, birds and fish circle);
* the **withered** mode (`Props(..., withered=True)`): the same scene as it looks before the
  stage is cleared - a dedicated derelict language, not just dead plants: bare trees, dry
  grass, boarded windows, missing tiles, toppled and broken things, dry wells and drained
  water, lamps out, no smoke, and the birds gone (one crow stays). The alive and withered
  variants are built from the same stage script so everything stays in the same place.
"""
import colorsys
import json
import math
import os
import random

from diorama_kit import Kit, hex_rgb

ENTRANCE_DEFAULTS = {"span": 1.35, "piece_time": 0.55, "rise_time": 0.7}
ENTRANCE_BASE = {
    "ground": 0.26, "building": 0.42, "roof": 0.64, "tree": 0.50, "prop": 0.56,
    "greenery": 0.84, "dove": 1.06, "foam": 0.80,
}
ANIM_BOUNDS = ((-16.0, -3.0, -12.0), (32.0, 10.0, 24.0))

# Motion kinds understood by shaders/diorama_build.gdshader (UV2.x = (kind + 0.5) / 32).
M_NONE, M_SWAY, M_PERCH, M_ROCK, M_SPIN_Z, M_SPIN_X, M_SWING, M_SMOKE, M_FLUTTER, M_FLY, M_SWIM, M_FLOAT = range(12)


def make_entrance_delay(scene, sweep: float = 0.24, seed: int = 5, base: dict = None):
    """Start time for a piece pivoting at Blender (x, y): grouped by kind, swept toward the
    viewer (front-right), plus a little jitter so rows never pop in lockstep."""
    rng = random.Random(seed)
    table = dict(ENTRANCE_BASE)
    if base:
        table.update(base)

    def delay(kind: str, x: float, y: float, extra: float = 0.0) -> float:
        c, r = x + scene.cols / 2.0, scene.rows / 2.0 - y
        s = min(max(0.75 * r / scene.rows + 0.25 * c / scene.cols, 0.0), 1.0)
        return table.get(kind, 0.5) + sweep * s + extra + rng.uniform(0.0, 0.05)

    return delay


def variant_setup(stage: str):
    """(withered, variant_name): DIORAMA_WITHERED=1 builds the derelict variant of a stage,
    written next to the alive one as <stage>_withered.glb / .json."""
    withered = os.environ.get("DIORAMA_WITHERED") == "1"
    return withered, (f"{stage}_withered" if withered else stage)


# --- the withered colour language ----------------------------------------------------------------

def _rgb_hex(r: float, g: float, b: float) -> str:
    return "#%02x%02x%02x" % tuple(int(round(min(max(v, 0.0), 1.0) * 255)) for v in (r, g, b))


def wither_hex(h: str, sat: float = 0.42, light: float = 0.95) -> str:
    """Dry a colour out: greens turn straw, everything loses most of its saturation and a little
    contrast, and the whole thing leans toward dusty grey-beige."""
    r, g, b = hex_rgb(h)
    hue, lum, s = colorsys.rgb_to_hls(r, g, b)
    deg = hue * 360.0
    if 60.0 < deg < 170.0:
        deg = 44.0 + (deg - 60.0) * 0.22
    elif 170.0 <= deg < 260.0:
        s *= 0.75
    s *= sat
    lum = 0.5 + (lum - 0.5) * 0.9
    lum = lum * light + 0.02
    r, g, b = colorsys.hls_to_rgb((deg % 360.0) / 360.0, min(max(lum, 0.0), 1.0), min(max(s, 0.0), 1.0))
    dust = hex_rgb("#a8a398")
    k = 0.14
    return _rgb_hex(r * (1 - k) + dust[0] * k, g * (1 - k) + dust[1] * k, b * (1 - k) + dust[2] * k)


def wither_table(table: dict) -> dict:
    """The table cloth of a withered stage: same hues, greyed and a shade dimmer."""
    return {
        "far": wither_hex(table["far"], sat=0.35, light=0.985),
        "near": wither_hex(table["near"], sat=0.35, light=0.975),
        "dots": [wither_hex(d, sat=0.3, light=0.97) for d in table["dots"]],
    }


def wither_palette(pal: dict) -> dict:
    out = {}
    for key, value in pal.items():
        if isinstance(value, str):
            out[key] = wither_hex(value)
        else:
            out[key] = [wither_hex(v) for v in value]
    out.update(WITHERED_OVERRIDES)
    return out


def write_layout(path, stage_id: str, scene, marker, water_levels: dict = None, water_colors: dict = None,
                 table: dict = None, extra: dict = None, withered: bool = False) -> None:
    """The JSON the Godot side reads: mask, heights, water, badge anchor, table palette, entrance."""
    layout = {
        "stage_id": stage_id,
        "withered": withered,
        "cell": 1.0,
        "cols": scene.cols,
        "rows": scene.rows,
        "mask": scene.mask,
        "heights": scene.heights,
        "bottom": scene.bottom,
        "marker": {"c": marker[0], "r": marker[1]},
        "entrance": dict(ENTRANCE_DEFAULTS, pivot_min=list(ANIM_BOUNDS[0]), pivot_size=list(ANIM_BOUNDS[1])),
    }
    if scene.water_y is not None:
        layout["water_y"] = scene.water_y
    if water_levels:
        layout["water_levels"] = water_levels
    if water_colors:
        layout["water"] = water_colors
    if table:
        layout["table"] = table
    if extra:
        layout.update(extra)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(layout, indent=1), encoding="utf-8")


# Stage 1's colours double as the defaults; other stages override what they need.
DEFAULT_PALETTE = {
    "grass_a": "#bccb90", "grass_b": "#b0c285", "grass_edge": "#a4b779",
    "sand": "#e7dab3", "sand_dark": "#dccc9f",
    "cliff_up": "#dac597", "cliff_low": "#bfa274", "stream_bed": "#c9b487",
    "wall": "#f3ead7", "trim": "#faf5ea", "door": "#5f8e82", "shutter": "#6c9a8d", "glass": "#c8dde0",
    "roof_a": "#d8935f", "roof_b": "#e1a173", "roof_c": "#cf8a58", "ridge": "#c27a4c", "roof_bed": "#c9835a",
    "chimney": "#d9ccb6", "chimney_cap": "#b9a88e",
    "trunk": "#9b7a5a",
    "leaves": ["#a6c27b", "#97b46d", "#b4ca88", "#8fae6a"],
    "fruit_a": "#e8a45f", "fruit_b": "#f0aa9d",
    "pine_a": "#8bad96", "pine_b": "#7ba08b",
    "bush": "#a3bd7b",
    "stones": ["#cbc5b5", "#bab3a2", "#aaa494"],
    "flag_a": "#cbc3b2", "flag_b": "#bdb4a2",
    "wood": "#d9c49d", "wood_dark": "#b99f78",
    "soil": "#b08e6a", "sprout": "#9cc06f",
    "dove": "#f2eee6", "beak": "#e3a558", "eye": "#3a3632",
    "flowers": ["#f2c4bf", "#f5e1a0", "#ffffff", "#e9a9c9"],
    "sign_green": "#8fb07f", "sign_orange": "#e5a35a", "sign_face": "#f6f0e2",
    "foam": "#ffffff", "still_water": "#a9d6cc", "hay": "#e6d29b",
    # Used by the newer props; stage 1 never draws them but the keys exist for every stage.
    "timber": "#6b5a4b", "slate": "#6f7f8f", "slate_dark": "#5c6a78", "iron": "#4a4642", "lantern": "#f3c56b",
    "thatch": "#c9ab73", "thatch_dark": "#b3945d", "sail": "#f4eee0", "hull": "#f5f2ec", "hull_trim": "#3b5a7a",
    "buoy": "#f08a5b", "rope": "#d8c7a4", "wheat": "#e2c77e", "wheat_dark": "#c9a955", "barn": "#b7543f",
    "barn_trim": "#f4efe4", "stone_wall": "#c9c3b6", "moss": "#7f9a6c", "boulder": "#8f8a80", "boulder_dark": "#6e6a61",
    "reed": "#8aa86a", "willow": "#9fc07f", "iris": "#7e8fc9", "koi": "#f0894f", "beacon": "#d9463a",
    "stone_trim": "#e2dccf", "ribbon": "#c9573f", "gold": "#e0b458",
    "plank": "#b7c2c6", "plank_dark": "#9aa6ab", "net": "#93aeb0",
    # Alive-only life signs and the derelict kit.
    "smoke": "#eeece8", "crow": "#33302d", "ivy": "#6f8560", "board": "#9c8467",
    "mud": "#9a8b74", "mud_dark": "#7d6f5b",
}

# What the dried-out palette forces regardless of stage: straw grass, dead leaves, lamps out,
# grey water, mouldy hay, dusty birds.
WITHERED_OVERRIDES = {
    "grass_a": "#bdb58a", "grass_b": "#b2aa7f", "grass_edge": "#9e9670",
    "leaves": ["#a99b6f", "#9b8d63", "#b4a677", "#8f8259"], "bush": "#a0946b", "willow": "#b3a67a",
    "pine_a": "#8c7c5f", "pine_b": "#7e6f54", "reed": "#a89a6c", "sprout": "#9a8f6a",
    "hay": "#b3a98d", "wheat": "#bfb08a", "wheat_dark": "#a8996f",
    "lantern": "#9c9a94", "gold": "#a89c7c", "still_water": "#7e857a", "foam": "#d8d8d2",
    "sail": "#c9c3b6", "dove": "#d9d6cf", "smoke": "#c9c6c0", "crow": "#33302d",
    "flowers": ["#b7a892", "#c1b39a", "#a8a08e"], "moss": "#9a9670", "iris": "#9a93a0",
    "ivy": "#7d8468", "mud": "#8f8677", "mud_dark": "#776e60", "board": "#8a7a66", "ribbon": "#a8776c",
}


class Scene:
    """Cell grid of one diorama: mask, heights and the cell → Blender coordinate mapping."""

    def __init__(self, mask, heights, bottom=-2.1, water_y=None):
        self.mask = mask
        self.rows = len(mask)
        self.cols = len(mask[0])
        for line in mask:
            assert len(line) == self.cols, "mask rows must have equal length"
        self.heights = heights
        self.bottom = bottom
        self.water_y = water_y
        self.land = {k for k, v in heights.items() if v >= 0.0}

    def cell_at(self, c: float, r: float) -> str:
        ci, ri = int(math.floor(c)), int(math.floor(r))
        if 0 <= ri < self.rows and 0 <= ci < self.cols:
            return self.mask[ri][ci]
        return "."

    def ground_z(self, c: float, r: float) -> float:
        t = self.cell_at(c, r)
        if t == "W" and self.water_y is not None:
            return self.water_y
        return self.heights.get(t, self.bottom)

    def xy(self, c: float, r: float):
        return (c - self.cols / 2.0, self.rows / 2.0 - r)

    def check_on_land(self, label: str, c: float, r: float) -> None:
        t = self.cell_at(c, r)
        if t not in self.land:
            print(f"WARNING {label} at ({c}, {r}) sits on '{t}'")


class Props:
    def __init__(self, kit: Kit, scene: Scene, palette: dict, withered: bool = False):
        self.kit = kit
        self.s = scene
        self.w = withered
        merged = dict(DEFAULT_PALETTE)
        merged.update(palette)
        self.pal = wither_palette(merged) if withered else merged
        self.rng = kit.rng
        self._crow_placed = False

    # --- helpers --------------------------------------------------------------------------

    def mat(self, key: str, hexcolor: str = None):
        """Material for a palette key (or an explicit colour under that name)."""
        return self.kit.mat(key, hexcolor or self.pal[key])

    def leaf(self, index: int):
        leaves = self.pal["leaves"]
        return self.kit.mat(f"leaf{index % len(leaves)}", leaves[index % len(leaves)])

    def stone_mat(self, tint: int):
        stones = self.pal["stones"]
        return self.kit.mat(f"stone{tint % len(stones)}", stones[tint % len(stones)])

    def _at(self, label, c, r):
        self.s.check_on_land(label, c, r)
        x, y = self.s.xy(c, r)
        return x, y, self.s.ground_z(c, r)

    def motion(self, kind: int, alive_only: bool = True):
        """(kind, phase) for kit.piece(); alive_only motions are dropped in the withered variant."""
        if kind == M_NONE or (alive_only and self.w):
            return None
        return (kind, self.rng.random())

    def _bare_tree(self, x, y, z0, size, trunk_h, branches=4, spread=0.9, radius=0.14):
        """Dead tree: a trunk and a few forked bare branches, no crown."""
        kit, rng = self.kit, self.rng
        bark = self.mat("trunk")
        kit.cyl("trees", radius * size, trunk_h, (x, y, z0 + trunk_h / 2), bark, verts=7)
        for i in range(branches):
            a = i / branches * math.tau + rng.uniform(-0.3, 0.3)
            tilt = rng.uniform(0.55, 0.95)
            length = rng.uniform(0.6, 1.0) * spread * size
            bz = z0 + trunk_h * rng.uniform(0.6, 0.98)
            cx = x + math.cos(a) * math.sin(tilt) * length / 2
            cy = y + math.sin(a) * math.sin(tilt) * length / 2
            kit.frustum("trees", 0.06 * size, 0.012 * size, length, (cx, cy, bz + math.cos(tilt) * length / 2), bark, verts=5,
                        rot=(-tilt * math.sin(a), tilt * math.cos(a), 0.0))

    def _boards(self, x, y, z, w, h, facing="-y"):
        """Two crossed planks nailed over an opening."""
        kit = self.kit
        board = self.mat("board")
        for s in (-1.0, 1.0):
            if facing == "-y":
                kit.box("buildings", (w * 1.15, 0.05, 0.14), (x, y - 0.08, z), board, rot=(0.0, s * math.radians(28), 0.0))
            else:
                sx = -1.0 if facing == "-x" else 1.0
                kit.box("buildings", (0.05, w * 1.15, 0.14), (x + sx * 0.08, y, z), board, rot=(s * math.radians(28), 0.0, 0.0))

    def _ivy(self, x, y, z0, w, facing="-y"):
        """Ivy creeping up a wall of an abandoned house: a few flat irregular patches."""
        kit, rng = self.kit, self.rng
        ivy = self.mat("ivy")
        for _ in range(3):
            pw, ph = rng.uniform(0.35, 0.8), rng.uniform(0.5, 1.3)
            off = rng.uniform(-w * 0.42, w * 0.42)
            if facing == "-y":
                kit.box("buildings", (pw, 0.05, ph), (x + off, y - 0.025, z0 + ph / 2 + 0.02), ivy, bevel=0.08, segments=2)
            else:
                sx = -1.0 if facing == "-x" else 1.0
                kit.box("buildings", (0.05, pw, ph), (x + sx * 0.025, y + off, z0 + ph / 2 + 0.02), ivy, bevel=0.08, segments=2)

    # --- vegetation -----------------------------------------------------------------------

    def block_tree(self, c, r, size=1.0, leaf=0, fruit=None, tall=False):
        kit, rng = self.kit, self.rng
        x, y, z0 = self._at("tree", c, r)
        kit.piece("tree", x, y, z0, motion=self.motion(M_SWAY))
        trunk_h = (1.05 if tall else 0.8) * size
        if self.w:
            self._bare_tree(x, y, z0, size, trunk_h + 0.9 * size, branches=4, spread=1.0)
            return
        kit.cyl("trees", 0.15 * size, trunk_h, (x, y, z0 + trunk_h / 2), self.mat("trunk"), verts=8)
        base = (1.55 if tall else 1.35) * size
        kit.box("trees", (base, base * 0.95, base * 0.82), (x, y, z0 + trunk_h + base * 0.36), self.leaf(leaf),
                bevel=0.30 * size, segments=3)
        top = base * 0.66
        ox, oy = rng.uniform(-0.28, 0.28) * size, rng.uniform(-0.22, 0.22) * size
        kit.box("trees", (top, top * 0.95, top * 0.8), (x + ox, y + oy, z0 + trunk_h + base * 0.36 + base * 0.62),
                self.leaf(leaf + 1), bevel=0.22 * size, segments=3)
        if fruit is not None:
            fm = self.mat("fruit_a" if fruit == 0 else "fruit_b")
            for _ in range(7):
                side = rng.choice(["x", "y", "z"])
                sgn = rng.choice([-1.0, 1.0])
                u, v = rng.uniform(-0.35, 0.35), rng.uniform(-0.1, 0.32)
                if side == "x":
                    p = (x + sgn * base * 0.49, y + u * base, z0 + trunk_h + base * 0.36 + v * base)
                elif side == "y":
                    p = (x + u * base, y + sgn * base * 0.47, z0 + trunk_h + base * 0.36 + v * base)
                else:
                    p = (x + u * base, y + rng.uniform(-0.35, 0.35) * base, z0 + trunk_h + base * 0.36 + base * 0.41)
                kit.sphere("trees", 0.09 * size, p, fm, segments=10, rings=6)

    def pine(self, c, r, size=1.0, alt=False):
        kit = self.kit
        x, y, z0 = self._at("pine", c, r)
        kit.piece("tree", x, y, z0, motion=self.motion(M_SWAY))
        m1, m2 = self.mat("pine_a"), self.mat("pine_b")
        kit.cyl("trees", 0.12 * size, 0.7 * size, (x, y, z0 + 0.35 * size), self.mat("trunk"), verts=8)
        tiers = [(1.05, 0.62, 0.78, 0.86), (0.80, 0.46, 0.72, 1.52), (0.52, 0.14, 0.78, 2.16)]
        if self.w:
            # Dead pine: a taller bare pole with two sparse brown tiers.
            kit.cyl("trees", 0.09 * size, 2.0 * size, (x, y, z0 + 1.6 * size), self.mat("trunk"), verts=7)
            tiers = [(0.7, 0.42, 0.5, 1.1), (0.42, 0.12, 0.5, 1.9)]
        for i, (r1, r2, d, zc) in enumerate(tiers):
            m = m2 if (i % 2 == (1 if alt else 0)) else m1
            kit.frustum("trees", r1 * size, r2 * size, d * size, (x, y, z0 + zc * size), m, verts=4,
                        rot=(0.0, 0.0, math.radians(45)), bevel=0.10 * size, segments=2)

    def poplar(self, c, r, size=1.0, leaf=0):
        """Tall narrow column tree: three stacked rounded blocks, the windbreak of a farm."""
        kit = self.kit
        x, y, z0 = self._at("poplar", c, r)
        kit.piece("tree", x, y, z0, motion=self.motion(M_SWAY))
        if self.w:
            self._bare_tree(x, y, z0, size, 3.2 * size, branches=3, spread=0.6, radius=0.12)
            return
        kit.cyl("trees", 0.12 * size, 0.7 * size, (x, y, z0 + 0.35 * size), self.mat("trunk"), verts=8)
        for i, (w, h, zc) in enumerate(((0.95, 1.2, 1.25), (0.78, 1.1, 2.2), (0.5, 0.9, 3.05))):
            kit.box("trees", (w * size, w * 0.9 * size, h * size), (x, y, z0 + zc * size), self.leaf(leaf + i),
                    bevel=0.2 * size, segments=3)

    def willow(self, c, r, size=1.0):
        """Weeping willow: a crown with hanging strand cones around it."""
        kit, rng = self.kit, self.rng
        x, y, z0 = self._at("willow", c, r)
        kit.piece("tree", x, y, z0, motion=self.motion(M_SWAY))
        crown = self.mat("willow")
        kit.cyl("trees", 0.16 * size, 1.4 * size, (x, y, z0 + 0.7 * size), self.mat("trunk"), verts=8)
        if self.w:
            # Bare willow: the trunk forks into drooping leafless whips.
            for i in range(6):
                a = i / 6 * math.tau + rng.uniform(-0.2, 0.2)
                rr = rng.uniform(0.35, 0.6) * size
                length = rng.uniform(1.2, 1.7) * size
                kit.frustum("trees", 0.05 * size, 0.01 * size, length,
                            (x + math.cos(a) * rr, y + math.sin(a) * rr, z0 + 1.6 * size - length * 0.5 + 0.1 * size),
                            self.mat("trunk"), verts=4, rot=(0.0, math.pi, 0.0))
            return
        kit.sphere("trees", 0.9 * size, (x, y, z0 + 1.9 * size), crown, scale=(1.0, 1.0, 0.75), segments=14, rings=9)
        for i in range(9):
            a = i / 9 * math.tau + rng.uniform(-0.2, 0.2)
            rr = rng.uniform(0.55, 0.85) * size
            length = rng.uniform(1.1, 1.6) * size
            kit.frustum("trees", 0.1 * size, 0.02 * size, length,
                        (x + math.cos(a) * rr, y + math.sin(a) * rr, z0 + 1.9 * size - length * 0.5 + 0.1 * size),
                        crown, verts=5, rot=(0.0, math.pi, 0.0))

    def bush(self, c, r, size=1.0, leaf=None):
        kit = self.kit
        x, y, z0 = self._at("bush", c, r)
        kit.piece("greenery", x, y, z0, motion=self.motion(M_SWAY))
        m = self.mat("bush") if leaf is None else self.leaf(leaf)
        if self.w:
            kit.box("greenery", (0.85 * size, 0.75 * size, 0.36 * size), (x, y, z0 + 0.16 * size), m,
                    bevel=0.14 * size, segments=2, rot=(0.0, 0.0, self.rng.uniform(-0.4, 0.4)))
            return
        kit.box("greenery", (0.95 * size, 0.85 * size, 0.62 * size), (x, y, z0 + 0.28 * size), m,
                bevel=0.24 * size, segments=3, rot=(0.0, 0.0, self.rng.uniform(-0.4, 0.4)))

    def reeds(self, c, r, count=7, spread=0.5):
        """Tall thin stalks with a dark seed head, on a bank or in shallow water."""
        kit, rng = self.kit, self.rng
        x, y = self.s.xy(c, r)
        z0 = self.s.ground_z(c, r)
        kit.piece("greenery", x, y, z0, motion=self.motion(M_SWAY, alive_only=False))
        if self.w:
            count = max(2, count // 2)
        for _ in range(count):
            px, py = x + rng.uniform(-spread, spread), y + rng.uniform(-spread, spread)
            h = rng.uniform(0.7, 1.15) * (0.8 if self.w else 1.0)
            tilt = 0.3 if self.w else 0.12
            kit.cyl("greenery", 0.03, h, (px, py, z0 + h / 2), self.mat("reed"), verts=5,
                    rot=(rng.uniform(-tilt, tilt), rng.uniform(-tilt, tilt), 0.0))
            if not self.w:
                kit.cyl("greenery", 0.05, 0.22, (px, py, z0 + h + 0.08), self.mat("trunk"), verts=6)

    def flowers(self, c, r, count=4):
        kit, rng = self.kit, self.rng
        self.s.check_on_land("flowers", c, r)
        px, py = self.s.xy(c, r)
        kit.piece("greenery", px, py, self.s.ground_z(c, r), motion=self.motion(M_SWAY, alive_only=False))
        stem = self.mat("sprout")
        flowers = self.pal["flowers"]
        for _ in range(count):
            cc, rr = c + rng.uniform(-0.3, 0.3), r + rng.uniform(-0.3, 0.3)
            x, y = self.s.xy(cc, rr)
            z0 = self.s.ground_z(cc, rr)
            h = rng.uniform(0.16, 0.26)
            kit.cyl("greenery", 0.015, h, (x, y, z0 + h / 2), stem, verts=5, rot=(rng.uniform(-0.3, 0.3) if self.w else 0.0, 0.0, 0.0))
            if self.w:
                continue   # dead stalks, no heads
            index = rng.randrange(len(flowers))
            kit.sphere("greenery", rng.uniform(0.05, 0.075), (x, y, z0 + h + 0.03),
                       kit.mat(f"flower{index}", flowers[index]), segments=8, rings=5)

    def tuft(self, c, r):
        kit, rng = self.kit, self.rng
        self.s.check_on_land("tuft", c, r)
        px, py = self.s.xy(c, r)
        kit.piece("greenery", px, py, self.s.ground_z(c, r), motion=self.motion(M_SWAY, alive_only=False))
        m = self.kit.mat("tuft", self.pal["leaves"][1])
        for _ in range(3):
            cc, rr = c + rng.uniform(-0.12, 0.12), r + rng.uniform(-0.12, 0.12)
            x, y = self.s.xy(cc, rr)
            z0 = self.s.ground_z(cc, rr)
            kit.frustum("greenery", 0.045, 0.0, 0.28, (x, y, z0 + 0.13), m, verts=5,
                        rot=(rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), 0.0))

    def lily(self, c, r):
        if self.w or self.s.water_y is None:
            return
        kit = self.kit
        x, y = self.s.xy(c, r)
        kit.piece("greenery", x, y, self.s.water_y, motion=self.motion(M_FLOAT))
        kit.cyl("greenery", 0.17, 0.03, (x, y, self.s.water_y + 0.02), self.leaf(2), verts=10)

    def iris(self, c, r, count=5):
        """Water irises on a bank: blade leaves and blue-violet heads."""
        kit, rng = self.kit, self.rng
        x, y = self.s.xy(c, r)
        z0 = self.s.ground_z(c, r)
        kit.piece("greenery", x, y, z0, motion=self.motion(M_SWAY, alive_only=False))
        for _ in range(count):
            px, py = x + rng.uniform(-0.3, 0.3), y + rng.uniform(-0.3, 0.3)
            h = rng.uniform(0.45, 0.7) * (0.7 if self.w else 1.0)
            kit.box("greenery", (0.05, 0.16, h), (px, py, z0 + h / 2), self.mat("reed"),
                    rot=(rng.uniform(-0.2, 0.2), 0.0, rng.uniform(0.0, math.pi)))
            if not self.w:
                kit.sphere("greenery", 0.09, (px, py, z0 + h + 0.05), self.mat("iris"), scale=(1.0, 1.0, 0.7), segments=8, rings=5)

    # --- ground props -------------------------------------------------------------------------

    def stone(self, c, r, radius=0.4, tint=0):
        kit, rng = self.kit, self.rng
        x, y, z0 = self._at("stone", c, r)
        kit.piece("ground", x, y, z0)
        scale = (1.0, rng.uniform(0.7, 0.95), rng.uniform(0.55, 0.75))
        kit.rock("props", radius, (x, y, z0 + radius * scale[2] * 0.62), self.stone_mat(tint),
                 scale=scale, rot=(0.0, 0.0, rng.uniform(0.0, math.pi)))

    def boulder(self, c, r, radius=0.9, dark=False):
        """A big mossy-topped rock: faceted body with a flatter moss cap."""
        kit, rng = self.kit, self.rng
        x, y = self.s.xy(c, r)
        z0 = self.s.ground_z(c, r)
        kit.piece("ground", x, y, z0)
        body = self.mat("boulder_dark" if dark else "boulder")
        kit.rock("props", radius, (x, y, z0 + radius * 0.45), body, scale=(1.0, rng.uniform(0.8, 1.0), 0.72),
                 rot=(0.0, 0.0, rng.uniform(0.0, math.pi)))
        kit.rock("props", radius * 0.6, (x + radius * 0.15, y - radius * 0.1, z0 + radius * 0.95), self.mat("moss"),
                 scale=(1.0, 0.85, 0.35), rot=(0.0, 0.0, rng.uniform(0.0, math.pi)))

    def stepping_stones(self, points):
        flag = self.mat("flag_a")
        for i, (c, r) in enumerate(points):
            x, y = self.s.xy(c, r)
            z = self.s.ground_z(c, r)
            if self.s.cell_at(c, r) == "W" and self.s.water_y is not None:
                z = self.s.water_y + 0.05
            self.kit.piece("ground", x, y, z, extra=0.04 * i)
            self.kit.cyl("props", self.rng.uniform(0.32, 0.42), 0.16, (x, y, z + 0.06), flag, verts=9, bevel=0.03)

    def fence(self, points, post_every=1.0, dark=False):
        kit, rng = self.kit, self.rng
        rail = self.mat("wood_dark" if dark else "wood")
        post = self.mat("timber" if dark else "wood_dark")
        for (c0, r0), (c1, r1) in zip(points[:-1], points[1:]):
            xa, ya = self.s.xy(c0, r0)
            xb, yb = self.s.xy(c1, r1)
            zm = (self.s.ground_z(c0, r0) + self.s.ground_z(c1, r1)) / 2
            kit.piece("ground", (xa + xb) / 2, (ya + yb) / 2, zm)
            length = math.hypot(c1 - c0, r1 - r0)
            n = max(1, int(round(length / post_every)))
            for i in range(n + 1):
                t = i / n
                c, r = c0 + (c1 - c0) * t, r0 + (r1 - r0) * t
                x, y = self.s.xy(c, r)
                z0 = self.s.ground_z(c, r)
                lean = (rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 0.0) if self.w else (0.0, 0.0, 0.0)
                kit.box("props", (0.14, 0.14, 0.78), (x, y, z0 + 0.39), post, bevel=0.02, segments=1, rot=lean)
            ang = math.atan2(yb - ya, xb - xa)
            for zr in (0.30, 0.58):
                if self.w and zr > 0.5 and rng.random() < 0.55:
                    # The top rail has come down and lies in the grass.
                    kit.box("props", (length * 0.8, 0.07, 0.06), ((xa + xb) / 2 + 0.2, (ya + yb) / 2 - 0.25, zm + 0.03), rail,
                            bevel=0.015, segments=1, rot=(0.0, 0.0, ang + 0.35))
                    continue
                kit.box("props", (length + 0.14, 0.07, 0.06), ((xa + xb) / 2, (ya + yb) / 2, zm + zr), rail,
                        bevel=0.015, segments=1, rot=(0.0, 0.0, ang))

    def steps(self, c, r_wall, width=1.7, top_z=0.9, facing=1.0, base_z=0.0, axis="r"):
        """Stone steps down a terrace wall, rising from base_z (the lower terrace) to top_z.
        axis="r": the wall runs along row r_wall, facing=+1 means the lower side is r > r_wall.
        axis="c": the wall runs along column c (r_wall is then the steps' row), facing=+1 means
        the lower side is c > c."""
        kit = self.kit
        x, y = self.s.xy(c, r_wall)
        flag, flag_b = self.mat("flag_a"), self.mat("flag_b")
        rise = top_z - base_z
        count = max(1, int(round(rise / 0.3)) - 1)
        if axis == "r":
            kit.piece("ground", x, y - 0.6 * facing, base_z)
        else:
            kit.piece("ground", x + 0.6 * facing, y, base_z)
        for k in range(count):
            h = rise - 0.3 * (k + 1)
            if h <= 0.0:
                break
            m = flag if k % 2 == 0 else flag_b
            if axis == "r":
                kit.box("props", (width, 0.57, h), (x, y - facing * 0.55 * (k + 0.5), base_z + h / 2), m, bevel=0.025, segments=1)
            else:
                kit.box("props", (0.57, width, h), (x + facing * 0.55 * (k + 0.5), y, base_z + h / 2), m, bevel=0.025, segments=1)
        land = 0.55 * count + 0.35
        if axis == "r":
            kit.box("props", (width + 0.3, 0.7, 0.08), (x, y - facing * land, base_z + 0.04), flag, bevel=0.02, segments=1)
        else:
            kit.box("props", (0.7, width + 0.3, 0.08), (x + facing * land, y, base_z + 0.04), flag, bevel=0.02, segments=1)

    def plaza(self, c, r, radius=2.4, with_bath=True):
        kit, rng = self.kit, self.rng
        self.s.check_on_land("plaza", c, r)
        flag, flag_b = self.mat("flag_a"), self.mat("flag_b")
        rings = ((0.72, 8), (1.24, 13), (1.76, 18), (2.28, 23))
        for ring_i, (ring, count) in enumerate(rings):
            if ring > radius:
                break
            for i in range(count):
                a = (i + rng.uniform(-0.12, 0.12)) / count * math.tau + ring
                rr = ring + rng.uniform(-0.06, 0.06)
                cc, rrow = c + math.cos(a) * rr, r + math.sin(a) * rr
                x, y = self.s.xy(cc, rrow)
                z = self.s.ground_z(cc, rrow)
                kit.piece("ground", x, y, z, extra=0.06 * ring_i)
                kit.box("props", (rng.uniform(0.50, 0.62), rng.uniform(0.40, 0.48), 0.06), (x, y, z + 0.03),
                        flag if rng.random() < 0.6 else flag_b, bevel=0.02, segments=1, rot=(0.0, 0.0, -a))
                if self.w and rng.random() < 0.18:
                    # weeds between the flags
                    self.tuft(cc + rng.uniform(-0.2, 0.2), rrow + rng.uniform(-0.2, 0.2))
        if with_bath:
            self.birdbath(c, r)

    def birdbath(self, c, r):
        kit = self.kit
        x, y, z0 = self._at("birdbath", c, r)
        kit.piece("prop", x, y, z0)
        stone = self.stone_mat(0)
        kit.cyl("props", 0.34, 0.10, (x, y, z0 + 0.05), stone, verts=12, bevel=0.02)
        kit.cyl("props", 0.16, 0.55, (x, y, z0 + 0.32), stone, verts=10)
        kit.cyl("props", 0.55, 0.16, (x, y, z0 + 0.66), stone, verts=14, bevel=0.03)
        kit.cyl("props", 0.46, 0.04, (x, y, z0 + 0.735), self.mat("mud" if self.w else "still_water"), verts=14)

    def bench(self, c, r, angle=0.0):
        kit = self.kit
        x, y, z0 = self._at("bench", c, r)
        kit.piece("prop", x, y, z0)
        wood, dark = self.mat("wood"), self.mat("wood_dark")
        rot = (0.0, 0.0, angle) if not self.w else (0.0, 0.16, angle)
        ca, sa = math.cos(angle), math.sin(angle)
        kit.box("props", (1.2, 0.38, 0.08), (x, y, z0 + 0.42 - (0.05 if self.w else 0.0)), wood, bevel=0.015, segments=1, rot=rot)
        for s in (-0.5, 0.5):
            if self.w and s > 0:
                continue   # one leg gone, the bench sags
            kit.box("props", (0.08, 0.34, 0.40), (x + s * ca, y + s * sa, z0 + 0.20), dark, rot=(0.0, 0.0, angle))
        kit.box("props", (1.2, 0.06, 0.34), (x - sa * 0.17, y + ca * 0.17, z0 + 0.70 - (0.06 if self.w else 0.0)), wood,
                bevel=0.015, segments=1, rot=rot)

    def veg_bed(self, c, r, w=2.4, d=1.4, sprout_key="sprout"):
        kit, rng = self.kit, self.rng
        x, y, z0 = self._at("veg bed", c, r)
        kit.piece("prop", x, y, z0)
        dark = self.mat("wood_dark")
        kit.box("props", (w, 0.12, 0.26), (x, y - d / 2, z0 + 0.13), dark, bevel=0.015, segments=1)
        kit.box("props", (w, 0.12, 0.26), (x, y + d / 2, z0 + 0.13), dark, bevel=0.015, segments=1)
        kit.box("props", (0.12, d, 0.26), (x - w / 2, y, z0 + 0.13), dark, bevel=0.015, segments=1)
        kit.box("props", (0.12, d, 0.26), (x + w / 2, y, z0 + 0.13), dark, bevel=0.015, segments=1)
        kit.box("props", (w - 0.16, d - 0.16, 0.16), (x, y, z0 + 0.12), self.mat("soil"))
        kit.piece("greenery", x, y, z0 + 0.2, motion=self.motion(M_SWAY, alive_only=False))
        if self.w:
            for _ in range(5):
                px, py = x + rng.uniform(-w * 0.4, w * 0.4), y + rng.uniform(-d * 0.35, d * 0.35)
                kit.cyl("greenery", 0.02, 0.3, (px, py, z0 + 0.34), self.mat("reed"), verts=4, rot=(rng.uniform(-0.4, 0.4), 0.0, 0.0))
            return
        sprout = self.mat(sprout_key)
        for i in range(5):
            for j in range(3):
                px = x - w / 2 + 0.36 + i * (w - 0.72) / 4
                py = y - d / 2 + 0.34 + j * (d - 0.68) / 2
                kit.sphere("greenery", 0.11, (px, py, z0 + 0.24), sprout, scale=(1.0, 1.0, 0.8), segments=8, rings=5)

    def crates(self, c, r, count=3, fruit=True):
        kit = self.kit
        x, y, z0 = self._at("crates", c, r)
        kit.piece("prop", x, y, z0)
        dark, wood = self.mat("wood_dark"), self.mat("wood")
        spots = ((0.0, 0.0, 0.26, 0.1), (0.0, 0.0, 0.78, -0.15), (0.62, 0.15, 0.26, 0.35))[:count]
        for k, (dx, dy, dz, ang) in enumerate(spots):
            if self.w and k == 1:
                # the top crate has fallen off and lies open beside the stack
                kit.box("props", (0.52, 0.52, 0.5), (x - 0.7, y + 0.3, z0 + 0.22), dark, bevel=0.02, segments=1, rot=(0.25, 0.0, 0.7))
                continue
            kit.box("props", (0.52, 0.52, 0.5), (x + dx, y + dy, z0 + dz), dark, bevel=0.02, segments=1, rot=(0.0, 0.0, ang))
            if not self.w:
                for s in (-0.18, 0.18):
                    kit.box("props", (0.56, 0.56, 0.07), (x + dx, y + dy, z0 + dz + s), wood, rot=(0.0, 0.0, ang))
        if fruit and count >= 2 and not self.w:
            fm = self.mat("fruit_a")
            for k in range(5):
                a = k / 5 * math.tau
                kit.sphere("props", 0.11, (x + math.cos(a) * 0.14, y + math.sin(a) * 0.14, z0 + 1.08), fm, segments=9, rings=6)

    def barrels(self, c, r, count=2):
        kit, rng = self.kit, self.rng
        x, y, z0 = self._at("barrels", c, r)
        kit.piece("prop", x, y, z0)
        for i in range(count):
            px, py = x + i * 0.62, y + (0.2 if i % 2 else -0.1)
            if self.w and i == count - 1:
                # the last barrel lies on its side
                kit.cyl("props", 0.28, 0.66, (px + 0.1, py - 0.2, z0 + 0.28), self.mat("wood_dark"), verts=12, bevel=0.04,
                        rot=(math.pi / 2, 0.0, 0.4))
                continue
            kit.cyl("props", 0.28, 0.66, (px, py, z0 + 0.33), self.mat("wood_dark"), verts=12, bevel=0.04)
            for zz in (0.14, 0.52):
                kit.cyl("props", 0.295, 0.05, (px, py, z0 + zz), self.mat("iron"), verts=12)

    def ladder(self, c, r, angle_to_tree, tilt=0.35, length=2.0):
        kit = self.kit
        x, y, z0 = self._at("ladder", c, r)
        kit.piece("prop", x, y, z0)
        wood = self.mat("wood")
        if self.w:
            # the ladder lies flat in the grass
            kit.box("props", (length, 0.5, 0.06), (x, y, z0 + 0.04), wood, rot=(0.0, 0.0, angle_to_tree + 0.5))
            for k in range(6):
                t = (k + 0.5) / 6 - 0.5
                kit.box("props", (0.05, 0.5, 0.08), (x + math.cos(angle_to_tree + 0.5) * t * length, y + math.sin(angle_to_tree + 0.5) * t * length, z0 + 0.05),
                        wood, rot=(0.0, 0.0, angle_to_tree + 0.5))
            return
        ca, sa = math.cos(angle_to_tree), math.sin(angle_to_tree)
        zc = z0 + length / 2 * math.cos(tilt)
        off = length / 2 * math.sin(tilt)
        for s in (-0.22, 0.22):
            kit.box("props", (0.06, 0.06, length), (x + ca * off + (-sa) * s, y + sa * off + ca * s, zc), wood,
                    rot=(tilt * sa, -tilt * ca, 0.0))
        for k in range(6):
            t = (k + 0.5) / 6 - 0.5
            kit.box("props", (0.05, 0.50, 0.05),
                    (x + ca * (off + t * length * math.sin(tilt)), y + sa * (off + t * length * math.sin(tilt)),
                     z0 + (t + 0.5) * length * math.cos(tilt)), wood, rot=(tilt * sa, -tilt * ca, angle_to_tree))

    def woodpile(self, c, r):
        kit = self.kit
        x, y, z0 = self._at("woodpile", c, r)
        kit.piece("prop", x, y, z0)
        bark = self.mat("trunk")
        logs = ((-0.28, 0.14), (0.0, 0.14), (0.28, 0.14), (-0.14, 0.38), (0.14, 0.38), (0.0, 0.62))
        for (dx, dz) in (logs[:4] if self.w else logs):
            kit.cyl("props", 0.13, 0.95, (x + dx, y, z0 + dz), bark, verts=8, rot=(math.pi / 2, 0.0, 0.0))

    def haystack(self, c, r, size=1.0):
        kit = self.kit
        x, y, z0 = self._at("haystack", c, r)
        kit.piece("prop", x, y, z0)
        hay = self.mat("hay")
        if self.w:
            kit.sphere("props", 0.78 * size, (x, y, z0 + 0.36 * size), hay, scale=(1.05, 1.0, 0.5), segments=14, rings=9)
            return
        kit.sphere("props", 0.78 * size, (x, y, z0 + 0.58 * size), hay, scale=(1.0, 1.0, 0.82), segments=14, rings=9)
        kit.sphere("props", 0.45 * size, (x, y, z0 + 1.18 * size), hay, scale=(1.0, 1.0, 0.9), segments=12, rings=8)
        kit.cyl("props", 0.03, 0.55 * size, (x, y, z0 + 1.45 * size), self.mat("trunk"), verts=6)

    def hay_bale(self, c, r, angle=0.0):
        kit = self.kit
        x, y, z0 = self._at("hay bale", c, r)
        kit.piece("prop", x, y, z0)
        kit.box("props", (0.9, 0.55, 0.5), (x, y, z0 + 0.25), self.mat("hay"), bevel=0.06, segments=2, rot=(0.0, 0.0, angle))
        for s in (-0.25, 0.25):
            kit.box("props", (0.06, 0.58, 0.53), (x + s * math.cos(angle), y + s * math.sin(angle), z0 + 0.25),
                    self.mat("rope"), rot=(0.0, 0.0, angle))

    def sheaf(self, c, r):
        """A bundle of wheat stood on end: a tied cylinder with a flared golden top."""
        kit, rng = self.kit, self.rng
        x, y, z0 = self._at("sheaf", c, r)
        kit.piece("prop", x, y, z0)
        if self.w and rng.random() < 0.5:
            a = rng.uniform(0.0, math.tau)
            kit.frustum("props", 0.26, 0.16, 0.8, (x + math.cos(a) * 0.35, y + math.sin(a) * 0.35, z0 + 0.2), self.mat("wheat"), verts=10,
                        rot=(-1.35 * math.sin(a), 1.35 * math.cos(a), 0.0))
            return
        kit.frustum("props", 0.26, 0.16, 0.8, (x, y, z0 + 0.4), self.mat("wheat"), verts=10)
        kit.frustum("props", 0.16, 0.34, 0.5, (x, y, z0 + 1.05), self.mat("wheat_dark"), verts=10)
        kit.cyl("props", 0.19, 0.08, (x, y, z0 + 0.72), self.mat("rope"), verts=10)

    def scarecrow(self, c, r, heading=0.3):
        kit = self.kit
        x, y, z0 = self._at("scarecrow", c, r)
        kit.piece("prop", x, y, z0)
        lean = 0.45 if self.w else 0.0
        rot = (lean, 0.0, heading)
        ca, sa = math.cos(heading), math.sin(heading)
        kit.cyl("props", 0.05, 1.7, (x, y - lean * 0.6, z0 + 0.85 * math.cos(lean)), self.mat("wood_dark"), verts=6, rot=rot)
        kit.box("props", (1.2, 0.07, 0.07), (x, y - lean * 0.95, z0 + 1.32 * math.cos(lean)), self.mat("wood_dark"), rot=(lean, 0.0, heading + (0.4 if self.w else 0.0)))
        kit.box("props", (0.5, 0.3, 0.6), (x, y - lean * 0.85, z0 + 1.15 * math.cos(lean)), self.mat("barn"), bevel=0.04, segments=1, rot=rot)
        if self.w:
            return
        kit.sphere("props", 0.2, (x, y, z0 + 1.68), self.mat("hay"), segments=10, rings=7)
        kit.frustum("props", 0.34, 0.14, 0.26, (x, y, z0 + 1.9), self.mat("wood_dark"), verts=10)
        kit.cyl("props", 0.34, 0.03, (x, y, z0 + 1.78), self.mat("wood_dark"), verts=10)
        kit.box("props", (0.16, 0.12, 0.14), (x + ca * 0.02, y + sa * 0.02, z0 + 1.15), self.mat("beak"), rot=rot)

    def cart(self, c, r, angle=0.0, load="hay"):
        kit = self.kit
        x, y, z0 = self._at("cart", c, r)
        kit.piece("prop", x, y, z0)
        wood, dark = self.mat("wood"), self.mat("wood_dark")
        ca, sa = math.cos(angle), math.sin(angle)
        if self.w:
            # Tipped onto its side, one wheel off and lying nearby.
            rot = (1.15, 0.0, angle)
            kit.box("props", (1.6, 0.9, 0.12), (x, y, z0 + 0.42), wood, bevel=0.02, segments=1, rot=rot)
            for s in (-0.45, 0.45):
                kit.box("props", (1.6, 0.06, 0.34), (x + sa * s * 0.4, y - ca * s * 0.4, z0 + 0.42 + s * 0.9), wood, rot=rot)
            for sx in (-0.5, 0.5):
                kit.cyl("props", 0.28, 0.1, (x + ca * sx - sa * 0.55, y + sa * sx + ca * 0.55, z0 + 0.28), dark, verts=12, rot=(math.pi / 2, 0.0, angle))
            kit.cyl("props", 0.28, 0.1, (x + ca * 1.1 + sa * 0.5, y + sa * 1.1 - ca * 0.5, z0 + 0.06), dark, verts=12, rot=(0.0, 0.0, angle))
            kit.box("props", (0.9, 0.07, 0.07), (x + ca * 1.15, y + sa * 1.15, z0 + 0.1), dark, rot=(0.0, 0.1, angle))
            return
        rot = (0.0, 0.0, angle)
        kit.box("props", (1.6, 0.9, 0.12), (x, y, z0 + 0.46), wood, bevel=0.02, segments=1, rot=rot)
        for s in (-0.45, 0.45):
            kit.box("props", (1.6, 0.06, 0.34), (x - sa * s, y + ca * s, z0 + 0.69), wood, rot=rot)
        for sx in (-0.5, 0.5):
            for sy in (-0.5, 0.5):
                px, py = x + ca * sx - sa * sy, y + sa * sx + ca * sy
                kit.cyl("props", 0.28, 0.1, (px, py, z0 + 0.28), dark, verts=12, rot=(math.pi / 2, 0.0, angle))
        kit.box("props", (0.9, 0.07, 0.07), (x + ca * 1.15, y + sa * 1.15, z0 + 0.5), dark, rot=(0.0, -0.25, angle))
        if load == "hay":
            kit.sphere("props", 0.55, (x, y, z0 + 0.95), self.mat("hay"), scale=(1.4, 0.8, 0.7), segments=12, rings=8, rot=rot)
        elif load == "crates":
            kit.box("props", (0.5, 0.5, 0.45), (x - ca * 0.3, y - sa * 0.3, z0 + 0.75), dark, bevel=0.02, segments=1, rot=rot)
            kit.box("props", (0.4, 0.4, 0.36), (x + ca * 0.35, y + sa * 0.35, z0 + 0.7), dark, bevel=0.02, segments=1, rot=rot)

    def signpost(self, c, r, color="green", facing=0.0):
        kit = self.kit
        x, y, z0 = self._at("signpost", c, r)
        kit.piece("prop", x, y, z0)
        wood = self.mat("wood_dark")
        lean = (0.32, 0.0, 0.0) if self.w else (0.0, 0.0, 0.0)
        kit.box("props", (0.10, 0.10, 1.05), (x, y - (0.16 if self.w else 0.0), z0 + 0.52 * math.cos(lean[0])), wood, bevel=0.015, segments=1, rot=lean)
        rot = (lean[0], 0.45 if self.w else 0.0, facing)
        ca, sa = math.cos(facing), math.sin(facing)
        board = self.mat("sign_green" if color == "green" else "sign_orange")
        top = z0 + (0.82 if self.w else 0.98)
        by = y - (0.32 if self.w else 0.0)
        kit.box("props", (0.62, 0.08, 0.44), (x - sa * 0.07, by + ca * 0.07, top), board, bevel=0.02, segments=1, rot=rot)
        kit.box("props", (0.46, 0.03, 0.30), (x - sa * 0.13, by + ca * 0.13, top), self.mat("sign_face"), rot=rot)
        kit.sphere("props", 0.07, (x - sa * 0.16, by + ca * 0.16, top + 0.02), board, segments=8, rings=5)

    def lantern_post(self, c, r, height=1.9, lit=True):
        """Iron post with a warm lantern: the accent light of dusk and village scenes. Withered: out."""
        kit = self.kit
        x, y, z0 = self._at("lantern", c, r)
        kit.piece("prop", x, y, z0)
        iron = self.mat("iron")
        lit = lit and not self.w
        kit.cyl("props", 0.05, height, (x, y, z0 + height / 2), iron, verts=8)
        kit.cyl("props", 0.14, 0.08, (x, y, z0 + 0.04), iron, verts=10)
        kit.box("props", (0.3, 0.3, 0.36), (x, y, z0 + height + 0.15), self.mat("lantern" if lit else "glass"), bevel=0.03, segments=1)
        kit.frustum("props", 0.26, 0.05, 0.16, (x, y, z0 + height + 0.41), iron, verts=4, rot=(0.0, 0.0, math.radians(45)))
        for s in (-1.0, 1.0):
            kit.box("props", (0.03, 0.34, 0.36), (x + s * 0.15, y, z0 + height + 0.15), iron)
            kit.box("props", (0.34, 0.03, 0.36), (x, y + s * 0.15, z0 + height + 0.15), iron)

    def foam(self, c, r, z, count=4, spread=0.45):
        if self.w:
            return
        kit, rng = self.kit, self.rng
        x, y = self.s.xy(c, r)
        kit.piece("foam", x, y, z, motion=self.motion(M_FLOAT))
        m = self.mat("foam")
        for i in range(count):
            t = (i + 0.5) / count - 0.5
            kit.box("props", (rng.uniform(0.18, 0.28), rng.uniform(0.16, 0.24), rng.uniform(0.10, 0.16)),
                    (x + t * spread * 2, y + rng.uniform(-0.06, 0.06), z), m, bevel=0.05, segments=2)

    def koi(self, c, r, count=4):
        """Orange fish just under the water, each slowly circling its own spot."""
        if self.w or self.s.water_y is None:
            return
        kit, rng = self.kit, self.rng
        x, y = self.s.xy(c, r)
        z = self.s.water_y - 0.08
        for _ in range(count):
            cx, cy = x + rng.uniform(-0.45, 0.45), y + rng.uniform(-0.45, 0.45)
            kit.piece("greenery", cx, cy, z, motion=(M_SWIM, rng.random()))
            kit.sphere("props", 0.11, (cx + 0.3, cy, z), self.mat("koi"), scale=(0.7, 1.8, 0.5), segments=8, rings=5)

    # --- birds ----------------------------------------------------------------------------------

    def _bird(self, x, y, z0, heading, size, body, wings=False):
        kit = self.kit
        ca, sa = math.cos(heading), math.sin(heading)
        s_ = size
        kit.sphere("props", 0.15 * s_, (x, y, z0 + 0.15 * s_), body, scale=(1.25, 0.95, 0.9), segments=12, rings=8,
                   rot=(0.0, 0.0, heading))
        hx, hy = x + ca * 0.16 * s_, y + sa * 0.16 * s_
        kit.sphere("props", 0.09 * s_, (hx, hy, z0 + 0.27 * s_), body, segments=10, rings=7)
        kit.frustum("props", 0.03 * s_, 0.0, 0.09 * s_, (hx + ca * 0.11 * s_, hy + sa * 0.11 * s_, z0 + 0.26 * s_),
                    self.mat("beak"), verts=6, rot=(0.0, math.pi / 2, heading))
        for s in (-1.0, 1.0):
            kit.sphere("props", 0.02 * s_, (hx + ca * 0.05 * s_ - sa * s * 0.07 * s_, hy + sa * 0.05 * s_ + ca * s * 0.07 * s_,
                                           z0 + 0.30 * s_), self.mat("eye"), segments=6, rings=4)
        kit.box("props", (0.22 * s_, 0.14 * s_, 0.04 * s_), (x - ca * 0.2 * s_, y - sa * 0.2 * s_, z0 + 0.14 * s_), body,
                bevel=0.01, segments=1, rot=(0.0, -0.35, heading))
        if wings:
            for s in (-1.0, 1.0):
                kit.box("props", (0.16 * s_, 0.42 * s_, 0.03 * s_), (x - sa * s * 0.28 * s_, y + ca * s * 0.28 * s_, z0 + 0.2 * s_), body,
                        bevel=0.01, segments=1, rot=(s * 0.35, 0.0, heading))

    def dove(self, c, r, z_off=0.0, heading=0.0, size=1.4, body_key="dove"):
        """A perched dove (nods and turns a little). Withered: the doves are gone; the first call
        leaves one crow behind, the rest place nothing."""
        kit = self.kit
        x, y = self.s.xy(c, r)
        z0 = self.s.ground_z(c, r) + z_off
        if self.w:
            if self._crow_placed:
                return
            self._crow_placed = True
            body_key = "crow"
            size *= 0.95
        kit.piece("dove", x, y, z0, motion=(M_PERCH, self.rng.random()))
        self._bird(x, y, z0, heading, size, self.mat(body_key))

    def flying_doves(self, c, r, height=4.5, radius=3.0, count=3, size=1.3):
        """Doves wheeling in a slow circle above (c, r); alive stages only."""
        if self.w:
            return
        kit = self.kit
        x, y = self.s.xy(c, r)
        z = self.s.ground_z(c, r) + height
        for i in range(count):
            kit.piece("dove", x, y, z, extra=0.05 * i, motion=(M_FLY, i / count))
            self._bird(x + radius, y, z + 0.2 * i, math.pi / 2, size, self.mat("dove"), wings=True)

    def smoke(self, x, y, z, count=3):
        """Chimney smoke: puffs that rise, swell and thin out (shader), alive stages only. Blender coords."""
        if self.w:
            return
        kit = self.kit
        m = self.mat("smoke")
        for i in range(count):
            kit.piece("prop", x, y, z, extra=0.3, motion=(M_SMOKE, i / count))
            kit.sphere("props", 0.17 + 0.04 * i, (x, y, z), m, segments=8, rings=6)

    def birdhouse(self, c, r):
        kit = self.kit
        x, y, z0 = self._at("birdhouse", c, r)
        kit.piece("prop", x, y, z0)
        lean = (0.0, 0.26, 0.0) if self.w else (0.0, 0.0, 0.0)
        kit.cyl("props", 0.05, 1.75, (x + (0.22 if self.w else 0.0), y, z0 + 0.875), self.mat("wood_dark"), verts=8, rot=lean)
        top = (x + (0.44 if self.w else 0.0), y, z0 + 1.92 - (0.06 if self.w else 0.0))
        kit.box("props", (0.38, 0.34, 0.38), top, self.mat("wall"), bevel=0.02, segments=1, rot=lean)
        for s in (-1.0, 1.0):
            kit.box("props", (0.46, 0.24, 0.05), (top[0], y + s * 0.11, top[2] + 0.24), self.mat("roof_a"),
                    bevel=0.01, segments=1, rot=(s * 0.7, lean[1], 0.0))
        kit.cyl("props", 0.06, 0.03, (top[0], y - 0.18, top[2] + 0.04), self.mat("eye"), verts=10, rot=(math.pi / 2, 0.0, 0.0))
        kit.cyl("props", 0.015, 0.16, (top[0], y - 0.24, top[2] - 0.1), self.mat("wood"), verts=6, rot=(math.pi / 2, 0.0, 0.0))

    def dovecote(self, c, r):
        kit = self.kit
        x, y, z0 = self._at("dovecote", c, r)
        kit.piece("building", x, y, z0)
        wall = self.mat("wall")
        kit.cyl("buildings", 0.72, 0.14, (x, y, z0 + 0.07), self.stone_mat(1), verts=12)
        kit.cyl("buildings", 0.62, 2.4, (x, y, z0 + 1.34), wall, verts=12, bevel=0.03)
        for k, zh in enumerate((1.25, 1.85)):
            for i in range(4):
                a = (i + 0.5 * k) / 4 * math.tau + 0.4
                hx, hy = x + math.cos(a) * 0.62, y + math.sin(a) * 0.62
                kit.cyl("buildings", 0.075, 0.04, (hx, hy, z0 + zh), self.mat("eye"), verts=10, rot=(math.pi / 2, 0.0, a + math.pi / 2))
                if self.w and (i + k) % 2 == 0:
                    continue   # perches broken off
                kit.box("buildings", (0.16, 0.26, 0.04), (x + math.cos(a) * 0.68, y + math.sin(a) * 0.68, z0 + zh - 0.13),
                        self.mat("wood"), rot=(0.0, 0.0, a))
        kit.piece("roof", x, y, z0 + 2.5)
        tilt = (0.12, 0.0, 0.0) if self.w else (0.0, 0.0, 0.0)
        kit.cyl("buildings", 0.70, 0.10, (x, y, z0 + 2.58), self.mat("wood_dark"), verts=12)
        kit.frustum("buildings", 0.86, 0.05, 0.85, (x, y - (0.08 if self.w else 0.0), z0 + 3.05), self.mat("roof_a"), verts=12, rot=tilt)
        if not self.w:
            kit.sphere("buildings", 0.09, (x, y, z0 + 3.52), self.mat("ridge"), segments=8, rings=5)
            self.dove(c + 0.66, r + 0.16, z_off=1.14, heading=math.radians(15))
            self.dove(c - 0.62, r - 0.3, z_off=1.74, heading=math.radians(200))

    # --- buildings ------------------------------------------------------------------------------

    def cottage(self, c, r, w=5.0, d=3.6, wall_h=2.3, rise=1.6, over=0.34, roof="tiles", chimney=True,
                windows_side=True, door_key="door", wall_key="wall"):
        """Gabled house facing the front (+r); ridge along X. Roof styles: tiles / slate / thatch.
        Two entrance pieces: walls with door and windows first, then the roof. Withered: boarded
        windows, no flower boxes, missing tiles, ivy up the walls, no smoke."""
        kit = self.kit
        x, y, z0 = self._at("cottage", c, r)
        wall, trim = self.mat(wall_key), self.mat("trim")
        apex = z0 + wall_h + rise
        kit.piece("building", x, y, z0)
        kit.box("buildings", (w, d, wall_h), (x, y, z0 + wall_h / 2), wall, bevel=0.03, segments=1)
        gable = [(y - d / 2, z0 + wall_h - 0.02), (y + d / 2, z0 + wall_h - 0.02), (y, apex - 0.02)]
        kit.prism("buildings", gable, x - w / 2, x + w / 2, wall)
        fy = y - d / 2
        kit.box("buildings", (1.02, 0.06, 1.82), (x, fy - 0.03, z0 + 0.91), trim, bevel=0.01, segments=1)
        if self.w:
            kit.box("buildings", (0.88, 0.08, 1.70), (x, fy - 0.06, z0 + 0.85), self.mat("timber"), bevel=0.015, segments=1,
                    rot=(0.0, 0.0, 0.0))
            self._boards(x, fy, z0 + 1.0, 0.9, 1.5)
        else:
            kit.box("buildings", (0.88, 0.08, 1.70), (x, fy - 0.06, z0 + 0.85), self.mat(door_key), bevel=0.015, segments=1)
            kit.sphere("buildings", 0.045, (x + 0.28, fy - 0.11, z0 + 0.92), self.mat("beak"), segments=8, rings=5)
        kit.box("buildings", (1.35, 0.55, 0.12), (x, fy - 0.30, z0 + 0.06), self.mat("flag_a"), bevel=0.02, segments=1)
        for wx in (x - w * 0.31, x + w * 0.31):
            self._window((wx, fy, z0 + wall_h * 0.59), facing="-y")
        if windows_side:
            self._window((x - w / 2, y + 0.1, z0 + wall_h * 0.56), facing="-x")
            self._window((x + w / 2, y + 0.1, z0 + wall_h * 0.56), facing="+x")
        if self.w:
            self._ivy(x, fy, z0, w, facing="-y")
            self._ivy(x + w / 2, y, z0, d, facing="+x")
        self._roof(x, y, z0, w, d, wall_h, rise, over, roof, chimney)

    def _roof(self, x, y, z0, w, d, wall_h, rise, over, style, chimney):
        kit, rng = self.kit, self.rng
        apex = z0 + wall_h + rise
        bed_lo = z0 + wall_h - 0.12
        kit.piece("roof", x, y, bed_lo)
        bed_key = {"tiles": "roof_bed", "slate": "slate_dark", "thatch": "thatch_dark", "navy": "hull_trim"}[style]
        roof_profile = [(y - d / 2 - over, bed_lo), (y + d / 2 + over, bed_lo), (y + d / 2 + over, bed_lo + 0.16),
                        (y, apex + 0.10), (y - d / 2 - over, bed_lo + 0.16)]
        kit.prism("buildings", roof_profile, x - w / 2 - 0.22, x + w / 2 + 0.22, self.mat(bed_key), flat=True)
        slope_len = math.hypot(d / 2 + over, rise - 0.06)
        ang = math.atan2(rise - 0.06, d / 2 + over)
        if style == "tiles":
            tile_w, tile_l, step_l, step_w = 0.30, 0.24, 0.20, 0.31
            tints = [self.mat("roof_a"), self.mat("roof_b"), self.mat("roof_c")]
        elif style == "slate":
            tile_w, tile_l, step_l, step_w = 0.42, 0.30, 0.26, 0.44
            tints = [self.mat("slate"), self.mat("slate_dark"), self.mat("slate")]
        else:
            tile_w = tile_l = step_l = step_w = 0.0
            tints = []
        if tints:
            n_rows = int(slope_len / step_l)
            n_cols = int((w + 0.44) / step_w) + 1
            for side in (-1.0, 1.0):
                for i in range(n_rows):
                    t = (i + 0.5) * step_l
                    for j in range(n_cols):
                        jx = x - (w + 0.44) / 2 + (j + (0.5 if i % 2 else 0.0)) * step_w
                        if jx < x - w / 2 - 0.20 or jx > x + w / 2 + 0.20:
                            continue
                        if self.w and rng.random() < 0.16:
                            continue   # tiles slipped off, the dark bed shows through
                        along = side * (d / 2 + over - t * math.cos(ang))
                        up = bed_lo + 0.16 + t * math.sin(ang) + 0.03
                        pick = (i + j) % 2 if rng.random() > 0.15 else 2
                        kit.box("buildings", (tile_w, tile_l, 0.06), (jx, y + along, up), tints[pick],
                                bevel=0.012, segments=1, rot=(-side * ang, 0.0, 0.0))
        elif style == "thatch":
            for side in (-1.0, 1.0):
                cy = y + side * (d / 2 + over) * 0.5
                sag = 0.12 if self.w else 0.0
                kit.box("buildings", (w + 0.5, slope_len * 0.98, 0.34 - sag), (x, cy, bed_lo + 0.16 + rise * 0.5 + 0.1 - sag),
                        self.mat("thatch"), bevel=0.12, segments=3, rot=(-side * ang - side * sag * 0.6, 0.0, 0.0))
        elif style == "navy":
            for side in (-1.0, 1.0):
                cy = y + side * (d / 2 + over) * 0.5
                length = w + 0.46
                cx = x
                if self.w and side > 0:
                    # A sheet of the roofing has blown off the back slope.
                    length *= 0.62
                    cx = x - (w + 0.46) * 0.19
                kit.box("buildings", (length, slope_len * 0.98, 0.14), (cx, cy, bed_lo + 0.16 + rise * 0.5 + 0.02),
                        self.mat("hull_trim"), bevel=0.03, segments=1, rot=(-side * ang, 0.0, 0.0))
        ridge_key = {"tiles": "ridge", "slate": "slate_dark", "thatch": "thatch_dark", "navy": "hull_trim"}[style]
        kit.box("buildings", (w + 0.40, 0.30, 0.13), (x, y, apex + (0.28 if style == "thatch" else 0.13)),
                self.mat(ridge_key), bevel=0.03, segments=1)
        if chimney:
            cx, cy = x + w * 0.27, y + d * 0.18
            kit.box("buildings", (0.52, 0.52, 1.05), (cx, cy, apex - 0.05), self.mat("chimney"), bevel=0.02, segments=1)
            if self.w:
                # the cap has fallen and a course of bricks with it
                kit.box("buildings", (0.64, 0.64, 0.12), (cx + 0.9, cy - 0.3, z0 + 0.06), self.mat("chimney_cap"), bevel=0.02, segments=1,
                        rot=(0.0, 0.0, 0.6))
            else:
                kit.box("buildings", (0.64, 0.64, 0.12), (cx, cy, apex + 0.5), self.mat("chimney_cap"), bevel=0.02, segments=1)
                self.smoke(cx, cy, apex + 0.62)

    def _window(self, pos, facing="-y", flower_box=True):
        kit = self.kit
        x, y, z = pos
        trim, glass, shutter, wood = self.mat("trim"), self.mat("glass"), self.mat("shutter"), self.mat("wood")
        flowers = self.pal["flowers"]
        if facing == "-y":
            kit.box("buildings", (0.74, 0.06, 0.74), (x, y - 0.03, z), trim, bevel=0.01, segments=1)
            kit.box("buildings", (0.58, 0.04, 0.58), (x, y - 0.06, z), self.mat("iron") if self.w else glass)
            if self.w:
                self._boards(x, y, z, 0.6, 0.6, facing)
                return
            kit.box("buildings", (0.06, 0.03, 0.58), (x, y - 0.08, z), trim)
            kit.box("buildings", (0.58, 0.03, 0.06), (x, y - 0.08, z), trim)
            for s in (-1.0, 1.0):
                kit.box("buildings", (0.22, 0.05, 0.74), (x + s * 0.50, y - 0.03, z), shutter, bevel=0.01, segments=1)
            if flower_box:
                kit.box("buildings", (0.82, 0.24, 0.16), (x, y - 0.14, z - 0.47), wood, bevel=0.02, segments=1)
                for i in range(3):
                    col = flowers[i % len(flowers)]
                    kit.sphere("buildings", 0.08, (x - 0.22 + i * 0.22, y - 0.16, z - 0.33), kit.mat(f"fl{i}", col), segments=8, rings=5)
        else:
            s = -1.0 if facing == "-x" else 1.0
            kit.box("buildings", (0.06, 0.74, 0.74), (x + s * 0.03, y, z), trim, bevel=0.01, segments=1)
            kit.box("buildings", (0.04, 0.58, 0.58), (x + s * 0.06, y, z), self.mat("iron") if self.w else glass)
            if self.w:
                self._boards(x, y, z, 0.6, 0.6, facing)
                return
            kit.box("buildings", (0.03, 0.06, 0.58), (x + s * 0.08, y, z), trim)
            kit.box("buildings", (0.03, 0.58, 0.06), (x + s * 0.08, y, z), trim)
            for t in (-1.0, 1.0):
                kit.box("buildings", (0.05, 0.22, 0.74), (x + s * 0.03, y + t * 0.50, z), shutter, bevel=0.01, segments=1)

    def barn(self, c, r, w=6.0, d=4.2, wall_h=2.6, rise=1.7):
        """Red barn with white trim, big front doors and a hayloft window; dark roof."""
        kit = self.kit
        x, y, z0 = self._at("barn", c, r)
        kit.piece("building", x, y, z0)
        red, trim = self.mat("barn"), self.mat("barn_trim")
        kit.box("buildings", (w, d, wall_h), (x, y, z0 + wall_h / 2), red, bevel=0.03, segments=1)
        apex = z0 + wall_h + rise
        gable = [(y - d / 2, z0 + wall_h - 0.02), (y + d / 2, z0 + wall_h - 0.02), (y, apex - 0.02)]
        kit.prism("buildings", gable, x - w / 2, x + w / 2, red)
        fy = y - d / 2
        for sx in (-1.0, 1.0):
            kit.box("buildings", (0.14, 0.1, wall_h), (x + sx * (w / 2 - 0.05), fy - 0.02, z0 + wall_h / 2), trim)
        kit.box("buildings", (2.0, 0.08, 2.0), (x, fy - 0.05, z0 + 1.0), trim, bevel=0.01, segments=1)
        if self.w:
            # One door hangs open on its hinge, the other is gone: dark inside.
            kit.box("buildings", (1.8, 0.06, 1.85), (x, fy - 0.09, z0 + 0.95), self.mat("iron"))
            kit.box("buildings", (0.86, 0.06, 1.85), (x - 0.62, fy - 0.35, z0 + 0.95), red, rot=(0.0, 0.0, math.radians(-35)))
        else:
            kit.box("buildings", (1.8, 0.06, 1.85), (x, fy - 0.09, z0 + 0.95), red)
            kit.box("buildings", (0.12, 0.05, 1.8), (x, fy - 0.12, z0 + 0.95), trim)
            kit.box("buildings", (1.8, 0.05, 0.12), (x, fy - 0.12, z0 + 0.95), trim)
            kit.box("buildings", (0.1, 0.04, 2.3), (x, fy - 0.14, z0 + 0.95), trim)
            kit.box("buildings", (0.1, 0.04, 2.3), (x, fy - 0.14, z0 + 0.95), trim, rot=(0.0, math.radians(38), 0.0))
            kit.box("buildings", (0.1, 0.04, 2.3), (x, fy - 0.14, z0 + 0.95), trim, rot=(0.0, math.radians(-38), 0.0))
        kit.box("buildings", (0.9, 0.08, 0.9), (x, fy - 0.03, z0 + wall_h + rise * 0.35), trim, bevel=0.01, segments=1)
        kit.box("buildings", (0.74, 0.06, 0.74), (x, fy - 0.06, z0 + wall_h + rise * 0.35), self.mat("timber"))
        if self.w:
            self._ivy(x - w * 0.3, fy, z0, w * 0.4, facing="-y")
        self._roof(x, y, z0, w, d, wall_h, rise, 0.36, "slate", chimney=False)

    def windmill(self, c, r, height=4.2, radius=1.15):
        """Tapered stone tower, wooden cap, four lattice sails that turn (alive) or hang broken."""
        kit = self.kit
        x, y, z0 = self._at("windmill", c, r)
        kit.piece("building", x, y, z0)
        kit.cyl("buildings", radius * 1.1, 0.25, (x, y, z0 + 0.12), self.stone_mat(1), verts=14)
        kit.frustum("buildings", radius, radius * 0.72, height, (x, y, z0 + height / 2), self.mat("wall"), verts=14)
        kit.box("buildings", (0.7, 0.08, 1.4), (x, y - radius * 0.86, z0 + 0.72), self.mat("timber" if self.w else "door"), bevel=0.02, segments=1)
        if self.w:
            self._boards(x, y - radius * 0.8, z0 + 0.8, 0.7, 1.3)
        kit.box("buildings", (0.5, 0.06, 0.5), (x, y - radius * 0.78, z0 + height * 0.62), self.mat("trim"), bevel=0.01, segments=1)
        kit.piece("roof", x, y, z0 + height)
        cap_r = radius * 0.86
        kit.frustum("buildings", cap_r, 0.12, 1.3, (x, y, z0 + height + 0.62), self.mat("wood_dark"), verts=14)
        kit.cyl("buildings", 0.1, 1.2, (x, y - cap_r * 0.2, z0 + height + 0.25), self.mat("timber"), verts=8,
                rot=(math.pi / 2, 0.0, 0.0))
        hub_y = y - cap_r * 0.2 - 0.62
        hub_z = z0 + height + 0.25
        # The sails are their own piece pivoting at the hub so the shader can spin them.
        kit.piece("prop", x, hub_y, hub_z, extra=0.15, motion=self.motion(M_SPIN_Z))
        kit.sphere("buildings", 0.2, (x, hub_y, hub_z), self.mat("timber"), segments=8, rings=6)
        for k in range(4):
            a = k * math.pi / 2 + 0.35
            arm = 2.2
            if self.w and k == 1:
                arm = 1.3   # one arm snapped
            ax = x + math.cos(a) * arm / 2
            az = hub_z + math.sin(a) * arm / 2
            kit.box("buildings", (arm, 0.08, 0.08), (ax, hub_y - 0.04, az), self.mat("timber"), rot=(0.0, -a, 0.0))
            if self.w and k % 2 == 1:
                continue   # sails torn off these arms
            sail_len = arm * (0.4 if self.w else 0.62)
            sx = x + math.cos(a) * (arm - sail_len / 2 - 0.1)
            sz = hub_z + math.sin(a) * (arm - sail_len / 2 - 0.1)
            kit.box("buildings", (sail_len, 0.04, 0.55 if not self.w else 0.4), (sx - math.sin(a) * 0.3, hub_y - 0.08, sz + math.cos(a) * 0.3),
                    self.mat("sail"), rot=(0.0, -a, 0.0))

    def well(self, c, r):
        """Stone ring, two posts, a small pitched roof and the bucket rope. Withered: dry, roof half gone."""
        kit = self.kit
        x, y, z0 = self._at("well", c, r)
        kit.piece("building", x, y, z0)
        ring = self.stone_mat(1)
        kit.cyl("buildings", 0.9, 0.85, (x, y, z0 + 0.42), ring, verts=14, bevel=0.05)
        kit.cyl("buildings", 0.66, 0.06, (x, y, z0 + 0.84), self.mat("mud" if self.w else "still_water"), verts=14)
        kit.cyl("buildings", 1.0, 0.12, (x, y, z0 + 0.9), self.stone_mat(0), verts=14)
        for s in (-1.0, 1.0):
            kit.box("buildings", (0.14, 0.14, 1.9), (x + s * 0.8, y, z0 + 0.95), self.mat("timber"), bevel=0.02, segments=1)
        kit.cyl("buildings", 0.09, 1.7, (x, y, z0 + 1.55), self.mat("wood"), verts=8, rot=(0.0, math.pi / 2, 0.0))
        kit.cyl("buildings", 0.03, 0.55, (x, y, z0 + 1.28), self.mat("rope"), verts=6)
        if not self.w:
            kit.cyl("buildings", 0.16, 0.22, (x, y, z0 + 0.98), self.mat("wood_dark"), verts=10)
        kit.piece("roof", x, y, z0 + 1.9)
        for s in (-1.0, 1.0):
            if self.w and s > 0:
                continue
            kit.box("buildings", (2.2, 0.95, 0.1), (x, y + s * 0.42, z0 + 2.2), self.mat("slate_dark"),
                    bevel=0.02, segments=1, rot=(s * 0.62, 0.0, 0.0))
        kit.box("buildings", (2.3, 0.2, 0.1), (x, y, z0 + 2.48), self.mat("slate"), bevel=0.02, segments=1)

    def chapel(self, c, r, w=3.4, d=5.0, wall_h=3.0, tower_h=5.6):
        """Small stone chapel: nave with a slate roof, square bell tower with a pointed cap."""
        kit = self.kit
        x, y, z0 = self._at("chapel", c, r)
        kit.piece("building", x, y, z0)
        wall = self.mat("stone_wall")
        kit.box("buildings", (w, d, wall_h), (x, y, z0 + wall_h / 2), wall, bevel=0.03, segments=1)
        apex = z0 + wall_h + 1.5
        gable = [(y - d / 2, z0 + wall_h - 0.02), (y + d / 2, z0 + wall_h - 0.02), (y, apex - 0.02)]
        kit.prism("buildings", gable, x - w / 2, x + w / 2, wall)
        fy = y - d / 2
        kit.box("buildings", (0.9, 0.08, 1.9), (x, fy - 0.04, z0 + 0.95), self.mat("timber"), bevel=0.015, segments=1)
        for i in range(3):
            wy = y - d / 2 + 1.1 + i * 1.4
            for s in (-1.0, 1.0):
                kit.box("buildings", (0.06, 0.4, 1.0), (x + s * w / 2, wy, z0 + 1.8), self.mat("glass"))
        self._roof(x, y, z0, w, d, wall_h, 1.5, 0.3, "slate", chimney=False)
        tx, ty = x, y + d / 2 - 1.0
        kit.piece("building", tx, ty, z0, extra=0.12)
        kit.box("buildings", (2.0, 2.0, tower_h), (tx, ty, z0 + tower_h / 2), wall, bevel=0.03, segments=1)
        kit.box("buildings", (0.5, 0.1, 0.8), (tx, ty - 1.0, z0 + tower_h - 1.1), self.mat("timber"))
        kit.sphere("buildings", 0.22, (tx, ty - 0.98, z0 + tower_h - 1.1), self.mat("lantern"), segments=8, rings=6)
        kit.piece("roof", tx, ty, z0 + tower_h)
        kit.frustum("buildings", 1.45, 0.05, 2.0, (tx, ty, z0 + tower_h + 1.0), self.mat("slate_dark"), verts=4,
                    rot=(0.0, 0.0, math.radians(45)))
        kit.sphere("buildings", 0.12, (tx, ty, z0 + tower_h + 2.1), self.mat("beak"), segments=8, rings=5)

    def stilt_hut(self, c, r, heading=0.0, deck_toward=-1.0):
        """Fisherman's hut on stilts at a pool edge: dark timber, thatched roof, a lantern by the door.
        Withered: a stilt gone, the deck broken, the thatch sagging, the lantern dark."""
        kit = self.kit
        x, y = self.s.xy(c, r)
        z0 = self.s.ground_z(c, r)
        water = self.s.water_y if self.s.water_y is not None else z0
        base = z0 if self.s.cell_at(c, r) != "W" else water - 0.25
        kit.piece("building", x, y, base)
        timber = self.mat("timber")
        deck_z = max(z0, water) + 0.55
        for sx in (-1.2, 1.2):
            for sy in (-1.0, 1.0):
                if self.w and sx < 0 and sy < 0:
                    continue
                kit.cyl("buildings", 0.1, deck_z - base + 0.1, (x + sx, y + sy, base + (deck_z - base) / 2), timber, verts=6)
        if self.w:
            kit.box("buildings", (2.2, 3.0, 0.14), (x + 0.6, y, deck_z), self.mat("wood_dark"), bevel=0.02, segments=1)
            kit.box("buildings", (1.0, 1.2, 0.1), (x - 1.4, y - 0.6, deck_z - 0.35), self.mat("wood_dark"), bevel=0.02, segments=1, rot=(0.3, 0.5, 0.2))
        else:
            kit.box("buildings", (3.4, 3.0, 0.14), (x, y, deck_z), self.mat("wood_dark"), bevel=0.02, segments=1)
        kit.box("buildings", (2.4, 2.1, 1.7), (x, y + 0.3, deck_z + 0.92), timber, bevel=0.03, segments=1)
        kit.box("buildings", (0.6, 0.06, 1.1), (x - 0.4, y - 0.76, deck_z + 0.62), self.mat("wood"), bevel=0.01, segments=1)
        kit.box("buildings", (0.5, 0.05, 0.5), (x + 0.55, y - 0.76, deck_z + 1.1), self.mat("glass" if self.w else "lantern"), bevel=0.01, segments=1)
        kit.piece("roof", x, y + 0.3, deck_z + 1.7)
        for s in (-1.0, 1.0):
            sag = 0.25 if self.w else 0.0
            kit.box("buildings", (3.0, 1.5, 0.3), (x, y + 0.3 + s * 0.6, deck_z + 2.15 - sag * 0.5), self.mat("thatch"),
                    bevel=0.1, segments=3, rot=(s * (0.6 + sag), 0.0, 0.0))
        kit.box("buildings", (3.1, 0.3, 0.16), (x, y + 0.3, deck_z + 2.55 - (0.12 if self.w else 0.0)), self.mat("thatch_dark"), bevel=0.04, segments=1)

    def watermill(self, c, r, wheel_side=1.0):
        """Mill house - stone lower storey, plank upper storey with a loft door and hoist beam,
        slate roof - with a big spoked wheel on one gable side (wheel_side = ±1 → +x / -x). The
        wheel turns when the stage is alive; withered it stands still with half its paddles gone."""
        kit = self.kit
        x, y, z0 = self._at("watermill", c, r)
        w, d, wall_h, rise = 4.2, 3.4, 2.6, 1.5
        stone, plank, timber, dark = self.mat("stone_wall"), self.mat("wood"), self.mat("timber"), self.mat("wood_dark")
        kit.piece("building", x, y, z0)
        kit.box("buildings", (w, d, 1.15), (x, y, z0 + 0.575), stone, bevel=0.03, segments=1)
        kit.box("buildings", (w + 0.1, d + 0.1, 0.12), (x, y, z0 + 1.15), timber, bevel=0.01, segments=1)
        kit.box("buildings", (w, d, wall_h - 1.2), (x, y, z0 + 1.2 + (wall_h - 1.2) / 2), plank, bevel=0.03, segments=1)
        apex = z0 + wall_h + rise
        gable = [(y - d / 2, z0 + wall_h - 0.02), (y + d / 2, z0 + wall_h - 0.02), (y, apex - 0.02)]
        kit.prism("buildings", gable, x - w / 2, x + w / 2, plank)
        fy = y - d / 2
        for zz in (1.55, 1.95, 2.35):
            kit.box("buildings", (w - 0.1, 0.03, 0.04), (x, fy - 0.015, z0 + zz), dark)
        kit.box("buildings", (0.9, 0.08, 1.6), (x - w * 0.2, fy - 0.04, z0 + 0.8), timber, bevel=0.012, segments=1)
        self._stone_window((x + w * 0.25, fy, z0 + 0.7), facing="-y")
        self._stone_window((x - w * 0.2, fy, z0 + 2.0), facing="-y")
        self._stone_window((x + w * 0.25, fy, z0 + 2.0), facing="-y")
        kit.box("buildings", (0.7, 0.08, 0.8), (x, fy - 0.04, z0 + wall_h + 0.45), self.mat("iron") if self.w else timber, bevel=0.012, segments=1)
        kit.box("buildings", (0.1, 0.9, 0.1), (x, fy - 0.4, z0 + wall_h + 1.0), timber)
        if not self.w:
            kit.cyl("buildings", 0.02, 0.5, (x, fy - 0.8, z0 + wall_h + 0.72), self.mat("rope"), verts=4)
        if self.w:
            self._ivy(x + w * 0.2, fy, z0, w * 0.5, facing="-y")
        self._roof(x, y, z0, w, d, wall_h, rise, 0.3, "slate", chimney=True)
        wx = x + wheel_side * 2.5
        wheel_z = z0 + 1.35
        kit.piece("prop", wx, y, wheel_z, extra=0.1, motion=self.motion(M_SPIN_X))
        side_rot = (0.0, math.pi / 2, 0.0)
        kit.torus("props", 1.3, 0.09, (wx, y, wheel_z), dark, rot=side_rot, seg_major=16, seg_minor=6)
        kit.torus("props", 0.8, 0.06, (wx, y, wheel_z), dark, rot=side_rot, seg_major=14, seg_minor=5)
        for k in range(3):
            a = k * math.pi / 3
            kit.box("props", (0.08, 2.5, 0.08), (wx, y, wheel_z), plank, rot=(a, 0.0, 0.0))
        for k in range(8):
            if self.w and k % 2 == 1:
                continue
            a = k * math.tau / 8 + 0.2
            kit.box("props", (0.5, 0.16, 0.36), (wx, y + math.sin(a) * 1.3, wheel_z + math.cos(a) * 1.3), plank, rot=(-a, 0.0, 0.0))
        kit.cyl("props", 0.1, 0.9, (x + wheel_side * 2.1, y, wheel_z), timber, verts=8, rot=side_rot)
        kit.sphere("props", 0.16, (wx, y, wheel_z), timber, segments=8, rings=6)

    def lighthouse(self, c, r, height=5.0):
        """Round striped tower with a gallery and a lamp room. Withered: faded, lamp out, rail broken."""
        kit = self.kit
        x, y, z0 = self._at("lighthouse", c, r)
        kit.piece("building", x, y, z0)
        kit.cyl("buildings", 1.2, 0.3, (x, y, z0 + 0.15), self.stone_mat(0), verts=16)
        bands = 5
        for i in range(bands):
            zc = z0 + 0.3 + (i + 0.5) * (height / bands)
            rad = 0.95 - 0.09 * i
            kit.frustum("buildings", rad + 0.045, rad - 0.045, height / bands + 0.02, (x, y, zc),
                        self.mat("beacon" if i % 2 == 0 else "hull"), verts=16)
        kit.box("buildings", (0.6, 0.08, 1.2), (x, y - 0.93, z0 + 0.9), self.mat("hull_trim"), bevel=0.02, segments=1)
        if self.w:
            self._boards(x, y - 0.9, z0 + 1.0, 0.6, 1.0)
        kit.piece("roof", x, y, z0 + height + 0.3)
        kit.cyl("buildings", 0.85, 0.14, (x, y, z0 + height + 0.35), self.mat("hull_trim"), verts=16)
        kit.cyl("buildings", 0.5, 0.9, (x, y, z0 + height + 0.9), self.mat("glass"), verts=12)
        for k in range(6):
            if self.w and k in (1, 4):
                continue
            a = k * math.tau / 6
            kit.box("buildings", (0.06, 0.06, 0.9), (x + math.cos(a) * 0.5, y + math.sin(a) * 0.5, z0 + height + 0.9), self.mat("hull_trim"))
        kit.sphere("buildings", 0.28, (x, y, z0 + height + 0.9), self.mat("iron" if self.w else "lantern"), segments=10, rings=7)
        kit.frustum("buildings", 0.7, 0.06, 0.6, (x, y - (0.08 if self.w else 0.0), z0 + height + 1.62), self.mat("beacon"), verts=12,
                    rot=((0.1, 0.06, 0.0) if self.w else (0.0, 0.0, 0.0)))

    def harbor_house(self, c, r, w=3.6, d=3.0, wall_h=2.5, stories_stripe=True):
        """Whitewashed harbour house with a navy roof and door, a stripe of awning over the window."""
        self.cottage(c, r, w=w, d=d, wall_h=wall_h, rise=1.1, over=0.28, roof="navy", chimney=False,
                     windows_side=False, door_key="hull_trim")

    # --- water & harbour ------------------------------------------------------------------------

    def plank_bridge(self, c, r, length=1.9, width=1.05, along_x=True):
        kit = self.kit
        x, y = self.s.xy(c, r)
        kit.piece("ground", x, y, 0.0)
        wood, dark = self.mat("wood"), self.mat("wood_dark")
        rot = 0.0 if along_x else math.pi / 2
        ca, sa = math.cos(rot), math.sin(rot)
        n = 8
        for i in range(n):
            if self.w and i in (2, 5):
                continue
            t = (i + 0.5) / n
            off = -length / 2 + t * length
            lift = 0.08 + 0.14 * math.sin(t * math.pi)
            kit.box("props", (length / n * 0.9, width, 0.07), (x + ca * off, y + sa * off, lift), wood, bevel=0.01, segments=1,
                    rot=(0.0, -0.12 * math.cos(t * math.pi) * ca, rot))
        for s in (-1.0, 1.0):
            if self.w and s > 0:
                continue
            side = (width / 2 - 0.05)
            kit.box("props", (length, 0.09, 0.09), (x - sa * s * side, y + ca * s * side, 0.06), dark, rot=(0.0, 0.0, rot))
            for e in (-1.0, 1.0):
                off = e * (length / 2 - 0.15)
                kit.box("props", (0.10, 0.10, 0.62), (x + ca * off - sa * s * (side + 0.07), y + sa * off + ca * s * (side + 0.07), 0.30),
                        dark, bevel=0.015, segments=1)
            kit.box("props", (length - 0.1, 0.07, 0.06), (x - sa * s * (side + 0.07), y + ca * s * (side + 0.07), 0.58), wood,
                    bevel=0.01, segments=1, rot=(0.0, 0.0, rot))

    def arch_bridge(self, c, r, length=3.2, width=1.3, along_x=True, rise=0.55):
        """Vermilion arched footbridge: curved deck of slats, posts with finials, two rails.
        Withered: slats missing, one rail gone, the paint faded (palette)."""
        kit = self.kit
        x, y = self.s.xy(c, r)
        kit.piece("ground", x, y, 0.0)
        red = self.mat("beacon")
        dark = self.mat("ridge")
        rot = 0.0 if along_x else math.pi / 2
        ca, sa = math.cos(rot), math.sin(rot)
        n = 11
        for i in range(n):
            if self.w and i in (3, 7):
                continue
            t = (i + 0.5) / n
            off = -length / 2 + t * length
            lift = 0.12 + rise * math.sin(t * math.pi)
            slope = -rise * math.pi * math.cos(t * math.pi) / length
            kit.box("props", (length / n * 0.92, width, 0.09), (x + ca * off, y + sa * off, lift), red, bevel=0.012, segments=1,
                    rot=(slope * sa, -slope * ca, rot))
        for s in (-1.0, 1.0):
            if self.w and s > 0:
                continue
            side = width / 2 + 0.08
            for k in range(5):
                t = k / 4
                off = -length / 2 + 0.15 + t * (length - 0.3)
                lift = 0.12 + rise * math.sin(max(0.03, min(0.97, t)) * math.pi)
                px, py = x + ca * off - sa * s * side, y + sa * off + ca * s * side
                kit.box("props", (0.11, 0.11, 0.7), (px, py, lift + 0.35), red, bevel=0.015, segments=1)
                kit.sphere("props", 0.09, (px, py, lift + 0.76), dark, segments=8, rings=5)
            for k in range(4):
                t0, t1 = k / 4, (k + 1) / 4
                o0 = -length / 2 + 0.15 + t0 * (length - 0.3)
                o1 = -length / 2 + 0.15 + t1 * (length - 0.3)
                l0 = 0.12 + rise * math.sin(max(0.03, min(0.97, t0)) * math.pi) + 0.62
                l1 = 0.12 + rise * math.sin(max(0.03, min(0.97, t1)) * math.pi) + 0.62
                mid = (o0 + o1) / 2
                seg = math.hypot(o1 - o0, l1 - l0)
                pitch = math.atan2(l1 - l0, o1 - o0)
                px, py = x + ca * mid - sa * s * side, y + sa * mid + ca * s * side
                kit.box("props", (seg, 0.07, 0.07), (px, py, (l0 + l1) / 2), red,
                        rot=(pitch * sa, -pitch * ca, rot))

    def dock(self, c, r, length=4.0, width=1.4, along_x=True, deck_z=0.35):
        """Wooden pier on piles running out over the water from (c, r) toward +x (or +r).
        Withered: a gap in the deck, piles leaning."""
        kit, rng = self.kit, self.rng
        x, y = self.s.xy(c, r)
        base = self.s.water_y if self.s.water_y is not None else self.s.heights.get("W", 0.0)
        kit.piece("ground", x, y, base)
        rot = 0.0 if along_x else -math.pi / 2
        ca, sa = math.cos(rot), math.sin(rot)
        if self.w:
            for (start, end) in ((0.0, length * 0.55), (length * 0.72, length)):
                mid = (start + end) / 2
                kit.box("props", (end - start, width, 0.12), (x + ca * mid, y + sa * mid, deck_z), self.mat("wood"), bevel=0.015, segments=1,
                        rot=(0.0, 0.0, rot))
        else:
            cx, cy = x + ca * length / 2, y + sa * length / 2
            kit.box("props", (length, width, 0.12), (cx, cy, deck_z), self.mat("wood"), bevel=0.015, segments=1, rot=(0.0, 0.0, rot))
        n = int(length / 0.42)
        for i in range(n):
            off = (i + 0.5) / n * length
            if self.w and length * 0.55 < off < length * 0.72:
                continue
            kit.box("props", (0.05, width + 0.02, 0.03), (x + ca * off, y + sa * off, deck_z + 0.075), self.mat("wood_dark"),
                    rot=(0.0, 0.0, rot))
        for k in range(int(length / 1.3) + 1):
            off = min(length - 0.25, 0.25 + k * 1.3)
            for s in (-1.0, 1.0):
                px, py = x + ca * off - sa * s * (width / 2 - 0.1), y + sa * off + ca * s * (width / 2 - 0.1)
                lean = (rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), 0.0) if self.w else (0.0, 0.0, 0.0)
                kit.cyl("props", 0.09, deck_z - base + 1.2, (px, py, base - 0.5 + (deck_z - base + 1.2) / 2), self.mat("timber"), verts=6, rot=lean)
                kit.cyl("props", 0.1, 0.5, (px, py, deck_z + 0.25), self.mat("timber"), verts=6, rot=lean)

    def boat(self, c, r, heading=0.0, sail=True, length=2.4, ground=False):
        """Small wooden boat: hull, gunwale trim, optional mast and sail. Floats (and rocks) at the
        water level unless `ground` (pulled up on the beach). Withered: half sunk and listing on the
        water, or lying upturned on the sand; no sail."""
        kit = self.kit
        x, y = self.s.xy(c, r)
        on_water = not ground and self.s.water_y is not None
        z = self.s.water_y if on_water else self.s.ground_z(c, r)
        hull = self.mat("hull")
        if self.w:
            kit.piece("prop", x, y, z)
            if on_water:
                rot = (0.42, 0.0, heading)
                kit.box("buildings", (length, length * 0.42, 0.42), (x, y, z - 0.02), hull, bevel=0.14, segments=3, rot=rot)
                kit.box("buildings", (length * 0.96, length * 0.42 + 0.06, 0.08), (x, y - 0.14, z + 0.18), self.mat("hull_trim"),
                        bevel=0.03, segments=2, rot=rot)
                if sail:
                    kit.cyl("buildings", 0.05, 0.9, (x, y, z + 0.45), self.mat("timber"), verts=6, rot=(0.5, 0.2, 0.0))
            else:
                kit.box("buildings", (length, length * 0.42, 0.42), (x, y, z + 0.21), self.mat("wood_dark"), bevel=0.14, segments=3,
                        rot=(math.pi, 0.0, heading))
                kit.box("buildings", (length * 0.96, length * 0.42 + 0.06, 0.08), (x, y, z + 0.04), self.mat("hull_trim"),
                        bevel=0.03, segments=2, rot=(0.0, 0.0, heading))
            return
        kit.piece("prop", x, y, z, motion=self.motion(M_ROCK) if on_water else None)
        rot = (0.0, 0.0, heading)
        kit.box("buildings", (length, length * 0.42, 0.42), (x, y, z + 0.18), hull, bevel=0.14, segments=3, rot=rot)
        kit.box("buildings", (length * 0.96, length * 0.42 + 0.06, 0.08), (x, y, z + 0.4), self.mat("hull_trim"),
                bevel=0.03, segments=2, rot=rot)
        kit.box("buildings", (length * 0.78, length * 0.3, 0.06), (x, y, z + 0.38), self.mat("wood_dark"), rot=rot)
        if sail:
            ca, sa = math.cos(heading), math.sin(heading)
            mx, my = x + ca * length * 0.05, y + sa * length * 0.05
            kit.cyl("buildings", 0.05, 2.4, (mx, my, z + 1.5), self.mat("timber"), verts=6)
            kit.box("buildings", (0.05, 1.3, 1.6), (mx + ca * 0.0 - sa * 0.66, my + sa * 0.0 + ca * 0.66, z + 1.55), self.mat("sail"),
                    rot=(0.0, 0.0, heading))
            kit.box("buildings", (0.06, 1.35, 0.06), (mx - sa * 0.66, my + ca * 0.66, z + 0.75), self.mat("timber"), rot=rot)

    def buoy(self, c, r):
        kit = self.kit
        x, y = self.s.xy(c, r)
        z = self.s.water_y if self.s.water_y is not None else self.s.ground_z(c, r)
        kit.piece("prop", x, y, z, motion=self.motion(M_ROCK))
        tilt = (0.35, 0.0, 0.0) if self.w else (0.0, 0.0, 0.0)
        kit.sphere("props", 0.26, (x, y, z + 0.1), self.mat("buoy"), scale=(1.0, 1.0, 0.8), segments=10, rings=7, rot=tilt)
        kit.cyl("props", 0.05, 0.5, (x, y - (0.15 if self.w else 0.0), z + 0.45), self.mat("iron"), verts=6, rot=tilt)
        if not self.w:
            kit.sphere("props", 0.08, (x, y, z + 0.72), self.mat("lantern"), segments=8, rings=5)

    def awning_stall(self, c, r, angle=0.0):
        """Market stall with a striped awning and crates of fish/fruit. Withered: half the awning
        strips gone, the rest sagging, the counter bare."""
        kit = self.kit
        x, y, z0 = self._at("stall", c, r)
        kit.piece("prop", x, y, z0)
        rot = (0.0, 0.0, angle)
        ca, sa = math.cos(angle), math.sin(angle)
        kit.box("props", (2.0, 0.9, 0.8), (x, y, z0 + 0.4), self.mat("wood"), bevel=0.02, segments=1, rot=rot)
        for sx in (-0.9, 0.9):
            kit.box("props", (0.08, 0.08, 2.0), (x + ca * sx - sa * 0.35, y + sa * sx + ca * 0.35, z0 + 1.0), self.mat("timber"))
        for i in range(6):
            if self.w and i % 2 == 1:
                continue
            off = -0.95 + (i + 0.5) * (2.0 / 6)
            key = "hull_trim" if i % 2 == 0 else "hull"
            kit.box("props", (2.0 / 6, 1.3, 0.05), (x + ca * off - sa * 0.05, y + sa * off + ca * 0.05, z0 + 2.05 - (0.1 if self.w else 0.0)),
                    self.mat(key), rot=(0.25 + (0.35 if self.w else 0.0), 0.0, angle))
        if self.w:
            return
        kit.box("props", (0.5, 0.4, 0.3), (x - ca * 0.5, y - sa * 0.5, z0 + 0.95), self.mat("wood_dark"), bevel=0.02, segments=1, rot=rot)
        kit.box("props", (0.5, 0.4, 0.3), (x + ca * 0.4, y + sa * 0.4, z0 + 0.95), self.mat("wood_dark"), bevel=0.02, segments=1, rot=rot)
        for k in range(4):
            kit.sphere("props", 0.1, (x + ca * (0.3 + 0.1 * k) - sa * 0.05, y + sa * (0.3 + 0.1 * k) + ca * 0.05, z0 + 1.15),
                       self.mat("buoy" if k % 2 else "fruit_a"), segments=8, rings=5)

    # --- stone hill village (老井村) ------------------------------------------------------------

    def ancient_tree(self, c, r, size=1.0, ribbons=9):
        """The village's old tree: a thick flared trunk under a huge many-lobed canopy, red wish
        ribbons swinging from the lower branches. Withered: the crown is gone, only the great bare
        branches and a few faded ribbons remain."""
        kit, rng = self.kit, self.rng
        x, y, z0 = self._at("ancient tree", c, r)
        kit.piece("tree", x, y, z0)
        bark = self.mat("trunk")
        trunk_h = 2.4 * size
        kit.frustum("trees", 0.64 * size, 0.42 * size, trunk_h, (x, y, z0 + trunk_h / 2), bark, verts=10,
                    bevel=0.06 * size, segments=2)
        for k in range(5):
            a = k / 5 * math.tau + 0.4
            rx, ry = x + math.cos(a) * 0.62 * size, y + math.sin(a) * 0.62 * size
            kit.frustum("trees", 0.24 * size, 0.07 * size, 0.95 * size, (rx, ry, z0 + 0.34 * size), bark, verts=6,
                        rot=(0.55 * math.sin(a), -0.55 * math.cos(a), 0.0))
        lobes = [(0.0, 0.0, 0.0, 3.9, 2.3, 0), (1.6, 0.7, -0.35, 2.4, 1.7, 1), (-1.55, 0.9, -0.2, 2.5, 1.6, 2),
                 (0.6, -1.55, -0.25, 2.3, 1.5, 1), (-0.95, -1.35, -0.4, 2.1, 1.4, 0), (0.2, 0.3, 1.25, 2.3, 1.3, 2),
                 (-1.95, -0.2, 0.5, 1.8, 1.2, 1), (1.95, -0.6, 0.55, 1.7, 1.1, 0)]
        crown_z = z0 + trunk_h + 0.55 * size
        branch_set = lobes[1:] if self.w else lobes[1:4]
        for (dx, dy, dz, _w, _h, _leaf) in branch_set:
            reach = 1.0 if not self.w else 1.35
            length = math.hypot(dx * reach, dy * reach, dz + 0.6) * size
            a = math.atan2(dy, dx)
            tilt = math.atan2(math.hypot(dx, dy) * reach, dz + 0.6)
            kit.cyl("trees", (0.11 if not self.w else 0.09) * size, length,
                    (x + dx * reach * 0.5 * size, y + dy * reach * 0.5 * size, z0 + trunk_h + (dz + 0.6) * 0.5 * size),
                    bark, verts=6, rot=(-tilt * math.sin(a), tilt * math.cos(a), 0.0))
        if self.w:
            # twigs at the branch ends
            for (dx, dy, dz, _w, _h, _leaf) in lobes[1:6]:
                tx, ty, tz = x + dx * 1.3 * size, y + dy * 1.3 * size, z0 + trunk_h + (dz + 1.15) * size
                for k in range(3):
                    a = k / 3 * math.tau + dx
                    kit.frustum("trees", 0.035 * size, 0.008 * size, 0.6 * size, (tx + math.cos(a) * 0.2, ty + math.sin(a) * 0.2, tz + 0.25),
                                bark, verts=4, rot=(-0.9 * math.sin(a), 0.9 * math.cos(a), 0.0))
        else:
            kit.piece("tree", x, y, crown_z - 0.9 * size, extra=0.08, motion=self.motion(M_SWAY))
            for (dx, dy, dz, w, h, leaf) in lobes:
                kit.box("trees", (w * size, w * 0.92 * size, h * size), (x + dx * size, y + dy * size, crown_z + dz * size),
                        self.leaf(leaf), bevel=0.34 * h * size, segments=3)
        rope, ribbon = self.mat("rope"), self.mat("ribbon")
        for i in range(3 if self.w else ribbons):
            a = i / max(ribbons, 1) * math.tau + rng.uniform(-0.2, 0.2) + (0.7 if self.w else 0.0)
            rr = rng.uniform(1.2, 1.9) * size
            px, py = x + math.cos(a) * rr, y + math.sin(a) * rr
            top = crown_z - 0.95 * size
            drop = rng.uniform(0.35, 0.6) * size
            kit.piece("greenery", px, py, top, extra=0.2, motion=self.motion(M_SWING, alive_only=False))
            kit.cyl("trees", 0.012, drop, (px, py, top - drop / 2), rope, verts=4)
            kit.box("trees", (0.15 * size, 0.03, (0.55 if not self.w else 0.32) * size), (px, py, top - drop - 0.27 * size), ribbon,
                    rot=(0.0, 0.0, rng.uniform(0.0, math.pi)))

    def well_pavilion(self, c, r):
        """井亭: the village well under its own two-tier slate roof on four timber posts, on an
        octagonal flagstone platform, windlass and bucket inside. Badge anchor of 老井村.
        Withered: dry, bucket gone, the upper roof tier fallen and the lower one askew."""
        kit = self.kit
        x, y, z0 = self._at("well pavilion", c, r)
        kit.piece("building", x, y, z0)
        kit.cyl("buildings", 1.8, 0.12, (x, y, z0 + 0.06), self.mat("flag_a"), verts=8, bevel=0.03)
        kit.cyl("buildings", 0.78, 0.8, (x, y, z0 + 0.4), self.stone_mat(1), verts=12, bevel=0.05)
        kit.cyl("buildings", 0.58, 0.06, (x, y, z0 + 0.8 - (0.3 if self.w else 0.0)), self.mat("mud" if self.w else "still_water"), verts=12)
        kit.cyl("buildings", 0.9, 0.12, (x, y, z0 + 0.86), self.stone_mat(0), verts=12)
        timber = self.mat("timber")
        post_h = 2.4
        for sx in (-1.15, 1.15):
            for sy in (-1.15, 1.15):
                kit.box("buildings", (0.18, 0.18, post_h), (x + sx, y + sy, z0 + post_h / 2), timber, bevel=0.02, segments=1)
        for s in (-1.15, 1.15):
            kit.box("buildings", (2.5, 0.16, 0.16), (x, y + s, z0 + post_h - 0.08), timber)
            kit.box("buildings", (0.16, 2.5, 0.16), (x + s, y, z0 + post_h - 0.08), timber)
        for s in (-1.0, 1.0):
            kit.box("buildings", (0.12, 0.12, 1.0), (x + s * 0.7, y, z0 + 1.3), self.mat("wood_dark"), bevel=0.015, segments=1)
        kit.cyl("buildings", 0.08, 1.5, (x, y, z0 + 1.72), self.mat("wood"), verts=8, rot=(0.0, math.pi / 2, 0.0))
        kit.cyl("buildings", 0.025, 0.6, (x, y, z0 + 1.4), self.mat("rope"), verts=6)
        if not self.w:
            kit.cyl("buildings", 0.15, 0.22, (x, y, z0 + 1.05), self.mat("wood_dark"), verts=10)
        kit.piece("roof", x, y, z0 + post_h)
        diag = math.radians(45)
        if self.w:
            kit.frustum("buildings", 2.3, 1.35, 0.55, (x, y + 0.1, z0 + post_h + 0.22), self.mat("slate"), verts=4, rot=(0.1, 0.0, diag))
            return
        kit.frustum("buildings", 2.3, 1.35, 0.55, (x, y, z0 + post_h + 0.27), self.mat("slate"), verts=4, rot=(0.0, 0.0, diag))
        kit.box("buildings", (1.6, 1.6, 0.3), (x, y, z0 + post_h + 0.66), timber, bevel=0.03, segments=1)
        kit.frustum("buildings", 1.45, 0.06, 0.95, (x, y, z0 + post_h + 0.8 + 0.47), self.mat("slate_dark"), verts=4,
                    rot=(0.0, 0.0, diag))
        kit.sphere("buildings", 0.13, (x, y, z0 + post_h + 1.34), self.mat("gold"), segments=8, rings=6)

    def stone_house(self, c, r, w=4.6, d=2.8, wall_h=1.75, rise=0.95, chimney=True):
        """Long, low farmhouse of rubble stone: plinth, small deep windows without shutters, a
        plank door under a lintel, low-pitched slate roof and a squat chimney."""
        kit = self.kit
        x, y, z0 = self._at("stone house", c, r)
        stone, trim = self.mat("stone_wall"), self.mat("stone_trim")
        kit.piece("building", x, y, z0)
        kit.box("buildings", (w, d, wall_h), (x, y, z0 + wall_h / 2), stone, bevel=0.04, segments=2)
        kit.box("buildings", (w + 0.16, d + 0.16, 0.22), (x, y, z0 + 0.11), self.stone_mat(2), bevel=0.02, segments=1)
        apex = z0 + wall_h + rise
        gable = [(y - d / 2, z0 + wall_h - 0.02), (y + d / 2, z0 + wall_h - 0.02), (y, apex - 0.02)]
        kit.prism("buildings", gable, x - w / 2, x + w / 2, stone)
        fy = y - d / 2
        dx = x - w * 0.2
        if self.w:
            kit.box("buildings", (0.78, 0.08, 1.42), (dx, fy - 0.04, z0 + 0.71), self.mat("iron"), bevel=0.012, segments=1)
            kit.box("buildings", (0.4, 0.06, 1.42), (dx - 0.32, fy - 0.2, z0 + 0.71), self.mat("timber"), bevel=0.012, segments=1, rot=(0.0, 0.0, 0.5))
        else:
            kit.box("buildings", (0.78, 0.08, 1.42), (dx, fy - 0.04, z0 + 0.71), self.mat("timber"), bevel=0.012, segments=1)
            kit.sphere("buildings", 0.04, (dx + 0.24, fy - 0.1, z0 + 0.72), self.mat("iron"), segments=6, rings=4)
        kit.box("buildings", (1.0, 0.14, 0.14), (dx, fy - 0.05, z0 + 1.48), trim, bevel=0.01, segments=1)
        kit.box("buildings", (0.95, 0.34, 0.08), (dx, fy - 0.2, z0 + 0.04), self.mat("flag_b"), bevel=0.015, segments=1)
        for wx in (x + w * 0.16, x + w * 0.36):
            self._stone_window((wx, fy, z0 + wall_h * 0.6), facing="-y")
        self._stone_window((x - w / 2, y + 0.1, z0 + wall_h * 0.58), facing="-x")
        self._stone_window((x + w / 2, y - 0.1, z0 + wall_h * 0.58), facing="+x")
        if self.w:
            self._ivy(x + w * 0.1, fy, z0, w * 0.6, facing="-y")
        self._roof(x, y, z0, w, d, wall_h, rise, 0.28, "slate", chimney)

    def _stone_window(self, pos, facing="-y"):
        kit = self.kit
        x, y, z = pos
        trim, glass = self.mat("stone_trim"), self.mat("iron" if self.w else "glass")
        if facing == "-y":
            kit.box("buildings", (0.52, 0.06, 0.52), (x, y - 0.03, z), trim, bevel=0.01, segments=1)
            kit.box("buildings", (0.36, 0.04, 0.36), (x, y - 0.06, z), glass)
            if self.w:
                self._boards(x, y, z, 0.42, 0.42, facing)
            else:
                kit.box("buildings", (0.04, 0.03, 0.36), (x, y - 0.08, z), trim)
            kit.box("buildings", (0.6, 0.16, 0.06), (x, y - 0.08, z - 0.29), trim, bevel=0.01, segments=1)
        else:
            s = -1.0 if facing == "-x" else 1.0
            kit.box("buildings", (0.06, 0.48, 0.48), (x + s * 0.03, y, z), trim, bevel=0.01, segments=1)
            kit.box("buildings", (0.04, 0.34, 0.34), (x + s * 0.06, y, z), glass)
            if self.w:
                self._boards(x, y, z, 0.4, 0.4, facing)
            else:
                kit.box("buildings", (0.03, 0.04, 0.34), (x + s * 0.08, y, z), trim)

    def stone_tower(self, c, r, side=2.3, height=3.9, with_dove=True):
        """Square stone watch tower with a string course, slit windows and a pyramidal slate cap."""
        kit = self.kit
        x, y, z0 = self._at("stone tower", c, r)
        kit.piece("building", x, y, z0)
        stone, trim = self.mat("stone_wall"), self.mat("stone_trim")
        kit.box("buildings", (side, side, height), (x, y, z0 + height / 2), stone, bevel=0.04, segments=2)
        kit.box("buildings", (side + 0.2, side + 0.2, 0.26), (x, y, z0 + 0.13), self.stone_mat(2), bevel=0.02, segments=1)
        kit.box("buildings", (side + 0.12, side + 0.12, 0.12), (x, y, z0 + height * 0.55), trim, bevel=0.01, segments=1)
        fy = y - side / 2
        kit.box("buildings", (0.7, 0.08, 1.4), (x, fy - 0.04, z0 + 0.7), self.mat("iron" if self.w else "timber"), bevel=0.012, segments=1)
        kit.box("buildings", (0.9, 0.14, 0.14), (x, fy - 0.05, z0 + 1.45), trim, bevel=0.01, segments=1)
        self._stone_window((x, fy, z0 + height * 0.76), facing="-y")
        self._stone_window((x + side / 2, y, z0 + height * 0.4), facing="+x")
        self._stone_window((x - side / 2, y, z0 + height * 0.7), facing="-x")
        if self.w:
            self._ivy(x, fy, z0, side, facing="-y")
        kit.piece("roof", x, y, z0 + height)
        diag = math.radians(45)
        r1 = (side / 2 + 0.34) / math.cos(diag)
        kit.frustum("buildings", r1 + 0.03, r1 - 0.05, 0.12, (x, y, z0 + height + 0.06), self.mat("slate"), verts=4, rot=(0.0, 0.0, diag))
        tilt = (0.08, 0.0, diag) if self.w else (0.0, 0.0, diag)
        kit.frustum("buildings", r1, 0.06, 1.4, (x, y + (0.1 if self.w else 0.0), z0 + height + 0.12 + 0.7), self.mat("slate_dark"), verts=4, rot=tilt)
        kit.cyl("buildings", 0.03, 0.5, (x, y, z0 + height + 1.75), self.mat("iron"), verts=6)
        if with_dove:
            self.dove(c, r, z_off=height + 1.98, heading=math.radians(-120), size=1.1)

    def dry_wall(self, points, height=0.5, thick=0.34):
        """Dry-stone field wall: a run of slightly jittered blocks topped with a row of cap stones.
        Withered: blocks tumbled out of the wall and lying at its foot."""
        kit, rng = self.kit, self.rng
        for (c0, r0), (c1, r1) in zip(points[:-1], points[1:]):
            xa, ya = self.s.xy(c0, r0)
            xb, yb = self.s.xy(c1, r1)
            z0 = (self.s.ground_z(c0, r0) + self.s.ground_z(c1, r1)) / 2
            kit.piece("ground", (xa + xb) / 2, (ya + yb) / 2, z0)
            length = math.hypot(xb - xa, yb - ya)
            ang = math.atan2(yb - ya, xb - xa)
            ca, sa = math.cos(ang), math.sin(ang)
            n = max(1, int(round(length / 0.62)))
            step = length / n
            for i in range(n):
                t = (i + 0.5) * step
                h = height * rng.uniform(0.9, 1.08)
                if self.w and rng.random() < 0.2:
                    side = rng.choice((-1.0, 1.0))
                    kit.box("props", (step * 0.8, thick * 0.9, h * 0.7), (xa + ca * t - sa * side * 0.55, ya + sa * t + ca * side * 0.55, z0 + h * 0.3),
                            self.stone_mat(i % 3), bevel=0.04, segments=1, rot=(0.3, 0.0, ang + rng.uniform(-0.6, 0.6)))
                    continue
                kit.box("props", (step * 0.97, thick * rng.uniform(0.9, 1.05), h), (xa + ca * t, ya + sa * t, z0 + h / 2),
                        self.stone_mat(i % 3), bevel=0.04, segments=1, rot=(0.0, 0.0, ang + rng.uniform(-0.03, 0.03)))
            m = max(1, int(round(length / 0.36)))
            for i in range(m):
                if self.w and rng.random() < 0.45:
                    continue
                t = (i + 0.5) * length / m
                j = rng.uniform(-0.03, 0.03)
                kit.box("props", (0.3, thick * 0.8, 0.12), (xa + ca * t - sa * j, ya + sa * t + ca * j, z0 + height + 0.05),
                        self.stone_mat((i + 1) % 3), bevel=0.02, segments=1, rot=(0.0, 0.0, ang + rng.uniform(-0.25, 0.25)), flat=True)

    # --- water garden (双桥) --------------------------------------------------------------------

    def pavilion(self, c, r, radius=1.5, col_h=2.3, open_side=5):
        """Open hexagonal garden pavilion: vermilion columns with low rail-seats, a two-tier slate
        roof with a red eave band and a gilt finial, a stone table and stools inside. Withered:
        rails broken, the upper roof tier fallen, the lower one askew, no finial."""
        kit = self.kit
        x, y, z0 = self._at("pavilion", c, r)
        kit.piece("building", x, y, z0)
        flag, flag_b = self.mat("flag_a"), self.mat("flag_b")
        kit.cyl("buildings", radius + 0.7, 0.12, (x, y, z0 + 0.06), flag_b, verts=6, bevel=0.03)
        kit.cyl("buildings", radius + 0.32, 0.12, (x, y, z0 + 0.18), flag, verts=6, bevel=0.03)
        red, dark_red = self.mat("beacon"), self.mat("ridge")
        floor_z = z0 + 0.24
        for k in range(6):
            a = k * math.tau / 6
            px, py = x + math.cos(a) * radius, y + math.sin(a) * radius
            kit.cyl("buildings", 0.09, col_h, (px, py, floor_z + col_h / 2), red, verts=8)
            kit.cyl("buildings", 0.15, 0.08, (px, py, floor_z + 0.04), self.stone_mat(0), verts=8)
            if k == open_side or (self.w and k in (1, 3)):
                continue
            mid_a = a + math.pi / 6
            mx, my = x + math.cos(mid_a) * radius * math.cos(math.pi / 6), y + math.sin(mid_a) * radius * math.cos(math.pi / 6)
            rot = (0.0, 0.0, a + 2 * math.pi / 3)
            kit.box("buildings", (radius * 0.96, 0.06, 0.06), (mx, my, floor_z + 0.62), red, rot=rot)
            kit.box("buildings", (radius * 0.9, 0.3, 0.06), (mx, my, floor_z + 0.45), self.mat("wood"), bevel=0.01, segments=1, rot=rot)
            kit.box("buildings", (radius * 0.96, 0.05, 0.05), (mx, my, floor_z + 0.2), red, rot=rot)
        kit.cyl("buildings", 0.1, 0.5, (x, y, floor_z + 0.25), self.stone_mat(1), verts=8)
        kit.cyl("buildings", 0.36, 0.08, (x, y, floor_z + 0.54), self.stone_mat(0), verts=10, bevel=0.02)
        if not self.w:
            for a in (math.radians(150), math.radians(270)):
                kit.cyl("buildings", 0.15, 0.36, (x + math.cos(a) * 0.62, y + math.sin(a) * 0.62, floor_z + 0.18), self.stone_mat(1), verts=8)
        kit.piece("roof", x, y, floor_z + col_h)
        kit.cyl("buildings", radius + 0.05, 0.16, (x, y, floor_z + col_h + 0.02), red, verts=6)
        kit.cyl("buildings", radius + 0.95, 0.1, (x, y, floor_z + col_h + 0.1), dark_red, verts=6)
        tilt = (0.07, 0.03, 0.0) if self.w else (0.0, 0.0, 0.0)
        kit.frustum("buildings", radius + 0.92, radius * 0.6, 0.72, (x, y, floor_z + col_h + 0.15 + 0.36), self.mat("slate"), verts=6, rot=tilt)
        if self.w:
            return
        top1 = floor_z + col_h + 0.15 + 0.72
        kit.cyl("buildings", radius * 0.5, 0.32, (x, y, top1 + 0.16), red, verts=6)
        kit.frustum("buildings", radius * 0.74, 0.06, 0.72, (x, y, top1 + 0.32 + 0.36), self.mat("slate_dark"), verts=6)
        kit.sphere("buildings", 0.14, (x, y, top1 + 0.32 + 0.72 + 0.05), self.mat("gold"), segments=8, rings=6)

    def stone_lantern(self, c, r, height=1.25):
        """石灯笼: plinth, pillar, a lit stone lamp box under a square cap with a knob. Withered: out."""
        kit = self.kit
        x, y, z0 = self._at("stone lantern", c, r)
        kit.piece("prop", x, y, z0)
        stone, stone_b = self.stone_mat(0), self.stone_mat(1)
        kit.box("props", (0.52, 0.52, 0.16), (x, y, z0 + 0.08), stone_b, bevel=0.02, segments=1)
        kit.cyl("props", 0.11, height * 0.5, (x, y, z0 + 0.16 + height * 0.25), stone, verts=8)
        kit.box("props", (0.46, 0.46, 0.1), (x, y, z0 + 0.16 + height * 0.5 + 0.05), stone_b, bevel=0.015, segments=1)
        zl = z0 + 0.16 + height * 0.5 + 0.1
        kit.box("props", (0.34, 0.34, 0.34), (x, y, zl + 0.17), self.mat("glass" if self.w else "lantern"), bevel=0.02, segments=1)
        for s in (-1.0, 1.0):
            kit.box("props", (0.05, 0.4, 0.34), (x + s * 0.17, y, zl + 0.17), stone)
            kit.box("props", (0.4, 0.05, 0.34), (x, y + s * 0.17, zl + 0.17), stone)
        kit.frustum("props", 0.48, 0.1, 0.3, (x, y, zl + 0.34 + 0.15), stone_b, verts=4, rot=(0.0, 0.0, math.radians(45)))
        if not self.w:
            kit.sphere("props", 0.07, (x, y, zl + 0.34 + 0.34), stone, segments=8, rings=5)

    def deck(self, c, r, w=2.6, d=2.0, deck_z=None, rails=("+x", "-y")):
        """Wooden viewing platform over the water's edge on piles, railed on the given sides.
        Withered: a plank gap and only the first rail left."""
        kit = self.kit
        x, y = self.s.xy(c, r)
        base = self.s.water_y if self.s.water_y is not None else self.s.heights.get("W", self.s.ground_z(c, r))
        z = deck_z if deck_z is not None else base + 0.4
        kit.piece("ground", x, y, base)
        wood, dark, timber = self.mat("wood"), self.mat("wood_dark"), self.mat("timber")
        if self.w:
            kit.box("props", (w * 0.55, d, 0.12), (x - w * 0.225, y, z), wood, bevel=0.015, segments=1)
            kit.box("props", (w * 0.28, d, 0.12), (x + w * 0.36, y, z), wood, bevel=0.015, segments=1)
        else:
            kit.box("props", (w, d, 0.12), (x, y, z), wood, bevel=0.015, segments=1)
        n = max(2, int(w / 0.4))
        for i in range(n):
            px = x - w / 2 + (i + 0.5) * w / n
            if self.w and w * 0.05 < px - x < w * 0.22:
                continue
            kit.box("props", (0.05, d + 0.02, 0.03), (px, y, z + 0.075), dark)
        for sx in (-1.0, 1.0):
            for sy in (-1.0, 1.0):
                px, py = x + sx * (w / 2 - 0.14), y + sy * (d / 2 - 0.14)
                kit.cyl("props", 0.09, z - base + 1.0, (px, py, base - 0.5 + (z - base + 1.0) / 2), timber, verts=6)
        for side in (rails[:1] if self.w else rails):
            if side in ("+x", "-x"):
                s = 1.0 if side == "+x" else -1.0
                rx = x + s * (w / 2 - 0.06)
                for sy in (-1.0, 1.0):
                    kit.box("props", (0.09, 0.09, 0.72), (rx, y + sy * (d / 2 - 0.1), z + 0.36), dark, bevel=0.012, segments=1)
                kit.box("props", (0.06, d, 0.06), (rx, y, z + 0.7), wood, bevel=0.01, segments=1)
                kit.box("props", (0.05, d, 0.05), (rx, y, z + 0.4), wood)
            else:
                s = 1.0 if side == "+y" else -1.0
                ry = y + s * (d / 2 - 0.06)
                for sx in (-1.0, 1.0):
                    kit.box("props", (0.09, 0.09, 0.72), (x + sx * (w / 2 - 0.1), ry, z + 0.36), dark, bevel=0.012, segments=1)
                kit.box("props", (w, 0.06, 0.06), (x, ry, z + 0.7), wood, bevel=0.01, segments=1)
                kit.box("props", (w, 0.05, 0.05), (x, ry, z + 0.4), wood)

    # --- harbour (尽头港) -----------------------------------------------------------------------

    def boathouse(self, c, r, w=7.0, d=3.6, wall_h=2.3, rise=1.2):
        """Long harbour boathouse: weathered plank walls with a big double door on the quay side,
        a row of small windows, a round gable window, a life ring and a stovepipe; low navy roof.
        Withered: one door leaf gone, windows boarded, the life ring missing, roofing blown off."""
        kit = self.kit
        x, y, z0 = self._at("boathouse", c, r)
        kit.piece("building", x, y, z0)
        plank, plank_dark, trim, navy = self.mat("plank"), self.mat("plank_dark"), self.mat("trim"), self.mat("hull_trim")
        kit.box("buildings", (w, d, wall_h), (x, y, z0 + wall_h / 2), plank, bevel=0.03, segments=1)
        kit.box("buildings", (w + 0.14, d + 0.14, 0.2), (x, y, z0 + 0.1), self.stone_mat(0), bevel=0.02, segments=1)
        apex = z0 + wall_h + rise
        gable = [(y - d / 2, z0 + wall_h - 0.02), (y + d / 2, z0 + wall_h - 0.02), (y, apex - 0.02)]
        kit.prism("buildings", gable, x - w / 2, x + w / 2, plank)
        fy = y - d / 2
        for zz in (0.62, 1.16, 1.7):
            kit.box("buildings", (w - 0.1, 0.03, 0.04), (x, fy - 0.015, z0 + zz), plank_dark)
        for sx in (-1.0, 1.0):
            kit.box("buildings", (0.12, 0.08, wall_h), (x + sx * (w / 2 - 0.04), fy - 0.02, z0 + wall_h / 2), trim)
        dx = x - w * 0.18
        kit.box("buildings", (2.4, 0.08, 2.05), (dx, fy - 0.04, z0 + 1.02), trim, bevel=0.01, segments=1)
        if self.w:
            kit.box("buildings", (2.2, 0.06, 1.9), (dx, fy - 0.08, z0 + 0.95), self.mat("iron"))
            kit.box("buildings", (1.05, 0.06, 1.9), (dx - 0.55, fy - 0.11, z0 + 0.95), navy, rot=(0.0, 0.08, 0.0))
        else:
            kit.box("buildings", (2.2, 0.06, 1.9), (dx, fy - 0.08, z0 + 0.95), navy)
            kit.box("buildings", (0.08, 0.05, 1.9), (dx, fy - 0.11, z0 + 0.95), trim)
            for s in (-1.0, 1.0):
                kit.box("buildings", (0.9, 0.05, 0.07), (dx + s * 0.55, fy - 0.11, z0 + 1.0), trim, rot=(0.0, s * math.radians(-32), 0.0))
        for wx in (x + w * 0.22, x + w * 0.38):
            kit.box("buildings", (0.56, 0.06, 0.56), (wx, fy - 0.03, z0 + wall_h * 0.62), trim, bevel=0.01, segments=1)
            kit.box("buildings", (0.42, 0.04, 0.42), (wx, fy - 0.06, z0 + wall_h * 0.62), self.mat("iron" if self.w else "glass"))
            if self.w:
                self._boards(wx, fy, z0 + wall_h * 0.62, 0.46, 0.46)
            else:
                kit.box("buildings", (0.04, 0.03, 0.42), (wx, fy - 0.08, z0 + wall_h * 0.62), trim)
        ex = x + w / 2
        kit.cyl("buildings", 0.34, 0.08, (ex + 0.02, y, z0 + wall_h + rise * 0.35), trim, verts=12, rot=(0.0, math.pi / 2, 0.0))
        kit.cyl("buildings", 0.24, 0.1, (ex + 0.04, y, z0 + wall_h + rise * 0.35), self.mat("iron" if self.w else "glass"), verts=12,
                rot=(0.0, math.pi / 2, 0.0))
        if not self.w:
            kit.torus("buildings", 0.3, 0.07, (ex + 0.08, y - 0.2, z0 + 1.35), self.mat("trim"), rot=(0.0, math.pi / 2, 0.0))
            for a in (0.0, math.pi):
                kit.box("buildings", (0.1, 0.22, 0.16), (ex + 0.08, y - 0.2 + math.cos(a) * 0.3, z0 + 1.35 + math.sin(a) * 0.3),
                        self.mat("beacon"), bevel=0.02, segments=1)
        else:
            self._ivy(ex, y, z0, d * 0.8, facing="+x")
        self._roof(x, y, z0, w, d, wall_h, rise, 0.3, "navy", chimney=False)
        pipe_tilt = (0.25, 0.0, 0.0) if self.w else (0.0, 0.0, 0.0)
        kit.cyl("buildings", 0.09, 0.9, (x + w * 0.3, y + d * 0.15, apex + 0.2), self.mat("iron"), verts=8, rot=pipe_tilt)
        kit.cyl("buildings", 0.13, 0.08, (x + w * 0.3, y + d * 0.15 - (0.2 if self.w else 0.0), apex + 0.68), self.mat("iron"), verts=8, rot=pipe_tilt)
        self.smoke(x + w * 0.3, y + d * 0.15, apex + 0.78)

    def harbor_tower(self, c, r, side=2.6, height=4.2):
        """Harbour master's house: a tall narrow whitewashed tower with a navy pyramid roof, a
        front balcony and a fluttering pennant. Withered: boarded, balcony rail broken, pennant
        in tatters."""
        kit = self.kit
        x, y, z0 = self._at("harbor tower", c, r)
        kit.piece("building", x, y, z0)
        wall, trim, navy = self.mat("wall"), self.mat("trim"), self.mat("hull_trim")
        kit.box("buildings", (side, side, height), (x, y, z0 + height / 2), wall, bevel=0.03, segments=1)
        kit.box("buildings", (side + 0.2, side + 0.2, 0.3), (x, y, z0 + 0.15), self.stone_mat(0), bevel=0.02, segments=1)
        fy = y - side / 2
        kit.box("buildings", (0.9, 0.06, 1.75), (x, fy - 0.03, z0 + 0.88), trim, bevel=0.01, segments=1)
        kit.box("buildings", (0.78, 0.08, 1.62), (x, fy - 0.06, z0 + 0.81), navy, bevel=0.012, segments=1)
        if self.w:
            self._boards(x, fy, z0 + 0.95, 0.8, 1.4)
        else:
            kit.sphere("buildings", 0.04, (x + 0.25, fy - 0.11, z0 + 0.88), self.mat("beak"), segments=6, rings=4)
        for wx in (x - 0.72, x + 0.72):
            self._window((wx, fy, z0 + height * 0.36), facing="-y", flower_box=False)
        self._window((x, fy, z0 + height * 0.8), facing="-y", flower_box=False)
        self._window((x - side / 2, y, z0 + height * 0.6), facing="-x", flower_box=False)
        self._window((x + side / 2, y, z0 + height * 0.6), facing="+x", flower_box=False)
        bz = z0 + height * 0.56
        kit.box("buildings", (side * 0.82, 0.9, 0.1), (x, fy - 0.42, bz), trim, bevel=0.015, segments=1)
        for sx in (-1.0, 1.0):
            kit.box("buildings", (0.12, 0.4, 0.3), (x + sx * side * 0.32, fy - 0.2, bz - 0.2), navy, bevel=0.01, segments=1)
            if self.w and sx > 0:
                continue
            kit.box("buildings", (0.06, 0.06, 0.62), (x + sx * (side * 0.41 - 0.03), fy - 0.84, bz + 0.36), navy)
            kit.box("buildings", (0.05, 0.84, 0.05), (x + sx * (side * 0.41 - 0.03), fy - 0.42, bz + 0.64), navy)
        if not self.w:
            kit.box("buildings", (side * 0.82, 0.05, 0.05), (x, fy - 0.84, bz + 0.64), navy)
        if self.w:
            self._ivy(x, fy, z0, side, facing="-y")
        kit.piece("roof", x, y, z0 + height)
        diag = math.radians(45)
        r1 = (side / 2 + 0.36) / math.cos(diag)
        kit.frustum("buildings", r1 + 0.03, r1 - 0.04, 0.12, (x, y, z0 + height + 0.06), trim, verts=4, rot=(0.0, 0.0, diag))
        kit.frustum("buildings", r1, 0.05, 1.3, (x, y, z0 + height + 0.12 + 0.65), navy, verts=4, rot=(0.0, 0.0, diag))
        pole_top = z0 + height + 1.4 + 1.5
        kit.cyl("buildings", 0.03, 1.5, (x, y, z0 + height + 1.4 + 0.75), self.mat("iron"), verts=6)
        kit.piece("prop", x, y, pole_top - 0.28, extra=0.2, motion=self.motion(M_FLUTTER))
        if self.w:
            kit.box("buildings", (0.28, 0.02, 0.14), (x + 0.16, y, pole_top - 0.34), self.mat("beacon"), rot=(0.0, 0.0, math.radians(-25)))
        else:
            kit.box("buildings", (0.55, 0.02, 0.26), (x + 0.3, y, pole_top - 0.28), self.mat("beacon"), rot=(0.0, 0.0, math.radians(-25)))

    def crane(self, c, r, angle=0.0, boom=2.4, load="crate"):
        """Timber quay hoist: a post with a raised boom, a pulley, a rope and a hanging crate that
        swings. Withered: the boom drooping, the rope frayed and empty."""
        kit = self.kit
        x, y, z0 = self._at("crane", c, r)
        kit.piece("prop", x, y, z0)
        timber, dark = self.mat("timber"), self.mat("wood_dark")
        ca, sa = math.cos(angle), math.sin(angle)
        kit.cyl("props", 0.32, 0.18, (x, y, z0 + 0.09), self.stone_mat(0), verts=10)
        kit.cyl("props", 0.11, 2.6, (x, y, z0 + 1.3), timber, verts=8)
        tilt = math.radians(14 if self.w else 36)
        ct, st = math.cos(tilt), math.sin(tilt)
        pivot_z = z0 + 2.35
        kit.box("props", (boom, 0.12, 0.14), (x + ca * boom * 0.5 * ct, y + sa * boom * 0.5 * ct, pivot_z + boom * 0.5 * st), dark,
                bevel=0.015, segments=1, rot=(0.0, -tilt, angle))
        brace_dz = boom * 0.55 * st - 0.95
        brace = math.hypot(boom * 0.55 * ct, brace_dz)
        b_tilt = math.atan2(brace_dz, boom * 0.55 * ct)
        kit.box("props", (brace, 0.08, 0.08), (x + ca * boom * 0.275 * ct, y + sa * boom * 0.275 * ct, pivot_z - 0.95 + brace_dz / 2 + 0.475),
                dark, rot=(0.0, -b_tilt, angle))
        tx, ty, tz = x + ca * boom * ct, y + sa * boom * ct, pivot_z + boom * st
        kit.cyl("props", 0.12, 0.08, (tx, ty, tz), self.mat("iron"), verts=10, rot=(math.pi / 2, 0.0, angle))
        kit.piece("prop", tx, ty, tz, extra=0.1, motion=self.motion(M_SWING))
        if self.w:
            kit.cyl("props", 0.02, 0.6, (tx, ty, tz - 0.3), self.mat("rope"), verts=4, rot=(0.2, 0.0, 0.0))
            return
        drop = 1.15
        kit.cyl("props", 0.02, drop, (tx, ty, tz - drop / 2), self.mat("rope"), verts=4)
        if load == "crate":
            kit.box("props", (0.5, 0.5, 0.46), (tx, ty, tz - drop - 0.23), dark, bevel=0.02, segments=1, rot=(0.0, 0.0, angle + 0.3))
            for s in (-0.16, 0.16):
                kit.box("props", (0.54, 0.54, 0.06), (tx, ty, tz - drop - 0.23 + s), self.mat("wood"), rot=(0.0, 0.0, angle + 0.3))
        else:
            kit.box("props", (0.7, 0.5, 0.06), (tx, ty, tz - drop - 0.03), self.mat("net"), rot=(0.0, 0.0, angle + 0.3))

    def net_rack(self, c, r, angle=0.0, width=1.8, height=1.5):
        """Two posts with a crossbar and a fishing net hung out to dry, cork floats along its top;
        the net stirs in the wind. Withered: a torn rag of net, one post leaning."""
        kit = self.kit
        x, y, z0 = self._at("net rack", c, r)
        kit.piece("prop", x, y, z0)
        ca, sa = math.cos(angle), math.sin(angle)
        dark = self.mat("wood_dark")
        for s in (-1.0, 1.0):
            lean = (0.0, 0.2 * s, 0.0) if (self.w and s > 0) else (0.0, 0.0, 0.0)
            kit.box("props", (0.1, 0.1, height), (x + ca * s * width / 2, y + sa * s * width / 2, z0 + height / 2), dark, bevel=0.012, segments=1, rot=lean)
        kit.box("props", (width + 0.2, 0.08, 0.08), (x, y, z0 + height - (0.1 if self.w else 0.0)), dark, rot=(0.0, 0.0, angle))
        kit.piece("prop", x, y, z0 + height, extra=0.1, motion=self.motion(M_SWING))
        if self.w:
            kit.box("props", (width * 0.45, 0.05, height * 0.4), (x - ca * width * 0.2, y - sa * width * 0.2, z0 + height - height * 0.2 - 0.12),
                    self.mat("net"), rot=(0.0, 0.0, angle))
            return
        kit.box("props", (width * 0.92, 0.05, height * 0.7), (x, y, z0 + height - height * 0.35 - 0.06), self.mat("net"), rot=(0.0, 0.0, angle))
        for k in range(3):
            t = (-0.32 + k * 0.32) * width
            kit.sphere("props", 0.08, (x + ca * t, y + sa * t, z0 + height - 0.16), self.mat("buoy"), segments=8, rings=5)

    def bollards(self, points):
        """Iron mooring bollards along a quay edge."""
        for (c, r) in points:
            x, y, z0 = self._at("bollard", c, r)
            self.kit.piece("prop", x, y, z0)
            self.kit.cyl("props", 0.11, 0.42, (x, y, z0 + 0.21), self.mat("iron"), verts=8)
            self.kit.sphere("props", 0.13, (x, y, z0 + 0.44), self.mat("iron"), segments=8, rings=6)

    def traps(self, c, r, count=2, angle=0.0):
        """A stack of slatted lobster traps. Withered: one broken trap on its side."""
        kit = self.kit
        x, y, z0 = self._at("traps", c, r)
        kit.piece("prop", x, y, z0)
        dark, wood = self.mat("wood_dark"), self.mat("wood")
        if self.w:
            kit.box("props", (0.62, 0.4, 0.3), (x, y, z0 + 0.18), self.mat("net"), bevel=0.02, segments=1, rot=(0.5, 0.0, angle))
            for s in (-0.27, 0.27):
                kit.box("props", (0.05, 0.44, 0.34), (x + s * math.cos(angle), y + s * math.sin(angle), z0 + 0.18), dark, rot=(0.5, 0.0, angle))
            return
        for i in range(count):
            a = angle + 0.12 * i
            dz = 0.16 + i * 0.33
            ox, oy = 0.06 * i * math.cos(a), 0.06 * i * math.sin(a)
            kit.box("props", (0.62, 0.4, 0.3), (x + ox, y + oy, z0 + dz), self.mat("net"), bevel=0.02, segments=1, rot=(0.0, 0.0, a))
            for s in (-0.27, 0.0, 0.27):
                kit.box("props", (0.05, 0.44, 0.34), (x + ox + s * math.cos(a), y + oy + s * math.sin(a), z0 + dz), dark, rot=(0.0, 0.0, a))
            kit.box("props", (0.66, 0.05, 0.05), (x + ox, y + oy, z0 + dz + 0.17), wood, rot=(0.0, 0.0, a))
