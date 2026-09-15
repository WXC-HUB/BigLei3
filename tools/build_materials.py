# -*- coding: utf-8 -*-
"""线下物料素材（HTML → PNG，Edge 无头渲染），按物料分文件夹放到 artifacts/materials/：

  01_窗贴/       透明底小元素：Logo（矢量）、果冻雷翻坑组合、角色精灵、印章
  02_角色立牌/   2 款 80×200 cm 竖版立牌，透明底、可沿轮廓切，板内是天空-树林-草地分层场景
  03_吊旗/       90×60 cm 横版主视觉：远山树线 + 草地岛 + 翻到雷的一瞬间
  04_丝绸手环/   350×15 mm 两色版本，花瓣纹理 + 小图标
  README.md      规格、原始分辨率、印刷注意

    python tools/build_materials.py

字体走 Google Fonts，渲染需联网。--force-device-scale-factor 拉高像素密度，
--default-background-color=00000000 出透明底。
"""
import base64
import io
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageFilter

try:
    import numpy as np
except ImportError:  # pragma: no cover
    np = None

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "artifacts", "materials")
BUILD = os.path.join(OUT, "_build")
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

DIR_STICKER = os.path.join(OUT, "01_窗贴")
DIR_STANDEE = os.path.join(OUT, "02_角色立牌")
DIR_FLAG = os.path.join(OUT, "03_吊旗")
DIR_BAND = os.path.join(OUT, "04_丝绸手环")

FONTS = u'<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=ZCOOL+KuaiLe&family=Noto+Sans+SC:wght@500;700;900&family=Fredoka:wght@600;700&display=swap">'

PALETTE = u"""
:root { --ink:#2e3e27; --matte:#1c281b; --honey:#f2bd4c; --honey-deep:#c8862a; --cream:#fff4d6; --paper:#f7e9c4; --seal:#c9463a; --grass:#9db552; --grass-deep:#6f8a35; }
html, body { margin:0; padding:0; }
body { font-family:"Noto Sans SC","Microsoft YaHei","PingFang SC",sans-serif; color:var(--ink); }
.title { margin:0; font-family:"ZCOOL KuaiLe","Noto Sans SC",sans-serif; font-weight:400; line-height:1; letter-spacing:.02em; color:var(--honey); white-space:nowrap; paint-order:stroke fill; }
.title .a { display:inline-block; transform:translateY(-.03em) rotate(-4deg); }
.title .b { display:inline-block; transform:translateY(.045em) rotate(3deg); color:#f7d06b; }
.title .c { display:inline-block; transform:translateY(-.02em) rotate(-2deg); color:#fbd77e; }
.title .d { display:inline-block; transform:translateY(.055em) rotate(5deg); }
.seal { background:var(--seal); color:var(--cream); display:grid; place-items:center; text-align:center; font-family:"ZCOOL KuaiLe","Noto Sans SC",sans-serif; white-space:nowrap; }
.sprite { background-size:contain; background-repeat:no-repeat; background-position:center; }
.bubble { background-size:100% 100%; background-repeat:no-repeat; display:grid; place-items:center; text-align:center; font-family:"ZCOOL KuaiLe","Noto Sans SC",sans-serif; color:var(--ink); line-height:1.05; box-sizing:border-box; }
.bubble > span { display:block; }
.petal { position:absolute; border-radius:60% 60% 60% 60% / 80% 80% 40% 40%; background:linear-gradient(160deg,#ffd7df,#f3a5b4); box-shadow:0 1px 0 rgba(46,62,39,.3); }
.petal.pale { background:linear-gradient(160deg,#fff8e6,#ffe6b0); }
.spark { position:absolute; background: radial-gradient(circle, rgba(255,255,255,.95) 0 18%, rgba(255,255,255,0) 20%), linear-gradient(#fff6c8,#fff6c8) 50% 0 / 14% 100% no-repeat, linear-gradient(#fff6c8,#fff6c8) 0 50% / 100% 14% no-repeat; opacity:.9; }
.hill { position:absolute; border-radius:50%; }
.tree { position:absolute; background-size:contain; background-repeat:no-repeat; background-position:bottom center; }
"""

TITLE_HTML = u'<h1 class="title" style="font-size:%(size)dpx; -webkit-text-stroke:%(stroke)dpx var(--ink); text-shadow:0 %(s1)dpx 0 var(--ink), 0 %(s2)dpx 0 var(--honey-deep), 0 %(s3)dpx 0 var(--ink); transform:rotate(-3deg);"><span class="a">咕</span><span class="b">咕</span><span class="c">啾</span><span class="d">啾</span></h1>'


def title_html(size):
    return TITLE_HTML % {"size": size, "stroke": int(size * 0.07), "s1": int(size * 0.06), "s2": int(size * 0.095), "s3": int(size * 0.13)}


# ---------------------------------------------------------------------------
# 图像工具
# ---------------------------------------------------------------------------

def load_rgba(rel):
    return Image.open(os.path.join(ROOT, rel)).convert("RGBA")


def defringe_and_upscale(image, long_side):
    """去掉抠图残留的深色/洋红边，再预乘 alpha 放大；放大后轻微锐化。

    边缘半透明像素的颜色是原图抠图时和黑底/洋红底混出来的脏色。做法：把 alpha 收缩 1px，
    然后用「只取完全不透明像素」的模糊结果给边缘像素重新上色——相当于把内部颜色向外扩。
    """
    if np is not None:
        alpha_img = image.getchannel("A").filter(ImageFilter.MinFilter(3))
        arr = np.asarray(image).astype(np.float32) / 255.0
        alpha = np.asarray(alpha_img).astype(np.float32)[..., None] / 255.0
        alpha[alpha < 0.08] = 0.0
        rgb = arr[..., :3]
        opaque = (alpha > 0.97).astype(np.float32)
        premul_opaque = Image.fromarray((np.concatenate([rgb * opaque, opaque], axis=2) * 255).astype(np.uint8), "RGBA")
        blurred = np.asarray(premul_opaque.filter(ImageFilter.GaussianBlur(4))).astype(np.float32) / 255.0
        fill = blurred[..., :3] / np.maximum(blurred[..., 3:4], 1e-3)
        edge = (alpha > 0.0) & (alpha <= 0.97) & (blurred[..., 3:4] > 0.02)
        rgb = np.where(edge, fill, rgb)
        premul = np.concatenate([rgb * alpha, alpha], axis=2)
        pre_img = Image.fromarray((np.clip(premul, 0, 1) * 255).astype(np.uint8), "RGBA")
    else:
        pre_img = image
    ratio = long_side / float(max(pre_img.size))
    size = (int(round(pre_img.size[0] * ratio)), int(round(pre_img.size[1] * ratio)))
    big = pre_img.resize(size, Image.LANCZOS)
    if np is not None:
        arr = np.asarray(big).astype(np.float32) / 255.0
        alpha = arr[..., 3:4]
        safe = np.where(alpha > 0.002, alpha, 1.0)
        rgb = np.clip(arr[..., :3] / safe, 0.0, 1.0)
        big = Image.fromarray((np.concatenate([rgb, alpha], axis=2) * 255).astype(np.uint8), "RGBA")
    rgb_layer = big.convert("RGB").filter(ImageFilter.UnsharpMask(radius=3, percent=90, threshold=2))
    big = Image.merge("RGBA", (*rgb_layer.split(), big.split()[3]))
    return big


def trim(image, pad=0):
    box = image.getchannel("A").getbbox()
    if box is None:
        return image
    left, top, right, bottom = box
    return image.crop((max(left - pad, 0), max(top - pad, 0), min(right + pad, image.size[0]), min(bottom + pad, image.size[1])))


def data_uri(image, fmt="PNG", quality=90):
    buffer = io.BytesIO()
    if fmt == "JPEG":
        image.convert("RGB").save(buffer, "JPEG", quality=quality, optimize=True)
        mime = "image/jpeg"
    elif fmt == "WEBP":
        image.save(buffer, "WEBP", quality=quality, method=6)
        mime = "image/webp"
    else:
        image.save(buffer, "PNG", optimize=True)
        mime = "image/png"
    return "data:%s;base64,%s" % (mime, base64.b64encode(buffer.getvalue()).decode("ascii"))


_URI_CACHE = {}


def sprite_uri(rel, long_side=None, clean=True):
    key = (rel, long_side, clean)
    if key not in _URI_CACHE:
        image = trim(load_rgba(rel))
        if long_side:
            image = defringe_and_upscale(image, long_side) if clean else image.resize(
                (long_side, int(image.size[1] * long_side / image.size[0])), Image.LANCZOS)
        _URI_CACHE[key] = data_uri(image)
    return _URI_CACHE[key]


def raw_uri(rel, limit=None, fmt="WEBP", quality=88):
    key = (rel, limit, fmt)
    if key not in _URI_CACHE:
        image = load_rgba(rel)
        if limit and max(image.size) > limit:
            ratio = limit / float(max(image.size))
            image = image.resize((int(image.size[0] * ratio), int(image.size[1] * ratio)), Image.LANCZOS)
        _URI_CACHE[key] = data_uri(image, fmt, quality)
    return _URI_CACHE[key]


def render(html, name, width, height, scale=1, transparent=False):
    os.makedirs(BUILD, exist_ok=True)
    html_path = os.path.join(BUILD, name + ".html")
    png_path = os.path.join(BUILD, name + ".png")
    with open(html_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(html)
    args = [
        EDGE, "--headless=new", "--disable-gpu", "--hide-scrollbars",
        "--window-size=%d,%d" % (width, height), "--force-device-scale-factor=%s" % scale,
        "--virtual-time-budget=14000", "--screenshot=" + png_path,
    ]
    if transparent:
        args.append("--default-background-color=00000000")
    args.append("file:///" + html_path.replace("\\", "/"))
    subprocess.run(args, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return png_path


def page(body, extra_css="", width=1920, height=1080, background="transparent"):
    return u"""<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">%s<style>%s
html, body { width:%dpx; height:%dpx; overflow:hidden; background:%s; }
#stage { position:relative; width:%dpx; height:%dpx; overflow:hidden; }
#stage > * { position:absolute; }
%s</style></head><body><div id="stage">%s</div></body></html>""" % (FONTS, PALETTE, width, height, background, width, height, extra_css, body)


def finish(png_path, dest_dir, dest_name, trim_alpha=False):
    os.makedirs(dest_dir, exist_ok=True)
    image = Image.open(png_path).convert("RGBA")
    if trim_alpha:
        image = trim(image, pad=24)
    dest = os.path.join(dest_dir, dest_name)
    image.save(dest, "PNG", optimize=True)
    print("  ->", os.path.relpath(dest, ROOT).encode("utf-8", "replace").decode("utf-8"), image.size, "%.1f MB" % (os.path.getsize(dest) / 1048576.0))
    return image.size


def petals(seed, width, height, count=24, sparks=8, band=None):
    """花瓣与星点。band=(x0,y0,x1,y1) 限定落点区域。"""
    parts = []
    state = seed
    def rand():
        nonlocal state
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        return state / float(0x7FFFFFFF)
    x0, y0, x1, y1 = band or (0, 0, width, height)
    for _ in range(count):
        size = 12 + rand() * 14
        parts.append('<i class="petal%s" style="left:%dpx;top:%dpx;width:%dpx;height:%dpx;transform:rotate(%ddeg);opacity:%.2f"></i>' % (
            "" if rand() > 0.35 else " pale", x0 + rand() * (x1 - x0), y0 + rand() * (y1 - y0), size, size * 0.62, rand() * 360, 0.55 + rand() * 0.45))
    for _ in range(sparks):
        size = 16 + rand() * 24
        parts.append('<i class="spark" style="left:%dpx;top:%dpx;width:%dpx;height:%dpx"></i>' % (x0 + rand() * (x1 - x0), y0 + rand() * (y1 - y0), size, size))
    return "\n".join(parts)


def trees_html(specs):
    out = []
    for kind, left, top, size, opacity in specs:
        out.append('<div class="tree" style="left:%dpx; top:%dpx; width:%dpx; height:%dpx; opacity:%s; background-image:url(%s)"></div>' % (
            left, top, size, size, opacity, raw_uri("my_asset/tree_0%d.png" % kind, 500)))
    return "\n".join(out)


# ---------------------------------------------------------------------------
# 01 窗贴
# ---------------------------------------------------------------------------
STICKER_SPRITES = [
    ("my_asset/hero_head.png", "04_探险家.png", 800),
    ("my_asset/birds/blue_find_yes.png", "05_蓝鸟_放大镜.png", 220),
    ("my_asset/birds/black_idle_1.png", "06_夜鹭.png", 220),
    ("my_asset/monster_big.png", "07_树精.png", 800),
]
STICKER_LONG_SIDE = 2400


def build_stickers():
    print("[01 窗贴]")
    os.makedirs(DIR_STICKER, exist_ok=True)
    branch = raw_uri("my_asset/birds/tree_left_1.png")
    # 01 Logo 组合：大字 + 缎带 + 印章 + 枝叶。
    css = u"""
.ribbon { left:340px; top:790px; width:1500px; height:130px; display:flex; align-items:center; justify-content:center; background:var(--ink); color:var(--cream); font-weight:900; font-size:60px; letter-spacing:.12em; clip-path:polygon(0 0,100%% 0,calc(100%% - 40px) 50%%,100%% 100%%,0 100%%,40px 50%%); transform:rotate(-3deg); }
.ribbon b { color:var(--honey); margin:0 14px; }
.sprig { position:absolute; background:url(%(branch)s) center / contain no-repeat; }
""" % {"branch": branch}
    body = u"""
<div class="sprig" style="left:-40px; top:40px; width:520px; height:390px; transform:rotate(-24deg)"></div>
<div class="sprig" style="left:2420px; top:600px; width:460px; height:345px; transform:rotate(160deg) scaleX(-1)"></div>
<div style="left:200px; top:180px;">%(title)s</div>
<div class="seal" style="left:2500px; top:140px; width:380px; height:400px; border-radius:46px; font-size:82px; line-height:1.15; letter-spacing:.06em; box-shadow: inset 0 0 0 14px var(--cream), inset 0 0 0 24px var(--seal), inset 0 0 0 30px rgba(255,244,214,.55); transform:rotate(8deg);"><span>有福<br>同享<br>有难<br>退队</span></div>
%(petals)s
""" % {"title": title_html(560), "petals": petals(3, 2900, 1000, count=16, sparks=6)}
    png = render(page(body, css, width=2950, height=1050), "sticker_logo_set", 2950, 1050, scale=1, transparent=True)
    finish(png, DIR_STICKER, "01_Logo组合_咕咕啾啾.png", trim_alpha=True)
    # 02 纯 Logo。
    body = u'<div style="left:120px; top:150px;">%s</div>' % title_html(560)
    png = render(page(body, width=2700, height=1000), "sticker_logo", 2700, 1000, scale=1, transparent=True)
    finish(png, DIR_STICKER, "02_Logo_咕咕啾啾.png", trim_alpha=True)
    # 03 果冻雷翻坑组合：泥坑 + 果冻 + 旗子 + 草皮 + 惊叹线 + 气泡。
    css = u"""
.shock { left:1180px; top:150px; width:160px; height:90px; transform:rotate(-8deg); background:
  linear-gradient(var(--ink),var(--ink)) 10px 14px / 9px 50px no-repeat, linear-gradient(var(--ink),var(--ink)) 60px 0 / 9px 60px no-repeat, linear-gradient(var(--ink),var(--ink)) 110px 10px / 9px 54px no-repeat; }
"""
    body = u"""
<div class="sprite" style="left:120px; top:820px; width:520px; height:520px; background-image:url(%(turf)s); transform:rotate(-6deg)"></div>
<div class="sprite" style="left:1480px; top:860px; width:520px; height:520px; background-image:url(%(turf_f)s); transform:rotate(5deg)"></div>
<div class="sprite" style="left:560px; top:700px; width:1000px; height:1000px; background-image:url(%(mud)s)"></div>
<div class="sprite" style="left:560px; top:250px; width:1000px; height:1000px; background-image:url(%(jelly)s); filter:drop-shadow(0 30px 24px rgba(46,62,39,.4))"></div>
<div class="sprite" style="left:1500px; top:480px; width:560px; height:560px; background-image:url(%(flag)s); filter:drop-shadow(0 20px 14px rgba(46,62,39,.35))"></div>
<div class="shock"></div>
<div class="sprite" style="left:80px; top:260px; width:300px; height:300px; background-image:url(%(heart)s); transform:rotate(-12deg)"></div>
<div class="sprite" style="left:300px; top:120px; width:260px; height:260px; background-image:url(%(coin)s); transform:rotate(8deg)"></div>
%(petals)s
""" % {
        "turf": raw_uri("ground_tiles/revealed_grass.png"), "turf_f": raw_uri("ground_tiles/revealed_small_flowers.png"),
        "mud": raw_uri("assets/sprites/generated/tile_dirt_empty.png"),
        "jelly": sprite_uri("my_asset/monster_small.png", 1800), "flag": sprite_uri("assets/sprites/generated/marker_flag.png", 1000),
        "heart": sprite_uri("my_asset/heart.png", 500), "coin": sprite_uri("my_asset/coin.png", 500), "petals": petals(9, 2200, 1800, count=14, sparks=6),
    }
    png = render(page(body, css, width=2200, height=1800), "sticker_jelly_set", 2200, 1800, scale=1, transparent=True)
    finish(png, DIR_STICKER, "03_果冻雷翻坑组合.png", trim_alpha=True)
    # 角色精灵。
    for rel, name, native in STICKER_SPRITES:
        image = defringe_and_upscale(trim(load_rgba(rel)), STICKER_LONG_SIDE)
        dest = os.path.join(DIR_STICKER, name)
        image.save(dest, "PNG", optimize=True)
        print("  ->", name, image.size, "(原图 %dpx)" % native)
    # 印章。
    body = u'<div class="seal" style="left:100px; top:100px; width:600px; height:600px; border-radius:70px; font-size:150px; line-height:1.15; letter-spacing:.08em; box-shadow: inset 0 0 0 22px var(--cream), inset 0 0 0 38px var(--seal), inset 0 0 0 46px rgba(255,244,214,.55); transform:rotate(6deg);"><span>有福同享<br>有难退队</span></div>'
    png = render(page(body, width=820, height=820), "sticker_seal", 820, 820, scale=2, transparent=True)
    finish(png, DIR_STICKER, "08_印章_有福同享有难退队.png", trim_alpha=True)


# ---------------------------------------------------------------------------
# 02 角色立牌：80×200 cm，渲染 1200×3000 @2 = 2400×6000
# ---------------------------------------------------------------------------
STANDEE_CSS = u"""
.board { left:60px; top:520px; width:1080px; height:2420px; border-radius:90px; overflow:hidden; border:14px solid var(--ink); box-sizing:border-box;
  background: linear-gradient(180deg, #8fd0ee 0%%, #bfe3f5 26%%, #f6e9c4 40%%, #dfe6b0 48%%, #9db552 60%%, #6f8a35 100%%); }
.board .sun { position:absolute; left:640px; top:-60px; width:520px; height:520px; border-radius:50%%; background:radial-gradient(circle, rgba(255,250,225,.95) 0 34%%, rgba(255,250,225,.5) 48%%, rgba(255,250,225,0) 70%%); }
.board .cloud { position:absolute; height:52px; border-radius:40px; background:rgba(255,255,255,.9); box-shadow:44px -20px 0 10px rgba(255,255,255,.9), 100px -6px 0 2px rgba(255,255,255,.9); }
.board .mist { position:absolute; left:0; right:0; top:1080px; height:220px; background:linear-gradient(180deg, rgba(255,250,225,0), rgba(255,250,225,.8) 50%%, rgba(255,250,225,0)); }
.board .island { position:absolute; left:-260px; top:1240px; width:1600px; height:1600px; background:url(%(island)s) center / contain no-repeat; transform:scaleY(.62); transform-origin:50%% 0; filter:drop-shadow(0 20px 18px rgba(46,62,39,.35)); }
.board .treant { position:absolute; left:560px; top:720px; width:520px; height:520px; background:url(%(treant)s) center / contain no-repeat; filter:saturate(.9); }
.board .shade { position:absolute; inset:0; box-shadow: inset 0 0 0 12px var(--cream), inset 0 0 0 20px rgba(46,62,39,.3), inset 0 0 160px rgba(46,62,39,.25); border-radius:76px; }
.board .tiles { position:absolute; left:40px; top:2200px; width:1000px; display:flex; gap:10px; }
.board .tiles i { flex:1; aspect-ratio:1; border-radius:18px; background-size:100%% 100%%; box-shadow:0 8px 0 rgba(46,62,39,.35); }
.hero { background-size:contain; background-repeat:no-repeat; background-position:bottom center; filter:drop-shadow(0 30px 24px rgba(0,0,0,.45)); }
.logo { left:0; width:1200px; display:flex; justify-content:center; }
.ribbon { left:150px; width:900px; height:110px; display:flex; align-items:center; justify-content:center; background:var(--ink); clip-path:polygon(0 0,100%% 0,calc(100%% - 34px) 50%%,100%% 100%%,0 100%%,34px 50%%); font-weight:900; font-size:44px; letter-spacing:.1em; color:var(--cream); white-space:nowrap; transform:rotate(-2deg); filter:drop-shadow(0 10px 0 rgba(46,62,39,.4)); }
.ribbon b { color:var(--honey); margin:0 10px; }
.plate { left:130px; width:940px; height:400px; padding:0 90px; box-sizing:border-box; display:flex; align-items:center; justify-content:center; text-align:center; background:url(%(paper)s) center / 100%% 100%% no-repeat; filter:drop-shadow(0 18px 16px rgba(46,62,39,.45)); }
.plate h2 { margin:0; font-family:"ZCOOL KuaiLe","Noto Sans SC",sans-serif; font-weight:400; font-size:66px; line-height:1.3; letter-spacing:.06em; color:#4a3a22; }
.items { left:120px; width:960px; display:flex; justify-content:space-evenly; align-items:center; }
.items i { width:150px; height:150px; background-size:contain; background-repeat:no-repeat; background-position:center; filter:drop-shadow(0 10px 8px rgba(0,0,0,.4)); }
.plate h2 em { font-style:normal; color:var(--seal); }
.plate p { margin:0; font-size:36px; line-height:1.5; font-weight:500; color:#5a4a30; }
.plate p + p { margin-top:10px; }
.branch { left:60px; width:1100px; height:230px; background:url(%(branch)s) center / 100%% 100%% no-repeat; filter:drop-shadow(0 12px 10px rgba(0,0,0,.45)); }
.birds { left:150px; width:900px; display:flex; justify-content:space-between; align-items:flex-end; }
.birds i { width:160px; height:160px; background-size:contain; background-repeat:no-repeat; background-position:bottom center; filter:drop-shadow(0 12px 10px rgba(0,0,0,.45)); }
.stamp { width:200px; height:200px; border-radius:30px; font-size:56px; line-height:1.1; letter-spacing:.06em; box-shadow: inset 0 0 0 8px var(--cream), inset 0 0 0 14px var(--seal), inset 0 0 0 18px rgba(255,244,214,.55), 0 10px 0 rgba(0,0,0,.45); transform:rotate(8deg); }
.sprig { background:url(%(branch)s) center / contain no-repeat; filter:drop-shadow(0 10px 8px rgba(0,0,0,.45)); }
.foot { left:0; width:1200px; text-align:center; font-family:"Fredoka","Noto Sans SC",sans-serif; font-weight:600; font-size:30px; letter-spacing:.3em; color:var(--cream); -webkit-text-stroke:6px var(--ink); paint-order:stroke fill; }
"""


def standee_body(hero_uri, hero_style, headline, items, birds):
    bird_html = "".join('<i style="background-image:url(%s); transform:%s"></i>' % (uri, tf) for uri, tf in birds)
    tiles = [raw_uri("ground_tiles/revealed_grass.png"), raw_uri("ground_tiles/revealed_small_flowers.png"), raw_uri("assets/sprites/generated/tile_dirt_empty.png")]
    tile_html = "".join('<i style="background-image:url(%s)"></i>' % tiles[k] for k in [0, 1, 0, 2, 0, 1, 0])
    return u"""
<div class="board">
  <div class="sun"></div>
  <div class="cloud" style="left:120px; top:200px; width:150px"></div>
  <div class="cloud" style="left:720px; top:330px; width:110px; transform:scale(.8)"></div>
  <div class="hill" style="left:-200px; top:820px; width:900px; height:360px; background:#b9cf9f; opacity:.9"></div>
  <div class="hill" style="left:500px; top:860px; width:900px; height:340px; background:#b3c996; opacity:.9"></div>
  <div class="treant"></div>
  %(trees)s
  <div class="mist"></div>
  <div class="island"></div>
  <div class="tiles">%(tiles)s</div>
  <div class="shade"></div>
</div>
<div class="hero" style="%(hero_style)s background-image:url(%(hero)s)"></div>
<div class="logo" style="top:1250px">%(title)s</div>
<div class="plate" style="top:1700px"><h2>%(headline)s</h2></div>
<div class="items" style="top:2140px">%(items)s</div>
<div class="birds" style="top:2560px">%(birds)s</div>
<div class="seal stamp" style="left:940px; top:1140px;"><span>咕咕<br>啾啾</span></div>
<div class="sprig" style="left:-30px; top:480px; width:330px; height:250px; transform:rotate(-24deg)"></div>
<div class="sprig" style="left:900px; top:2760px; width:300px; height:225px; transform:rotate(160deg) scaleX(-1)"></div>
%(petals)s
""" % {
        "hero": hero_uri, "hero_style": hero_style, "title": title_html(250), "headline": headline,
        "items": "".join('<i style="background-image:url(%s); transform:rotate(%ddeg)"></i>' % (uri, rot) for uri, rot in items),
        "birds": bird_html, "tiles": tile_html,
        "trees": trees_html([(2, 70, 860, 260, .92), (1, 300, 900, 220, .9), (1, 880, 820, 300, 1), (2, 130, 1020, 180, 1)]),
        "petals": petals(11, 1200, 3000, count=26, sparks=10, band=(40, 480, 1160, 3000)),
    }


def standee_css():
    return STANDEE_CSS % {
        "island": raw_uri("my_asset/base_01.png", 1400), "treant": raw_uri("my_asset/monster_big.png", 640),
        "paper": raw_uri("my_asset/panel_01.png", 1200), "branch": raw_uri("my_asset/birds/tree_left_1.png"),
    }


def build_standees():
    print("[02 角色立牌]")
    css = standee_css()
    birds = [
        (sprite_uri("my_asset/birds/blue_idle_1.png", 520), "none"),
        (sprite_uri("my_asset/birds/red_idle_1.png", 520), "scaleX(-1)"),
        (sprite_uri("my_asset/birds/black_idle_1.png", 520), "none"),
        (sprite_uri("my_asset/birds/attacker_idle_1.png", 520), "scaleX(-1)"),
        (sprite_uri("my_asset/birds/eg_idle_1.png", 520), "none"),
    ]
    # A：果冻雷。
    items = [
        (sprite_uri("my_asset/heart.png", 400), -10), (sprite_uri("my_asset/coin.png", 400), 6),
        (sprite_uri("assets/sprites/generated/marker_flag.png", 400), -4),
        (sprite_uri("assets/sprites/generated/potion_heal_green.png", 400), 8),
        (sprite_uri("assets/sprites/generated/potion_star_purple.png", 400), -6),
    ]
    body_a = standee_body(
        sprite_uri("my_asset/monster_small.png", 1800), "left:190px; top:120px; width:820px; height:820px;",
        u"翻格子、插旗子，<br><em>五只鸟</em>帮你扫雷",
        items, birds,
    )
    png = render(page(body_a, css, width=1200, height=3000), "standee_a", 1200, 3000, scale=2, transparent=True)
    finish(png, DIR_STANDEE, "立牌A_果冻雷_80x200cm.png")
    # B：探险家。
    body_b = standee_body(
        sprite_uri("my_asset/hero_head.png", 1800), "left:130px; top:40px; width:940px; height:940px;",
        u"扫雷 × 肉鸽，<br>看着数字<em>手别抖</em>",
        items, birds,
    )
    png = render(page(body_b, css, width=1200, height=3000), "standee_b", 1200, 3000, scale=2, transparent=True)
    finish(png, DIR_STANDEE, "立牌B_探险家_80x200cm.png")


# ---------------------------------------------------------------------------
# 03 吊旗：90×60 cm，渲染 2700×1800 @2 = 5400×3600
# ---------------------------------------------------------------------------
FLAG_CSS = u"""
.sky { inset:0; background:url(%(sky)s) center / cover no-repeat; }
.warm { inset:0; background: radial-gradient(1400px 900px at 82%% 6%%, rgba(255,236,170,.72), rgba(255,236,170,0) 70%%), linear-gradient(180deg, rgba(255,214,120,.1), rgba(255,255,255,0) 40%%, rgba(255,250,220,.35) 58%%, rgba(255,250,220,0) 70%%); }
.rays { left:1200px; top:-300px; width:1900px; height:1500px; background:repeating-linear-gradient(112deg, rgba(255,255,255,0) 0 100px, rgba(255,255,255,.16) 100px 160px, rgba(255,255,255,0) 160px 270px); -webkit-mask-image:radial-gradient(closest-side at 70%% 20%%, rgba(0,0,0,.9), rgba(0,0,0,0)); transform:rotate(-6deg); }
.mist { left:0; right:0; top:820px; height:200px; background:linear-gradient(180deg, rgba(255,250,225,0), rgba(255,250,225,.75) 45%%, rgba(255,250,225,0)); }
.treeline { left:0; right:0; top:930px; height:120px; background:linear-gradient(180deg, rgba(86,112,42,0), rgba(86,112,42,.7) 60%%, rgba(86,112,42,.95)); }
.treant { left:1980px; top:400px; width:640px; height:640px; background:url(%(treant)s) center / contain no-repeat; filter:saturate(.92); }
.island { left:-140px; top:900px; width:3000px; height:3000px; background:url(%(island)s) center / contain no-repeat; transform:scaleY(.52); transform-origin:50%% 0; filter:drop-shadow(0 30px 24px rgba(46,62,39,.35)); }
.tiles { left:520px; top:1300px; width:1660px; display:flex; gap:12px; transform:perspective(2200px) rotateX(38deg); transform-origin:50%% 0; }
.tiles i { flex:1; aspect-ratio:1; border-radius:20px; background-size:100%% 100%%; box-shadow:0 10px 0 rgba(46,62,39,.35); }
.frame { inset:44px; border:14px solid var(--ink); border-radius:60px; box-shadow: inset 0 0 0 12px var(--cream), inset 0 0 0 18px rgba(46,62,39,.35), 0 0 0 10px rgba(255,244,214,.6); }
.glow { left:150px; top:60px; width:1700px; height:700px; border-radius:50%%; background:radial-gradient(closest-side, rgba(255,248,220,.85), rgba(255,248,220,0)); }
.logo { left:120px; top:120px; }
.ribbon { left:170px; top:640px; height:110px; padding:0 50px; display:flex; align-items:center; background:var(--ink); color:var(--cream); font-weight:900; font-size:56px; letter-spacing:.1em; clip-path:polygon(0 0,100%% 0,calc(100%% - 40px) 50%%,100%% 100%%,0 100%%); white-space:nowrap; transform:rotate(-3deg); filter:drop-shadow(0 12px 0 rgba(46,62,39,.35)); }
.ribbon b { color:var(--honey); margin:0 12px; }
.stamp { width:340px; height:300px; border-radius:40px; font-size:64px; line-height:1.15; letter-spacing:.06em; box-shadow: inset 0 0 0 11px var(--cream), inset 0 0 0 19px var(--seal), inset 0 0 0 24px rgba(255,244,214,.55), 0 14px 0 rgba(46,62,39,.35); transform:rotate(8deg); }
.shock { width:160px; height:80px; transform:rotate(-8deg); background: linear-gradient(var(--ink),var(--ink)) 10px 14px / 8px 44px no-repeat, linear-gradient(var(--ink),var(--ink)) 56px 0 / 8px 54px no-repeat, linear-gradient(var(--ink),var(--ink)) 104px 10px / 8px 48px no-repeat; }
.tag { width:280px; height:210px; background:url(%(banner)s) center / contain no-repeat; display:grid; place-items:center; padding:0 26px 0 72px; box-sizing:border-box; font-family:"ZCOOL KuaiLe","Noto Sans SC",sans-serif; font-size:46px; color:var(--ink); transform:rotate(-8deg) scaleX(-1); }
.tag > span { transform:scaleX(-1); display:block; }
.sprig { background:url(%(branch)s) center / contain no-repeat; filter:drop-shadow(0 10px 8px rgba(0,0,0,.35)); }
.deco { background-size:contain; background-repeat:no-repeat; background-position:bottom center; }
"""


def build_flag():
    print("[03 吊旗]")
    sky = Image.open(os.path.join(ROOT, "my_asset", "sky.png")).convert("RGB")
    sky = sky.crop((0, 0, 2000, 1334)).resize((2700, 1800), Image.LANCZOS)
    css = FLAG_CSS % {
        "sky": data_uri(sky, "JPEG", 90), "treant": raw_uri("my_asset/monster_big.png", 800), "island": raw_uri("my_asset/base_01.png", 1400),
        "banner": raw_uri("my_asset/ach_banner.png"), "branch": raw_uri("my_asset/birds/tree_left_1.png"),
    }
    tiles = [raw_uri("ground_tiles/revealed_grass.png"), raw_uri("ground_tiles/revealed_small_flowers.png"), raw_uri("assets/sprites/generated/tile_dirt_empty.png")]
    tile_html = "".join('<i style="background-image:url(%s)"></i>' % tiles[k] for k in [0, 1, 0, 2, 2, 2, 0, 1, 0])
    body = u"""
<div class="sky"></div><div class="warm"></div><div class="rays"></div>
<div class="hill" style="left:-400px; top:700px; width:2200px; height:760px; background:#b9cf9f; opacity:.9"></div>
<div class="hill" style="left:1500px; top:720px; width:1800px; height:700px; background:#b3c996; opacity:.9"></div>
<div class="hill" style="left:600px; top:790px; width:2000px; height:620px; background:#9eb97e"></div>
<div class="mist"></div>
%(trees)s
<div class="treant"></div>
%(trees_front)s
<div class="treeline"></div>
<div class="island"></div>
<div class="tiles">%(tiles)s</div>
<div class="deco" style="left:2080px; top:1180px; width:480px; height:480px; background-image:url(%(rock)s)"></div>
<div class="deco" style="left:2330px; top:1330px; width:420px; height:420px; background-image:url(%(mushroom)s)"></div>
<div class="deco" style="left:-40px; top:1280px; width:520px; height:520px; background-image:url(%(grass)s); transform:scaleX(-1)"></div>
<div class="sprite" style="left:1020px; top:1010px; width:520px; height:520px; background-image:url(%(jelly)s); filter:drop-shadow(0 26px 18px rgba(46,62,39,.4)); transform:scaleX(1.06) scaleY(.94) rotate(-2deg); transform-origin:50%% 100%%"></div>
<div class="shock" style="left:1210px; top:930px"></div>
<div class="sprite" style="left:1490px; top:1200px; width:300px; height:300px; background-image:url(%(flag)s); filter:drop-shadow(0 14px 10px rgba(46,62,39,.35))"></div>
<div class="sprite" style="left:640px; top:1180px; width:420px; height:420px; background-image:url(%(blue)s); filter:drop-shadow(0 20px 14px rgba(46,62,39,.4)); transform:rotate(6deg)"></div>
<div class="sprite" style="left:1560px; top:1330px; width:340px; height:340px; background-image:url(%(wood)s); filter:drop-shadow(0 16px 12px rgba(46,62,39,.4)); transform:rotate(-20deg) scaleX(-1)"></div>
<div class="sprite" style="left:2330px; top:230px; width:300px; height:300px; background-image:url(%(heron)s); filter:drop-shadow(0 26px 18px rgba(46,62,39,.25)); transform:rotate(8deg)"></div>
<div class="sprite" style="left:2540px; top:440px; width:110px; height:110px; background-image:url(%(lantern)s); filter:drop-shadow(0 0 30px rgba(255,214,110,.95)); transform:rotate(10deg)"></div>
<div class="sprite" style="left:1700px; top:120px; width:560px; height:560px; background-image:url(%(kestrel)s); filter:drop-shadow(0 36px 22px rgba(46,62,39,.22)); transform:rotate(18deg) scaleX(-1)"></div>
<div class="sprite" style="left:2420px; top:720px; width:300px; height:300px; background-image:url(%(red)s); filter:drop-shadow(0 16px 12px rgba(46,62,39,.3)); transform:rotate(-14deg)"></div>
<div class="glow"></div>
<div class="logo">%(title)s</div>
<div class="seal stamp" style="left:1720px; top:640px;"><span>有福同享<br>有难退队</span></div>
<div class="sprite" style="left:200px; top:640px; width:150px; height:150px; background-image:url(%(heart)s); transform:rotate(-12deg)"></div>
<div class="sprite" style="left:330px; top:600px; width:150px; height:150px; background-image:url(%(heart)s); transform:rotate(4deg)"></div>
<div class="sprite" style="left:460px; top:650px; width:150px; height:150px; background-image:url(%(heart)s); transform:rotate(14deg)"></div>
<div class="sprite" style="left:700px; top:620px; width:170px; height:170px; background-image:url(%(coin)s); transform:rotate(-8deg)"></div>

%(petals)s
<div class="frame"></div>
<div class="sprig" style="left:-60px; top:-50px; width:420px; height:315px; transform:rotate(-24deg)"></div>
<div class="sprig" style="left:2320px; top:1500px; width:380px; height:285px; transform:rotate(160deg) scaleX(-1)"></div>
""" % {
        "title": title_html(430), "tiles": tile_html,
        "trees": trees_html([(2, 100, 640, 320, .9), (1, 420, 620, 340, .92), (2, 760, 700, 260, .9), (1, 1500, 560, 400, 1), (2, 2500, 700, 300, .9)]),
        "trees_front": trees_html([(1, 1860, 720, 280, 1)]),
        "jelly": sprite_uri("my_asset/monster_small.png", 1400), "flag": sprite_uri("assets/sprites/generated/marker_flag.png", 700),
        "blue": sprite_uri("my_asset/birds/blue_find_1.png", 900), "heron": sprite_uri("my_asset/birds/black_fly_1.png", 900),
        "wood": sprite_uri("my_asset/birds/attacker_zhuo.png", 800), "kestrel": sprite_uri("my_asset/birds/eg_fly_big.png", 1100),
        "red": sprite_uri("my_asset/birds/red_fly_1.png", 700), "lantern": sprite_uri("assets/sprites/generated/bird_items/item_bird_lantern.png", 400),
        "heart": sprite_uri("my_asset/heart.png", 400), "coin": sprite_uri("my_asset/coin.png", 400),
        "compass": sprite_uri("assets/sprites/generated/bird_items/item_bird_compass.png", 400), "orbital": sprite_uri("assets/sprites/generated/bird_items/item_bird_orbital.png", 400),
        "rock": raw_uri("my_asset/rock_02.png", 500), "mushroom": raw_uri("my_asset/mushroom01.png", 500), "grass": raw_uri("my_asset/grass_flower_05.png", 500),
        "cloud": raw_uri("my_asset/kuang_think_01.png"),
        "petals": petals(21, 2700, 1800, count=34, sparks=12, band=(60, 60, 2640, 1740)),
    }
    png = render(page(body, css, width=2700, height=1800, background="#1c281b"), "flag", 2700, 1800, scale=2)
    finish(png, DIR_FLAG, "吊旗_咕咕啾啾_90x60cm.png")


# ---------------------------------------------------------------------------
# 04 丝绸手环：350×15 mm，渲染 3500×150 @2 = 7000×300
# ---------------------------------------------------------------------------
BAND_CSS = u"""
.band { inset:0; display:flex; align-items:center; justify-content:space-evenly; padding:0 40px; box-sizing:border-box; overflow:hidden; }
.band::before { content:""; position:absolute; left:24px; right:24px; top:14px; bottom:14px; border-top:3px dashed var(--line); border-bottom:3px dashed var(--line); }
.band .name { font-family:"ZCOOL KuaiLe","Noto Sans SC",sans-serif; font-size:92px; letter-spacing:.1em; line-height:1; color:var(--name); -webkit-text-stroke:7px var(--stroke); paint-order:stroke fill; text-shadow:0 5px 0 var(--stroke); }
.band .slogan { font-weight:900; font-size:48px; letter-spacing:.18em; line-height:1; color:var(--fg); }
.band .dot { width:20px; height:20px; border-radius:50%; background:var(--accent); }
.band i { width:118px; height:118px; background-size:contain; background-repeat:no-repeat; background-position:center; display:inline-block; filter:drop-shadow(0 4px 3px rgba(0,0,0,.3)); }
.band .flag { width:84px; height:84px; }
"""


def build_bands():
    print("[04 丝绸手环]")
    icons = {
        "jelly": sprite_uri("my_asset/monster_small.png", 400), "blue": sprite_uri("my_asset/birds/blue_idle_1.png", 400),
        "red": sprite_uri("my_asset/birds/red_idle_1.png", 400), "heron": sprite_uri("my_asset/birds/black_idle_1.png", 400),
        "wood": sprite_uri("my_asset/birds/attacker_idle_1.png", 400), "kestrel": sprite_uri("my_asset/birds/eg_idle_1.png", 400),
        "flag": sprite_uri("assets/sprites/generated/marker_flag.png", 300),
        "heart": sprite_uri("my_asset/heart.png", 300), "coin": sprite_uri("my_asset/coin.png", 300),
    }
    def band(bg, fg, accent, name_fill, stroke, line, name):
        css = BAND_CSS + ".band{background:%s; --fg:%s; --accent:%s; --name:%s; --stroke:%s; --line:%s}" % (bg, fg, accent, name_fill, stroke, line)
        body = (u"""<div class="band">
<i style="background-image:url(%(jelly)s)"></i><span class="name">咕咕啾啾</span><i class="flag" style="background-image:url(%(flag)s)"></i><i style="background-image:url(%(blue)s)"></i><i style="background-image:url(%(red)s)"></i>
<span class="name">咕咕啾啾</span><i style="background-image:url(%(heron)s)"></i><i class="flag" style="background-image:url(%(heart)s)"></i><i style="background-image:url(%(wood)s)"></i>
<span class="name">咕咕啾啾</span><i style="background-image:url(%(kestrel)s)"></i><i class="flag" style="background-image:url(%(coin)s)"></i><i style="background-image:url(%(jelly)s)"></i><span class="name">咕咕啾啾</span>
</div>""" % icons) + petals(5, 3500, 150, count=40, sparks=0, band=(0, 0, 3500, 150))
        png = render(page(body, css, width=3500, height=150, background=bg), "band_" + name, 3500, 150, scale=2)
        finish(png, DIR_BAND, "手环_%s_350x15mm.png" % name)
    band("#f2bd4c", "#2e3e27", "#c9463a", "#fff4d6", "#2e3e27", "rgba(46,62,39,.45)", "蜂蜜金底")
    band("#1c281b", "#fff4d6", "#f2bd4c", "#f2bd4c", "#0f1a10", "rgba(255,244,214,.4)", "墨绿底")


README = u"""# 《咕咕啾啾》线下物料素材

所有文件均为 PNG。文字、Logo、边框、色块由矢量渲染，任意尺寸清晰；角色精灵来自游戏内原图（见下表原始分辨率），
已做去边、预乘 Lanczos 放大与锐化，远看没问题，近看会有轻微柔化。如果赛事组需要更高清的角色图，请告知，我们再补。

| 文件夹 | 物料 | 尺寸 | 内容 |
|---|---|---|---|
| 01_窗贴 | 窗贴（约 50×50 cm，异形） | 长边 2200–2900 px，透明底 | Logo+印章+枝叶组合、纯 Logo、果冻雷翻坑组合、探险家、蓝鸟、夜鹭、树精、印章，共 8 个，任选 4–5 |
| 02_角色立牌 | 角色立牌（约 80×200 cm） | 2400×6000 px（30 px/cm），透明底 | A 果冻雷版、B 探险家版：板内天空-树林-草地分层场景、一句话介绍、道具图标、五只鸟，可沿轮廓切 |
| 03_吊旗 | 吊旗（90×60 cm） | 5400×3600 px（60 px/cm） | 主视觉：Logo + 远山树线 + 草地岛 + 翻到果冻雷那一瞬间、五只鸟各有反应 |
| 04_丝绸手环 | 丝绸手环（350×15 mm） | 7000×300 px（20 px/mm） | 蜂蜜金底 / 墨绿底两色，Logo ×4 + 九个小图标 + 花瓣纹理，无标语 |

## 角色精灵原始分辨率

| 元素 | 原图 | 备注 |
|---|---|---|
| 果冻雷 | 300 px | 游戏里的“雷”，最有辨识度 |
| 探险家（主角） | 800 px | 半身圆形头像，底边为直切 |
| 树精 | 800 px | 大 Boss |
| 蓝鸟 / 夜鹭 / 其余鸟 | 220 px | 放大倍数最高，单独做窗贴建议 30–40 cm 而非 50 cm |
| Logo / 印章 / 缎带 / 文字 / 边框 | 矢量渲染 | 任意尺寸清晰 |

## 印刷注意
- 主色：墨绿 #2e3e27、蜂蜜金 #f2bd4c、奶油 #fff4d6、印章红 #c9463a、草绿 #9db552。
- 立牌与窗贴为透明底，轮廓即裁切线；建议外扩 3–5 mm 白边或墨绿边再切。
- 手环文字高度约 9 mm，建议采用蜂蜜金底版本，深色底在丝绸上易显脏。
- 重新生成：`python tools/build_materials.py`（需联网加载 Google Fonts）。
"""


def main():
    if os.path.isdir(BUILD):
        shutil.rmtree(BUILD)
    for folder in (DIR_STICKER, DIR_STANDEE, DIR_FLAG, DIR_BAND):
        if os.path.isdir(folder):
            shutil.rmtree(folder)
    build_stickers()
    build_standees()
    build_flag()
    build_bands()
    with open(os.path.join(OUT, "README.md"), "w", encoding="utf-8", newline="\n") as handle:
        handle.write(README)
    shutil.rmtree(BUILD, ignore_errors=True)
    print("done ->", OUT)


if __name__ == "__main__":
    sys.exit(main())
