from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

SOURCE = Path(r"C:\Users\claude.wu\Downloads\upscaled_534e861e-4e34-458b-a806-ee2596b6fb20.jpeg")
OUTPUT = Path("ground_tiles")
TILE_SIZE = 330

# Centres are measured from the supplied 4096×2336 source image.
ROWS = [
    (279, [395, 815, 1231, 1639, 2051, 2459], [
        "revealed_plain", "revealed_rock", "revealed_grass", "revealed_small_flowers", "revealed_large_flowers", "revealed_mushroom",
    ]),
    (746, [395, 816, 1231, 1639, 2051, 2458], [
        "fogged_plain", "fogged_rock", "fogged_grass", "fogged_small_flowers", "fogged_large_flowers", "fogged_mushroom",
    ]),
    (1209, [395, 1233, 1639, 2049, 2455, 2856], [
        "special_stream", "special_cracked_ground", "special_mossy_rocks", "special_rock_border", "special_stream_bank", "special_plain",
    ]),
    (1668, [390, 806, 1218, 1627, 2041, 2446], [
        "overlay_none", "overlay_solid_cross", "overlay_faded_cross", "overlay_dashed_cross", "overlay_subtle_cross", "overlay_corners",
    ]),
    (2114, [394, 807, 1220, 1632, 2043, 2450, 2854], [
        "variation_01", "variation_02", "variation_03", "variation_04", "variation_05", "variation_06", "variation_07",
    ]),
]


def rounded_alpha(size: tuple[int, int]) -> Image.Image:
    """Remove only the surrounding sheet background, without colour-keying art."""
    width, height = size
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((6, 6, width - 7, height - 7), radius=12, fill=255)
    return mask


def save_tile(image: Image.Image, name: str, box: tuple[int, int, int, int], rounded: bool = True) -> Image.Image:
    tile = image.crop(box).convert("RGBA")
    if rounded:
        tile.putalpha(ImageChops.multiply(tile.getchannel("A"), rounded_alpha(tile.size)))
    tile.save(OUTPUT / f"{name}.png")
    return tile


def remove_bridge_background(tile: Image.Image) -> Image.Image:
    """Make only the unmistakable magenta sheet background transparent."""
    pixels = tile.load()
    for y in range(tile.height):
        for x in range(tile.width):
            r, g, b, a = pixels[x, y]
            if r > 165 and g < 90 and b > 85 and r - g > 100 and b - g > 30:
                pixels[x, y] = (r, g, b, 0)
    return tile


def main() -> None:
    image = Image.open(SOURCE)
    if image.size != (4096, 2336):
        raise ValueError(f"Unexpected source size: {image.size}")
    OUTPUT.mkdir(exist_ok=True)

    tiles: list[Image.Image] = []
    for center_y, centers_x, names in ROWS:
        for center_x, name in zip(centers_x, names):
            tiles.append(save_tile(image, name, (center_x - 165, center_y - 165, center_x + 165, center_y + 165)))

    # The bridge has posts that extend beyond a normal square tile.
    bridge = remove_bridge_background(image.crop((654, 1020, 984, 1400)).convert("RGBA"))
    bridge.save(OUTPUT / "special_bridge.png")

    # Preview keeps the categories legible; bridge occupies a 340×390 cell.
    preview = Image.new("RGBA", (TILE_SIZE * 7, TILE_SIZE * 5 + 50), (0, 0, 0, 0))
    index = 0
    for row, (_, centers_x, _) in enumerate(ROWS):
        y = row * TILE_SIZE + (50 if row >= 2 else 0)
        if row == 2:
            preview.alpha_composite(tiles[index], (0, y))
            preview.alpha_composite(bridge, (TILE_SIZE, y - 25))
            index += 1
            for col in range(2, 7):
                preview.alpha_composite(tiles[index], (col * TILE_SIZE, y))
                index += 1
        else:
            for col in range(len(centers_x)):
                preview.alpha_composite(tiles[index], (col * TILE_SIZE, y))
                index += 1
    preview.save(OUTPUT / "_preview_sheet.png")


if __name__ == "__main__":
    main()
