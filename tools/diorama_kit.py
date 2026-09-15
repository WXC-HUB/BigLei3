"""Shared Blender (headless) helpers for the stage dioramas.

A diorama is one hand-composed low-poly "display piece": a stepped plateau of grid
cells with painted grass, plus bespoke props (cottage, block trees, fences, ...).
Everything is built from primitives with bevels, flat pastel materials and
smooth-by-angle shading, then joined per group and exported as a single GLB.

Conventions
* 1 cell = 1 world unit. Layouts use (c, r) cell coordinates: c grows to the
  right, r grows toward the viewer (row 0 is the back). Blender x = c - cols/2,
  Blender y = rows/2 - r, so with the exporter's Y-up conversion the front of the
  map is +Z in Godot and a camera at +X/+Z looks at it from the front-right.
* Colours are given as sRGB hex; Principled inputs are scene-linear so they are
  converted. Lighting in Godot is calibrated so lit tops read ~1.0x the albedo.
* The plateau top is textured (painted with GroundPainter); walls, props and the
  stream bed use plain materials.

Used by tools/build_diorama_*.py; run those with Steam Blender:
  "D:/Steam/steamapps/common/Blender/blender.exe" -b --python tools/build_diorama_grass_1.py
"""
import math
import random
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Matrix


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgb(h: str):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def hex_np(h: str) -> np.ndarray:
    return np.array(hex_rgb(h), np.float32)


def box_blur(a: np.ndarray, r: int) -> np.ndarray:
    """Separable box blur with edge padding; call three times for a gaussian-ish falloff."""
    if r <= 0:
        return a
    for axis in (0, 1):
        pad = [(r + 1, r) if ax == axis else (0, 0) for ax in (0, 1)]
        cs = np.cumsum(np.pad(a, pad, mode="edge"), axis=axis)
        if axis == 0:
            a = (cs[2 * r + 1:, :] - cs[:-(2 * r + 1), :]) / (2 * r + 1)
        else:
            a = (cs[:, 2 * r + 1:] - cs[:, :-(2 * r + 1)]) / (2 * r + 1)
    return a


def soft_blur(a: np.ndarray, r: int) -> np.ndarray:
    for _ in range(3):
        a = box_blur(a, max(1, r // 2))
    return a


class Kit:
    """Primitive factory + material cache + group registry for one diorama."""

    TOP, BED, CAP, UP, LOW = range(5)

    def __init__(self, seed: int = 1):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.rng = random.Random(seed)
        self._mats = {}
        self.groups = {}
        # Entrance animation ("build-up"): every primitive belongs to the current piece and
        # pops around that piece's pivot at that piece's start time. See piece().
        self.delay_fn = None
        self.anim_span = 1.35
        self.anim_bounds = ((-16.0, -3.0, -12.0), (32.0, 10.0, 24.0))
        self._anim = None
        self._motion = None

    def piece(self, kind: str, x: float, y: float, z: float, extra: float = 0.0, motion=None) -> None:
        """Start a new entrance piece: primitives taken from now on pop as one unit around the
        Blender-space pivot (x, y, z), starting at delay_fn(kind, x, y, extra) seconds.
        `motion` = (kind_id, phase) gives the piece an idle animation in the Godot shader
        (sway / bob / rock / spin / swing / smoke / flutter / fly / swim / float), also around
        this pivot; it is written into the "Motion" UV layer (TEXCOORD_1) at finalize."""
        delay = float(self.delay_fn(kind, x, y, extra)) if self.delay_fn is not None else 0.3
        self._anim = (float(x), float(y), float(z), delay)
        self._motion = (int(motion[0]), float(motion[1])) if motion is not None else None

    # --- materials -------------------------------------------------------------------

    def mat(self, name: str, hexcolor: str = "#ffffff", roughness: float = 1.0, image=None):
        if name in self._mats:
            return self._mats[name]
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        r, g, b = hex_rgb(hexcolor)
        bsdf.inputs["Base Color"].default_value = (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        if "IOR Level" in bsdf.inputs:
            bsdf.inputs["IOR Level"].default_value = 0.2
        if image is not None:
            tex = m.node_tree.nodes.new("ShaderNodeTexImage")
            tex.image = image
            tex.interpolation = "Linear"
            m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        self._mats[name] = m
        return m

    # --- registry ---------------------------------------------------------------------

    def _take(self, group: str, ob, flat: bool = False):
        if flat:
            ob["flat_shade"] = 1
        if self._anim is not None:
            ob["anim"] = list(self._anim)
        if self._motion is not None:
            ob["motion"] = [float(self._motion[0]), float(self._motion[1])]
        self.groups.setdefault(group, []).append(ob)
        return ob

    @staticmethod
    def _bevel(ob, width: float, segments: int, limit: str = "NONE", angle: float = math.radians(60)):
        """Bevel the object's mesh in place with bmesh (applied immediately, so merging later
        never has to evaluate modifiers). limit="ANGLE" only bevels edges sharper than `angle`."""
        me = ob.data
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.normal_update()
        if limit == "ANGLE":
            edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) >= angle]
        else:
            edges = bm.edges[:]
        if edges:
            bmesh.ops.bevel(bm, geom=edges, offset=width, offset_type="OFFSET", segments=segments, profile=0.5,
                            affect="EDGES", clamp_overlap=True, loop_slide=True, material=-1)
        bm.to_mesh(me)
        bm.free()
        me.update()

    # --- primitives -------------------------------------------------------------------

    def box(self, group, size, loc, mat, bevel=0.0, segments=2, rot=(0.0, 0.0, 0.0), flat=False):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
        ob = bpy.context.active_object
        ob.scale = size
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        ob.data.materials.append(mat)
        if bevel > 0.0:
            self._bevel(ob, bevel, segments, "NONE")
        return self._take(group, ob, flat)

    def cyl(self, group, radius, depth, loc, mat, verts=12, rot=(0.0, 0.0, 0.0), bevel=0.0, segments=2, flat=False):
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
        ob = bpy.context.active_object
        ob.data.materials.append(mat)
        if bevel > 0.0:
            self._bevel(ob, bevel, segments, "ANGLE", math.radians(60))
        return self._take(group, ob, flat)

    def frustum(self, group, r1, r2, depth, loc, mat, verts=4, rot=(0.0, 0.0, 0.0), bevel=0.0, segments=2, flat=False):
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
        ob = bpy.context.active_object
        ob.data.materials.append(mat)
        if bevel > 0.0:
            self._bevel(ob, bevel, segments, "NONE")
        return self._take(group, ob, flat)

    def sphere(self, group, radius, loc, mat, scale=(1.0, 1.0, 1.0), segments=14, rings=9, rot=(0.0, 0.0, 0.0), flat=False):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=loc, rotation=rot)
        ob = bpy.context.active_object
        ob.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        ob.data.materials.append(mat)
        return self._take(group, ob, flat)

    def rock(self, group, radius, loc, mat, scale=(1.0, 0.85, 0.6), rot=(0.0, 0.0, 0.0)):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=loc, rotation=rot)
        ob = bpy.context.active_object
        ob.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        ob.data.materials.append(mat)
        return self._take(group, ob, flat=True)

    def torus(self, group, major, minor, loc, mat, rot=(0.0, 0.0, 0.0), seg_major=14, seg_minor=7):
        bpy.ops.mesh.primitive_torus_add(major_segments=seg_major, minor_segments=seg_minor, major_radius=major,
                                         minor_radius=minor, location=loc, rotation=rot)
        ob = bpy.context.active_object
        ob.data.materials.append(mat)
        return self._take(group, ob)

    def prism(self, group, profile, x0, x1, mat, flat=False):
        """Extrude a closed (y, z) polygon along X between x0 and x1 (roof and gable shapes)."""
        bm = bmesh.new()
        front = [bm.verts.new((x0, y, z)) for (y, z) in profile]
        back = [bm.verts.new((x1, y, z)) for (y, z) in profile]
        bm.faces.new(front[::-1])
        bm.faces.new(back)
        n = len(profile)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((front[i], front[j], back[j], back[i]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new("Prism")
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mat)
        ob = bpy.data.objects.new("Prism", me)
        bpy.context.scene.collection.objects.link(ob)
        return self._take(group, ob, flat)

    # --- terrain ----------------------------------------------------------------------

    def terrain(self, mask, heights, mats, bottom=-2.4, seam=-1.25, cap=0.14, bevel=0.07, name="Terrain", bed_chars="W"):
        """Stepped plateau from an ASCII mask.

        mask    : list of equal-length strings; '.' empty, other chars index `heights`.
        heights : {'L': 0.0, 'U': 0.9, 'W': -0.45}; 'L'/'U' tops are textured grass,
                  anything else (the stream bed) uses the plain `bed` material.
        mats    : dict top/bed/cap/cliff_up/cliff_low.
        Every cell gets its own top quad (UV = cell position over the whole grid) and
        outward walls wherever the neighbour is lower, split into strata bands; the
        convex rim between tops and walls is bevelled so the edge reads soft.
        """
        rows, cols = len(mask), len(mask[0])
        for line in mask:
            assert len(line) == cols, "mask rows must have equal length"
        bm = bmesh.new()
        uv_layer = bm.loops.layers.uv.new("UVMap")
        # Every non-negative height is textured grass except the water beds (any level).
        grass = {k for k, v in heights.items() if v >= 0.0 and k not in bed_chars}

        def cell(c, r):
            return mask[r][c] if 0 <= r < rows and 0 <= c < cols else "."

        def top_z(t):
            return heights.get(t)

        def xy(c, r):
            return (c - cols / 2.0, rows / 2.0 - r)

        for r in range(rows):
            for c in range(cols):
                t = cell(c, r)
                zt = top_z(t)
                if zt is None:
                    continue
                x0, y0 = xy(c, r + 1)
                x1, y1 = xy(c + 1, r)
                quad = [bm.verts.new((x0, y0, zt)), bm.verts.new((x1, y0, zt)),
                        bm.verts.new((x1, y1, zt)), bm.verts.new((x0, y1, zt))]
                face = bm.faces.new(quad)
                face.material_index = self.TOP if t in grass else self.BED
                uvs = [(c / cols, 1 - (r + 1) / rows), ((c + 1) / cols, 1 - (r + 1) / rows),
                       ((c + 1) / cols, 1 - r / rows), (c / cols, 1 - r / rows)]
                for loop, tuv in zip(face.loops, uvs):
                    loop[uv_layer].uv = tuv
                edges = (((0, 1), (x0, y0), (x1, y0)), ((1, 0), (x1, y0), (x1, y1)),
                         ((0, -1), (x1, y1), (x0, y1)), ((-1, 0), (x0, y1), (x0, y0)))
                for (dc, dr), a, b in edges:
                    zn = top_z(cell(c + dc, r + dr))
                    if zn is None:
                        zn = bottom
                    if zn >= zt:
                        continue
                    for za, zb, m in self._wall_bands(zn, zt, t in grass, seam, cap):
                        wall = [bm.verts.new((a[0], a[1], za)), bm.verts.new((b[0], b[1], za)),
                                bm.verts.new((b[0], b[1], zb)), bm.verts.new((a[0], a[1], zb))]
                        wf = bm.faces.new(wall)
                        wf.material_index = m
                        for loop in wf.loops:
                            loop[uv_layer].uv = (0.0, 0.0)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bm.normal_update()
        rim = []
        for e in bm.edges:
            if len(e.link_faces) != 2:
                continue
            f1, f2 = e.link_faces
            n1, n2 = f1.normal, f2.normal
            top_wall = (n1.z > 0.9 and abs(n2.z) < 0.1) or (n2.z > 0.9 and abs(n1.z) < 0.1)
            if not top_wall:
                continue
            mid = (e.verts[0].co + e.verts[1].co) * 0.5
            centre = (f1.calc_center_median() + f2.calc_center_median()) * 0.5
            if (n1 + n2).dot(mid - centre) > 0.0:
                rim.append(e)
        if rim and bevel > 0.0:
            bmesh.ops.bevel(bm, geom=rim, offset=bevel, offset_type="OFFSET", segments=2, profile=0.5,
                            affect="EDGES", clamp_overlap=True, loop_slide=True, material=-1)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for key in ("top", "bed", "cap", "cliff_up", "cliff_low"):
            me.materials.append(mats[key])
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return self._take("terrain", ob)

    def _wall_bands(self, zn, zt, has_cap, seam, cap):
        cuts = {zn, zt}
        if zn < seam < zt:
            cuts.add(seam)
        cap_z = zt - cap if has_cap else zt
        if zn < cap_z < zt:
            cuts.add(cap_z)
        cuts = sorted(cuts)
        bands = []
        for za, zb in zip(cuts[:-1], cuts[1:]):
            mid = (za + zb) * 0.5
            if has_cap and mid > cap_z:
                m = self.CAP
            elif mid < seam:
                m = self.LOW
            else:
                m = self.UP
            bands.append((za, zb, m))
        return bands

    # --- finishing --------------------------------------------------------------------

    def finalize(self, smooth_angle_deg: float = 35.0):
        """Merge each group into one mesh object.

        Parts are plain meshes (bevels were applied at creation), so this just bakes each
        part's own transform, remaps material slots and rebuilds the faces in one bmesh, then
        sets smooth-by-angle shading (parts flagged flat_shade stay faceted). The originals
        are unlinked from the scene; only the merged objects get exported.
        """
        threshold = math.radians(smooth_angle_deg)
        (pmin, psize) = self.anim_bounds
        merged_objects = {}
        for group, objs in self.groups.items():
            bm = bmesh.new()
            uv_layer = bm.loops.layers.uv.new("UVMap")
            mo_layer = bm.loops.layers.uv.new("Motion")
            slots = []
            anim_rows = []
            for ob in objs:
                me = ob.data
                src_uv = me.uv_layers.active.data if me.uv_layers else None
                motion = ob.get("motion", None)
                mo_uv = ((float(motion[0]) + 0.5) / 32.0, float(motion[1])) if motion is not None else (0.5 / 32.0, 0.0)
                remap = []
                for m in me.materials:
                    if m not in slots:
                        slots.append(m)
                    remap.append(slots.index(m))
                matrix = Matrix.LocRotScale(ob.location, ob.rotation_euler, ob.scale)
                verts = [bm.verts.new(matrix @ v.co) for v in me.vertices]
                anim_rows.append((self._encode_anim(ob, matrix, me), len(verts)))
                flat = bool(ob.get("flat_shade", 0))
                for poly in me.polygons:
                    try:
                        face = bm.faces.new([verts[i] for i in poly.vertices])
                    except ValueError:
                        continue
                    face.material_index = remap[poly.material_index] if remap else 0
                    face.smooth = not flat
                    for loop, li in zip(face.loops, poly.loop_indices):
                        if src_uv is not None:
                            loop[uv_layer].uv = src_uv[li].uv
                        loop[mo_layer].uv = mo_uv
            bm.normal_update()
            for e in bm.edges:
                if len(e.link_faces) != 2 or not (e.link_faces[0].smooth and e.link_faces[1].smooth):
                    e.smooth = False
                else:
                    e.smooth = e.calc_face_angle(0.0) <= threshold
            merged = bpy.data.meshes.new(group.capitalize())
            bm.to_mesh(merged)
            bm.free()
            for m in slots:
                merged.materials.append(m)
            self._write_anim_attribute(merged, anim_rows)
            merged.update()
            out = bpy.data.objects.new(group.capitalize(), merged)
            bpy.context.scene.collection.objects.link(out)
            merged_objects[group] = out
        for objs in self.groups.values():
            for ob in objs:
                for collection in list(ob.users_collection):
                    collection.objects.unlink(ob)
        self.merged = merged_objects
        return merged_objects

    def _encode_anim(self, ob, matrix, me):
        """(r, g, b, a) for every vertex of this part: pivot in Godot space normalised into
        anim_bounds, and the start time as a fraction of anim_span. Parts without a piece
        pop from their own base centre a little after the terrain has landed."""
        anim = ob.get("anim", None)
        if anim is None:
            xs = [(matrix @ v.co) for v in me.vertices]
            if xs:
                cx = sum(p.x for p in xs) / len(xs)
                cy = sum(p.y for p in xs) / len(xs)
                cz = min(p.z for p in xs)
            else:
                cx = cy = cz = 0.0
            anim = (cx, cy, cz, 0.3)
        bx, by, bz, delay = anim
        gx, gy, gz = bx, bz, -by                      # Blender Z-up -> Godot Y-up
        (mx, my, mz), (sx, sy, sz) = self.anim_bounds
        enc = (
            min(max((gx - mx) / sx, 0.0), 1.0),
            min(max((gy - my) / sy, 0.0), 1.0),
            min(max((gz - mz) / sz, 0.0), 1.0),
            min(max(delay / self.anim_span, 0.0), 1.0),
        )
        return enc

    @staticmethod
    def _write_anim_attribute(me, anim_rows) -> None:
        total = sum(n for _, n in anim_rows)
        if total != len(me.vertices):
            raise RuntimeError(f"anim attribute vertex count mismatch {total} != {len(me.vertices)}")
        flat = []
        for enc, n in anim_rows:
            flat.extend(enc * n)
        attr = me.color_attributes.new(name="Anim", type="FLOAT_COLOR", domain="POINT")
        attr.data.foreach_set("color", flat)
        idx = me.color_attributes.find("Anim")
        me.color_attributes.active_color_index = idx
        me.color_attributes.render_color_index = idx


def export_glb(path: Path, objects=None) -> None:
    """Export the given objects (default: everything still linked in the scene) as one GLB."""
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    targets = list(objects) if objects is not None else list(bpy.context.scene.collection.all_objects)
    for ob in targets:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = targets[0]
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        use_selection=True,
        export_materials="EXPORT",
        export_normals=True,
        export_texcoords=True,
        export_animations=False,
        export_skins=False,
        export_image_format="AUTO",
        # The "Anim" colour attribute carries entrance pivots/timing, not colour: export it
        # regardless of whether a material reads it.
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
    )


class GroundPainter:
    """Paints the plateau-top albedo: two-tone checker grass, soft sand paths and contact AO.

    Works in cell coordinates (c, r) like the layout; pixel (0, 0) is the back-left
    corner, matching the terrain UVs.
    """

    def __init__(self, cols: int, rows: int, px: int = 64, seed: int = 3, tint=None):
        """`tint` (optional callable hex -> hex) recolours every colour the painter is given;
        the withered variants pass `wither_hex` so the whole ground dries out at once."""
        self.cols, self.rows, self.px = cols, rows, px
        self.tint = tint
        self.w, self.h = cols * px, rows * px
        self.rng = np.random.default_rng(seed)
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        self.cx = ((xx + 0.5) / px).astype(np.float32)
        self.cy = ((yy + 0.5) / px).astype(np.float32)
        self.img = np.zeros((self.h, self.w, 3), np.float32)
        self.sand = np.zeros((self.h, self.w), np.float32)
        self.ao = np.zeros((self.h, self.w), np.float32)

    def _c(self, h: str) -> np.ndarray:
        return hex_np(self.tint(h) if self.tint is not None else h)

    def checker(self, a: str, b: str, noise: float = 0.010) -> None:
        parity = (np.floor(self.cx) + np.floor(self.cy)) % 2
        col = np.where(parity[..., None] == 0, self._c(a), self._c(b))
        # Low-frequency mottling so big lawns do not read as a flat fill.
        mottle = soft_blur(self.rng.normal(0.0, 1.0, (self.h, self.w)).astype(np.float32), self.px)
        mottle = mottle / (np.abs(mottle).max() + 1e-6) * 0.018
        grain = self.rng.normal(0.0, noise, (self.h, self.w, 1)).astype(np.float32)
        self.img = np.clip(col + mottle[..., None] + grain, 0.0, 1.0)

    def stripes(self, a: str, b: str, furrow: str, period: float = 1.0, furrow_width: float = 0.16,
                along: str = "x", noise: float = 0.010) -> None:
        """Crop rows: bands of a/b alternating across the field with a dark furrow line between
        rows. `along="x"` makes rows run left-right (they vary with r)."""
        coord = self.cy if along == "x" else self.cx
        band = np.floor(coord / period) % 2
        col = np.where(band[..., None] == 0, self._c(a), self._c(b))
        frac = (coord / period) % 1.0
        furrow_mask = np.clip(1.0 - np.abs(frac - furrow_width * 0.5) / (furrow_width * 0.5), 0.0, 1.0)
        col = col * (1.0 - furrow_mask[..., None] * 0.85) + self._c(furrow) * (furrow_mask[..., None] * 0.85)
        mottle = soft_blur(self.rng.normal(0.0, 1.0, (self.h, self.w)).astype(np.float32), self.px)
        mottle = mottle / (np.abs(mottle).max() + 1e-6) * 0.02
        grain = self.rng.normal(0.0, noise, (self.h, self.w, 1)).astype(np.float32)
        self.img = np.clip(col + mottle[..., None] + grain, 0.0, 1.0).astype(np.float32)

    def cobbles(self, a: str, b: str, joint: str, cell: float = 0.5, joint_width: float = 0.05, noise: float = 0.012) -> None:
        """Cobbled paving: a grid of half-cell stones with random tints and thin dark joints,
        rows offset by half a stone."""
        row = np.floor(self.cy / cell)
        shift = (row % 2) * cell * 0.5
        col_i = np.floor((self.cx + shift) / cell)
        seed = np.sin(col_i * 12.9898 + row * 78.233) * 43758.5453
        tint = (seed - np.floor(seed))[..., None]
        col = self._c(a) * (1.0 - tint) + self._c(b) * tint
        fx = ((self.cx + shift) / cell) % 1.0
        fy = (self.cy / cell) % 1.0
        edge = np.minimum(np.minimum(fx, 1.0 - fx), np.minimum(fy, 1.0 - fy)) * cell
        joint_mask = np.clip(1.0 - edge / joint_width, 0.0, 1.0)
        col = col * (1.0 - joint_mask[..., None] * 0.9) + self._c(joint) * (joint_mask[..., None] * 0.9)
        grain = self.rng.normal(0.0, noise, (self.h, self.w, 1)).astype(np.float32)
        self.img = np.clip(col + grain, 0.0, 1.0).astype(np.float32)

    def paint_cells(self, mask, chars: str, painter, feather_cells: float = 0.3) -> None:
        """Paint a different ground on every mask cell whose char is in `chars`. `painter` is a
        callable(GroundPainter) that fills a scratch painter (same size) with the other ground;
        the two are blended with a soft edge."""
        scratch = GroundPainter(self.cols, self.rows, self.px, seed=int(self.rng.integers(1, 1 << 30)), tint=self.tint)
        painter(scratch)
        sel = np.zeros((self.rows, self.cols), np.float32)
        for r, line in enumerate(mask):
            for c, ch in enumerate(line):
                if ch in chars:
                    sel[r, c] = 1.0
        field = np.repeat(np.repeat(sel, self.px, axis=0), self.px, axis=1)
        field = np.clip(soft_blur(field, int(feather_cells * self.px)), 0.0, 1.0)
        # Re-sharpen a little so the blend stays inside ~half a cell of the boundary.
        field = np.clip((field - 0.35) / 0.3, 0.0, 1.0)
        self.img = (self.img * (1.0 - field[..., None]) + scratch.img * field[..., None]).astype(np.float32)

    def _dist_polyline(self, points) -> np.ndarray:
        d = np.full((self.h, self.w), 1e9, np.float32)
        for (ax, ay), (bx, by) in zip(points[:-1], points[1:]):
            vx, vy = bx - ax, by - ay
            l2 = max(vx * vx + vy * vy, 1e-9)
            t = np.clip(((self.cx - ax) * vx + (self.cy - ay) * vy) / l2, 0.0, 1.0)
            d = np.minimum(d, np.hypot(self.cx - (ax + t * vx), self.cy - (ay + t * vy)))
        return d

    def path(self, points, width: float, strength: float = 1.0, wobble: float = 0.12) -> None:
        d = self._dist_polyline(points)
        if wobble > 0.0:
            noise = soft_blur(self.rng.normal(0.0, 1.0, (self.h, self.w)).astype(np.float32), self.px // 2)
            d = d + noise / (np.abs(noise).max() + 1e-6) * wobble
        m = np.clip(1.0 - (d - width * 0.5) / (width * 0.35), 0.0, 1.0)
        self.sand = np.maximum(self.sand, m * strength)

    def patch(self, c: float, r: float, radius: float, strength: float = 1.0, target: str = "sand") -> None:
        d = np.hypot(self.cx - c, self.cy - r)
        m = np.clip(1.0 - d / radius, 0.0, 1.0)
        m = m * m * (3.0 - 2.0 * m)
        if target == "sand":
            self.sand = np.maximum(self.sand, m * strength)
        else:
            self.ao = np.maximum(self.ao, m * strength)

    def rect_ao(self, c0: float, r0: float, c1: float, r1: float, feather: float, strength: float = 1.0) -> None:
        dx = np.maximum(np.maximum(c0 - self.cx, self.cx - c1), 0.0)
        dy = np.maximum(np.maximum(r0 - self.cy, self.cy - r1), 0.0)
        d = np.hypot(dx, dy)
        m = np.clip(1.0 - d / feather, 0.0, 1.0)
        self.ao = np.maximum(self.ao, m * strength)

    def finish(self, sand: str, sand_dark: str, ao_strength: float = 0.16, edge_blur_cells: float = 0.22) -> None:
        sand_mask = soft_blur(self.sand, int(edge_blur_cells * self.px))
        sand_mask = np.clip(sand_mask, 0.0, 1.0)
        # Sand is slightly darker where it is thick (the middle of a path) than at the fringe.
        core = np.clip((sand_mask - 0.55) / 0.45, 0.0, 1.0)
        sand_col = self._c(sand)[None, None, :] * (1.0 - core[..., None]) + self._c(sand_dark)[None, None, :] * core[..., None]
        grain = self.rng.normal(0.0, 0.008, (self.h, self.w, 1)).astype(np.float32)
        sand_col = np.clip(sand_col + grain, 0.0, 1.0)
        self.img = self.img * (1.0 - sand_mask[..., None]) + sand_col * sand_mask[..., None]
        ao = np.clip(soft_blur(self.ao, int(0.35 * self.px)), 0.0, 1.0)
        self.img = np.clip(self.img * (1.0 - ao_strength * ao)[..., None], 0.0, 1.0)

    def save(self, path: Path, name: str = "ground"):
        path.parent.mkdir(parents=True, exist_ok=True)
        rgba = np.concatenate([self.img, np.ones((self.h, self.w, 1), np.float32)], axis=2)
        # Image.pixels wants float32; some painter ops promote to float64 along the way.
        flat = np.ascontiguousarray(rgba[::-1], dtype=np.float32).ravel()
        img = bpy.data.images.new(name, width=self.w, height=self.h, alpha=False, float_buffer=False)
        img.pixels.foreach_set(flat)
        img.filepath_raw = str(path)
        img.file_format = "PNG"
        img.save()
        return img
