# -*- coding: utf-8 -*-
"""把本次制作的全部宣传资源整理成一个 zip：artifacts/咕咕啾啾_宣传素材包.zip

    python tools/pack_promo_bundle.py            # 不含 exe
    python tools/pack_promo_bundle.py --with-exe # 顺带打进 build/windows/BigLei3.exe
"""
import os
import shutil
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "artifacts")
STAGE = os.path.join(ART, "_bundle")
ZIP = os.path.join(ART, "咕咕啾啾_宣传素材包.zip")

# (目标子目录, 源文件/目录列表)
PLAN = [
    ("01_封面", [
        "artifacts/cover/cover.png",
        "artifacts/cover/cover.html",
    ]),
    ("02_宣传截图/带标语版", [
        "artifacts/promo/framed/01_gameplay.png",
        "artifacts/promo/framed/02_world_map.png",
        "artifacts/promo/framed/03_shop.png",
        "artifacts/promo/framed/04_custom_editor.png",
        "artifacts/promo/framed/05_aqueduct.png",
    ]),
    ("02_宣传截图/原始实机截图", [
        "artifacts/promo/01_gameplay.png",
        "artifacts/promo/02_gameplay_bird.png",
        "artifacts/promo/03_world_map.png",
        "artifacts/promo/04_shop.png",
        "artifacts/promo/05_custom_editor.png",
        "artifacts/promo/06_redstart_unlock.png",
        "artifacts/promo/07_aqueduct_rising.png",
        "artifacts/promo/08_aqueduct.png",
    ]),
    ("03_操作说明图", [
        "artifacts/guide/01_controls.png",
        "artifacts/guide/02_flow.png",
    ]),
    ("04_线下物料", [
        "artifacts/materials/01_窗贴",
        "artifacts/materials/02_角色立牌",
        "artifacts/materials/03_吊旗",
        "artifacts/materials/04_丝绸手环",
        "artifacts/materials/README.md",
    ]),
    ("06_生成脚本", [
        "tools/build_cover.py",
        "tools/build_promo.py",
        "tools/build_guide.py",
        "tools/build_materials.py",
        "tools/capture_promo.gd",
        "tools/capture_promo_map.gd",
        "tools/capture_promo_aqueduct.gd",
        "tools/pack_promo_bundle.py",
    ]),
]
EXE = ("05_游戏包", ["build/windows/BigLei3.exe"])

README = u"""# 《咕咕啾啾》宣传素材包

扫雷 × 肉鸽 × 五只不太靠谱的鸟。全部图片为 PNG，尺寸见各目录说明。

| 目录 | 内容 | 尺寸 |
|---|---|---|
| 01_封面 | 游戏封面成品 PNG，以及可再改的 HTML 源（精灵图已内嵌，双击即开） | 1920×1080 |
| 02_宣传截图/带标语版 | 5 张：核心玩法 / 世界地图 / 局间商店 / 自定义模式 / 彩蛋水渠，带画框、标语贴纸和吐槽小鸟。提交 2–4 张，推荐前 4 张 | 1920×1080 |
| 02_宣传截图/原始实机截图 | 8 张未加工的实机画面，含红隼无敌时刻与水渠彩蛋三帧 | 1920×1080 |
| 03_操作说明图 | 2 张：基础操作与目标 / 新手指引（一局怎么打 + 鸟与道具一览） | 1920×1080 |
| 04_线下物料 | 窗贴（8 个透明底元素）/ 角色立牌 2 款 / 吊旗 / 丝绸手环 2 色，附 README 写明规格与印刷注意 | 见子目录 README |
| 05_游戏包 | Windows 单文件 exe（可选，体积大） | — |
| 06_生成脚本 | 所有图的生成脚本。Python 脚本用 Pillow + Edge 无头渲染，Godot 脚本负责实机截图 | — |

## 重新生成
在游戏工程根目录执行（需要联网加载 Google Fonts，需要本机 Edge）：

    python tools/build_cover.py
    python tools/build_promo.py
    python tools/build_guide.py
    python tools/build_materials.py

实机截图需要真实窗口（不能 --headless）：

    godot --resolution 1920x1080 --fixed-fps 60 --script tools/capture_promo.gd
    godot --resolution 1920x1080 --fixed-fps 60 --script tools/capture_promo_map.gd
    godot --resolution 1920x1080 --fixed-fps 60 --script tools/capture_promo_aqueduct.gd

## 视觉规范
- 主色：墨绿 #2e3e27、蜂蜜金 #f2bd4c、奶油 #fff4d6、印章红 #c9463a、草绿 #9db552。
- 字体：标题 ZCOOL KuaiLe（站酷快乐体），正文 Noto Sans SC，数字 Fredoka。
- 口号：有福同享 · 有难退队。
"""


def copy_into(dest_dir, rel):
    src = os.path.join(ROOT, rel)
    if not os.path.exists(src):
        print("  ! missing", rel)
        return 0
    os.makedirs(dest_dir, exist_ok=True)
    if os.path.isdir(src):
        target = os.path.join(dest_dir, os.path.basename(src))
        shutil.copytree(src, target, dirs_exist_ok=True)
        return sum(len(files) for _, _, files in os.walk(target))
    shutil.copy2(src, os.path.join(dest_dir, os.path.basename(src)))
    return 1


def main(with_exe=False):
    if os.path.isdir(STAGE):
        shutil.rmtree(STAGE)
    os.makedirs(STAGE)
    plan = PLAN + ([EXE] if with_exe else [])
    total = 0
    for sub, items in plan:
        dest = os.path.join(STAGE, sub)
        for rel in items:
            total += copy_into(dest, rel)
    with open(os.path.join(STAGE, "README.md"), "w", encoding="utf-8", newline="\n") as handle:
        handle.write(README)
    if os.path.exists(ZIP):
        os.remove(ZIP)
    with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for folder, _, files in os.walk(STAGE):
            for name in files:
                path = os.path.join(folder, name)
                archive.write(path, os.path.relpath(path, STAGE))
    shutil.rmtree(STAGE)
    print("files:", total + 1)
    print("zip:", ZIP, "%.1f MB" % (os.path.getsize(ZIP) / 1048576.0))


if __name__ == "__main__":
    main("--with-exe" in sys.argv)
