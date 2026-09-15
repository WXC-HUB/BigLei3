"""把用户给的四张动物图（熊 / 猴 / 企鹅 / 狐狸）抠成带透明通道的游荡动物贴图。

源图是 1254×1254 的扁平插画：单色背景 + 一只动物，动物在右下被画框切断。做法是从画面四
边按颜色距离泛洪，只吃掉和背景同色的连通区域（动物身上的米白肚皮和背景色差得很开，不会
误伤），再贴边裁到主体、按统一高度缩放。

抠完会打印主体贴到画框哪几条边——右/下被切的那部分就是「站在草里」的裁切线，选关图上的
游荡动物按这个高度落地。

跑法（项目根目录）：
  python tools/build_wander_animals.py
输出 assets/sprites/generated/wander/<key>.png
"""
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
SOURCE_DIR = PROJECT / "my_asset/source/wander"
OUT_DIR = PROJECT / "assets/sprites/generated/wander"

## 源文件顺序就是用户发图的顺序。
ANIMALS = [
    {"src": "wander_0.jpg", "key": "bear", "name": "狗熊"},
    {"src": "wander_1.jpg", "key": "monkey", "name": "猴子"},
    {"src": "wander_2.jpg", "key": "penguin", "name": "企鹅"},
    {"src": "wander_3.jpg", "key": "fox", "name": "狐狸"},
]

## 和背景色的距离在这以内算背景（0-255 的欧氏距离）。插画是扁平色块，留一点给 JPEG 噪点。
BG_TOLERANCE = 34.0
## 抠完往里缩一圈再羽化，免得留一圈背景色的硬边。
EDGE_FEATHER = 2
## 统一输出高度，宽按比例。
OUT_HEIGHT = 320


def background_mask(rgb: np.ndarray) -> np.ndarray:
    """从四条边泛洪，标出和背景同色且与边框连通的像素。"""
    h, w, _ = rgb.shape
    # 背景色取四角的中位数：四角一定是背景。
    corners = np.stack([rgb[0, 0], rgb[0, w - 1], rgb[h - 1, 0], rgb[h - 1, w - 1]]).astype(np.float32)
    bg = np.median(corners, axis=0)
    close = np.linalg.norm(rgb.astype(np.float32) - bg, axis=2) <= BG_TOLERANCE

    filled = np.zeros((h, w), bool)
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            if close[y, x] and not filled[y, x]:
                filled[y, x] = True
                queue.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if close[y, x] and not filled[y, x]:
                filled[y, x] = True
                queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and close[ny, nx] and not filled[ny, nx]:
                filled[ny, nx] = True
                queue.append((ny, nx))
    return filled


def cut(spec: dict) -> None:
    src = Image.open(SOURCE_DIR / spec["src"]).convert("RGB")
    rgb = np.asarray(src)
    h, w, _ = rgb.shape
    bg = background_mask(rgb)
    alpha = np.where(bg, 0, 255).astype(np.uint8)

    # 羽化：贴着背景的那一圈半透明，边缘不至于像剪纸。
    for _ in range(EDGE_FEATHER):
        soft = alpha.astype(np.float32)
        pad = np.pad(soft, 1, mode="edge")
        neigh = np.minimum.reduce([pad[:-2, 1:-1], pad[2:, 1:-1], pad[1:-1, :-2], pad[1:-1, 2:]])
        alpha = np.where((alpha > 0) & (neigh == 0), 170, alpha).astype(np.uint8)

    ys, xs = np.nonzero(alpha > 8)
    top, bottom, left, right = ys.min(), ys.max(), xs.min(), xs.max()
    touching = [name for name, hit in (
        ("上", top <= 1), ("下", bottom >= h - 2), ("左", left <= 1), ("右", right >= w - 2)) if hit]

    rgba = np.dstack([rgb, alpha])[top:bottom + 1, left:right + 1]
    out = Image.fromarray(rgba, "RGBA")
    scale = OUT_HEIGHT / out.height
    out = out.resize((max(1, round(out.width * scale)), OUT_HEIGHT), Image.LANCZOS)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / f"{spec['key']}.png"
    out.save(path)
    cover = float((alpha > 8).sum()) / (h * w)
    print(f"{spec['name']:<3} -> {path.relative_to(PROJECT)}  {out.size}  占画面 {cover:.0%}  贴边: {'/'.join(touching) or '无'}")


if __name__ == "__main__":
    for spec in ANIMALS:
        cut(spec)
