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
| Netplay | 联机连接、消息收发与对战局状态机 | BoardModel, GameFlow, ShopEconomy, Persistence | FEAT-001, FEAT-003 | 🟢 活跃 |
| WorldMap | 六边形 3D 世界地图的手工布局场景、相机、关卡节点与悬浮牌交互、关卡表数据 | GameFlow, Persistence, ShopEconomy, BoardModel | FEAT-002 | 🟢 活跃 |
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

- **职责**：六边形 3D 世界地图的手工布局场景、相机（拖拽+缩放）、关卡节点与悬浮牌交互、关卡表数据。代码位于 `scripts/game/stage_table.gd`（数据）、`scripts/ui/world_map.gd`（场景控制）、`scripts/ui/stage_badge.gd`（悬浮牌）与 `scenes/world_map.tscn`（手摆布局）。
- **对外接口**（草稿，待 that-is-all 定稿）：
  - `StageTable.stage(id)` / `region(id)` / `stages_in_region(region_id)` / `all_stages()` — 关卡表查询
  - `StageTable.boards_of(id)` / `board_at(id, round)` / `target_round_of(id)` — 盘列表（形状+雷数）；`target_round` 由盘数派生
  - `StageTable.is_stage_unlocked(id, cleared)` / `is_region_unlocked(region_id, cleared)` / `region_progress(region_id, cleared)` — 解锁与进度判定，纯函数
  - `WorldMap.present(cleared, resume_stage_id, stage_round)` / `dismiss()` — 显示与收起
  - `WorldMap` 信号 `stage_selected(stage_id)` / `title_requested` / `resume_requested` / `abandon_requested` — GameFlow 靠订阅这四条做路由
  - `StageBadge.bind(stage)` / `set_stage_state(state)` — 悬浮牌内容与四态
- **关联模块**：GameFlow, Persistence, ShopEconomy, BoardModel
- **关联 FEAT**：FEAT-002, FEAT-004
- **关键术语**：[[世界地图]]、[[地格]]、[[关卡]]、[[目标盘数]]、[[悬浮牌]]、[[地形区]]、[[关卡表]]、[[盘列表]]
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
- **关键术语**：[[盘]]
- **本 FEAT 新增接口**：`_enter_stage(stage_id, resume)` / `_is_stage_run()` / `_stage_complete()` / `_show_world_map()` / `_return_to_world_map()` / `_on_stage_cleared()`；抽出 `_reset_run_state()`（回标题页与进新关共用的 run 级复位）；`_set_scenery_visible()`（地图开着时收走 2D 布景）

### ShopEconomy

- **职责**：金币收支与关卡间商店的道具/强化购买。代码位于 `scripts/ui/shop_overlay.gd` 与 `scripts/main.gd` 的金币逻辑。
- **对外接口**：_(既有代码，待后续 FEAT 收尾时定稿)_
- **关联模块**：GameFlow
- **关联 FEAT**：FEAT-001
- **关键术语**：[[大全商店]]
- **本 FEAT 新增接口**：`ShopOverlay.present_full(gold, price)`（大全商店，13 项全列不刷新）、`set_duel_round_result/countdown/opponent/opponent_ready/self_ready()`（中场休息条）、`exit_duel_mode()`（还原成单机形态）、信号 `ready_pressed`

### Persistence

- **职责**：单槽存档的读写与 run 进度恢复。代码位于 `scripts/game/game_save.gd`。
- **对外接口**：_(既有代码，待后续 FEAT 收尾时定稿)_
- **关联模块**：GameFlow
- **关联 FEAT**：FEAT-001, FEAT-002
- **关键术语**：—
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
| 盘 | Board Round | 一个关卡内的第 N 张棋盘，对应现有 `_run_number`；现有 UI 文案里的"局"统一改称此名 | GameFlow | FEAT-002 | 🔒 锁定 |
| 目标盘数 | Target Round | 该关盘列表长度；打完全部盘即通关（由 `boards.size()` 派生） | WorldMap | FEAT-002 | 🔒 锁定 |
| 悬浮牌 | Stage Badge | 关卡上方悬浮的 UI 卡片，显示序号/名字、目标盘数、状态图标 | WorldMap | FEAT-002 | 🔒 锁定 |
| 地形区 | Region | 一组共享地形主题、成组解锁的关卡 | WorldMap | FEAT-002 | 🔒 锁定 |
| 关卡表 | Stage Table | 与场景摆放分离的关卡数据：id / 名字 / 盘列表(形状+雷数) / 主题 / 所属区 / 解锁关系 | WorldMap | FEAT-002 | 🔒 锁定 |
| 盘列表 | Board List | 关卡内按顺序配置的每一盘：`shape` + `mines` | WorldMap | FEAT-004 | 🔒 锁定 |
| 盘面形状 | Board Shape | 包围盒 + 可玩格掩码；引擎只认掩码 | BoardModel | FEAT-004 | 🔒 锁定 |
| 可玩格 | Active Cell | 掩码为 1、可交互并计入胜负与布雷的格子 | BoardModel | FEAT-004 | 🔒 锁定 |

---

## 约定

- 模块 / 术语的**每一次增删改**都由某个 FEAT（或 quick）驱动，并在本文档留痕（关联 FEAT 列 / 状态列）。
- 术语的"所属模块"应是模块库里存在的模块名；未归属写 `—`。
- 用 `[[术语中文]]` 在模块详情里交叉引用术语。
- 废弃模块 / 淘汰术语**不删行**，改状态为 🗑️，便于回溯"这个名字曾经指什么"。
- **模块归档线框**是该界面当前真实结构的权威单一来源，放 `docs/modules/<Module>/<Page>Wireframe.html`；FEAT 工作线框只是通往它的一次改动记录。任何动了 UI 结构的 FEAT/quick 都必须让归档线框跟上。
