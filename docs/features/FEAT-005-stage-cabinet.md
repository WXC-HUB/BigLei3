# FEAT-005: stage-cabinet

| 字段 | 值 |
|---|---|
| ID | FEAT-005 |
| 状态 | 🟣 待收尾 |
| 起 | 2026-09-11 |
| 止 | - |
| 一句话目的 | 选关界面改成「一个柜子六件展品」：六关各是一件独立的低模场景艺术品，排成一列摆在同一张波点桌布上，一次只看一件，左右箭头滑到相邻关卡，滑进来的那件重新搭起来 |
| 需独立 UI 设计 | 是（沿用 FEAT-002 的顶栏/悬浮牌/续局条，新增聚焦卡） |
| 归属模块 | WorldMap |
| 关联模块 | GameFlow, Persistence |
| 新建模块 | 无（WorldMap 模块内换壳） |

## 术语 (Terminology)

| 中文 | English | 定义 | 所属模块 | 状态 |
|---|---|---|---|---|
| 陈列柜 | Stage Cabinet | 选关界面的新壳：一张波点桌布的台面上把六件展品排成一列，一次只看一件，左右切换 | WorldMap | 🔵 spec |
| 展品 | Stage Diorama | 一关一件的低模场景艺术品（Blender 脚本生成 GLB + 布局 JSON），自带入场动画与拾取体 | WorldMap | 🔵 spec |
| 泥胚 | Clay Maquette | 两层意思：①还没做出真展品的关卡用灰泥胚占位岛顶着；②未解锁的关卡整件抽色染灰，读作「还没上色」 | WorldMap | 🔵 spec |
| 切换 | Slide | 相机沿画面横向滑到相邻展品：切走的收回台面、滑进来的重搭 | WorldMap | 🔵 spec |
| 搭积木入场 | Build-up Entrance | 展品从台面弹起、各件道具按编好的时刻围自己的基点果冻式弹出的入场动画（顶点色编码，一个着色器驱动） | WorldMap | 🔵 spec |

## Discuss

### 背景

FEAT-002 的六边形/体素大地图在一张图上堆六个主题，越打磨越拥挤。用户于 2026-09-11 决定换方向：每关做成一件独立展品（参考图：奶油底、阶梯悬崖、瓦顶小屋的低模农庄），选关界面变成陈列这些展品的柜子。第一关「青草坡」已按参考图做出（QUICK_LOG #7/#8），本 FEAT 是壳层改造。

### ▶ 共识

1. **壳层重写、接口不变**：新建 `StageCabinet`（`scenes/stage_cabinet.tscn` + `scripts/ui/stage_cabinet.gd`），对主场景暴露与 `WorldMap` 完全相同的信号与 `present()/dismiss()`；`main.gd` 只改加载路径与类型。老地图文件保留不删（`WorldMap.apply_toon_water_material` 仍被解锁页与展品复用；老测试照跑）。
2. **六个位置一件真展品**：青草坡是真展品，其余五关用灰泥胚占位岛（`assets/dioramas/placeholder`，Blender 生成），以后一件件替换，替换只需把 GLB+JSON 放进 `assets/dioramas/<stage_id>/`，`StageDiorama.paths_for()` 自动接上。
3. **摆法（用户 2026-09-11 纠正：不要整柜总览）**：六件沿画面横向排成一列（世界坐标里转了相机方位角），间距 60 比一屏宽，停下时只看得见当前一件；相机俯仰/方位与单件展示一致（-37° / 31°），每件展品的光影与单独展示完全一样。关卡之间不画路，也没有矮台。
4. **左右切换**：屏幕两侧 ‹ › 圆按钮或键盘 ←/→（A/D）切到相邻关卡，两端禁用不循环。切换 0.72 s：相机沿横向滑，切走的展品按原路收回台面（`play_exit`），滑进来的展品先收成空、滑到一半多一点开始重搭。可以浏览未解锁的关卡（泥胚色），只是卡上的按钮是禁用的「未解锁」。点当前展品本体、牌子或卡上主按钮进关。
5. **状态呈现**：悬浮牌沿用 StageBadge 四态；未解锁的展品整件抽色染暖灰（着色器 `desaturate`/`tint`）、溪水收掉。悬停一件轻抬 0.35。
6. **续局单槽**：present 时有续局就停在进行中的那关，卡上是「续上这一关」+「放弃」，续局条（卡内一行琥珀提示）写到第几盘；切到别关时续局条改成提醒「进这一关会放弃那份进度」，进入先弹放弃确认，确认后 `abandon_requested` → `stage_selected`，与 FEAT-002 共识 6 一致。没有续局就停在第一个可挑战的关。
7. **进场**：柜子每次 present（从隐藏变可见）当前那件重搭一遍；蚊子（QUICK_LOG #6）搬到柜子 UI 层继续飞。

## Spec

### 验收标准

- 主场景点「开始」（或回地图）出现的是陈列柜；六件展品、六张牌、顶栏三件、左右箭头、关卡卡（含续局条）与确认卡都在；`tests/test_stage_run_flow.gd` 与 `tests/test_start_screen_prefab.gd` 的地图断言改成 `StageCabinet` 后通过。
- `tests/test_stage_cabinet.gd`：六件展品排成一列且带拾取体、present 停在该打的关并只有它在播入场、四态与泥胚观感、‹ › 切换时相机滑动/切走收回/滑进重搭、两端禁用、锁定关按钮禁用且不发信号、进入（按钮/本体/牌子）发 `stage_selected`、续局的续上/放弃/进别关先确认（信号顺序 `abandon → select`）、右键/顶栏信号、dismiss 收干净。
- `tools/capture_cabinet.gd` 出第一关、切换途中、第二关三张过目图。

### 修改范围（合同）

新建：`scripts/ui/stage_cabinet.gd`、`scenes/stage_cabinet.tscn`、`tools/build_diorama_placeholder.py`、`assets/dioramas/placeholder/`、`tools/capture_cabinet.gd`、`tests/test_stage_cabinet.gd`。
修改：`scripts/ui/stage_diorama.gd`（托管模式 `standalone=false`、`paths_for`、`set_locked_look`、拾取体、静态展柜零件）、`shaders/diorama_build.gdshader`（抽色/染色）、`scripts/main.gd`（`_world_map` 类型与加载路径，两处）、`tests/test_stage_run_flow.gd` / `tests/test_start_screen_prefab.gd`（类型转换）、NAVIGATION、README、FEATURES。
不动：`scripts/ui/world_map.gd`、`scenes/world_map.tscn`、`tests/test_world_map.gd`（老壳层封存）。

### 边界 & 不做

- 第 7 关「无尽远海」的展品另议（由另一条线负责无尽关本身）；目前用泥胚占位。
- 老地图上的随机事件（啄木鸟、苍鹭、红隼、红尾鸲拍照、面包与鸽子）不迁移；它们是老壳层的彩蛋，新柜子的彩蛋以后另议。
- 局外成长数值位继续只占位。

## Implementation Log

### 2026-09-11

- 展品托管模式：`StageDiorama.standalone=false` 时不建台面/灯/环境/相机，只留模型、水、锚点、岛影、拾取体；台面/灯/环境的构造抽成静态方法给柜子复用，保证同一套光。
- 泥胚占位岛：`tools/build_diorama_placeholder.py`，圆角矩形台地 + 抽象方块屋/树/石，同样的顶点色入场编码。
- 柜子：见共识 1～7；相机飞行用两个 tween_method 同步推 target 与 size。
- 摆位第二稿：六件沿**画面**横向/纵深排 3×2，总览才是齐整的柜子；矮台顺着画面横向摆。第一稿沿世界轴摆，总览成了菱形、矮台成了斜穿画面的一道带子。
- 第三稿（用户纠正）：不要整柜总览，改成一列 + 左右箭头切换；矮台、总览、返回总览全部去掉，聚焦卡变成常驻关卡卡并吸收续局条；切走的展品新增 `StageDiorama.play_exit()` 按原路收回。
- 测试教训：无头跑时一帧远不到 1/60 秒，等相机/入场要盯 `is_transitioning()` / `is_entrance_playing()`，不能数帧。
- `main.gd` 只改两处：`_world_map` 的类型与 `_build_world_map()` 的加载路径；`tests/test_stage_run_flow.gd`、`tests/test_start_screen_prefab.gd` 的 `as WorldMap` 改成 `as StageCabinet`。

### 2026-09-12 · 六件真展品与专属配色

- 用户要求每关专属配色与场景主题、桌布波点跟着换、配色差异化且合理。道具生成器抽成 `tools/diorama_props.py`（`Scene` + 按配色表取色的 `Props`，青草坡的颜色是默认表），新增风车、谷仓、麦捆、稻草人、板车、水井、钟楼、灯柱、柳树、芦苇、鸢尾、拱桥、水车、栈桥、船、灯塔、浮标、吊脚屋、巨石、杨树、市集棚等；地面绘制新增麦垄条纹 `stripes`、石板 `cobbles`、按格刷区域 `paint_cells`；地形支持多层水位（`bed_chars`）。
- 六关主题与配色（相邻两关色相/明度都拉开）：①青草坡 灰绿草地 + 奶油墙 + 陶土瓦，暖奶油桌布；②麦垄 麦金与赭土、橄榄黄草地，谷仓红是唯一强调、屋顶炭灰压住金色，小麦色桌布配金/赭/锈点；③老井村 冷绿草地、灰石、青蓝板岩屋顶，青蓝门与灯笼暖光点睛，冷灰奶油桌布配板岩/苔/石点；④双桥 春日亮绿与浅沙河岸、清透蓝绿水，朱红拱桥是唯一热色，屋顶绿灰板岩，薄荷奶油桌布配水青/叶/朱粉点；⑤深潭 深青潭水、暗苔绿、板岩灰石，灯笼与锦鲤是仅有的暖色，暮色灰紫桌布配青/靛/苔点；⑥尽头港 海蓝、白墙、藏青屋顶与门，红白灯塔与珊瑚浮标点睛，浅石灰岩悬崖与黄绿海边草，亮奶油桌布配海/藏青灰/珊瑚点。
- Godot：`StageDiorama` 读 JSON `table`（桌布配色）、`water`（水色）、`water_levels`（多层水位，深潭的台地小溪与潭面两层）；`StageCabinet` 切换时把共用台面材质与背景色按 `SLIDE_DURATION` 渐变到当前展品的桌布配色。每关一个 `scenes/dioramas/<id>.tscn` 可 F6 预览。测试 `tests/test_stage_dioramas.gd` 检查六关都是真展品、水面层数、水色、锚点，并量化桌布配色两两与相邻的差异。截图 `tools/capture_stages.gd` 从第一关一路切到最后一关各拍一张。

### 2026-09-12 · 场景拉开差距

- 用户看图后指出「房子太多、太同质化，场景差距要拉开」：青草坡、老井村、双桥、尽头港当时都是「草地 + 山墙小屋 + 换屋顶色」。改法：每关只保留一种别处没有的主景与地形轮廓，小屋只留给青草坡。
  - 老井村：三级梯田（1.4 / 0.7 / 0）斜着从后左降到前右，台沿干砌石墙、石阶（`steps` 新增 `base_z` 与竖向 `axis="c"`）、方形石塔、两长一短三座低矮石屋（石砌、小深窗、石门楣，无百叶与花箱）、井亭（四柱两重板岩顶，锚点）与挂红绸的古树、石栏畜栏 + 石槽、菜畦台地。桌布改冷蓝灰。
  - 双桥：河汇成潭、潭心小岛上一座六角亭（锚点），两座朱红拱桥错行搭上岛；石灯笼、六棵垂柳、观景木台、踏石；唯一建筑是水磨（石基 + 木板层 + 阁楼门，轮圈 + 辐条 + 桨板的真轮子）。
  - 尽头港：防波堤（掩码 B，0.35 高）从右岸合围港池，灯塔在堤尖；岸上只有长条船库（木板墙、藏青大门、圆窗、救生圈、烟管）与高窄港务塔（阳台、旗杆三角旗）；吊车、晾网架、龟笼、系船柱、沙滩上拉上岸的船（`boat(ground=True)`）。桌布改浅天蓝白。
- 修 bug：`Kit.finalize` 用 bmesh 合并部件时没有带 UV 层，导出的地形没有 TEXCOORD_0，所有手绘地面（石板广场、沙滩、麦垄条纹、沙径、接触阴影）在引擎里都只剩棋盘底色——前几轮截图里「石板不明显、沙滩看不见」就是它。现在按部件把 UV 写进合并网格；`tools/dump_diorama_texture.gd` 可把引擎解出的地形贴图存成 PNG 核对；`tests/test_stage_dioramas.gd` 新增「带贴图的面必须有 UV」。
- 六关配色最终值以 `tools/build_diorama_<id>.py` 顶部 `TABLE` 为准；`scratchpad` 里的距离算法与测试一致（两两 > 0.05、相邻 > 0.07）。

### 2026-09-12 · 可动要素与荒废态

- 用户两条新需求：①更多可动要素（云 + 地面云影、鸟动、船动、水动、植被摇曳）；②每关按是否通关有自己的「枯萎荒废态」，且是整套设计语言，不只是植物变化。
- **微动**：不在 Godot 里逐件做动画，而是把「这件东西怎么动」编进模型——Blender 端 `kit.piece(..., motion=(kind, phase))`，finalize 写进第二套 UV「Motion」（TEXCOORD_1：x = (kind+0.5)/32，y = 相位）；`diorama_build.gdshader` 的 vertex() 按 kind 围着该件的基点（顶点色里那份）做位移/旋转：1 枝叶摇曳、2 停鸟点头、3 船浮标摇晃、4 风车翼绕 z 转、5 水车绕 x 转、6 悬挂物钟摆、7 炊烟、8 旗帆抖、9 绕圈飞、10 绕圈游、11 水面漂浮。需要独立转动的部件（风车翼、水车轮、红绸、渔网、吊车货、三角旗、每条锦鲤、每团烟、每只飞鸟）各自成 piece，基点就是转轴/悬点。荒废态 `motion_amount` 收到 0.45。
- **云**：`StageDiorama._build_clouds()`：3 朵球团卡通云（`cartoon_cloud.gdshader`，不吃光），沿 `wind`（柜子设成画面横向）漂，飘出航线从另一头回来；云影两份：只投影的椭球给主光真阴影（岛面与道具都吃到），水面因为 unshaded 吃不到灯光阴影，所以每帧把云的地面落点塞给水着色器 `cloud_shadows`。荒废态的云偏灰暗。
- **荒废态**：同一布景脚本 `DIORAMA_WITHERED=1` 出第二版 `<id>_withered.glb/.json`（JSON 带 `withered: true`，桌布 `wither_table`）。`Props(withered=True)`：配色过 `wither_palette`（`wither_hex`：绿→枯黄、饱和度 ×0.42、对比压一点、往灰米色靠 14%，再叠 `WITHERED_OVERRIDES`），生成器逐个分支出荒废版（见 QUICK_LOG #11 清单）；地面绘制全部颜色经 `GroundPainter(tint=wither_hex)`；干涸的水床改成有 UV 的顶面并刷裂纹泥（`bed_chars` 去掉该字符 + `paint_cells` 泥色 cobbles）；鸟全走只留一只乌鸦（`dove()` 第一次调用）、没有炊烟没有飞鸟。
- **柜子**：`StageDiorama.withered` + `paths_for(id, want_withered)`；`present()` 按 `cleared` 给每件 `set_withered(...)`；这次回来新通关的关先停在它身上，`set_withered(false, animate=true)`：`play_exit` 收回 → 换模型/水/桌布 → `play_entrance` 重搭；播完停 `ADVANCE_DELAY` 再自动滑到下一关（已解锁且未通关时）。未解锁的关 = 荒废版 + 泥胚抽色，可挑战的关 = 荒废版原色，通关的关 = 生机版。
- 测试：`tests/test_stage_dioramas.gd` 加荒废版存在/标记/桌布更灰、微动编码、云与投影体；`tests/test_stage_cabinet.gd` 加版本归属与复原→自动前进流程（也把「麦垄是泥胚」的旧断言改成无尽关）。截图 `DIORAMA_WITHERED=1 godot --fixed-fps 60 --script tools/capture_stages.gd` 出六关荒废版。

### 2026-09-12 · 通关流程：排行榜 → 复原仪式 → 自动下一关

- 用户定下通关后的顺序：①弹排行榜页；②播本关从荒芜到正常的动画，配粒子与文字反馈；③自动切到下一关。
- 主场景已有的顺序是「present 柜子 → 开榜（阻塞）→ 关榜再 present」，所以柜子这边只需把复原变成**待播**：present 发现新通关的关就停在它身上、保持荒废版、记进 `_pending_restore_id`；`_process` 里等 `visible` 且没有 `modal_overlay`（排行榜在这个组里）再起播；再 present 一次（关榜后那次）不会丢掉待播，也不会把它换成生机版。仪式进行中或待播时，进关、点展品、左右切换都不响应。
- 仪式内容：`StageDiorama.set_withered(false, animate=true)` 收回 → 换模型 → `_spawn_restore_effects()`（台面一圈暖光 `TorusMesh` 扩开淡出；`CPUParticles3D` 叶片花瓣 96 粒随风飘落、暖光点 64 粒加法上浮；1.65 s 后锚点处一团星屑）→ `play_entrance` 重搭；柜子 UI 弹标题卡 `RestoreTitle`（「「关名」复苏」+ 副题）与三行 `RestoreLines` 短句（`RESTORE_LINES` 按关卡，`RESTORE_LINE_TIMES` 1.05 / 1.85 / 2.65 s，短句各自飘完淡掉），模型搭完后标题卡还要留 `RESTORE_TAIL`（1.15 s）让最后一句说完，这段尾巴里柜子仍不接受操作，整段仪式读起来是一拍；之后标题淡出、停 `ADVANCE_DELAY`（1.7 s）再 `_go_to(next)`。短句按 `_ceremony_token` 认领，仪式结束后迟到的定时器不会再弹出短句。粒子材质必须 `billboard_keep_scale = true`，否则每粒都按网格原尺寸渲、未激活的粒子在发射点留黑方块。
- 测试 `tests/test_stage_cabinet.gd::_check_restore`：假排行榜（加入 `modal_overlay` 的 CanvasLayer）开着时不起播且再 present 不丢；关掉后起播、有标题、有粒子节点 `RestoreFx/RestoreLeaves`、有短句、复原后是生机版、自动滑到下一关。截图 `tools/capture_restore.gd` 连拍六帧。

- 用户反馈「特效稍微放慢」：收回 0.5 → 0.72 s，台面光圈 1.15 → 1.85 s，花瓣叶片寿命 2.6 → 3.9 s（初速与重力、自转都降一档，飘得更悠），光点 3.0 → 4.4 s，星屑 0.85 → 1.25 s 且晚到 1.95 s（对上鸟落回的时刻），粒子节点回收 3.6 → 5.6 s；标题卡进 0.42/0.3 → 0.58/0.4 s、出 0.4 → 0.6 s，短句进 0.28/0.2 → 0.38/0.28 s、停 0.9 → 1.45 s、飘 1.1 → 1.6 s。展品自身的「搭积木」入场时序不动（用户早前要的就是快弹手感），慢的只是仪式外围。
