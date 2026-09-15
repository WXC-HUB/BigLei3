# -*- coding: utf-8 -*-
"""把 artifacts/promo 的实机截图包成带画框、标语贴纸与装饰的宣传图（HTML → PNG，1920×1080）。

    python tools/build_promo.py            # 生成 HTML 并用 Edge 无头渲染成 PNG
    python tools/build_promo.py --no-render # 只生成 HTML

产物在 artifacts/promo/framed/。截图占满画面 90%%，四周墨绿衬边；左上角蜂蜜缎带写栏目，
画面里一张手写体标语贴纸、一只吐槽的鸟（或果冻）配云朵气泡，四处飘花瓣和星点，
右下角盖一枚「咕咕啾啾」印章。不讲玩法，只负责可爱。
"""
import base64
import io
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "artifacts", "promo")
OUT_DIR = os.path.join(SRC_DIR, "framed")
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

SHOT_LEFT, SHOT_TOP, SHOT_W, SHOT_H = 90, 50, 1740, 979

MASCOTS = {
    "jelly": "my_asset/monster_small.png",
    "blue": "my_asset/birds/blue_find_yes.png",
    "red": "my_asset/birds/red_idle_1.png",
    "heron": "my_asset/birds/black_idle_1.png",
    "wood": "my_asset/birds/attacker_idle_1.png",
    "kestrel": "my_asset/birds/eg_idle_1.png",
}

# 坐标全是 1920×1080 画布坐标。sticker: 标语贴纸左上角 + 旋转；mascot: 精灵 + 气泡。
PAGES = [
    {
        "slug": "01_gameplay",
        "src": "02_gameplay_bird.png",
        "kicker": "核心玩法",
        "sub": "扫雷，但鸟会帮忙（有时候）",
        "sticker": {"html": "手比脑子快，<em>扫雷也能爽</em>", "pos": (640, 905), "rot": -2},
        "mascot": {"kind": "jelly", "pos": (470, 880), "size": 160, "rot": -6, "flip": False,
                   "bubble": {"text": "我只是路过", "pos": (250, 760), "size": (250, 175), "rot": -6}},
    },
    {
        "slug": "02_world_map",
        "src": "03_world_map.png",
        "kicker": "世界地图",
        "sub": "六关，一条土路，慢慢走",
        "sticker": {"html": "六个大关卡，<em>机制更好玩</em>", "pos": (560, 118), "rot": -1.5},
        "mascot": {"kind": "heron", "pos": (1520, 790), "size": 210, "rot": 4, "flip": True,
                   "bubble": {"text": "前面那关……<br>我先不去了", "pos": (1240, 640), "size": (300, 210), "rot": 4}},
    },
    {
        "slug": "03_shop",
        "src": "04_shop.png",
        "kicker": "局间商店",
        "sub": "标雷赚的钱，全在这儿花光",
        "sticker": {"html": "店主大酬宾，<em>就是不打折</em>", "pos": (740, 735), "rot": -1.5},
        "mascot": {"kind": "kestrel", "pos": (1560, 860), "size": 170, "rot": -4, "flip": True,
                   "bubble": {"text": "5G 买我，<br>不亏", "pos": (1470, 690), "size": (260, 180), "rot": -4}},
    },
    {
        "slug": "04_custom_editor",
        "src": "05_custom_editor.png",
        "kicker": "自定义模式",
        "sub": "自己画关，害朋友",
        "sticker": {"html": "支持自定义，<em>创意无极限</em>", "pos": (330, 878), "rot": -1.5},
        "mascot": {"kind": "red", "pos": (990, 235), "size": 170, "rot": 4, "flip": True,
                   "bubble": {"text": "别发给我", "pos": (720, 190), "size": (250, 170), "rot": 4}},
    },
    {
        "slug": "05_aqueduct",
        "src": "08_aqueduct.png",
        "kicker": "彩蛋",
        "sub": "把红尾水鸲撩到第 21 下",
        "sticker": {"html": "你也是<em>鸟？？？</em>", "pos": (720, 930), "rot": -2},
        "mascot": {"kind": "red", "pos": (1555, 850), "size": 190, "rot": -5, "flip": False,
                   "bubble": {"text": "武魂真身！！！", "pos": (1270, 700), "size": (320, 215), "rot": -5}},
    },
]


def data_uri(path, mode="png", limit=None, quality=88):
    image = Image.open(path)
    if limit and max(image.size) > limit:
        ratio = limit / float(max(image.size))
        image = image.resize((int(image.size[0] * ratio), int(image.size[1] * ratio)), Image.LANCZOS)
    buffer = io.BytesIO()
    if mode == "jpeg":
        image.convert("RGB").save(buffer, "JPEG", quality=quality, optimize=True)
        mime = "image/jpeg"
    else:
        image.save(buffer, "PNG", optimize=True)
        mime = "image/png"
    return "data:%s;base64,%s" % (mime, base64.b64encode(buffer.getvalue()).decode("ascii"))


def petals_html(seed):
    """花瓣与星点：确定性伪随机，落在衬边和画面边缘，别糊到正中间。"""
    parts = []
    state = seed
    def rand():
        nonlocal state
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        return state / float(0x7FFFFFFF)
    for _ in range(22):
        # 只落在四周 260px 的环带里。
        edge = rand()
        if edge < 0.5:
            x = rand() * 1920
            y = rand() * 200 if edge < 0.25 else 880 + rand() * 200
        else:
            x = rand() * 260 if edge < 0.75 else 1660 + rand() * 260
            y = rand() * 1080
        size = 12 + rand() * 12
        parts.append(
            '<i class="petal%s" style="left:%dpx;top:%dpx;width:%dpx;height:%dpx;transform:rotate(%ddeg);opacity:%.2f"></i>'
            % ("" if rand() > 0.35 else " pale", x, y, size, size * 0.62, rand() * 360, 0.6 + rand() * 0.4))
    for _ in range(7):
        x = 80 + rand() * 1760
        y = 60 + rand() * 960
        size = 16 + rand() * 20
        parts.append('<i class="spark" style="left:%dpx;top:%dpx;width:%dpx;height:%dpx"></i>' % (x, y, size, size))
    return "\n".join(parts)


HTML = u"""<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>咕咕啾啾 · %(kicker)s</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=ZCOOL+KuaiLe&family=Noto+Sans+SC:wght@700;900&family=Fredoka:wght@600;700&display=swap">
<style>
:root {
  --ink: #2e3e27; --matte: #1c281b; --matte-2: #24331f;
  --honey: #f2bd4c; --honey-deep: #c8862a; --cream: #fff4d6; --paper: #f7e9c4; --seal: #c9463a;
}
html, body { margin: 0; height: 100%%; background: var(--matte); overflow: hidden; }
body { display: grid; place-items: center; font-family: "Noto Sans SC", "Microsoft YaHei", sans-serif; color: var(--ink); }
#stage {
  position: relative; width: 1920px; height: 1080px; overflow: hidden; transform-origin: center;
  background:
    radial-gradient(1200px 700px at 50%% 45%%, rgba(157,181,82,.18), rgba(157,181,82,0) 70%%),
    repeating-linear-gradient(135deg, rgba(255,255,255,.028) 0 2px, rgba(255,255,255,0) 2px 14px),
    linear-gradient(180deg, var(--matte-2), var(--matte));
}
#stage > * { position: absolute; }

/* 画框里的截图 */
.shot {
  left: %(shot_left)dpx; top: %(shot_top)dpx; width: %(shot_w)dpx; height: %(shot_h)dpx;
  border-radius: 20px; overflow: hidden; border: 6px solid var(--ink);
  box-shadow: inset 0 0 0 4px var(--cream), 0 0 0 3px rgba(255,244,214,.35), 0 30px 60px rgba(0,0,0,.55), 0 0 90px rgba(242,189,76,.18);
  background: url(%(shot)s) center / cover no-repeat;
}
.shot::after { content: ""; position: absolute; inset: 0; border-radius: 14px; box-shadow: inset 0 0 120px rgba(0,0,0,.18); }

/* 角落枝叶 */
.sprig { background: url(%(branch)s) center / contain no-repeat; pointer-events: none; filter: drop-shadow(0 10px 8px rgba(0,0,0,.45)); }
.sprig.tr { right: -40px; top: -18px; width: 320px; height: 240px; transform: rotate(-22deg) scaleX(-1); }
.sprig.bl { left: -50px; bottom: -30px; width: 300px; height: 225px; transform: rotate(152deg); }

/* 左上缎带 */
.ribbon {
  left: 34px; top: 18px; height: 84px; padding: 0 44px 0 40px; display: flex; align-items: baseline; gap: 22px;
  background: linear-gradient(180deg, #f7cd68, var(--honey) 55%%, #e0a93a);
  clip-path: polygon(0 0, 100%% 0, calc(100%% - 26px) 50%%, 100%% 100%%, 0 100%%);
  filter: drop-shadow(0 8px 0 rgba(0,0,0,.35)) drop-shadow(0 14px 20px rgba(0,0,0,.35));
  transform: rotate(-1.5deg);
}
.ribbon::before {
  content: ""; position: absolute; left: 18px; right: 40px; top: 10px; bottom: 10px;
  border-top: 2px dashed rgba(46,62,39,.35); border-bottom: 2px dashed rgba(46,62,39,.35);
}
.ribbon b { font-family: "ZCOOL KuaiLe", "Noto Sans SC", sans-serif; font-weight: 400; font-size: 44px; color: var(--ink); letter-spacing: .06em; line-height: 84px; }
.ribbon span { font-weight: 900; font-size: 20px; letter-spacing: .12em; color: rgba(46,62,39,.8); }

/* 标语贴纸 */
.sticker {
  left: %(sticker_x)dpx; top: %(sticker_y)dpx; transform: rotate(%(sticker_rot)sdeg);
  padding: 12px 38px 14px; background: var(--paper); border: 5px solid var(--ink); border-radius: 18px;
  box-shadow: 0 10px 0 var(--ink), 0 22px 30px rgba(0,0,0,.45);
  font-family: "ZCOOL KuaiLe", "Noto Sans SC", "Microsoft YaHei", sans-serif; font-size: 52px; line-height: 1.15; color: var(--ink); white-space: nowrap;
}
.sticker em { font-style: normal; color: var(--seal); }
.sticker::before, .sticker::after {
  /* 两条胶带，贴纸才像贴上去的 */
  content: ""; position: absolute; width: 96px; height: 30px; top: -20px;
  background: rgba(255,244,214,.72); border: 2px solid rgba(46,62,39,.35); transform: rotate(-8deg);
  box-shadow: 0 3px 6px rgba(0,0,0,.25);
}
.sticker::before { left: 26px; }
.sticker::after { right: 26px; transform: rotate(7deg); }

/* 吐槽的家伙 + 云朵气泡 */
.mascot {
  left: %(mascot_x)dpx; top: %(mascot_y)dpx; width: %(mascot_size)dpx; height: %(mascot_size)dpx;
  background: url(%(mascot)s) center / contain no-repeat;
  transform: rotate(%(mascot_rot)sdeg) scaleX(%(mascot_flip)s);
  filter: drop-shadow(0 12px 8px rgba(0,0,0,.5));
}
.bubble {
  left: %(bubble_x)dpx; top: %(bubble_y)dpx; width: %(bubble_w)dpx; height: %(bubble_h)dpx;
  background: url(%(cloud)s) center / 100%% 100%% no-repeat;
  display: grid; place-items: center; text-align: center; padding: 18px 40px 46px 40px; box-sizing: border-box;
  font-family: "ZCOOL KuaiLe", "Noto Sans SC", sans-serif; font-size: 27px; line-height: 1.1; color: var(--ink);
  transform: rotate(%(bubble_rot)sdeg) scaleX(%(bubble_flip)s);
  filter: drop-shadow(0 10px 10px rgba(0,0,0,.4));
}
.bubble > span { display: block; transform: scaleX(%(bubble_flip)s); }

/* 印章 */
.seal {
  right: 58px; bottom: 44px; width: 118px; height: 118px; border-radius: 16px; background: var(--seal);
  box-shadow: inset 0 0 0 5px var(--cream), inset 0 0 0 9px var(--seal), inset 0 0 0 11px rgba(255,244,214,.55), 0 8px 0 rgba(0,0,0,.4);
  display: grid; place-items: center; text-align: center;
  font-family: "ZCOOL KuaiLe", "Noto Sans SC", sans-serif; font-size: 34px; line-height: 1.1; letter-spacing: .06em; color: var(--cream);
  transform: rotate(8deg);
}

/* 花瓣、星点 */
.petal { border-radius: 60%% 60%% 60%% 60%% / 80%% 80%% 40%% 40%%; background: linear-gradient(160deg, #ffd7df, #f3a5b4); box-shadow: 0 1px 0 rgba(0,0,0,.35); }
.petal.pale { background: linear-gradient(160deg, #fff8e6, #ffe6b0); }
.spark {
  background: radial-gradient(circle, rgba(255,255,255,.95) 0 18%%, rgba(255,255,255,0) 20%%),
    linear-gradient(#fff6c8, #fff6c8) 50%% 0 / 14%% 100%% no-repeat,
    linear-gradient(#fff6c8, #fff6c8) 0 50%% / 100%% 14%% no-repeat;
  opacity: .9; filter: drop-shadow(0 0 6px rgba(255,220,120,.8));
}

.foot {
  left: 100px; right: 100px; bottom: 12px; height: 28px; display: flex; justify-content: space-between; align-items: center;
  font-family: "Fredoka", "Noto Sans SC", sans-serif; font-weight: 600; font-size: 18px; letter-spacing: .22em; color: rgba(255,244,214,.62);
}
.foot em { font-style: normal; font-family: "ZCOOL KuaiLe", "Noto Sans SC", sans-serif; font-size: 22px; letter-spacing: .3em; color: rgba(255,244,214,.85); }
</style>
</head>
<body>
<div id="stage">
  <div class="shot"></div>
%(petals)s
  <div class="mascot"></div>
  <div class="bubble"><span>%(bubble_text)s</span></div>
  <div class="sticker">%(sticker_html)s</div>
  <div class="ribbon"><b>%(kicker)s</b><span>%(sub)s</span></div>
  <div class="sprig tr"></div>
  <div class="sprig bl"></div>
  <div class="seal">咕咕<br>啾啾</div>
  <div class="foot"><em>咕咕啾啾</em><span>扫雷 × 肉鸽 × 五只不太靠谱的鸟　·　%(index)s</span></div>
</div>
<script>
(function () {
  var stage = document.getElementById("stage");
  function fit() { stage.style.transform = "scale(" + Math.min(innerWidth / 1920, innerHeight / 1080) + ")"; }
  addEventListener("resize", fit); fit();
})();
</script>
</body>
</html>
"""


def main(render=True):
    os.makedirs(OUT_DIR, exist_ok=True)
    branch = data_uri(os.path.join(ROOT, "my_asset", "birds", "tree_left_1.png"))
    cloud = data_uri(os.path.join(ROOT, "my_asset", "kuang_think_01.png"))
    total = len(PAGES)
    for number, page in enumerate(PAGES, 1):
        src = os.path.join(SRC_DIR, page["src"])
        if not os.path.exists(src):
            print("skip %s (missing %s)" % (page["slug"], page["src"]))
            continue
        sticker = page["sticker"]
        mascot = page["mascot"]
        bubble = mascot["bubble"]
        html = HTML % {
            "kicker": page["kicker"], "sub": page["sub"],
            "shot": data_uri(src, "jpeg", quality=92), "branch": branch, "cloud": cloud,
            "shot_left": SHOT_LEFT, "shot_top": SHOT_TOP, "shot_w": SHOT_W, "shot_h": SHOT_H,
            "sticker_html": sticker["html"], "sticker_x": sticker["pos"][0], "sticker_y": sticker["pos"][1], "sticker_rot": sticker["rot"],
            "mascot": data_uri(os.path.join(ROOT, MASCOTS[mascot["kind"]])),
            "mascot_x": mascot["pos"][0], "mascot_y": mascot["pos"][1], "mascot_size": mascot["size"],
            "mascot_rot": mascot["rot"], "mascot_flip": -1 if mascot["flip"] else 1,
            "bubble_text": bubble["text"], "bubble_x": bubble["pos"][0], "bubble_y": bubble["pos"][1],
            "bubble_w": bubble["size"][0], "bubble_h": bubble["size"][1], "bubble_rot": bubble["rot"],
            "bubble_flip": -1 if mascot["flip"] else 1,
            "petals": petals_html(number * 31 + 7),
            "index": "%02d / %02d" % (number, total),
        }
        html_path = os.path.join(OUT_DIR, page["slug"] + ".html")
        with open(html_path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(html)
        print("wrote", html_path)
        if render:
            png_path = os.path.join(OUT_DIR, page["slug"] + ".png")
            subprocess.run([
                EDGE, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                "--window-size=1920,1080", "--virtual-time-budget=12000",
                "--screenshot=" + png_path, "file:///" + html_path.replace("\\", "/"),
            ], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("rendered", png_path)


if __name__ == "__main__":
    main(render="--no-render" not in sys.argv)
