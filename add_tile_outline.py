from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

SOURCE_DIRS = (Path("ground_tiles"), Path("minesweeper_tiles"))
OUTPUT_ROOT = Path("outlined_tiles")
OUTLINE_WIDTH = 3
OUTLINE_OPACITY = 96  # About 38% opacity.


def add_outline(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A")
    dilated = alpha.filter(ImageFilter.MaxFilter(OUTLINE_WIDTH * 2 + 1))
    outer = ImageChops.subtract(dilated, alpha).point(lambda value: value * OUTLINE_OPACITY // 255)
    outline = Image.new("RGBA", image.size, (255, 255, 255, 0))
    outline.putalpha(outer)
    return Image.alpha_composite(outline, image)


def main() -> None:
    for source_dir in SOURCE_DIRS:
        target_dir = OUTPUT_ROOT / source_dir.name
        target_dir.mkdir(parents=True, exist_ok=True)
        for source in source_dir.glob("*.png"):
            if source.name.startswith("_"):
                continue
            add_outline(Image.open(source)).save(target_dir / source.name)


if __name__ == "__main__":
    main()
