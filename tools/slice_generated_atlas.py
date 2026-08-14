"""Slice the generated 1024x1024 concept atlas into Godot-ready sprites.

The source has seven sprites in rows 1-5 and eight sprites in row 6.
Each result is normalized to a 256x256 transparent canvas while preserving
the source illustration's relative placement inside its original cell.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image


ROWS: list[tuple[int, list[str]]] = [
    (130, [
        "tile_grass_dense", "tile_grass_sparse", "tile_grass_flowers",
        "tile_grass_stones", "tile_dirt_empty", "tile_dirt_pebbles",
        "tile_dirt_cracked",
    ]),
    (280, [
        "number_1", "number_2", "number_3", "number_4", "number_5",
        "number_6", "number_7",
    ]),
    (432, [
        "number_8", "marker_flag", "mine_basic", "mine_flagged",
        "marker_unknown", "tool_shovel", "tool_pickaxe",
    ]),
    (580, [
        "item_boots", "item_lantern", "item_compass", "item_treasure_map",
        "item_rope", "item_dynamite", "tool_metal_detector",
    ]),
    (735, [
        "potion_heart_red", "potion_shield_blue", "potion_heal_green",
        "potion_star_purple", "potion_luck_yellow", "item_board_map",
        "item_backpack",
    ]),
    (912, [
        "reward_star", "status_burning", "hazard_poison_cauldron",
        "status_frozen", "item_shield", "item_clover", "hazard_skull",
        "hazard_cursed_skull",
    ]),
]


def chroma_to_alpha(image: Image.Image) -> Image.Image:
    """Remove magenta and recover antialiased edge colors from the color key."""
    rgb = image.convert("RGB")
    colors = np.asarray(rgb, dtype=np.float32)
    key = np.array([248.0, 2.0, 244.0], dtype=np.float32)

    red = colors[:, :, 0]
    green = colors[:, :, 1]
    blue = colors[:, :, 2]

    # Estimate how much of the keyed background is present in each pixel.
    # This also turns the generated magenta antialias fringe into partial alpha.
    key_strength = min(key[0], key[2]) - key[1]
    background_fraction = np.clip((np.minimum(red, blue) - green) / key_strength, 0.0, 1.0)
    raw_alpha = 1.0 - background_fraction

    # Generated chroma backgrounds contain colored compression noise. Tighten
    # the matte so those unstable, nearly-transparent pixels do not become a
    # red/cyan fringe after color recovery.
    alpha = np.clip((raw_alpha - 0.28) / 0.72, 0.0, 1.0)

    safe_alpha = np.maximum(raw_alpha[:, :, None], 1.0 / 255.0)
    recovered = (colors - background_fraction[:, :, None] * key) / safe_alpha
    recovered = np.clip(recovered, 0.0, 255.0)

    # Desaturate only the unstable outermost antialias fringe. The source art
    # uses a dark ink contour, so a neutral edge is visually faithful.
    neutral_amount = np.clip((0.72 - raw_alpha) / 0.36, 0.0, 1.0)[:, :, None]
    luminance = (
        recovered[:, :, 0] * 0.299
        + recovered[:, :, 1] * 0.587
        + recovered[:, :, 2] * 0.114
    )[:, :, None]
    recovered = recovered * (1.0 - neutral_amount) + luminance * neutral_amount
    recovered[alpha == 0.0] = 0.0

    rgba = np.empty((*colors.shape[:2], 4), dtype=np.uint8)
    rgba[:, :, :3] = recovered.astype(np.uint8)
    rgba[:, :, 3] = np.round(alpha * 255.0).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def crop_cell(source: Image.Image, row_y: int, column: int, columns: int) -> Image.Image:
    cell_size = source.width / columns
    left = round(column * cell_size)
    right = round((column + 1) * cell_size)
    side = right - left
    top = round(row_y - side / 2)
    bottom = top + side
    return source.crop((left, top, right, bottom))


def normalize_tile(image: Image.Image, padding: int = 4) -> Image.Image:
    """Give every terrain tile the same visible footprint and center."""
    alpha = image.getchannel("A").point(lambda value: 255 if value > 20 else 0)
    bounds = alpha.getbbox()
    if bounds is None:
        return image
    visible = image.crop(bounds)
    target_size = 256 - padding * 2
    visible = visible.convert("RGBa").resize(
        (target_size, target_size), Image.Resampling.LANCZOS
    ).convert("RGBA")
    normalized = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    normalized.alpha_composite(visible, (padding, padding))
    return normalized


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: slice_generated_atlas.py SOURCE OUTPUT_DIR")

    source_path = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    output_dir.mkdir(parents=True, exist_ok=True)

    source = Image.open(source_path).convert("RGB")
    if source.size != (1024, 1024):
        raise ValueError(f"expected a 1024x1024 source atlas, got {source.size}")

    manifest: dict[str, object] = {
        "source": "res://assets/sprites/source/generated_sprite_atlas.png",
        "cell_size": [256, 256],
        "sprite_count": sum(len(names) for _, names in ROWS),
        "sprites": {},
    }

    for row_index, (row_y, names) in enumerate(ROWS):
        columns = len(names)
        for column, name in enumerate(names):
            cell = crop_cell(source, row_y, column, columns)
            cell = chroma_to_alpha(cell)
            # Resize premultiplied RGBA to prevent colored halos at transparent edges.
            cell = cell.convert("RGBa").resize(
                (256, 256), Image.Resampling.LANCZOS
            ).convert("RGBA")
            if name.startswith("tile_"):
                cell = normalize_tile(cell)
            destination = output_dir / f"{name}.png"
            cell.save(destination, optimize=True)
            manifest["sprites"][name] = {
                "path": f"res://assets/sprites/generated/{name}.png",
                "row": row_index,
                "column": column,
            }

    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {manifest['sprite_count']} sprites and {manifest_path}")


if __name__ == "__main__":
    main()
