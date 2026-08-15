from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

SOURCE = Path(r"C:\Users\claude.wu\Downloads\upscaled_045c98df-271f-4549-811c-6cbc34aa3784.jpeg")
OUTPUT = Path("minesweeper_tiles")

# Tile bounds measured from the supplied 4096×2336 sheet.
XS = [112, 510, 908, 1302, 1698, 2094, 2484, 2880, 3272, 3672]
YS = [252, 808]
SIZE = 314
NAMES = [
    "center", "edge_n", "edge_s", "edge_e", "edge_w",
    "corner_nw", "corner_ne", "corner_sw", "corner_se", "center_little_grass",
    "center_crack", "center_stain", "center_flower_petal", "center_moss", "center_pebbles",
    "worn_1", "worn_2", "worn_3", "dirty_1", "dirty_2",
]


def remove_outer_magenta(tile: Image.Image) -> Image.Image:
    """Remove only the source sheet's exposed magenta border.

    A geometric mask is used instead of a colour key so pink/brown artwork in
    the worn and dirty tile variants remains untouched.
    """
    alpha = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(alpha).rounded_rectangle((6, 6, SIZE - 7, SIZE - 7), radius=13, fill=255)
    cleaned = tile.copy()
    cleaned.putalpha(ImageChops.multiply(cleaned.getchannel("A"), alpha))
    return cleaned


def main() -> None:
    image = Image.open(SOURCE).convert("RGBA")
    if image.size != (4096, 2336):
        raise ValueError(f"Unexpected source size: {image.size}; expected (4096, 2336)")

    OUTPUT.mkdir(exist_ok=True)
    tiles = []
    for name, (x, y) in zip(NAMES, [(x, y) for y in YS for x in XS]):
        tile = remove_outer_magenta(image.crop((x, y, x + SIZE, y + SIZE)))
        tile.save(OUTPUT / f"{name}.png")
        tiles.append(tile)

    sheet = Image.new("RGBA", (SIZE * 10, SIZE * 2), (0, 0, 0, 0))
    for index, tile in enumerate(tiles):
        sheet.alpha_composite(tile, ((index % 10) * SIZE, (index // 10) * SIZE))
    sheet.save(OUTPUT / "_preview_sheet.png")


if __name__ == "__main__":
    main()
