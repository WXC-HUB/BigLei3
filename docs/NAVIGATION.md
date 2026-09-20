# 导航 · 模块库 & 术语库

> 本项目的**模块地图**与**术语字典**。全项目按"模块"组织，每个 Feature 的关键概念都登记为中英对照术语。
>
> **谁维护**：`/wxc-mini:start` `discuss` `spec` `do-it` `that-is-all` `quick` 按各自阶段写入；`/wxc-mini:term-list` 只读展示。

---

## 模块库 (Module Registry)

> 一个"模块"是一块有明确职责边界、对外接口相对稳定的代码/资产集合（autoload / 子系统 / 场景族）。
> 每个 Feature 必须声明**归属模块**（主战场）与**关联模块**（会读/会碰但不主改）。

**模块状态**：🟡 拟建（start/discuss 提出） · 🟢 活跃（do-it 已落地） · 🗑️ 废弃（已移除，保留条目备查）

### 索引表

| 模块 | 职责(一句话) | 关联模块 | 关联 FEAT | 状态 |
|---|---|---|---|---|
| SplitScreen | 对战分屏布局、对手棋盘位与迷雾罩 | GameFlow, Netplay | FEAT-003 | 🟢 活跃 |
| CustomLevel | 自定义关卡：画地图、配雷数与道具、JSON 导入导出、编辑器界面 | GameFlow, BoardModel | quick #1 | 🟢 活跃 |
| Netplay | 联机连接、消息收发与对战局状态机 | BoardModel, GameFlow, ShopEconomy, Persistence | FEAT-001, FEAT-003 | 🟢 活跃 |
| WorldMap | 陈列柜选关（FEAT-005）：六件关卡展品排成一列摆在一张波点桌布上，一次只看一件、左右箭头切换；展品由 Blender 脚本生成；悬浮牌、续局单槽、看榜沿用；老的六边/体素大地图封存未删 | GameFlow, Persistence, ShopEconomy, BoardModel | FEAT-002, FEAT-005 | 🟢 活跃 |
| BoardModel | 扫雷棋盘的纯规则核（布雷、翻开、标记、道具散布、推理） | — | FEAT-001, FEAT-002 | 🟢 活跃 |
| GameFlow | 关卡流转、回合结算与演出编排 | BoardModel, ShopEconomy, Persistence, WorldMap, SplitScreen | FEAT-001, FEAT-002, FEAT-003 | 🟢 活跃 |
| ShopEconomy | 金币收支与关卡间商店的道具/强化购买 | GameFlow | FEAT-001, FEAT-002 | 🟢 活跃 |
| Persistence | 单槽存档的读写与 run 进度恢复 | GameFlow | FEAT-001, FEAT-002 | 🟢 活跃 |

### 模块详情

### SplitScreen

- **职责**：对战分屏布局、对手棋盘位与迷雾罩。代码位于 `scripts/ui/opponent_board_slot.gd`、`scripts/ui/duel_hud.gd` 的分屏部分，以及 `main.gd` 的 `_apply_split_layout()`。
- **对外接口**（草稿，待 that-is-all 定稿）：
  - `OpponentBoardSlot.set_board(columns, rows, cell_size, gap) -> Vector2` — 按行列重排并返回整块位的尺寸
  - `OpponentBoardSlot.flash()` — 对手标雷时整片雾闪一次
  - `DuelHud.set_opponent_board(columns, rows, cell_size, gap, center_offset)` / `flash_opponent_board()`
  - `main.gd` 的 `_cell_size` / `_board_center_offset` — 分屏几何的唯一真相，所有 offset 写入点都读它
  - **零网络接口**：对手棋盘全遮，棋盘状态不过线
- **关联模块**：GameFlow, Netplay
- **关联 FEAT**：FEAT-003
- **关键术语**：[[分屏]]、[[迷雾罩]]、[[对手棋盘位]]、[[自适应格子尺寸]]
- **归档线框**：_(待 wireframe 阶段产出)_

### CustomLevel

- **职责**：自定义模式。玩家自己画地图（矩形填/擦）、配雷数与九种道具数量，开局、导出/导入 JSON。数据与 JSON 进出在 `scripts/game/custom_level.gd`，编辑器界面在 `scripts/ui/custom_level_editor.gd`，开局/结果/返回编辑的流转在 `main.gd` 的「自定义模式」段。
- **对外接口**：
  - `CustomLevel.make_default()` / `validate(level)` / `is_valid(level)` / `max_mines(level)` / `active_count(level)` / `item_count(level, key)` — 数据与校验，纯函数
  - `CustomLevel.to_json(level)` / `from_json(text)` — JSON 进出；地图写成逐行 `[0/1]` 数组，导入也接受 `"##.#"` ASCII 行；`from_json` 返回 `{ok, level, error}`
  - `CustomLevel.file_name_for(level)` / `sanitize_name(name)` — 关卡名即文件名
  - `CustomLevelEditor.present()` / `dismiss()` / `is_open()` / `load_level(level)` / `current_level()` / `import_text(text)` / `export_text()` / `present_result(won, flagged, mines)`
  - `CustomLevelEditor` 信号 `play_requested(level)` / `back_requested` / `replay_requested` / `edit_requested` / `exit_requested` — GameFlow 靠订阅这五条做路由
  - `main.gd`：`_is_custom()`（`_custom_level` 非空）、`_prepare_custom_run()`、`_return_to_custom_editor()`；`_clear_board_presentation()` 从 `_return_to_world_map()` 抽出，回地图与回编辑器共用
  - **不写存档**：`_save_progress()` 在 `_is_custom()` 时直接返回，与对战同一道闸
- **关联模块**：GameFlow, BoardModel
- **关联 FEAT**：quick #1
- **关键术语**：[[自定义关卡]]、[[可玩格]]
- **归档线框**：_(界面由代码搭建，见 `custom_level_editor.gd` 的 `_build_*`)_

### Netplay

- **职责**：联机连接、消息收发与对战局状态机。代码位于 `scripts/net/`（`duel_config.gd` 数值 / `duel_protocol.gd` 消息 / `duel_client.gd` 传输 / `duel_session.gd` 状态机）与 `scripts/ui/duel_hud.gd`（对战 HUD）。
- **对外接口**（草稿，待 that-is-all 定稿）：
  - `DuelSession.host_duel(port)` / `join_duel(address, port)` / `leave()` — 建立与拆除对战局
  - `DuelSession.level_seed_for(round)` — 每轮棋盘种子，双方算出同一个值
  - `DuelSession.report_mine_marked()` / `report_state(hp, max_hp, gold)` / `report_upgrade(offer)` / `report_round_cleared()` / `report_defeat()` / `mark_ready()` — 出站事件
  - `DuelSession` 信号 `linked` / `link_lost` / `duel_started` / `round_started` / `opponent_changed` / `damage_taken` / `round_frozen` / `duel_finished` — GameFlow 靠订阅这些改画面
  - `DuelSession.poll(delta)` — 场景树外手动驱动（headless 测试与将来的无头服务端）
  - `DuelConfig.*` — 全部可调数值的唯一去处
- **关联模块**：BoardModel, GameFlow, ShopEconomy, Persistence
- **关联 FEAT**：FEAT-001
- **关键术语**：[[对战局]]、[[对战轮]]、[[对局种子]]、[[标雷伤害]]、[[中场休息]]
- **归档线框**：_(FEAT 工作线框见 `docs/features/wireframes/FEAT-001-DuelHudWireframe.html`；归档融合待 that-is-all)_

### WorldMap

- **职责**：3D 选关图、相机（拖拽+缩放）、关卡节点与悬浮牌交互、关卡表数据。代码位于 `scripts/game/stage_table.gd`（数据）、`scripts/ui/world_map.gd`（场景控制）、`scripts/ui/stage_badge.gd`（悬浮牌）与 `scenes/world_map.tscn`（手摆布局）。
- **画风（2026-09-10 改造）**：「体素陈列柜」——奶油色平底、正交相机斜 10° 俯 38°（岛顶满画框，房子约占画面高 8%）、平滑受光 + 软阴影（体素图走标准材质 `_apply_clean_materials()`，卡通着色器只留给水球场景）。地块用 16×16 最近邻像素贴图（草/石板/沙土三种纹样，`_pixel_texture()`）加顶点色接触阴影；`_dress_island()` 按 `STAGE_THEMES` 给每关一副布景：青草坡=草地果树与石头、麦垄=田土格加麦垄小方条、老井村=石板广场配酒馆铁匠铺教堂、双桥=两道水渠横穿广场架两座桥、深潭=伸进潭里的木栈桥与石头、尽头港=木板码头加岛缘挖出的港湾（`_apply_theme_terrain()` 改格子种类，道具经 `_theme_props` 落位）；外围再散几间小屋。`world_map.tscn` 里手摆的六边地格只当**数据**（关卡绑定、拾取、悬停仍走 `pad_` 节点），运行时 `_plan_voxel_island()` / `_build_voxel_floor()` 按方格铺一层立方体地块（顶面灰绿草 / 侧面沙土 / 关卡广场与关卡间石板 / 方格水面），岛是带缺口的矩形；`_declutter_grove()` 收掉草丛与尖刺植物，`_restyle_trees()` 把针叶树换成 Blender 生成的极简方块树。图集颜色由 `tools/build_clean_atlas.py` 重配（荧光草绿→灰绿、翠绿屋顶→陶土），树模型由 `tools/build_clean_trees.py`（Steam Blender 无头）生成到 `assets/nature_clean/`。UI 全部白卡 + 墨字 + 细边（`_card_style()` / `_make_button()`），顶栏不再铺深色横条。过目截图用 `tools/capture_world_map_direct.gd`（直接实例化场景，不经 main）。
- **陈列柜壳层（2026-09-11，FEAT-005，已接入）**：`scripts/ui/stage_cabinet.gd`（`StageCabinet`）接管选关，`main.gd` 的 `_world_map` 现在是它；对外信号与 `present()/dismiss()` 和老 `WorldMap` 一致。六件 `StageDiorama`（`standalone=false`，台面/灯/相机由柜子提供）沿画面横向排成一列（间距 `SLOT_STEP` 60，比一屏宽），一次只看一件；没有真展品的关卡用 `assets/dioramas/placeholder`（`tools/build_diorama_placeholder.py`）占位，未解锁的整件抽色（着色器 `desaturate`/`tint`）。‹ ›（或 ←/→）切换：相机滑 `SLIDE_DURATION`，切走的 `play_exit()` 收回，滑进来的先收成空、半路 `play_entrance()`；关卡卡常驻底部（进入关卡/续上这一关 + 放弃/再打一遍/未解锁），续局条是卡内一行琥珀提示；续局确认与老地图同一套。present 停在续局那关或第一个可挑战的关。拾取用 `PICK_LAYER` 射线打每件展品的 `Pick` 体。截图 `tools/capture_cabinet.gd`，测试 `tests/test_stage_cabinet.gd`。老地图 `world_map.gd/.tscn` 与 `tests/test_world_map.gd` 保留未删（水材质仍被复用）。
- **六关展品（2026-09-12）**：道具生成器在 `tools/diorama_props.py`（`Scene`/`Props`，颜色全部走配色表，`DEFAULT_PALETTE` 即青草坡），每关一个 `tools/build_diorama_<id>.py`（掩码、配色、桌布、道具坐标、地面绘制），产物 `assets/dioramas/<id>/`。布局 JSON 多了 `table`（桌布 far/near/dots）、`water`（shallow/deep）、`water_levels`（字符 → 水位）。柜子切换时台面与背景色渐变到当前展品的桌布配色。六关各有一种别处没有的主景（青草坡瓦顶小屋与果园、麦垄风车与红谷仓、老井村石梯田 + 古树井亭、双桥潭心六角亭与双拱桥、深潭瀑布吊脚屋、尽头港防波堤灯塔 + 船库），小屋只出现在青草坡；`Kit.finalize` 合并时必须带上 UV，否则手绘地面进不了引擎（`tools/dump_diorama_texture.gd` 核对）。展品会动：每件东西的运动种类与相位编在第二套 UV 里，由 `diorama_build.gdshader` 驱动（树摇、鸟点头、船晃、风车水车转、炊烟、飞鸟绕圈等），云由 `StageDiorama` 自己飘并投影。每关另有荒废版 `<id>_withered.glb/.json`（`DIORAMA_WITHERED=1` 同一脚本出图，`Props(withered=True)` 分支 + `wither_hex` 配色），没通关的关摆荒废版，刚通关回柜子时先弹排行榜，榜一关原地播复原仪式（一圈光 + 叶片花瓣与光点粒子 + 标题卡与三行关卡短句），再自动滑到下一关；柜子用 `_pending_restore_id` 等 `modal_overlay` 收掉再起播。
- **展品试点（2026-09-11）**：新方向是把六关做成六件独立的场景艺术品，先做了第一关「青草坡」。`tools/diorama_kit.py` 是 Blender 无头公共库（材质/倒角基元/ASCII 掩码台地生成/顶面绘制/按组合并导出），`tools/build_diorama_grass_1.py` 是这一关的布景（掩码、配色、道具坐标都在文件顶部，改完重跑即可），产物在 `assets/dioramas/grass_1/`（GLB + 布局 JSON）。Godot 端 `scripts/ui/stage_diorama.gd`（`StageDiorama`）只做展柜：台面与岛底软阴影、主光/补光/环境光、按掩码 W 格铺卡通溪水（复用 `WorldMap.apply_toon_water_material`）、`StageMarker`（meta stage_id）与正交 `ShowcaseCamera`；相机与布光参数都是 @export。截图 `tools/capture_diorama.gd`（环境变量 DIORAMA / DIORAMA_SHOT / DIORAMA_LIVE），测试 `tests/test_stage_diorama.gd`。布光注意：Compatibility 渲染器里主光 + 环境光叠加明显超过各自单独渲染之和，调参要量像素而不是算数。
  台面是 `shaders/diorama_table.gdshader`（屏幕空间波点桌布，点色/间距/强度都是 uniform）。入场动画：模型材质统一换成 `shaders/diorama_build.gdshader`，顶点色 rgb = 该件的基点（按 JSON `entrance.pivot_min/size` 归一化，Godot 坐标）、a = 起跳时刻占 `entrance.span` 的比例，由 `diorama_kit.py` 的 `Kit.piece()`/`finalize()` 写入，布景脚本里每个生成器开头调一次 `kit.piece(kind, x, y, z)`，起跳时刻由 `entrance_delay(kind, x, y)` 决定（按种类分档 + 后左→前右扫掠 + 抖动）。Godot 端 `play_entrance()` 只推进 `build_progress`（同步到全部材质的 `build`），另抬溪水、淡入岛影；地形组 mode 0 从台面弹起，其它组 mode 1 围基点果冻式弹出。
- **游荡动物 + 薅毛（2026-09-16）**：`scripts/ui/map_wander_animal.gd`（`MapWanderAnimal`，挂在 `CabinetUi/WanderAnimal`），只在第 2 关出（`StageCabinet.WANDER_STAGE`）。四只动物（狗熊/猴子/企鹅/狐狸）的贴图由 `tools/build_wander_animals.py` 从 `my_asset/source/wander/` 的用户原图抠出（四边按颜色距离泛洪去纯色背景）。**位置是岛的格子坐标**：`set_ground_source(展品, 相机)` → 从 `layout()` 掩码挑陆地格（只取岛前半截）、取该格地形高度 → 每帧 `unproject_position` 投影成屏幕坐标。不能用屏幕矩形当活动区：等距岛面在屏幕上是菱形，矩形里大半不在岛上（第一版就是这么飘在半空的）。相机正交，缩放按「一格多少像素」算。鼠标悬停 `HOVER_ARM` 秒即触发薅毛（不用点），四拍动画与毛絮、惨叫音效复用乌鸦解锁页的素材，薅够 `PLUCK_GOAL`（3）种发成就【薅遍四野】。截图 `tools/capture_wander_animal.gd`。
- **蚊子（2026-09-10）**：`scripts/ui/map_mosquito.gd`（`MapMosquito`，挂在 `WorldMapUi/Mosquito`，悬浮牌之上、顶栏之下，整层 `MOUSE_FILTER_IGNORE`）。在飞行区（顶栏下方、四边留边）里带高频抖动地乱飞、8 帧翅膀轮播、嗡嗡声按与指针的距离调音量；命中不用 mouse_entered，而是每帧把指针前后位置连成线段、看是否扫过身体中心 `HIT_RADIUS` 内且速度 ≥ `SWAT_SPEED`（一帧跳超 `SWAT_MAX_JUMP` 视为窗口外跳回，不算）；慢于 `FLEE_SLOW_SPEED` 且进入 `FLEE_RADIUS` 则 `FLEE_REACT` 秒后往反方向窜。拍死：压扁 → 翻滚下落淡出 → `swatted` 信号 → `RESPAWN_WAIT` 后再飞进来；拍满 `SWAT_LIMIT`（3）只时柜子发成就【三振出局】，蚊子随即彻底退场（`is_retired()`，退场闸在 `_tick` 的 HIDDEN 分支里，`start()` 也叫不回来）。蚊子只在第 1 关出（`StageCabinet.MOSQUITO_STAGE`），柜子用 `_sync_easter_eggs()` 按当前关开关，`mosquito_events` 是选关彩蛋共用的总开关。素材由 `tools/build_mosquito_assets.py` 从 `my_asset/source/mosquito_sheet.png` 抠白（边框泛洪，眼白保留）并合成嗡嗡/拍击两段 WAV。测试 `tests/test_map_mosquito.gd` 手动推帧、注入指针坐标。
- **对外接口**（草稿，待 that-is-all 定稿）：
  - `StageTable.stage(id)` / `region(id)` / `stages_in_region(region_id)` / `all_stages()` — 关卡表查询
  - `StageTable.boards_of(id)` / `board_at(id, round, seed)` / `target_round_of(id)` — 盘列表（形状+雷数）；`target_round` 由盘数派生（无尽关为 0）
  - `StageTable.ENDLESS_STAGE_ID` / `is_endless(id)` / `endless_board(round, seed)` / `endless_size_for(round)` / `endless_density_for(round)` / `endless_difficulty_fraction(round)` / `endless_shape_pool(size)` — 无尽关（quick #9）：没有盘列表，按 (盘序, 本盘种子) 现生成盘；难度曲线常量 `ENDLESS_*`
  - `StageTable.is_stage_unlocked(id, cleared)` / `is_region_unlocked(region_id, cleared)` / `region_progress(region_id, cleared)` — 解锁与进度判定，纯函数
  - `WorldMap.present(cleared, resume_stage_id, stage_round)` / `dismiss()` — 显示与收起；`StageCabinet.present()` 同签名，另接 `high_scores` 与 `best_rounds`（无尽关最远盘数）
  - `WorldMap` 信号 `stage_selected(stage_id)` / `title_requested` / `resume_requested` / `abandon_requested` — GameFlow 靠订阅这四条做路由
  - `StageBadge.bind(stage)` / `set_stage_state(state)` — 悬浮牌内容与四态
- **关联模块**：GameFlow, Persistence, ShopEconomy, BoardModel
- **关联 FEAT**：FEAT-002, FEAT-004
- **关键术语**：[[世界地图]]、[[地格]]、[[体素地块]]、[[石板路]]、[[关卡]]、[[目标盘数]]、[[悬浮牌]]、[[地形区]]、[[关卡表]]、[[盘列表]]
- **归档线框**：_(FEAT 工作线框见 `docs/features/wireframes/FEAT-002-WorldMapWireframe.html`；归档融合待 that-is-all)_

### BoardModel

- **职责**：扫雷棋盘的纯规则核（布雷、翻开、标记、道具散布、推理、可玩格掩码）。代码位于 `scripts/game/minesweeper_board.gd`；形状库 `scripts/game/board_shape.gd`。
- **对外接口**：_(既有代码，待后续 FEAT 收尾时定稿)_
- **关联模块**：—
- **关联 FEAT**：FEAT-001, FEAT-002, FEAT-004
- **关键术语**：[[开局格]]、[[盘面形状]]、[[可玩格]]
- **本 FEAT 新增接口**：`take_scored_mine_log()`（对战计分用的 append-only 去重队列，与连携那条 `take_marked_mine_log()` 互不干扰）、`opening_cell_for(seed, w, h)`（静态，由种子推出开局格）
- **FEAT-004 新增**：构造函数 `active_mask`；`is_active` / `active_cell_count`；`BoardShape.get_shape` / `has_shape` / `is_mask_connected` / `max_mines_for`

### GameFlow

- **职责**：关卡流转、回合结算与演出编排。代码位于 `scripts/main.gd`。
- **对外接口**：_(既有代码，待后续 FEAT 收尾时定稿)_
- **关联模块**：BoardModel, ShopEconomy, Persistence, WorldMap
- **关联 FEAT**：FEAT-001, FEAT-002
- **关键术语**：[[盘]]、[[强引导]]、[[伙伴图鉴]]、[[鸟类图鉴]]、[[奖励盘]]
- **quick #25 新增（奖励盘）**：`_should_open_bonus_board(item_queue)`（该不该开：雷已用尽 + 队列还有牌 + 非对战/自定义/教学 + 没到 `BONUS_BOARD_LIMIT`）、`_open_bonus_board(item_queue, queued_items)`（等在飞的结算落地 → 记账 → 建同尺寸无牌新盘 → `_replant_queued_cards()` 把剩下的牌原样种回并翻开 → 演出）、`_replant_queued_cards()` / `_bonus_card_slot()` / `_mask_of_board()` / `_bonus_board_seed()`、`_request_bonus_board()`（多张牌同时要换盘时的合流闸，配 `_bonus_board_opening` / `_bonus_board_waiters`；**判据在 `_resolve_queued_item()` 里牌生效之前，不能只看队列**——派发不等结果，牌会在盘面变「已赢」之前就离队）、`_play_bonus_board_intro()` / `_build_bonus_aura()` / `_close_bonus_board()`、`_round_is_won()`（**胜负判据从 `_board.won` 改走这里**：奖励盘上永远凑不齐「雷全标完」，这一盘开过奖励盘就按赢算）；`_is_invincible()` 在奖励盘期间恒真；`_correctly_flagged_mines()` 与 `_endless_board_mine_points()` 会把 `_banked_flagged_mines` / `_banked_scored_mines` 加进来。演出层 `BonusBoardAura.present(board_rect)` / `dismiss()` / `is_showing()` / `title_box()`。
- **quick #9 新增（无尽关）**：`_is_endless_stage()`（当前关是无尽关）、`_bank_endless_round()`（打赢一盘刷新 `_endless_best_round`）、`_present_endless_fall()`（倒下时以「止步第 N 盘」标题弹结算榜，复用 `_present_clear_leaderboard(stage_id, score, title)`）、`_best_rounds_for_map()`；`_stage_complete()` 对无尽关恒为假；`_start_game` 把 `_level_seed_for_current_round()` 当 `board_at` 的种子。
- **本 FEAT 新增接口**：`_enter_stage(stage_id, resume)` / `_is_stage_run()` / `_stage_complete()` / `_show_world_map()` / `_return_to_world_map()` / `_on_stage_cleared()`；抽出 `_reset_run_state()`（回标题页与进新关共用的 run 级复位）；`_set_scenery_visible()`（地图开着时收走 2D 布景）
- **quick #4 新增（新手强引导）**：数据与纯判断在 `scripts/game/guided_tutorial.gd`（`GuidedTutorial.WIDTH/HEIGHT/MINES`、`STEPS`、`allows_click(step, cell, button)`、`is_step_done(step, board)`、`step_bbcode(step)`、`layout_matches(board)`），演出层 `scripts/ui/guided_tutorial_overlay.gd`（`GuidedTutorialOverlay.present_step(config)` / `dismiss()` / `play_nudge()` / 信号 `next_pressed`、`blocked_click`），main.gd 编排：`_is_guided_tutorial_round()`（`_run_number == 1` 且非对战非自定义）、`_begin_guided_tutorial(boot)`、`_present_guided_step()`、`_sync_guided_tutorial()`（棋盘回到可点状态时调用）、`_end_guided_tutorial()`；点击放行只有一处闸门 `_on_cell_mouse_button_changed`。BoardModel 配套 `place_fixed_mines(indices)`（写死雷位、清空道具、跳过随机布雷）。
- **quick #21 新增（鸟类图鉴）**：总表 `scripts/game/bird_catalog.gd`（`BirdCatalog.ENTRIES` / `entry(id)` / `ids()` / `count()`；每条是 id、名字、外号、能力、解锁条件、待机帧、`faces_right`），页面 `scripts/ui/bird_codex_screen.gd`（`BirdCodexScreen.present()` / `dismiss()` / `set_unlocked(id, value)` / `is_unlocked(id)` / `unlocked_count()` / `entry_parts(id)` / 信号 `back_requested`；整页由代码搭建，两行铺满、列数按鸟数算）。main.gd：`_bird_unlock_states()`（id → 那一排 `*_unlocked` 的唯一映射）、`_refresh_bird_codex()`（挂在 `_apply_bird_unlock_visibility()` 最前面，所以送鸟 / 读盘 / 跳过教学都会带上它）、`_on_bird_codex_requested()` / `_on_bird_codex_back_requested()`。`StartScreen` 加信号 `bird_codex_requested` 与 `set_bird_codex_progress(unlocked, total)`。
- **quick #5 新增（第 2 盘伙伴牌课）**：`scripts/game/guided_item_lesson.gd`（`GuidedItemLesson.STEPS` 三步、`ITEM_ENTRIES` 图鉴条目、`format_bbcode(entry)`、`ANY_CELL` 放行任意格；步骤字段与 GuidedTutorial 同构，另有 `pointer_cell` / `next_text` / `resume_on_board` / `opens_guide`），`scripts/ui/item_guide_screen.gd`（`ItemGuideScreen.present()` / `dismiss()` / `is_open()` / `cards()` / 信号 `closed`）。main.gd：`_guided_lesson: GDScript` 记当前课，`_guided_lesson_for_round()`（1→GuidedTutorial，2→GuidedItemLesson），`_guided_item_intro(item_queue)`（`_resolve_turn` 里翻牌动画后、结算前停下来讲夜鹭牌；`_guided_item_intro_pending()` 为真时 `_present_revealed` 不预飞夜鹭），`_on_item_guide_closed()`。`GuidedTutorial.Focus` 加 `BOARD_ALL` / `ITEM`；`GuidedTutorialOverlay.present_step` 加 `next_text`。

### ShopEconomy

- **职责**：金币收支与关卡间商店的道具/强化购买。代码位于 `scripts/ui/shop_overlay.gd` 与 `scripts/main.gd` 的金币逻辑。
- **对外接口**：_(既有代码，待后续 FEAT 收尾时定稿)_
- **关联模块**：GameFlow
- **关联 FEAT**：FEAT-001
- **关键术语**：[[大全商店]]、[[鸟窝]]
- **quick #24 新增（无尽关的鸟窝）**：`main.gd` 的 `SLOT_OFFER_BONUS`（占格子的商品 → 它加的数值位，**鸟窝是这七个数的唯一真相**）、`ENDLESS_SLOT_START` / `ENDLESS_SLOT_PER_EXPANSION` / `ENDLESS_SLOT_EXPANSION_COSTS`、`_is_slot_shop()` / `_slot_capacity()` / `_free_slot_index()` / `_place_in_free_slot()` / `_seed_endless_slots()` / `_sync_bonuses_from_slots()` / `_sync_shop_slots()`、替换三步 `_choose_shop_offer()` 挂起 → `_on_shop_slot_replace_chosen()` 结账 / `_on_shop_slot_replace_cancelled()` 作废、`_on_shop_expand_slots()`；`ShopOverlay.set_nest_shop(on)` / `set_slots(slots, expand_cost, expansions_left, per_expansion)` / `begin_slot_replacement(offer)`（压暗背景 + 屏幕正中的换鸟弹窗）/ `end_slot_replacement()` / `is_replacing()` / `slot_chips()`（替换时返回弹窗里那排；**一张牌是一种鸟、不是一格**）/ `nest_tally()`（按鸟归类的 {offer, count, slot}）/ `replace_modal()` 与信号 `slot_replace_chosen(slot_index)` / `slot_replace_cancelled` / `expand_slots_requested`；`OFFER_SHORT_NAMES` 与 `SLOT_OFFER_BONUS` 必须同进同出（`tests/test_endless_slot_shop.gd` 盯着）。
- **本 FEAT 新增接口**：`ShopOverlay.present_full(gold, price)`（大全商店，13 项全列不刷新）、`set_duel_round_result/countdown/opponent/opponent_ready/self_ready()`（中场休息条）、`exit_duel_mode()`（还原成单机形态）、信号 `ready_pressed`

### Persistence

- **职责**：单槽存档的读写与 run 进度恢复。代码位于 `scripts/game/game_save.gd`。
- **对外接口**：_(既有代码，待后续 FEAT 收尾时定稿)_
- **关联模块**：GameFlow
- **关联 FEAT**：FEAT-001, FEAT-002
- **关键术语**：—
- **quick #24**：`GameSave.VERSION = 5`，新增 `endless_slots` / `endless_slot_expansions`（无尽关的鸟窝）；v4 → v5 迁移补一个空窝——鸟窝是 v5 才有的概念，没法从老档的数值位倒推玩家当初摆了什么。
- **quick #9**：`GameSave.VERSION = 4`，新增 `endless_best_round`（无尽关最远盘数），v3 → v4 迁移补 0；放弃本轮的那份存档也保留它。
- **本 FEAT 新增接口**：`GameSave.VERSION = 2`（新增 `cleared_stages` / `resume_stage_id` / `stage_round` / `music_break_played` 四个字段）、`load_data()` 现在接受 `version < VERSION` 并走 `_migrate()` 前向迁移，`version > VERSION` 仍然拒绝

> 每个模块一节，字段：职责 / 对外接口（由 that-is-all 定稿，是别的模块能依赖的稳定契约）/ 关联模块 / 关联 FEAT / 关键术语 / **归档线框**（该模块有独立 UI 时，指向 `docs/modules/<Module>/<Page>Wireframe.html`——界面结构的权威单一来源，由 wireframe→that-is-all 融合、quick 同步、wireframe-check 校验）。

---

## 术语库 (Glossary)

> 每个关键概念必须有一条**中英对照**术语，避免同物异名 / 一名多义。
> 术语在 start **初定**、discuss **确认**、spec **锁定**、that-is-all **归档**。锁定后不得随意改名（改名开新 FEAT 或走 quick 并同步全库）。

**术语状态**：🌱 初定 · 🌿 确认 · 🔒 锁定 · ✅ 归档

| 中文 | English | 定义(一句话) | 所属模块 | 来源 FEAT | 状态 |
|---|---|---|---|---|---|
| 对战局 | Duel | 一次 1v1 对局，由多个对战轮组成，持续到一方血量归零 | Netplay | FEAT-001 | 🔒 锁定 |
| 对战轮 | Duel Round | 对战局内的一盘棋，从开盘到任一方清完棋盘为止 | Netplay | FEAT-001 | 🔒 锁定 |
| 对局种子 | Duel Seed | 由房主下发、派生出每轮棋盘布局与开局格的共享随机种子 | Netplay | FEAT-001 | 🔒 锁定 |
| 开局格 | Opening Cell | 由对局种子算出、棋盘生成时即已翻开的起始格，同时充当 `_place_mines` 的 `first_index` | BoardModel | FEAT-001 | 🔒 锁定 |
| 标雷伤害 | Mark Damage | 玩家每标出一个雷对**对手**造成的伤害，按雷逐个结算 | Netplay | FEAT-001 | 🔒 锁定 |
| 大全商店 | Full Shop | 对战专用商店，一次陈列全部 13 项强化、不刷新、每项限购 1 次 | ShopEconomy | FEAT-001 | 🔒 锁定 |
| 中场休息 | Intermission | 一方率先清完棋盘后双方共同进入的商店与备战阶段 | Netplay | FEAT-001 | 🔒 锁定 |
| 分屏 | Split Screen | 对战时把视口对半分，左屏自己的棋盘、右屏对手的 | SplitScreen | FEAT-003 | 🔒 锁定 |
| 迷雾罩 | Fog Veil | 盖住整个对手棋盘的不透明雾层，全程不散，只在对手标雷时闪一下 | SplitScreen | FEAT-003 | 🔒 锁定 |
| 对手棋盘位 | Opponent Board Slot | 右屏那块与自己棋盘等尺寸的占位区，底下是格子轮廓、上面是迷雾罩 | SplitScreen | FEAT-003 | 🔒 锁定 |
| 自适应格子尺寸 | Adaptive Cell Size | 按可用宽高算出的格子边长，取代写死的 CELL_SIZE = 88 | SplitScreen | FEAT-003 | 🔒 锁定 |
| 世界地图 | World Map | 承载全部关卡的六边形 3D 网格场景，是选关的唯一界面 | WorldMap | FEAT-002 | 🔒 锁定 |
| 地格 | Hex Tile | 世界地图的最小单元，对应一块 KayKit 六边形地块模型 | WorldMap | FEAT-002 | 🔒 锁定 |
| 关卡 | Stage | 世界地图上的一个可点节点，进入后是一整局从头开始的肉鸽 | WorldMap | FEAT-002 | 🔒 锁定 |
| 奖励盘 | Bonus Board | 一盘的雷被提前清空、结算队列却还压着牌时自动展开的同尺寸空盘：只有雷、不发新牌，专供剩下的伙伴牌继续结算；玩家不操作它，盘上免伤，标出的雷照常算钱算分，结算完照常进下一盘 | GameFlow | quick #25 | 🌱 初定 |
| 盘 | Board Round | 一个关卡内的第 N 张棋盘，对应现有 `_run_number`；现有 UI 文案里的"局"统一改称此名 | GameFlow | FEAT-002 | 🔒 锁定 |
| 目标盘数 | Target Round | 该关盘列表长度；打完全部盘即通关（由 `boards.size()` 派生） | WorldMap | FEAT-002 | 🔒 锁定 |
| 悬浮牌 | Stage Badge | 关卡上方悬浮的 UI 卡片，显示序号/名字、目标盘数、状态图标 | WorldMap | FEAT-002 | 🔒 锁定 |
| 地形区 | Region | 一组共享地形主题、成组解锁的关卡 | WorldMap | FEAT-002 | 🔒 锁定 |
| 关卡表 | Stage Table | 与场景摆放分离的关卡数据：id / 名字 / 盘列表(形状+雷数) / 主题 / 所属区 / 解锁关系 | WorldMap | FEAT-002 | 🔒 锁定 |
| 盘列表 | Board List | 关卡内按顺序配置的每一盘：`shape` + `mines` | WorldMap | FEAT-004 | 🔒 锁定 |
| 无尽关 | Endless Stage | 第 7 关「无尽远海」：没有盘列表与目标盘数，每盘按 (盘序, 种子) 从全部形状族随机生成、尺寸与雷密度随盘序爬升，只有血量归零才收场；成绩是最远盘数与累计分 | WorldMap / GameFlow | quick #9 | 🌱 初定 |
| 盘面形状 | Board Shape | 包围盒 + 可玩格掩码；引擎只认掩码 | BoardModel | FEAT-004 | 🔒 锁定 |
| 可玩格 | Active Cell | 掩码为 1、可交互并计入胜负与布雷的格子 | BoardModel | FEAT-004 | 🔒 锁定 |
| 自定义关卡 | Custom Level | 玩家在编辑器里画出的地图掩码 + 雷数 + 道具数量，可导出为逐行 0/1 数组的 JSON | CustomLevel | quick #1 | 🌿 确认 |
| 强引导 | Guided Tutorial | 新手前两盘的固定教学：遮罩挖洞 + 小手指 + 引导文本逐步只放行一种点击。第 1 盘棋盘与雷位写死、六步走完通关；第 2 盘三步认识伙伴牌（找牌 → 看它表演 → 伙伴图鉴） | GameFlow | quick #4, #5 | 🌿 确认 |
| 伙伴图鉴 | Item Guide | 第 2 盘课末弹出的整页说明：全部伙伴牌按上图下文摆成小卡（图标 / 名字 / 作用，关键词强调色），「开始排雷」关掉 | GameFlow | quick #5 | 🌿 确认 |
| 鸟类图鉴 | Bird Codex | 标题页翻开的队伍名册：每只鸟一张卡（待机帧头像 / 名字 / 外号 / 一句能力），没解锁的只露黑剪影、名字打码、能力换成解锁条件。和[[伙伴图鉴]]不是一回事——那个讲的是**牌**的作用、教学里弹一次；这个讲的是**鸟**，常驻标题页 | GameFlow | quick #21 | 🌿 确认 || 上限商品 | Capped Offer | 买满就整轮 run 下架的商品：红隼 3 只、长尾山雀 2 张（含每关自带那张），不再被抽中、货架上只留「已满」 | ShopEconomy | quick #23 | 🌿 确认 |
| 鸟窝 | Bird Nest | 无尽关专用的槽位制商店：一格住一只伙伴、每盘按窝里的鸟埋牌；起手 6 格（`ENDLESS_STARTER_BIRDS` 那两只已入住），满了再买要弹窗选一只换掉，花钱可扩建三次、每次 +3 格、最多 15 格；商店面板按鸟归类显示【总数 X / Y ｜ 鸟A×a 鸟B×b……】 | ShopEconomy | quick #24 | 🌱 初定 |
| 重复购买涨价 | Repeat-Purchase Markup | 同一件商品第 n 次的价格 = 基础价 5G × 1.2ⁿ 向上取整，次数逐件记、跟着存档走，刷新价不涨 | ShopEconomy | quick #23 | 🌿 确认 |
| 通关奖励 | Level Clear Bonus | 打完一盘固定进账的 3G，在账单上与标雷、吃鱼、连击各占一行 | ShopEconomy | quick #23 | 🌿 确认 |
| 心叠放 | Heart Stack | 血量上限超过 4 颗后，心并成最多 4 摞、每摞最多 3 颗的摆法（6 → 2+2+1+1），排不下整排等比缩小 | GameFlow | quick #23 | 🌿 确认 |


---

## 约定

- 模块 / 术语的**每一次增删改**都由某个 FEAT（或 quick）驱动，并在本文档留痕（关联 FEAT 列 / 状态列）。
- 术语的"所属模块"应是模块库里存在的模块名；未归属写 `—`。
- 用 `[[术语中文]]` 在模块详情里交叉引用术语。
- 废弃模块 / 淘汰术语**不删行**，改状态为 🗑️，便于回溯"这个名字曾经指什么"。
- **模块归档线框**是该界面当前真实结构的权威单一来源，放 `docs/modules/<Module>/<Page>Wireframe.html`；FEAT 工作线框只是通往它的一次改动记录。任何动了 UI 结构的 FEAT/quick 都必须让归档线框跟上。
