# -*- coding: utf-8 -*-
"""生成游戏封面 artifacts/cover/cover.html（1920×1080，静态，精灵图全部内嵌）。

    python tools/build_cover.py

大图（天空、草地岛、羊皮纸、树精、主角）先用 Pillow 缩放并转成 WebP/JPEG 再内嵌，
其余小精灵原样 base64。之后可用 Edge 无头模式截成 PNG，见脚本末尾提示。
"""
import base64
import io
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "artifacts", "cover")
OUT = os.path.join(OUT_DIR, "cover.html")

## key -> (路径, 处理方式)。处理方式：None 原样；("webp", 最大边) 缩放后 WebP（保留透明）；
## ("sky",) 天空专用：裁上半段成 16:9 再存 JPEG。
SPRITES = {
    "sky": ("my_asset/sky.png", ("sky",)),
    "island": ("my_asset/base_01.png", ("webp", 1400)),
    "paper": ("my_asset/panel_01.png", ("webp", 900)),
    "treant": ("my_asset/monster_big.png", ("webp", 640)),
    "hero": ("my_asset/hero_head.png", ("webp", 700)),
    "blue": ("my_asset/birds/blue_find_1.png", None),
    "wood": ("my_asset/birds/attacker_zhuo.png", None),
    "heron": ("my_asset/birds/black_fly_1.png", None),
    "kestrel": ("my_asset/birds/eg_fly_big.png", None),
    "red": ("my_asset/birds/red_fly_1.png", None),
    "jelly": ("my_asset/monster_small.png", None),
    "cloud": ("my_asset/kuang_think_01.png", None),
    "banner": ("my_asset/ach_banner.png", None),
    "turf": ("ground_tiles/revealed_grass.png", None),
    "turf_flower": ("ground_tiles/revealed_small_flowers.png", None),
    "mud": ("assets/sprites/generated/tile_dirt_empty.png", None),
    "n1": ("assets/sprites/generated/number_1.png", None),
    "n2": ("assets/sprites/generated/number_2.png", None),
    "n3": ("assets/sprites/generated/number_3.png", None),
    "flag": ("assets/sprites/generated/marker_flag.png", None),
    "tree1": ("my_asset/tree_01.png", ("webp", 400)),
    "tree2": ("my_asset/tree_02.png", ("webp", 400)),
    "mushroom": ("my_asset/mushroom01.png", ("webp", 400)),
    "rock": ("my_asset/rock_02.png", ("webp", 420)),
    "grass": ("my_asset/grass_flower_05.png", ("webp", 420)),
    "branch": ("my_asset/birds/tree_left_1.png", None),
    "coin": ("my_asset/coin.png", None),
    "heart": ("my_asset/heart.png", None),
    "lantern": ("assets/sprites/generated/bird_items/item_bird_lantern.png", None),
}


def encode(rel, mode):
    path = os.path.join(ROOT, rel)
    if mode is None:
        with open(path, "rb") as handle:
            return "image/png", handle.read()
    image = Image.open(path)
    if mode[0] == "sky":
        # 2000×2000 的天空：取上面 2000×1125 那一段（云在两上角），压成 1920×1080。
        width, height = image.size
        band = image.crop((0, 0, width, int(width * 9 / 16)))
        band = band.convert("RGB").resize((1920, 1080), Image.LANCZOS)
        buffer = io.BytesIO()
        band.save(buffer, "JPEG", quality=86, optimize=True)
        return "image/jpeg", buffer.getvalue()
    limit = mode[1]
    image = image.convert("RGBA")
    if max(image.size) > limit:
        ratio = limit / float(max(image.size))
        image = image.resize((int(image.size[0] * ratio), int(image.size[1] * ratio)), Image.LANCZOS)
    buffer = io.BytesIO()
    image.save(buffer, "WEBP", quality=88, method=6)
    return "image/webp", buffer.getvalue()


def css_vars():
    lines = []
    for key, (rel, mode) in SPRITES.items():
        mime, data = encode(rel, mode)
        lines.append("  --img-%s: url(data:%s;base64,%s);" % (key, mime, base64.b64encode(data).decode("ascii")))
    return "\n".join(lines)


# 棋盘：12 列 × 6 行。'.' 草皮，'f' 带花草皮，'m' 翻开的泥坑，'1/2/3' 带数字的泥坑，
# 'F' 插旗的草皮，'J' 果冻雷所在的泥坑（果冻是另一层放的，这里只留坑）。
BOARD_ROWS = [
    ". . f . . . . . . f . .",
    ". . . . . m 1 1 . . . f",
    ". f . . 1 1 J 2 1 . . .",
    ". . . . 1 F 3 m 1 . f .",
    ". . . . . 1 1 1 . . . .",
    ". . f . . . . . . . . .",
]


def board_html():
    cells = []
    for y, row in enumerate(BOARD_ROWS):
        for x, code in enumerate(row.split()):
            classes = ["cell"]
            inner = ""
            if code == ".":
                classes.append("turf")
            elif code == "f":
                classes.append("turf-flower")
            elif code in ("m", "J"):
                classes.append("mud")
            elif code in ("1", "2", "3"):
                classes.append("mud")
                inner = '<i class="num n%s"></i>' % code
            elif code == "F":
                classes.append("turf")
                inner = '<i class="flag"></i>'
            classes.append("v%d" % ((x * 7 + y * 13) % 5))
            cells.append('<div class="%s">%s</div>' % (" ".join(classes), inner))
    return "\n".join(cells)


def petals_html():
    """飘落的花瓣与光点：确定性伪随机，保证每次生成一样。"""
    parts = []
    state = 7
    def rand():
        nonlocal state
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        return state / float(0x7FFFFFFF)
    for _ in range(26):
        x = 60 + rand() * 1800
        y = 40 + rand() * 640
        size = 10 + rand() * 12
        rot = rand() * 360
        alpha = 0.55 + rand() * 0.4
        pink = rand() > 0.35
        parts.append(
            '<i class="petal%s" style="left:%dpx;top:%dpx;width:%dpx;height:%dpx;'
            'transform:rotate(%ddeg);opacity:%.2f"></i>' % (
                "" if pink else " pale", x, y, size, size * 0.62, rot, alpha))
    for _ in range(9):
        x = 80 + rand() * 1000
        y = 60 + rand() * 420
        size = 14 + rand() * 22
        parts.append('<i class="spark" style="left:%dpx;top:%dpx;width:%dpx;height:%dpx"></i>' % (x, y, size, size))
    return "\n".join(parts)


HTML = u"""<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>咕咕啾啾 · 封面</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=ZCOOL+KuaiLe&family=Noto+Sans+SC:wght@700;900&family=Fredoka:wght@600;700&display=swap">
<style>
:root {
%(vars)s
  --grass: #9db552;
  --grass-deep: #6f8a35;
  --ink: #2e3e27;
  --honey: #f2bd4c;
  --honey-deep: #c8862a;
  --cream: #fff4d6;
  --seal: #c9463a;
  --paper: #e8d3a2;
}
html, body { margin: 0; height: 100%%; background: var(--ink); overflow: hidden; }
body {
  display: grid; place-items: center;
  font-family: "Noto Sans SC", "Microsoft YaHei", "PingFang SC", sans-serif;
  color: var(--ink);
}
#stage {
  position: relative; width: 1920px; height: 1080px; overflow: hidden;
  transform-origin: center center;
  background: var(--img-sky) center / cover no-repeat;
}
#stage > * { position: absolute; }
.sprite, .deco, .tree { background-size: contain; background-repeat: no-repeat; background-position: center; }

/* ---------- 天空层：暖光、光柱、远山、薄雾 ---------- */
.sky-warm {
  inset: 0;
  background:
    radial-gradient(900px 560px at 84%% 4%%, rgba(255,236,170,.72), rgba(255,236,170,0) 70%%),
    linear-gradient(180deg, rgba(255,214,120,.10) 0%%, rgba(255,255,255,0) 40%%, rgba(255,250,220,.35) 58%%, rgba(255,250,220,0) 70%%);
}
.rays {
  left: 900px; top: -200px; width: 1300px; height: 1000px;
  background: repeating-linear-gradient(112deg, rgba(255,255,255,0) 0 70px, rgba(255,255,255,.16) 70px 110px, rgba(255,255,255,0) 110px 190px);
  -webkit-mask-image: radial-gradient(closest-side at 70%% 20%%, rgba(0,0,0,.9), rgba(0,0,0,0));
  mask-image: radial-gradient(closest-side at 70%% 20%%, rgba(0,0,0,.9), rgba(0,0,0,0));
  transform: rotate(-6deg);
}
.hill { border-radius: 50%%; }
.hill.h1 { left: -260px; top: 405px; width: 1500px; height: 520px; background: #b9cf9f; opacity: .9; }
.hill.h2 { left: 1000px; top: 420px; width: 1300px; height: 480px; background: #b3c996; opacity: .9; }
.hill.h3 { left: 380px; top: 470px; width: 1400px; height: 420px; background: #9eb97e; }
.hill.h4 { left: -400px; top: 500px; width: 1200px; height: 360px; background: #93b072; }
.mist {
  left: 0; right: 0; top: 500px; height: 130px;
  background: linear-gradient(180deg, rgba(255,250,225,0) 0%%, rgba(255,250,225,.75) 45%%, rgba(255,250,225,0) 100%%);
}
.treeline-shade {
  left: 0; right: 0; top: 560px; height: 90px;
  background: linear-gradient(180deg, rgba(86,112,42,0), rgba(86,112,42,.65) 60%%, rgba(86,112,42,.9));
}

/* ---------- 远景树线 + 树精 ---------- */
.tree { background-position: bottom center; }
.tree.t1 { background-image: var(--img-tree1); }
.tree.t2 { background-image: var(--img-tree2); }
.treant {
  left: 1215px; top: 205px; width: 540px; height: 540px;
  background-image: var(--img-treant); filter: saturate(.92);
}

/* ---------- 草地岛 + 棋盘 ---------- */
.island {
  left: -60px; top: 455px; width: 2040px; height: 2040px;
  background: var(--img-island) center / contain no-repeat;
  transform: scaleY(.60); transform-origin: 50%% 0;
  filter: drop-shadow(0 30px 24px rgba(46,62,39,.35));
}
.board-wrap {
  left: 0; right: 0; top: 540px; height: 620px; perspective: 1900px; perspective-origin: 50%% -10%%;
}
.board {
  position: absolute; left: 50%%; top: 40px; width: 1800px; margin-left: -900px;
  display: grid; grid-template-columns: repeat(12, 150px); gap: 0;
  transform: rotateX(56deg) translateZ(-40px); transform-origin: 50%% 0;
}
.cell { position: relative; width: 150px; height: 150px; }
.cell::before {
  content: ""; position: absolute; inset: 3px; border-radius: 14px;
  background-size: 100%% 100%%; background-repeat: no-repeat;
  box-shadow: 0 6px 0 rgba(46,62,39,.35);
}
.cell.turf::before { background-image: var(--img-turf); }
.cell.turf-flower::before { background-image: var(--img-turf_flower); }
.cell.mud::before {
  background-image: var(--img-mud); background-size: 116%% 116%%; background-position: center;
  box-shadow: inset 0 10px 18px rgba(0,0,0,.28);
}
.cell.v1::before { filter: brightness(1.04) hue-rotate(-3deg); }
.cell.v2::before { filter: brightness(.96) hue-rotate(4deg); }
.cell.v3::before { filter: brightness(1.02) saturate(1.08); }
.cell.v4::before { filter: brightness(.98) saturate(.94); }
.cell .num {
  position: absolute; left: 12px; top: 8px; width: 126px; height: 126px;
  background-size: contain; background-repeat: no-repeat;
  transform: rotateX(-56deg) translateY(-26px); transform-origin: 50%% 100%%;
}
.cell .n1 { background-image: var(--img-n1); }
.cell .n2 { background-image: var(--img-n2); }
.cell .n3 { background-image: var(--img-n3); }
.cell .flag {
  position: absolute; left: 4px; top: -30px; width: 146px; height: 146px;
  background: var(--img-flag) center / contain no-repeat;
  transform: rotateX(-56deg) translateY(-40px); transform-origin: 50%% 100%%;
}
.ground-shade {
  left: 0; right: 0; bottom: 0; height: 200px;
  background: linear-gradient(180deg, rgba(46,62,39,0), rgba(46,62,39,.5));
}

/* ---------- 前景装饰 ---------- */
.deco { background-position: bottom center; }
.rock { left: 1470px; top: 690px; width: 330px; height: 330px; background-image: var(--img-rock); }
.mushroom { left: 1690px; top: 800px; width: 300px; height: 300px; background-image: var(--img-mushroom); }
.grass-l { left: -40px; top: 720px; width: 380px; height: 380px; background-image: var(--img-grass); }
.grass-r { left: 1560px; top: 880px; width: 300px; height: 300px; background-image: var(--img-grass); transform: scaleX(-1); opacity: .95; }
.petal {
  border-radius: 60%% 60%% 60%% 60%% / 80%% 80%% 40%% 40%%;
  background: linear-gradient(160deg, #ffd7df, #f3a5b4); box-shadow: 0 1px 0 rgba(46,62,39,.25);
}
.petal.pale { background: linear-gradient(160deg, #fff8e6, #ffe6b0); }
.spark {
  background: radial-gradient(circle, rgba(255,255,255,.95) 0 18%%, rgba(255,255,255,0) 20%%),
    linear-gradient(#fff6c8, #fff6c8) 50%% 0 / 14%% 100%% no-repeat,
    linear-gradient(#fff6c8, #fff6c8) 0 50%% / 100%% 14%% no-repeat;
  opacity: .85;
}

/* ---------- 角色 ---------- */
.jelly {
  left: 990px; top: 520px; width: 330px; height: 330px; background-image: var(--img-jelly);
  filter: drop-shadow(0 16px 10px rgba(46,62,39,.35));
  transform-origin: 50%% 100%%; transform: scaleX(1.06) scaleY(.94) rotate(-2deg);
}
.jelly-shock {
  left: 1105px; top: 485px; width: 120px; height: 60px;
  background:
    linear-gradient(var(--ink), var(--ink)) 8px 10px / 6px 34px no-repeat,
    linear-gradient(var(--ink), var(--ink)) 40px 0 / 6px 40px no-repeat,
    linear-gradient(var(--ink), var(--ink)) 74px 8px / 6px 36px no-repeat;
  transform: rotate(-8deg);
}
.blue { left: 760px; top: 640px; width: 290px; height: 290px; background-image: var(--img-blue); filter: drop-shadow(0 14px 8px rgba(46,62,39,.35)); transform: rotate(6deg); }
.wood { left: 1185px; top: 720px; width: 250px; height: 250px; background-image: var(--img-wood); filter: drop-shadow(0 12px 8px rgba(46,62,39,.35)); transform: rotate(-20deg) scaleX(-1); }
.heron { left: 880px; top: 235px; width: 280px; height: 280px; background-image: var(--img-heron); filter: drop-shadow(0 20px 14px rgba(46,62,39,.25)); transform: rotate(8deg); }
.lantern { left: 1075px; top: 405px; width: 96px; height: 96px; background-image: var(--img-lantern); filter: drop-shadow(0 0 26px rgba(255,214,110,.95)) drop-shadow(0 8px 4px rgba(46,62,39,.3)); transform: rotate(10deg); }
.kestrel { left: 1250px; top: 110px; width: 380px; height: 380px; background-image: var(--img-kestrel); filter: drop-shadow(0 26px 16px rgba(46,62,39,.22)); transform: rotate(18deg) scaleX(-1); }
.red { left: 1735px; top: 380px; width: 220px; height: 220px; background-image: var(--img-red); filter: drop-shadow(0 12px 8px rgba(46,62,39,.3)); transform: rotate(-14deg); }
.red-dust { left: 1680px; top: 500px; width: 90px; height: 40px; border-radius: 50%%; background: rgba(255,255,255,.6); box-shadow: -36px 6px 0 -8px rgba(255,255,255,.5), -66px 14px 0 -14px rgba(255,255,255,.4); }
.hero { left: -30px; top: 520px; width: 620px; height: 620px; background-image: var(--img-hero); filter: drop-shadow(0 18px 12px rgba(46,62,39,.35)); }

/* ---------- 气泡 ---------- */
.bubble {
  background: var(--img-cloud) center / 100%% 100%% no-repeat;
  display: grid; place-items: center; text-align: center;
  font-family: "ZCOOL KuaiLe", "Noto Sans SC", "Microsoft YaHei", sans-serif;
  color: var(--ink); line-height: 1.05;
}
.bubble > span { display: block; }
.bubble-jelly { left: 1300px; top: 430px; width: 340px; height: 255px; padding: 30px 50px 62px 50px; font-size: 40px; transform: rotate(4deg); }
.bubble-jelly small { display: block; font-size: 21px; font-family: "Noto Sans SC", sans-serif; font-weight: 700; margin-top: 4px; opacity: .8; line-height: 1.2; }
.bubble-hero { left: 480px; top: 470px; width: 330px; height: 248px; padding: 30px 48px 62px 48px; font-size: 30px; transform: rotate(-5deg) scaleX(-1); }
.bubble-hero > span { transform: scaleX(-1); }
.tag-red {
  left: 1560px; top: 300px; width: 200px; height: 150px;
  background: var(--img-banner) center / contain no-repeat;
  display: grid; place-items: center; padding: 0 20px 0 52px;
  font-family: "ZCOOL KuaiLe", "Noto Sans SC", sans-serif; font-size: 34px; color: var(--ink);
  transform: rotate(-8deg) scaleX(-1);
}
.tag-red > span { transform: scaleX(-1); display: block; }

/* ---------- 标题组：大字 + 缎带 + 印章 ---------- */
.title-block { left: 96px; top: 70px; width: 1000px; height: 460px; }
.title-glow {
  position: absolute; left: -80px; top: -60px; width: 1000px; height: 420px; border-radius: 50%%;
  background: radial-gradient(closest-side, rgba(255,248,220,.85), rgba(255,248,220,0));
}
.title {
  position: absolute; left: 0; top: 0; margin: 0;
  font-family: "ZCOOL KuaiLe", "Noto Sans SC", "Microsoft YaHei", sans-serif;
  font-size: 224px; line-height: 1; letter-spacing: .02em; font-weight: 400;
  color: var(--honey);
  -webkit-text-stroke: 16px var(--ink); paint-order: stroke fill;
  text-shadow: 0 14px 0 var(--ink), 0 22px 0 var(--honey-deep), 0 30px 0 var(--ink), 0 46px 30px rgba(46,62,39,.35);
  transform: rotate(-3deg); white-space: nowrap;
}
.title .a { display: inline-block; transform: translateY(-6px) rotate(-4deg); }
.title .b { display: inline-block; transform: translateY(10px) rotate(3deg); color: #f7d06b; }
.title .c { display: inline-block; transform: translateY(-4px) rotate(-2deg); color: #fbd77e; }
.title .d { display: inline-block; transform: translateY(12px) rotate(5deg); }
.ribbon {
  position: absolute; left: 10px; top: 300px; height: 74px; padding: 0 58px;
  display: flex; align-items: center; justify-content: center;
  font-family: "Noto Sans SC", "Microsoft YaHei", sans-serif; font-weight: 900; font-size: 40px; letter-spacing: .08em; white-space: nowrap;
  color: var(--cream); background: var(--ink);
  clip-path: polygon(0 0, 100%% 0, calc(100%% - 22px) 50%%, 100%% 100%%, 0 100%%, 22px 50%%);
  transform: rotate(-3deg); filter: drop-shadow(0 8px 0 rgba(46,62,39,.35));
}
.ribbon b { color: var(--honey); margin: 0 6px; }
.ribbon::before, .ribbon::after {
  content: ""; position: absolute; top: 12px; left: 22px; right: 22px; height: 0;
  border-top: 2px dashed rgba(255,244,214,.45);
}
.ribbon::after { top: auto; bottom: 12px; }
.seal {
  position: absolute; left: 690px; top: 292px; width: 176px; height: 214px; border-radius: 20px;
  background: var(--seal);
  box-shadow: inset 0 0 0 7px var(--cream), inset 0 0 0 12px var(--seal), inset 0 0 0 14px rgba(255,244,214,.55), 0 10px 0 rgba(46,62,39,.35);
  display: flex; align-items: center; justify-content: center; text-align: center;
  font-family: "ZCOOL KuaiLe", "Noto Sans SC", sans-serif; font-size: 40px; line-height: 1.12; letter-spacing: .08em;
  color: var(--cream); transform: rotate(8deg);
}
.seal > span { display: block; position: relative; z-index: 1; }
.seal::after {
  /* 印泥缺角：像真的盖上去时没沾匀 */
  content: ""; position: absolute; inset: 0; border-radius: 22px;
  background: radial-gradient(circle at 20%% 80%%, rgba(255,244,214,.35) 0 8px, rgba(255,244,214,0) 9px),
    radial-gradient(circle at 78%% 18%%, rgba(255,244,214,.25) 0 6px, rgba(255,244,214,0) 7px);
}

/* ---------- 角标：HUD、羊皮纸评价、页脚 ---------- */
.hud {
  left: 1290px; top: 58px; display: flex; gap: 10px; align-items: center; transform: rotate(-3deg);
  font-family: "Fredoka", "Noto Sans SC", sans-serif; font-weight: 700; font-size: 40px; color: var(--cream);
  -webkit-text-stroke: 6px var(--ink); paint-order: stroke fill; letter-spacing: .04em;
}
.hud i { width: 60px; height: 60px; background-size: contain; background-repeat: no-repeat; display: inline-block; }
.hud .coin { background-image: var(--img-coin); }
.hud .heart { background-image: var(--img-heart); }
.hud span { transform: translateY(2px); }
.paper {
  right: 44px; bottom: 30px; width: 470px; height: 352px;
  background: var(--img-paper) center / 100%% 100%% no-repeat;
  padding: 58px 62px 0 66px; box-sizing: border-box;
  transform: rotate(2deg); filter: drop-shadow(0 12px 10px rgba(46,62,39,.4));
}
.paper .stars { font-family: "Fredoka", sans-serif; font-weight: 700; font-size: 40px; color: var(--honey-deep); letter-spacing: .06em; line-height: 1; }
.paper .quote { font-family: "ZCOOL KuaiLe", "Noto Sans SC", sans-serif; font-size: 34px; margin-top: 10px; line-height: 1.15; color: #4a3a22; }
.paper .who { font-family: "Noto Sans SC", sans-serif; font-weight: 700; font-size: 19px; color: #6a5638; margin-top: 10px; letter-spacing: .04em; }
.footer {
  left: 50%%; bottom: 36px; transform: translateX(-50%%);
  font-family: "Noto Sans SC", sans-serif; font-weight: 900; font-size: 22px; letter-spacing: .22em; color: var(--cream);
  -webkit-text-stroke: 5px var(--ink); paint-order: stroke fill; white-space: nowrap;
}

/* ---------- 画框：墨线双框 + 角落枝叶 ---------- */
.frame {
  inset: 22px; border: 6px solid var(--ink); border-radius: 28px; pointer-events: none;
  box-shadow: inset 0 0 0 5px var(--cream), inset 0 0 0 7px rgba(46,62,39,.35), 0 0 0 5px rgba(255,244,214,.6);
}
.sprig { background-image: var(--img-branch); background-size: contain; background-repeat: no-repeat; pointer-events: none; }
.sprig.tl { left: -30px; top: 8px; width: 300px; height: 225px; transform: rotate(-24deg); }
.sprig.tr { right: -30px; top: 8px; width: 300px; height: 225px; transform: rotate(-24deg) scaleX(-1); }
.vignette { inset: 0; pointer-events: none; background: radial-gradient(ellipse at 50%% 45%%, rgba(0,0,0,0) 58%%, rgba(46,62,39,.26) 100%%); }
.grain {
  inset: 0; pointer-events: none; opacity: .16; mix-blend-mode: multiply;
  background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='2' stitchTiles='stitch'/><feColorMatrix values='0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 .6 0'/></filter><rect width='160' height='160' filter='url(%%23n)'/></svg>");
}
</style>
</head>
<body>
<div id="stage" role="img" aria-label="咕咕啾啾 游戏封面：蓝天草地上的透视扫雷棋盘翻出一只惊慌的果冻雷，蓝鸟举着放大镜凑近看，啄木鸟在旗杆旁敲，夜鹭提灯飞来，红隼从天上俯冲，红尾水鸲已经飞出画外。">
  <div class="sky-warm"></div>
  <div class="rays"></div>
  <div class="hill h1"></div>
  <div class="hill h2"></div>
  <div class="hill h3"></div>
  <div class="hill h4"></div>
  <div class="mist"></div>

  <div class="tree t2" style="left:180px; top:440px; width:150px; height:150px; opacity:.85;"></div>
  <div class="tree t1" style="left:330px; top:420px; width:190px; height:190px; opacity:.9;"></div>
  <div class="tree t2" style="left:560px; top:400px; width:220px; height:220px; opacity:.92;"></div>
  <div class="tree t1" style="left:760px; top:430px; width:180px; height:180px; opacity:.9;"></div>
  <div class="treant sprite"></div>
  <div class="tree t1" style="left:1060px; top:330px; width:300px; height:300px;"></div>
  <div class="tree t2" style="left:1620px; top:430px; width:170px; height:170px; opacity:.9;"></div>
  <div class="treeline-shade"></div>

  <div class="island"></div>
  <div class="board-wrap"><div class="board">
%(board)s
  </div></div>
  <div class="ground-shade"></div>

  <div class="grass-l deco"></div>
  <div class="rock deco"></div>
  <div class="mushroom deco"></div>
  <div class="grass-r deco"></div>

  <div class="jelly sprite"></div>
  <div class="jelly-shock"></div>
  <div class="blue sprite"></div>
  <div class="wood sprite"></div>
  <div class="hero sprite"></div>
  <div class="heron sprite"></div>
  <div class="lantern sprite"></div>
  <div class="kestrel sprite"></div>
  <div class="red-dust"></div>
  <div class="red sprite"></div>

%(petals)s

  <div class="bubble bubble-jelly"><span>别点我！！<small>我真的只是路过</small></span></div>
  <div class="bubble bubble-hero"><span>周围明明<br>都写着 0……</span></div>
  <div class="tag-red"><span>先撤了</span></div>

  <div class="title-block">
    <div class="title-glow"></div>
    <h1 class="title"><span class="a">咕</span><span class="b">咕</span><span class="c">啾</span><span class="d">啾</span></h1>
    <div class="ribbon"><span>扫雷<b>×</b>肉鸽<b>×</b>五只不太靠谱的鸟</span></div>
    <div class="seal"><span>有福<br>同享<br>有难<br>退队</span></div>
  </div>

  <div class="hud"><i class="heart"></i><span>×3</span><i class="coin"></i><span>×37</span></div>
  <div class="paper">
    <div class="stars">★★★★★</div>
    <div class="quote">「炸了 37 次，<br>还想再来一局。」</div>
    <div class="who">—— 一位匿名的、旗插错格的玩家</div>
  </div>

  <div class="frame"></div>
  <div class="sprig tl"></div>
  <div class="sprig tr"></div>
  <div class="vignette"></div>
  <div class="grain"></div>
</div>
<script>
(function () {
  var stage = document.getElementById("stage");
  function fit() {
    var s = Math.min(window.innerWidth / 1920, window.innerHeight / 1080);
    stage.style.transform = "scale(" + s + ")";
  }
  window.addEventListener("resize", fit);
  fit();
})();
</script>
</body>
</html>
"""


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    html = HTML % {"vars": css_vars(), "board": board_html(), "petals": petals_html()}
    with open(OUT, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(html)
    size_mb = os.path.getsize(OUT) / 1024.0 / 1024.0
    print("wrote %s (%.1f MB)" % (OUT, size_mb))
    print("PNG: msedge --headless=new --screenshot=artifacts/cover/cover.png --window-size=1920,1080 "
          "--hide-scrollbars --virtual-time-budget=12000 file:///%s" % OUT.replace("\\", "/"))


if __name__ == "__main__":
    sys.exit(main())
