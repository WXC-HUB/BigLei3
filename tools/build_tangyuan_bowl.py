"""Draw the tangyuan bowl for the long-tailed tit unlock easter egg.

The tangyuan are the tit's own round face, cropped out of the idle frame, so the
"flock merges into a bowl of tangyuan" gag reads at a glance. Output:
my_asset/tangyuan_bowl.png (760x600 RGBA).
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / "my_asset" / "tangyuan_bowl.png"
W, H = 760, 600
INK = (46, 32, 30, 255)


def face_ball(diameter: int) -> Image.Image:
    """A tangyuan: the tit's head (eye + beak + cheek) cropped into a soft white ball."""
    src = Image.open(PROJECT / "my_asset" / "birds" / "tit_idle_4.png").convert("RGBA")
    # Head centre in the 220 frame sits around (150, 92); crop a disc there.
    cx, cy, r = 150, 92, 58
    crop = src.crop((cx - r, cy - r, cx + r, cy + r)).resize((diameter, diameter), Image.LANCZOS)
    ball = Image.new("RGBA", (diameter, diameter), (0, 0, 0, 0))
    base = Image.new("RGBA", (diameter, diameter), (251, 246, 238, 255))
    mask = Image.new("L", (diameter, diameter), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, diameter - 1, diameter - 1), fill=255)
    ball.paste(base, (0, 0), mask)
    # Face pixels on top (crop alpha keeps the beak outline crisp), then a soft shade rim.
    ball.paste(crop, (0, 0), Image.composite(crop.split()[3], Image.new("L", crop.size, 0), mask))
    shade = Image.new("RGBA", (diameter, diameter), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    sd.ellipse((0, 0, diameter - 1, diameter - 1), outline=INK, width=4)
    sd.arc((6, 6, diameter - 7, diameter - 7), 20, 160, fill=(210, 190, 176, 140), width=6)
    ball = Image.alpha_composite(ball, shade)
    return ball


def main() -> None:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Shadow on the table.
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((110, 470, 650, 560), fill=(0, 0, 0, 90))
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(14)))
    d = ImageDraw.Draw(img)
    # Bowl body: a deep blue-green glaze with a lighter band, then the foot.
    d.ellipse((250, 470, 510, 530), fill=(52, 82, 112, 255), outline=INK, width=6)
    body = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    # The body is the lower half of an ellipse centred on the rim line (y=150), so it
    # hangs straight off the rim instead of floating below it.
    body_box = (90, -220, 670, 520)
    bd.chord(body_box, 0, 180, fill=(74, 118, 158, 255))
    bd.chord(body_box, 0, 180, outline=INK, width=6)
    # Glaze band and highlight follow the same curvature.
    bd.arc((118, -150, 642, 492), 30, 150, fill=(110, 160, 196, 255), width=26)
    bd.arc((150, -90, 610, 460), 65, 115, fill=(170, 210, 236, 200), width=10)
    img = Image.alpha_composite(img, body)
    d = ImageDraw.Draw(img)
    # Rim and soup.
    d.ellipse((90, 100, 670, 200), fill=(230, 238, 244, 255), outline=INK, width=6)
    d.ellipse((120, 116, 640, 190), fill=(247, 228, 196, 255), outline=(200, 170, 130, 255), width=3)
    # Tangyuan bobbing in the soup: back row smaller, front row bigger.
    balls = [(230, 118, 88), (380, 108, 92), (525, 120, 86), (300, 150, 104), (455, 152, 108), (380, 176, 96)]
    for x, y, dia in balls:
        ball = face_ball(dia)
        img.alpha_composite(ball, (x - dia // 2, y - dia // 2))
    d = ImageDraw.Draw(img)
    # Steam.
    for sx in (300, 380, 460):
        pts = []
        for i in range(0, 60):
            t = i / 59.0
            pts.append((sx + math.sin(t * math.pi * 2.0) * 14.0, 96.0 - t * 80.0))
        steam = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(steam).line(pts, fill=(255, 255, 255, 170), width=9, joint="curve")
        img = Image.alpha_composite(img, steam.filter(ImageFilter.GaussianBlur(2)))
    img.save(OUT)
    print("wrote", OUT.relative_to(PROJECT), img.size)


if __name__ == "__main__":
    main()
