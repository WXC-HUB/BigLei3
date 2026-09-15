"""Generate the "clean" recolor of KayKit's hexagons_medieval atlas for the world map.

The atlas is an 8x4 grid of vertical-gradient swatches (128x256 each). We keep every
swatch's luminance gradient and only swap the hue of the few loud ones:

* lime grass  -> sage green      (the hex tile tops; the single biggest source of "yellow")
* teal roofs  -> terracotta      (building roofs / trims, matching the warm reference palette)
* bright blue -> dusty blue      (water tiles)

Output: assets/hexmap/clean/hexagons_medieval_clean.png (used by both tiles and buildings).
Run from the project root:  python tools/build_clean_atlas.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/hexmap/tiles/base/hexagons_medieval.png"
OUTPUT = ROOT / "assets/hexmap/clean/hexagons_medieval_clean.png"

COLS, ROWS = 8, 4

# (col, row) -> target albedo (sRGB 0..1). Chosen so that after the map's key light
# (~1.14x on lit faces) the result lands on the reference's muted tones.
RECOLOR = {
    (0, 2): (0.61, 0.70, 0.50),  # #c5cb3b lime grass      -> sage
    (4, 1): (0.56, 0.66, 0.46),  # #94bd56 second green    -> darker sage
    (1, 2): (0.78, 0.46, 0.35),  # #009959 teal (roofs)    -> terracotta
    (3, 3): (0.70, 0.40, 0.31),  # #009959 teal (trims)    -> deeper terracotta
    (1, 1): (0.46, 0.66, 0.78),  # #289ed7 water blue      -> dusty blue
    (0, 1): (0.64, 0.79, 0.86),  # #76bade light blue      -> pale dusty blue
    (0, 3): (0.46, 0.66, 0.78),  # #289ed7 blue (2nd copy) -> dusty blue
}


def luminance(rgb):
    r, g, b = rgb[:3]
    return 0.299 * r + 0.587 * g + 0.114 * b


def main() -> None:
    image = Image.open(SOURCE).convert("RGBA")
    width, height = image.size
    cell_w, cell_h = width // COLS, height // ROWS
    pixels = image.load()
    for (col, row), target in RECOLOR.items():
        x0, y0 = col * cell_w, row * cell_h
        # Mean luminance of the swatch's top half: that is where the models' UVs sample.
        samples = [
            luminance(pixels[x, y])
            for y in range(y0, y0 + cell_h // 2)
            for x in range(x0, x0 + cell_w)
        ]
        mean = max(sum(samples) / len(samples), 1.0)
        for y in range(y0, y0 + cell_h):
            for x in range(x0, x0 + cell_w):
                r, g, b, a = pixels[x, y]
                k = luminance((r, g, b)) / mean
                # Soften the swatch's own gradient a touch: the clean look wants flatter colour.
                k = 1.0 + (k - 1.0) * 0.6
                pixels[x, y] = (
                    min(255, int(round(target[0] * 255 * k))),
                    min(255, int(round(target[1] * 255 * k))),
                    min(255, int(round(target[2] * 255 * k))),
                    a,
                )
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT)
    print("wrote", OUTPUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
