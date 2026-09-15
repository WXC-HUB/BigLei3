# -*- coding: utf-8 -*-
"""操作说明图两张（HTML → PNG，1920×1080）：
  01_controls.png  基础操作与目标：实机截图 + 编号标注 + 鼠标图例
  02_flow.png      新手指引：一局怎么打（四步流程）+ 五只鸟与道具一览

    python tools/build_guide.py            # 生成并渲染
    python tools/build_guide.py --no-render

产物在 artifacts/guide/。文字全部 ≥ 22px，普通屏幕能读。
"""
import base64
import io
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROMO = os.path.join(ROOT, "artifacts", "promo")
OUT_DIR = os.path.join(ROOT, "artifacts", "guide")
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"


def data_uri(path, mode="png", limit=None, quality=90):
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


def asset(rel, **kw):
    return data_uri(os.path.join(ROOT, rel), **kw)


COMMON_CSS = u"""
:root {
  --ink: #2e3e27; --matte: #1c281b; --matte-2: #24331f;
  --honey: #f2bd4c; --honey-deep: #c8862a; --cream: #fff4d6; --paper: #f7e9c4; --seal: #c9463a; --leaf: #9db552;
}
html, body { margin: 0; height: 100%; background: var(--matte); overflow: hidden; }
body { display: grid; place-items: center; font-family: "Noto Sans SC", "Microsoft YaHei", "PingFang SC", sans-serif; color: var(--ink); }
#stage {
  position: relative; width: 1920px; height: 1080px; overflow: hidden; transform-origin: center;
  background:
    radial-gradient(1200px 700px at 50% 45%, rgba(157,181,82,.16), rgba(157,181,82,0) 70%),
    repeating-linear-gradient(135deg, rgba(255,255,255,.028) 0 2px, rgba(255,255,255,0) 2px 14px),
    linear-gradient(180deg, var(--matte-2), var(--matte));
}
#stage > * { position: absolute; }
.frame { inset: 22px; border: 5px solid rgba(255,244,214,.55); border-radius: 26px; box-shadow: inset 0 0 0 3px rgba(46,62,39,.9), inset 0 0 0 5px rgba(255,244,214,.25); pointer-events: none; }
.sprig { background: url(%(branch)s) center / contain no-repeat; pointer-events: none; filter: drop-shadow(0 10px 8px rgba(0,0,0,.45)); }
.sprig.tr { right: -40px; top: -18px; width: 300px; height: 225px; transform: rotate(-22deg) scaleX(-1); }
.sprig.bl { left: -50px; bottom: -30px; width: 280px; height: 210px; transform: rotate(152deg); }
.ribbon {
  left: 34px; top: 18px; height: 84px; padding: 0 44px 0 40px; display: flex; align-items: baseline; gap: 22px;
  background: linear-gradient(180deg, #f7cd68, var(--honey) 55%, #e0a93a);
  clip-path: polygon(0 0, 100% 0, calc(100% - 26px) 50%, 100% 100%, 0 100%);
  filter: drop-shadow(0 8px 0 rgba(0,0,0,.35)) drop-shadow(0 14px 20px rgba(0,0,0,.35));
  transform: rotate(-1.5deg);
}
.ribbon b { font-family: "ZCOOL KuaiLe", "Noto Sans SC", sans-serif; font-weight: 400; font-size: 44px; color: var(--ink); letter-spacing: .06em; line-height: 84px; }
.ribbon span { font-weight: 900; font-size: 20px; letter-spacing: .12em; color: rgba(46,62,39,.8); }
.seal {
  right: 58px; bottom: 44px; width: 104px; height: 104px; border-radius: 14px; background: var(--seal);
  box-shadow: inset 0 0 0 5px var(--cream), inset 0 0 0 9px var(--seal), inset 0 0 0 11px rgba(255,244,214,.55), 0 8px 0 rgba(0,0,0,.4);
  display: grid; place-items: center; text-align: center;
  font-family: "ZCOOL KuaiLe", "Noto Sans SC", sans-serif; font-size: 30px; line-height: 1.1; letter-spacing: .06em; color: var(--cream);
  transform: rotate(8deg);
}
.foot {
  left: 100px; right: 100px; bottom: 12px; height: 28px; display: flex; justify-content: space-between; align-items: center;
  font-family: "Fredoka", "Noto Sans SC", sans-serif; font-weight: 600; font-size: 18px; letter-spacing: .22em; color: rgba(255,244,214,.62);
}
.foot em { font-style: normal; font-family: "ZCOOL KuaiLe", "Noto Sans SC", sans-serif; font-size: 22px; letter-spacing: .3em; color: rgba(255,244,214,.85); }
.num {
  width: 44px; height: 44px; border-radius: 50%; display: grid; place-items: center; flex: none;
  background: var(--honey); border: 3px solid var(--ink); color: var(--ink);
  font-family: "Fredoka", sans-serif; font-weight: 700; font-size: 26px; box-shadow: 0 3px 0 var(--ink);
}
.card {
  background: var(--paper); border: 4px solid var(--ink); border-radius: 16px; box-shadow: 0 6px 0 rgba(46,62,39,.95), 0 14px 22px rgba(0,0,0,.4);
}
"""

def common_css(ctx):
    """COMMON_CSS 里有大量 `%` 单位，先整体转义再放回占位符。"""
    return COMMON_CSS.replace("%", "%%").replace("%%(branch)s", "%(branch)s") % ctx


FONTS = u'<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=ZCOOL+KuaiLe&family=Noto+Sans+SC:wght@500;700;900&family=Fredoka:wght@600;700&display=swap">'

# ---------------------------------------------------------------------------
# 图 1：基础操作与目标
# ---------------------------------------------------------------------------
SHOT1 = dict(left=70, top=150, w=1150, h=647)

CALLOUTS = [
    # (编号, 原图坐标, 标题, 说明)
    (1, (330, 140), "生命与金币", "三颗心。踩到果冻雷或插错旗各扣 1 颗，归零这局就结束。标对的雷在盘末结算成金币。"),
    (2, (960, 150), "剩余雷 · 道具读数", "上面是这盘还剩几只雷没标；下面一排是本盘埋着的道具卡还剩几张。"),
    (3, (865, 655), "数字与连锁", "数字 = 周围 8 格里的雷数。翻到空白格会自动连锁展开。翻开全部安全格 = 清盘。"),
    (4, (150, 520), "五只鸟", "栖在两侧枝头。翻到对应的道具卡，鸟就飞出来帮忙：翻格、标雷、清行、无敌……"),
    (5, (1750, 640), "连击计分", "连续正确操作累积连击，分数成倍涨；踩雷或标错旗连击清零。"),
]


def guide1_html(ctx):
    scale = SHOT1["w"] / 1920.0
    dots = []
    for number, (x, y), _, _ in CALLOUTS:
        cx = SHOT1["left"] + x * scale
        cy = SHOT1["top"] + y * scale
        dots.append('<div class="dot" style="left:%.0fpx;top:%.0fpx"><span class="num">%d</span></div>' % (cx - 22, cy - 22, number))
    items = []
    for number, _, title, body in CALLOUTS:
        items.append(
            '<li><span class="num">%d</span><div><b>%s</b><p>%s</p></div></li>' % (number, title, body)
        )
    return u"""<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>咕咕啾啾 · 基础操作</title>%(fonts)s<style>%(common)s
.shot { left: %(sl)dpx; top: %(st)dpx; width: %(sw)dpx; height: %(sh)dpx; border-radius: 16px; border: 5px solid var(--ink);
  box-shadow: inset 0 0 0 3px var(--cream), 0 24px 40px rgba(0,0,0,.5); background: url(%(shot)s) center / cover no-repeat; }
.dot { width: 44px; height: 44px; }
.dot .num { position: absolute; left: 0; top: 0; box-shadow: 0 0 0 6px rgba(242,189,76,.35), 0 3px 0 var(--ink); }
.list { left: 1268px; top: 150px; width: 594px; margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: 14px; }
.list li { display: flex; gap: 16px; align-items: flex-start; padding: 14px 18px 14px 14px; background: var(--paper); border: 4px solid var(--ink); border-radius: 16px; box-shadow: 0 6px 0 rgba(46,62,39,.95), 0 12px 20px rgba(0,0,0,.4); }
.list b { display: block; font-size: 26px; font-weight: 900; letter-spacing: .04em; margin-bottom: 4px; }
.list p { margin: 0; font-size: 21px; line-height: 1.4; font-weight: 500; color: #3f4d37; }
.legend { left: 70px; top: 826px; width: 1150px; height: 190px; display: flex; gap: 18px; align-items: stretch; }
.legend .card { flex: 1; display: flex; align-items: center; gap: 18px; padding: 16px 20px; }
.mouse { position: relative; flex: none; width: 74px; height: 110px; border-radius: 34px 34px 38px 38px; background: #fffaf0; border: 4px solid var(--ink); overflow: hidden; box-shadow: 0 4px 0 var(--ink); }
.mouse::before { content: ""; position: absolute; left: 50%%; top: 0; width: 4px; height: 48px; background: var(--ink); transform: translateX(-50%%); }
.mouse::after { content: ""; position: absolute; left: 0; right: 0; top: 48px; height: 4px; background: var(--ink); }
.mouse i { position: absolute; top: 0; width: 50%%; height: 48px; background: var(--honey); }
.mouse.left i { left: 0; border-radius: 34px 0 0 0; }
.mouse.right i { right: 0; border-radius: 0 34px 0 0; }
.legend b { display: block; font-family: "ZCOOL KuaiLe", "Noto Sans SC", sans-serif; font-size: 34px; letter-spacing: .04em; line-height: 1.1; }
.legend b em { font-style: normal; color: var(--seal); }
.legend p { margin: 6px 0 0; font-size: 20px; line-height: 1.35; font-weight: 500; color: #3f4d37; }
.goal { left: 1268px; top: 826px; width: 594px; height: 190px; padding: 18px 24px; box-sizing: border-box; background: var(--ink); border: 4px solid var(--honey); border-radius: 16px; color: var(--cream); box-shadow: 0 12px 20px rgba(0,0,0,.4); }
.goal b { display: block; font-family: "ZCOOL KuaiLe", "Noto Sans SC", sans-serif; font-size: 34px; color: var(--honey); letter-spacing: .06em; margin-bottom: 8px; }
.goal p { margin: 0; font-size: 21px; line-height: 1.45; font-weight: 500; }
.goal p + p { margin-top: 4px; }
.goal em { font-style: normal; color: var(--honey); font-weight: 900; }
</style></head><body><div id="stage">
  <div class="shot"></div>
  %(dots)s
  <ul class="list">%(items)s</ul>
  <div class="legend">
    <div class="card"><div class="mouse left"><i></i></div><div><b>左键 <em>翻开</em></b><p>点一格就翻一格。第一下永远安全，随便点。</p></div></div>
    <div class="card"><div class="mouse right"><i></i></div><div><b>右键 <em>插旗 / 撤旗</em></b><p>觉得是雷就插旗。插错了会掉 1 颗心，别乱猜。</p></div></div>
  </div>
  <div class="goal"><b>这一盘的目标</b><p>把所有<em>不是雷</em>的格子翻开，就算清盘。雷不用点，插上旗子即可。</p><p>右上角「蒜鸟，下一关」可以跳过这盘，但拿不到金币。</p></div>
  <div class="ribbon"><b>基础操作</b><span>左键翻开 · 右键插旗 · 翻完安全格就赢</span></div>
  <div class="frame"></div><div class="sprig tr"></div><div class="sprig bl"></div>
  <div class="seal">咕咕<br>啾啾</div>
  <div class="foot"><em>咕咕啾啾</em><span>操作说明 · 01 / 02</span></div>
</div><script>(function(){var s=document.getElementById("stage");function f(){s.style.transform="scale("+Math.min(innerWidth/1920,innerHeight/1080)+")";}addEventListener("resize",f);f();})();</script></body></html>""" % dict(
        ctx, fonts=FONTS, sl=SHOT1["left"], st=SHOT1["top"], sw=SHOT1["w"], sh=SHOT1["h"],
        dots="\n".join(dots), items="\n".join(items), common=common_css(ctx),
    )


# ---------------------------------------------------------------------------
# 图 2：新手指引——一局怎么打 + 鸟与道具
# ---------------------------------------------------------------------------
STEPS = [
    ("03_world_map.png", "世界地图选关", "六关沿着土路排开，打通上一关才开下一关。每关是一整局从头开始的肉鸽。"),
    ("02_gameplay_bird.png", "一盘一盘清", "每关要连清好几盘异形棋盘。三颗心是整关共用的，掉光就回地图。"),
    ("04_shop.png", "结算 · 进商店", "每盘结束按标对的雷发金币。店主卖鸟的强化：更多灯、更多罗盘、更多无敌。"),
    ("05_custom_editor.png", "还想玩？自己画", "自定义模式：拖矩形画地图、配道具数量，导出 JSON 发给朋友互相为难。"),
]

ITEMS = [
    ("my_asset/birds/black_idle_1.png", "夜鹭 · 灯", "翻开后随机在周围翻开 1 格，保证没有雷。"),
    ("my_asset/birds/red_idle_1.png", "红尾水鸲 · 罗盘", "自动标出 1 只雷。"),
    ("my_asset/birds/attacker_idle_1.png", "啄木鸟 · 轰击", "清掉所在的一整行或一整列。"),
    ("my_asset/birds/eg_idle_1.png", "红隼 · 无敌", "接下来 1 步无敌，踩中雷也不掉血。"),
    ("assets/sprites/generated/potion_heal_green.png", "疗愈鸟 · 医疗包", "恢复 1 颗爱心，不超过上限。"),
    ("assets/sprites/generated/item_treasure_map.png", "透视", "随机 1 格显示内容 3 秒，但不翻开。"),
    ("assets/sprites/generated/item_rope.png", "连携", "与下一只标出的雷之间的格子全翻开，可转弯。"),
    ("assets/sprites/generated/potion_star_purple.png", "变大", "下一步连周围一起翻开，且这一步无敌。"),
    ("assets/sprites/generated/tool_metal_detector.png", "探测", "自动找出并标记 1 只还没处理的雷。"),
]


def guide2_html(ctx):
    steps = []
    for index, (src, title, body) in enumerate(STEPS, 1):
        thumb = data_uri(os.path.join(PROMO, src), "jpeg", limit=760, quality=88)
        steps.append(
            '<div class="step"><div class="thumb" style="background-image:url(%s)"></div>'
            '<div class="cap"><span class="num">%d</span><div><b>%s</b><p>%s</p></div></div></div>' % (thumb, index, title, body)
        )
        if index < len(STEPS):
            steps.append('<div class="arrow">➜</div>')
    items = []
    for src, title, body in ITEMS:
        items.append('<div class="item card"><i style="background-image:url(%s)"></i><div><b>%s</b><p>%s</p></div></div>' % (asset(src), title, body))
    return u"""<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>咕咕啾啾 · 新手指引</title>%(fonts)s<style>%(common)s
.steps { left: 60px; top: 132px; width: 1800px; display: flex; align-items: flex-start; gap: 0; }
.step { width: 400px; flex: none; }
.thumb { width: 400px; height: 225px; border-radius: 14px; border: 5px solid var(--ink); box-shadow: inset 0 0 0 3px var(--cream), 0 14px 24px rgba(0,0,0,.5); background-size: cover; background-position: center; box-sizing: border-box; }
.cap { display: flex; gap: 12px; align-items: flex-start; margin-top: 14px; padding: 0 4px; color: var(--cream); }
.cap b { display: block; font-family: "ZCOOL KuaiLe", "Noto Sans SC", sans-serif; font-size: 30px; color: var(--honey); letter-spacing: .04em; line-height: 1.1; margin-bottom: 6px; }
.cap p { margin: 0; font-size: 20px; line-height: 1.4; font-weight: 500; color: rgba(255,244,214,.88); }
.arrow { flex: 1; text-align: center; padding-top: 88px; font-size: 54px; color: var(--honey); text-shadow: 0 4px 0 rgba(0,0,0,.5); }
.section { left: 60px; top: 588px; display: flex; align-items: center; gap: 18px; color: var(--cream); }
.section b { font-family: "ZCOOL KuaiLe", "Noto Sans SC", sans-serif; font-size: 36px; color: var(--honey); letter-spacing: .06em; }
.section span { font-size: 21px; font-weight: 500; color: rgba(255,244,214,.8); }
.section::after { content: ""; width: 1000px; height: 3px; background: repeating-linear-gradient(90deg, rgba(255,244,214,.45) 0 12px, transparent 12px 22px); }
.grid { left: 60px; top: 650px; width: 1800px; display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px 18px; }
.item { display: flex; align-items: center; gap: 14px; padding: 10px 16px 10px 10px; min-height: 92px; box-sizing: border-box; }
.item i { flex: none; width: 76px; height: 76px; background-size: contain; background-repeat: no-repeat; background-position: center; filter: drop-shadow(0 3px 2px rgba(0,0,0,.25)); }
.item b { display: block; font-size: 24px; font-weight: 900; letter-spacing: .03em; margin-bottom: 3px; }
.item p { margin: 0; font-size: 19px; line-height: 1.35; font-weight: 500; color: #3f4d37; }
</style></head><body><div id="stage">
  <div class="steps">%(steps)s</div>
  <div class="section"><b>五只鸟与道具</b><span>翻到卡就自动使用，越买越多</span></div>
  <div class="grid">%(items)s</div>
  <div class="ribbon"><b>新手指引</b><span>一局怎么打 · 鸟都能干什么</span></div>
  <div class="frame"></div><div class="sprig tr"></div><div class="sprig bl"></div>
  <div class="seal">咕咕<br>啾啾</div>
  <div class="foot"><em>咕咕啾啾</em><span>操作说明 · 02 / 02</span></div>
</div><script>(function(){var s=document.getElementById("stage");function f(){s.style.transform="scale("+Math.min(innerWidth/1920,innerHeight/1080)+")";}addEventListener("resize",f);f();})();</script></body></html>""" % dict(
        ctx, fonts=FONTS, steps="\n".join(steps), items="\n".join(items), common=common_css(ctx),
    )


def main(render=True):
    os.makedirs(OUT_DIR, exist_ok=True)
    ctx = {"branch": asset("my_asset/birds/tree_left_1.png"), "shot": data_uri(os.path.join(PROMO, "02_gameplay_bird.png"), "jpeg", quality=92)}
    pages = [("01_controls", guide1_html(ctx)), ("02_flow", guide2_html(ctx))]
    for slug, html in pages:
        html_path = os.path.join(OUT_DIR, slug + ".html")
        with open(html_path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(html)
        print("wrote", html_path)
        if render:
            png_path = os.path.join(OUT_DIR, slug + ".png")
            subprocess.run([
                EDGE, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                "--window-size=1920,1080", "--virtual-time-budget=12000",
                "--screenshot=" + png_path, "file:///" + html_path.replace("\\", "/"),
            ], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("rendered", png_path, os.path.getsize(png_path) // 1024, "KB")


if __name__ == "__main__":
    main(render="--no-render" not in sys.argv)
