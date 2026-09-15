"""Build the world map's minimalist trees with Blender (headless) and export them as GLB.

Two variants, flat-shaded, a handful of faces each, so they sit next to KayKit's blocky
buildings as one family instead of the leafy Stylized Nature pines:

* tree_round.glb : trunk + two lightly-bevelled cube canopies (the reference's "cube tree")
* tree_pine.glb  : trunk + three stacked low-poly cones

Model units are chosen for the Grove nodes' existing scale (~0.5): a round tree ends up
about 1.3 world units tall, roughly one KayKit house.

Run from the project root (Steam Blender):
  "D:/Steam/steamapps/common/Blender/blender.exe" -b --python tools/build_clean_trees.py -- assets/nature_clean
"""
import sys
from pathlib import Path

import bpy


def out_dir() -> Path:
    if "--" in sys.argv:
        return Path(sys.argv[sys.argv.index("--") + 1]).resolve()
    return Path("assets/nature_clean").resolve()


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_material(name: str, rgb) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    lin = [srgb_to_linear(v) for v in rgb]
    bsdf.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


def rounded_box(name, size, bevel, segments, location, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(scale=True)
    mod = ob.modifiers.new("Bevel", "BEVEL")
    mod.width = bevel
    mod.segments = segments
    mod.limit_method = "NONE"
    ob.data.materials.append(material)
    return ob


def cylinder(name, radius, depth, location, material, vertices=8):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(material)
    return ob


def cone(name, radius_bottom, radius_top, depth, location, material, vertices=8):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius_bottom, radius2=radius_top, depth=depth, location=location
    )
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(material)
    return ob


def export_glb(path: Path) -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        use_selection=True,
        export_materials="EXPORT",
        export_normals=True,
        export_texcoords=False,
        export_animations=False,
        export_skins=False,
    )


# Target albedos in sRGB, pre-compensated for the map's lighting (lit faces read ~1.0x under the
# current key + ambient). Blender's Principled inputs are scene-linear, so convert before assigning.
LEAF_A = (0.60, 0.73, 0.42)
LEAF_B = (0.66, 0.78, 0.47)
PINE = (0.50, 0.65, 0.42)
TRUNK = (0.52, 0.40, 0.30)


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def build_round_tree(path: Path) -> None:
    reset_scene()
    trunk = make_material("trunk", TRUNK)
    leaf_a = make_material("leaf_a", LEAF_A)
    leaf_b = make_material("leaf_b", LEAF_B)
    cylinder("Trunk", 0.16, 0.9, (0.0, 0.0, 0.45), trunk)
    rounded_box("Canopy", (1.5, 1.5, 1.4), 0.16, 2, (0.0, 0.0, 1.55), leaf_a)
    rounded_box("CanopyTop", (0.9, 0.9, 0.8), 0.10, 2, (0.40, 0.28, 2.45), leaf_b)
    export_glb(path)


def build_pine_tree(path: Path) -> None:
    reset_scene()
    trunk = make_material("trunk", TRUNK)
    pine = make_material("pine", PINE)
    cylinder("Trunk", 0.14, 0.8, (0.0, 0.0, 0.4), trunk)
    cone("Tier1", 0.85, 0.36, 0.9, (0.0, 0.0, 1.05), pine, vertices=8)
    cone("Tier2", 0.64, 0.26, 0.85, (0.0, 0.0, 1.75), pine, vertices=8)
    cone("Tier3", 0.42, 0.0, 0.8, (0.0, 0.0, 2.45), pine, vertices=8)
    export_glb(path)


def main() -> None:
    target = out_dir()
    target.mkdir(parents=True, exist_ok=True)
    build_round_tree(target / "tree_round.glb")
    build_pine_tree(target / "tree_pine.glb")
    print("CLEAN_TREES_DONE", target)


main()
