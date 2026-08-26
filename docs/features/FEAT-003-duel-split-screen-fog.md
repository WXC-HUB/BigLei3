# FEAT-003: duel-split-screen-fog

| 字段 | 值 |
|---|---|
| ID | FEAT-003 |
| 状态 | 🟣 待收尾 |
| 起 | 2026-08-25 |
| 止 | - |
| 一句话目的 | 对战界面对半分屏，右屏放对手棋盘并全程盖上迷雾罩 |
| 需独立 UI 设计 | 是 |
| 归属模块 | SplitScreen |
| 关联模块 | GameFlow, Netplay |
| 新建模块 | SplitScreen |

## 术语 (Terminology)

> 中英对照。start 初定 → discuss 确认 → spec 锁定 → that-is-all 归档。同步 [导航文档](../NAVIGATION.md) 术语库。

| 中文 | English | 定义 | 所属模块 | 状态 |
|---|---|---|---|---|
| 分屏 | Split Screen | 对战时把 1920×1080 视口对半分，左屏自己的棋盘、右屏对手的 | SplitScreen | 🔒 锁定 |
| 迷雾罩 | Fog Veil | 盖住整个对手棋盘的**不透明**雾层，全程不散，只在对手标雷时闪一下 | SplitScreen | 🔒 锁定 |
| 对手棋盘位 | Opponent Board Slot | 右屏那块与自己棋盘等尺寸的占位区，底下是格子轮廓、上面是迷雾罩 | SplitScreen | 🔒 锁定 |
| 自适应格子尺寸 | Adaptive Cell Size | 按可用宽高算出的格子边长，取代写死的 `CELL_SIZE = 88` | SplitScreen | 🔒 锁定 |

## Discuss

> 由 `/wxc-mini:discuss FEAT-003` 填充。设计共识与决策清单 (3-7 条)。

### 前置：代码勘查

- **分屏放得下**。10×10 是最大盘，`CELL_SIZE = 88` 时宽 943px；对半分后每屏 960px、留 40px 边距剩 880px 可用 → 格子边长降到 **81.7**，只小 7%。6×6 反而有富余（可到 140）。
- **格子尺寸本来就是参数**。`MineCell.configure(index, cell_size)`（mine_cell.gd:266）收尺寸参数，`_cell_center()` 直接读节点的 `global_position + size`——**VFX 定位天生跟着实际尺寸走**，不需要跟着改。
- **要改的 `CELL_SIZE` 用点只有 5 处**：建格子（main.gd:1427-1430）与 `_resize_board_layout()`（1460-1461）。另外 5 处是特效半径，差 7% 看不出来，不动。
- **棋盘整体是中心锚点 + 对称 offset**（`_set_centered_board_panel_rect`，main.gd:1469）。挪到左半屏 = 给所有 offset 写入点加一个水平位移，改动集中。
- **每张 MineCard 运行时建 19 层子节点**，10×10 约 2000 节点。这是「对手棋盘要不要也用 MineCell」的成本前提。

### 逐条问答

**Q1: 战争迷雾遮什么？**
A: **棋盘全遮**。对手棋盘全程盖不透明迷雾罩，零空间信息。
理由 / 备注: ⚠️ 推翻了我给的三个选项（我预设的都是「只遮未翻开的格子」这类部分遮蔽）。关键推论：**棋盘状态因此完全不需要同步**——协议一个字节都不用加，FEAT-001 的消息集原样够用。信息公开度也没被破坏：FEAT-001 共识 #5 说的「血量 / 标雷进度 / 已购强化」全是 HUD 级聚合量，本来就不含棋盘的空间信息。于是「聚合信息公开、空间信息全藏」是自洽的。

**Q2: 分屏比例怎么定？**
A: 对半 50/50。
理由 / 备注: 两边等尺寸。最大盘 10×10 时格子从 88 降到 81.7；6×6 有富余。代价是自己的牌略小、HUD 得挪到上下。

**Q3: 对手棋盘用什么渲染？**
A: ~~复用 MineCell，禁交互并关掉 VFX~~ → **作废**。
理由 / 备注: 这题是在「部分遮蔽」的前提下问的。Q1 定了全遮之后没有任何格子状态要显示，摆 100 张 MineCard 在不透明雾底下纯属浪费（约 2000 个节点换零像素）。改为：一层格子轮廓的平铺底 + 一层迷雾罩，两个轻量 Control。

**Q4: FEAT-003 归属哪个模块？**
A: 新建 SplitScreen。
理由 / 备注: 它不管连接（那是 Netplay）也不管回合（那是 GameFlow），是一块独立的展示层职责；将来做观战/回放也能复用同一套分屏。

### 补充陈述的假设（未单独提问，如有异议在 spec 阶段推翻）

- **迷雾罩底下画格子轮廓**：右屏若是一整块死板的雾会很空。画出与真实棋盘同行列数的格子轮廓，右屏才读得出「那边是一副和我一样大的盘」。棋盘尺寸本来就是公开信息（同种子同曲线），不算泄漏。
- **对手标雷时迷雾闪一下**：`MINE_MARKED` 消息 FEAT-001 已经在收，拿来驱动一次雾面高光是零协议成本的紧张感来源。不暴露位置——闪的是整片雾，不是某一格。
- **单机布局一个像素都不动**：分屏只在对战局里生效，`_is_duel()` 为假时走原来的居中全屏路径。
- **FEAT-001 的 OpponentPanel 移到右屏**：它现在锚在右上角，分屏后归属右屏的顶部，与迷雾罩同属对手侧。

### ▶ 共识 (锁定后进 /wxc-mini:spec)

1. **分屏结构**：对战局中视口对半分，左屏 = 自己的棋盘 + 自己的 HUD，右屏 = [[对手棋盘位]] + FEAT-001 的对手面板。单机路径完全不受影响。
2. **迷雾罩全程不透明**：[[迷雾罩]]盖住整个对手棋盘，零格子状态可见；底下只画与真实棋盘同行列数的格子轮廓；对手标雷时整片雾闪一次高光（不指示位置）。
3. **棋盘状态不过线**：Q1 的直接推论——本 FEAT **不新增任何网络消息**，FEAT-001 的协议原样够用。
4. **格子尺寸自适应**：用 [[自适应格子尺寸]] 取代写死的 `CELL_SIZE = 88`，按半屏可用宽高算；10×10 时约 81.7。`MineCell.configure()` 与 `_cell_center()` 已经是尺寸无关的，不必跟改。
5. **模块归属**：本 feature 归属**新建的 SplitScreen 模块**（分屏布局 + 对手棋盘位 + 迷雾罩）；关联 GameFlow（棋盘布局与格子建造在 `main.gd`）、Netplay（对手面板归位、标雷事件驱动雾闪）。
6. **边界**：不做对手棋盘的任何状态同步、不做迷雾的渐散/局部透视、不做观战与回放。

### ▶ 实施期补充 (2026-08-25)

1. **格子边长只缩不放，上限锁死 `CELL_SIZE`**。触发：`_apply_split_layout()` 按可用空间算，6×6 能涨到 140。决策：`minf(CELL_SIZE, ...)` 封顶——整套牌面美术是按 88 调的，放大只会露馅。**意外收获**：6×6 到 9×9 因此完全不缩，只有 10×10 掉到 79.3，比 Spec 预期的「全都缩 7%」好得多。
2. **自身 HUD 整体缩放 0.72**。触发：10 颗心占 540px，读数行 484px，两者在 960px 的左半屏里必然重叠。决策：缩放 `_player_status` 节点，而不是改 `player_status.gd`（后者不在本 FEAT 的允许修改范围内）。**顺带关掉了 FEAT-001 遗留的「血量 10 会撑爆 HUD」风险项**。
3. **读数行在分屏下改为右对齐**。触发：同上。原本 `_position_board_counters()` 把读数居中在棋盘正上方，分屏后会压在自身 HUD 上。决策：分屏分支里改为贴左半屏右缘。
4. **对手面板从单行改双行，高度 76 → 120**。触发：线框按单行画的，实际 13 个 44px 图标占 572px，加上第一行的身份/连接/血条/进度/金币超出 848px 可用宽。决策：拆成「状态行 + 强化墙行」；顶部 HUD 带高度随之从 140 调到 160。已同步回工作线框。
5. **飘字目标改用 `get_global_rect().get_center()`**。触发：`_player_status` 被缩放后，`_health_bar.size` 仍是未缩放的局部尺寸，原来的 `global_position + size * 0.5` 会算偏。

## Wireframe

> 仅"需独立 UI 设计 = 是"时，由 `/wxc-mini:wireframe FEAT-003` 填充（线框产物路径 + 结构结论）。否则本段写 "本 feature 无需独立 UI 设计"。

### DuelSplitScreen 线框

- **产物 (FEAT 工作线框)**: [FEAT-003-DuelSplitScreenWireframe.html](wireframes/FEAT-003-DuelSplitScreenWireframe.html)
- **基线**: [FEAT-001-DuelHudWireframe.html](wireframes/FEAT-001-DuelHudWireframe.html) —— ⚠️ 这是 FEAT-001 的**工作**线框，不是模块归档线框。`docs/modules/` 至今是空的（FEAT-001 与 FEAT-003 都没跑过 that-is-all）。拿它当基线是因为分屏本质就是把那一版重排，标 diff 比从零画信息量大得多。
- **归属模块**: SplitScreen
- **本次改动 (vs 基线)**: 🆕 新增 7 / ✏️ 改动 6 / ↔️ 移位 4 / 🗑️ 删除 0
  - 🆕 `SplitDivider` `SelfHalf` `OpponentHalf` `OpponentBoardSlot` `FogGridBackdrop` `FogVeil` `FogHintLabel`
  - ✏️ `DuelSplitScreen`（从 HUD 叠层升级为布局根）、`BoardPanel`（offset 加水平位移 + 缩放）、`MineCardGrid`（格子边长自适应）、`OpponentPanel`（560×404 竖卡 → 880×76 横条）、`OpponentUpgradeGrid`（6 列方阵 → 单行、图标 76→44px）、`DamageFeedLayer`（飘字起点改为右屏棋盘位中心）
  - ↔️ `RoundLabel`（棋盘正上方 → 视口顶端中缝）、`PlayerStatus` / `MineCounter` / `ItemCounter`（随左屏棋盘左移）
- **节点/受控字段**: 共 18 节点，受控 12 个（Label 4 / PanelContainer 4 / Control 3 / ColorRect 1）
- **行为标签分布**: 赋值 9 / 点击 0 / 悬停 0 / 状态 2 / 拷贝 1
- **用到的术语**: 分屏、迷雾罩、对手棋盘位、自适应格子尺寸、对战轮、标雷伤害
- **接口对齐结论**:
  - 复用现有：`MineCell.configure(index, cell_size)`（已收尺寸参数）、`_cell_center()`（读节点实际几何，天生尺寸无关）、`DuelHud.refresh_opponent()` / `set_round()` / `set_frozen()` / `play_incoming_damage()`、`PlayerStatus.set_health()` / `set_gold()`、`_position_board_counters()` / `_position_tutorial_guide()`
  - ⚠️ 需新增：`DuelHud.set_opponent_board(columns, rows, cell_size, panel_size)`、`DuelHud.flash_opponent_board()`、`OpponentBoardSlot`（新类）、main.gd 的 `_cell_size` / `_board_center_x` 两个状态与 `_apply_split_layout()`
  - **零新增网络接口** —— Q1 的直接推论
- **待决策的开放问题**: 无
- **归档处置建议 (供 that-is-all)**: 新建 `docs/modules/SplitScreen/DuelSplitScreenWireframe.html`；它同时**取代** FEAT-001 DuelHud 线框的布局部分，两者收尾时应合并成一张，别留两份互相矛盾的归档

## Spec

> 由 `/wxc-mini:spec FEAT-003` 填充。验收标准、影响文件、数据 schema、边界 & 不做、风险。

### 验收标准

> 全部勾完才视为本 feature 完成。

- [ ] 对战开局后画面对半分：左屏是我的棋盘，右屏是一块与它**等尺寸**的对手棋盘位，中间有分隔线。
- [ ] 对手棋盘位全程被不透明迷雾罩盖住，看不到任何格子的翻开/插旗状态。
- [ ] 迷雾罩底下能看到与真实棋盘**同行列数**的格子轮廓（10×10 的轮就是 10×10 格）。
- [ ] 最大盘（10×10）时左屏棋盘完整落在左半屏内、不越过中线，格子边长约 81.7（原 88）。
- [ ] 剩余雷/剩余道具计数与自身 HUD 都在左半屏内，不越过中线。
- [ ] 对手面板（血量/标雷进度/金币/已购强化）在右半屏顶部，横排一行。
- [ ] 对手标出一个雷时，迷雾罩整片闪一次高光；闪光不指示任何格子位置。
- [ ] 受击飘字从右屏棋盘位中心飞向左屏血条。
- [ ] **本 FEAT 不新增任何网络消息**：`DuelProtocol.Kind` 的成员数与 FEAT-001 完全一致。
- [ ] 单机模式布局零变化：棋盘仍居中全屏、格子边长仍是 88、无分屏无迷雾。
- [ ] `godot --headless` 跑测试全绿，含新增的 `test_duel_split_layout.gd`（分屏几何 + 单机不受影响 + 协议未膨胀）；FEAT-001 的四个对战测试无回归。

### 涉及的代码改动 (预估)

| 文件 | 改动 | 所属模块 |
|---|---|---|
| `scripts/ui/opponent_board_slot.gd` | 新建 — 对手棋盘位：格子轮廓 `_draw()` + 迷雾罩 + `flash()` | SplitScreen |
| `scripts/ui/duel_hud.gd` | 对手面板改横排；挂载对手棋盘位；加 `set_opponent_board()` / `flash_opponent_board()`；飘字起点改为棋盘位中心 | SplitScreen |
| `scripts/main.gd` | 加 `_cell_size` / `_board_center_x`；`_resize_board_layout()` 算自适应尺寸与半屏位移；4 处 offset 写入点加位移；建格子改用 `_cell_size`；标雷时驱动雾闪 | GameFlow |
| `tests/test_duel_split_layout.gd` | 新建 — 分屏几何、单机回归、协议未膨胀 | SplitScreen |
| `docs/NAVIGATION.md` | SplitScreen 🟡 拟建 → 🟢 活跃；4 条术语 🌿 → 🔒 | — |

### 修改范围（合同）

- **允许修改**：
  - `scripts/ui/opponent_board_slot.gd`（新建）
  - `scripts/ui/duel_hud.gd`
  - `scripts/main.gd`（仅布局相关：`_resize_board_layout` / `_set_centered_board_panel_rect` / `_position_board_counters` / `_position_tutorial_guide` / `_apply_board_shake_offset` / 建格子那段 / 对战函数块）
  - `tests/test_duel_split_layout.gd`（新建）
  - `docs/**`
- **禁止修改**：
  - `scripts/net/**` —— **本 FEAT 一个网络字节都不加**，这是共识 #3 的硬约束
  - `scripts/game/minesweeper_board.gd` —— 分屏是纯展示层，规则核不碰
  - `scripts/ui/mine_cell.gd` —— 它的 `configure(index, cell_size)` 本来就收尺寸参数，够用
  - `scripts/game/game_save.gd`、`scripts/ui/world_map.gd`、`scripts/game/stage_table.gd` —— FEAT-002 的地盘
  - `scripts/ui/shop_overlay.gd` —— 中场休息商店是全屏模态，不参与分屏

### 数据 schema 变更

无。分屏与迷雾罩全是展示层，不落盘、不过线。

### 边界 & 不做

- ❌ 对手棋盘的任何状态同步（Q1 的直接推论，也是本 FEAT 最大的省）
- ❌ 迷雾的渐散 / 局部透视 / 侦察类道具
- ❌ 观战与回放
- ❌ 中场休息商店的分屏化（它是全屏模态，盖住两屏）
- ❌ 单机模式的分屏或任何布局变化

### 风险 / 已知坑

- ⚠️ **棋盘缩到 81.7 后美术是否还立得住**：`MineCard` 的泥坑底/内侧阴影/接触阴影都是按 88px 调的，缩 7% 后细节可能糊。headless 测不出来，要真机目视。
- ⚠️ **`BOARD_VERTICAL_SHIFT := CELL_SIZE - 36.0` 是编译期常量**（= 52），不会跟着 `_cell_size` 走。分屏下棋盘的垂直落点因此有轻微偏差，需实测确认可接受，否则要一并改成运行时算。
- ⚠️ **`_apply_board_shake_offset()` 独立重写四个 offset**（main.gd:1935-1941），它绕过了 `_set_centered_board_panel_rect()`。水平位移必须在这里也加一遍，否则棋盘一震就会弹回屏幕中央。
- ⚠️ **对手面板从 560×404 压成 880×76**，`OpponentUpgradeGrid` 最多 13 个图标要塞进一行；44px × 13 = 572px，加上左边的文字接近 880px 上限。真到 13 项时可能溢出，需要实测。
- ⚠️ FEAT-001 的 `test_duel_integration` 会实例化两份 `main.tscn`，分屏后两份都会建对手棋盘位，节点数上升。它已经是较慢的测试，注意别再拖长。

## Implementation Log

> 由 `/wxc-mini:do-it FEAT-003` 填充, 可多条按时间追加。

### 2026-08-25 实施记录

**改动摘要**: 新建 SplitScreen 模块（对手棋盘位 + 迷雾罩），把对战布局改成左右对半分屏，格子边长改为按半屏可用空间自适应。**网络层一个字节没加** —— 「棋盘全遮」直接消掉了整块状态同步。

**实际改的文件** (与 spec 对照):
- ✅ `scripts/ui/opponent_board_slot.gd` — 新建。`FogGridBackdrop` 内部类用 `_draw()` 画格子轮廓，外层挂不透明 `FogVeil` 与提示文案，`flash()` 走一次高光 tween
- ✅ `scripts/ui/duel_hud.gd` — 对手面板竖卡改横条；新增分隔线、对手棋盘位、`set_opponent_board()` / `flash_opponent_board()`；飘字起点改为右屏棋盘位中心
- ✅ `scripts/main.gd` — 新增 6 个分屏常量 + `_cell_size` / `_board_center_offset` 两个状态 + `_apply_split_layout()`；4 处 offset 写入点加位移；建格子改用 `_cell_size`
- ✅ `tests/test_duel_split_layout.gd` — 新建，5 组断言
- ✅ `docs/NAVIGATION.md` — SplitScreen 🟡 拟建 → 🟢 活跃；4 条术语 🔒
- ➖ 未新建 `.tscn` — 沿用本项目「UI 在代码里搭」的惯例，与 FEAT-001 的 DuelHud 一致

**模块增减兑现**:
- 🟢 新建 SplitScreen — 落在 `scripts/ui/opponent_board_slot.gd` + `scripts/ui/duel_hud.gd` 的分屏部分 + `main.gd` 的 `_apply_split_layout()`

**验收勾选**:
- [x] 1 对半分屏、右屏等尺寸棋盘位、有分隔线 — `_test_board_sits_in_left_half` + `_test_opponent_slot_mirrors_the_board`
- [x] 2 迷雾罩全程不透明 — 断言 `FogVeil.color.a > 0.95`
- [x] 3 轮廓行列数与真实棋盘一致 — 断言 `backdrop.columns == board.width`
- [x] 4 最大盘落在左半屏内、格子约 79.3 — `_test_cell_size_only_shrinks_on_the_biggest_board`（实测 79.3，且 6×6~9×9 完全不缩）
- [x] 5 读数与自身 HUD 不越中线 — `_test_counters_stay_in_left_half`
- [x] 6 对手面板在右半屏顶部 — 断言面板在中线右侧
- [x] 7 标雷时整片雾闪光 — `_on_duel_damage_taken` 接 `flash_opponent_board()`（视觉效果 headless 测不了，接线已验）
- [x] 8 飘字从右屏飞向左屏血条 — 起点改为 `_opponent_slot.get_global_rect().get_center()`
- [x] 9 **零新增网络消息** — `_test_protocol_did_not_grow` 钉死 `Kind.size() == 8`
- [x] 10 单机布局零变化 — `_test_single_player_layout_untouched`
- [x] 11 测试全绿 — 5 个对战测试 + 6 个既有测试全 PASS

**验证方式**: `/d/Godot/godot --headless --script tests/test_xxx.gd`。新增 `test_duel_split_layout` 通过；FEAT-001 的四个对战测试与 `test_minesweeper_board` / `test_tactical_shop_inventory` / `test_shop_motion` / `test_find_flag_flow` / `test_mine_counter_ui` / `test_item_counter_ui` 全部无回归。

**踩坑 / 后续 TODO**:
- 格子缩到 79.3 后牌面美术是否还立得住，headless 测不出来，需真机目视。
- 迷雾罩现在是纯色 `ColorRect`，没有雾的质感。要做成流动的雾得上 shader，那是另一个 FEAT。
- 分屏几何按设计分辨率 1920×1080 写死。窗口拉成超宽比例时 `expand` 会放大视口，`-480` 就不再正好是四分之一点，会有轻微偏移。当前窗口 override 是 1280×720（同比例），不受影响。

## 受影响文件

> 由 `/wxc-mini:do-it` 完成时填。

| 文件 | 类型 | 所属模块 |
|---|---|---|
| `scripts/ui/opponent_board_slot.gd` | 新建 | SplitScreen |
| `scripts/ui/duel_hud.gd` | 改 | SplitScreen |
| `scripts/main.gd` | 改 | GameFlow |
| `tests/test_duel_split_layout.gd` | 新建 | SplitScreen |
| `docs/features/FEAT-003-duel-split-screen-fog.md` | 新建 | — |
| `docs/features/wireframes/FEAT-003-DuelSplitScreenWireframe.html` | 新建 | SplitScreen |
| `docs/FEATURES.md` | 改 | — |
| `docs/NAVIGATION.md` | 改 | — |

## 验收报告 (Verify)

> 由 `/wxc-mini:verify FEAT-003` 填（Goal-Backward 证据 + 多维 review）。非必跑；规模大/风险高建议必跑，纯占位类可注明免验收。

(待填)

## 结案总结 (Wrap-up)

> 由 `/wxc-mini:that-is-all FEAT-003` 收尾时填。技术结论、对外接口、模块归档确认、术语锁定。

(待填)
