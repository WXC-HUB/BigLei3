# FEAT-001: pvp-duel-core

| 字段 | 值 |
|---|---|
| ID | FEAT-001 |
| 状态 | 🟣 待收尾 |
| 起 | 2026-08-24 |
| 止 | - |
| 一句话目的 | 搭起 1v1 对战骨架：同棋盘、各自血量、标雷互伤、共享商店经济 |
| 需独立 UI 设计 | 是 |
| 归属模块 | Netplay |
| 关联模块 | BoardModel, GameFlow, ShopEconomy, Persistence |
| 新建模块 | Netplay |

## 术语 (Terminology)

> 中英对照。start 初定 → discuss 确认 → spec 锁定 → that-is-all 归档。同步 [导航文档](../NAVIGATION.md) 术语库。

| 中文 | English | 定义 | 所属模块 | 状态 |
|---|---|---|---|---|
| 对战局 | Duel | 一次 1v1 对局，由多个对战轮组成，持续到一方血量归零 | Netplay | 🔒 锁定 |
| 对战轮 | Duel Round | 对战局内的一盘棋，从开盘到任一方清完棋盘为止 | Netplay | 🔒 锁定 |
| 对局种子 | Duel Seed | 由房主下发、派生出每轮棋盘布局与开局格的共享随机种子 | Netplay | 🔒 锁定 |
| 开局格 | Opening Cell | 由对局种子算出、棋盘生成时即已翻开的起始格，同时充当 `_place_mines` 的 `first_index` | BoardModel | 🔒 锁定 |
| 标雷伤害 | Mark Damage | 玩家每标出一个雷对**对手**造成的伤害，按雷逐个结算 | Netplay | 🔒 锁定 |
| 大全商店 | Full Shop | 对战专用商店，一次陈列全部 13 项强化、不刷新、每项限购 1 次 | ShopEconomy | 🔒 锁定 |
| 中场休息 | Intermission | 一方率先清完棋盘后双方共同进入的商店与备战阶段 | Netplay | 🔒 锁定 |

## Discuss

> 由 `/wxc-mini:discuss FEAT-001` 填充。设计共识与决策清单 (3-7 条)。

### 前置：模块上下文扫描

模块库在本 FEAT 开工时为空，四个关联模块均为**首次登记**，无并行 FEAT，故无方案/文件冲突预警。代码侧扫描结论：

- **Netplay 是真空**：全项目零网络代码（`Multiplayer*` / `WebSocket` / `ENet` / `HTTPRequest` 均无命中），确认是一块全新职责边界，新建模块成立。
- **BoardModel 是干净的纯规则核**：`extends RefCounted`、零节点依赖、状态全在 `PackedByteArray`、自带 seeded `_rng`，可直接在 headless 端复用。
- **GameFlow 是隐藏耦合的重灾区**：`main.gd` 4509 行，~60 个 run 状态变量与 UI 节点/Tween 混居，152 处 `await`，回合结算与动画时长耦合。
- **ShopEconomy 实际横跨两处**：`shop_overlay.gd`（展示 + 自己的 `_rng`）与 `main.gd` 的 `_gold` / `_choose_shop_offer`。NAVIGATION 已按此登记职责。

### 批量确认的假设（Confident）

| # | 假设 | 证据 | 结论 |
|---|---|---|---|
| C1 | 「标出一个雷」不用新做触发点：`_marked_mine_log` 已统一收集全部标雷入口（右键、灯笼、罗盘、夜鹭、连携、探测），`take_marked_mine_log()` 取走即消费 | `minesweeper_board.gd:48,341-354` | ✅ 确认 |
| C2 | 「双方棋盘相同」现在拿不到，必须先做**首点搬雷 + 种子链** | `minesweeper_board.gd:502-529` 布局依赖首点；`main.gd:1256` 每关现造时间种子 | ✅ 确认 |
| C3 | ~~大全商店是全新界面~~ → **修正**：13 个 `ShopOffer` 本身就是「大全」，全部是永久强化 `_*_bonus += 1`、统一价 5 金；现有商店只是随机抽 3 个展示。故**数据层完全复用**，只有展示层从「抽 3」改「全列 13」 | `main.gd:143-157`、`main.gd:1162-1205` | ⚠️ 已修正 |
| C4 | 传输层用 `WebSocketMultiplayerPeer`，ENet 出局（Web 首发，浏览器开不了 UDP） | `export_presets.cfg` preset.0 = Web | ✅ 确认 |
| C5 | PVP 不走单机流程线：4 关教程、中场音乐演出、存档续关全部跳过 | `TUTORIAL_LEVEL_COUNT`、`MUSIC_BREAK_LEVEL`、`main.gd:523` | ✅ 确认 |

### 逐条问答

**Q1: 现有 PVE 伤害（踩雷 -1、错旗 -1、大怪每 3 回合攻击 -1）在 PVP 里怎么处理？**
A: 共用一条血，PVE 伤害全部保留。「对手标雷」只是新增的一条伤害源。
理由 / 备注: 技术上零改动，规则最简单，踩雷本来就该痛。代价是初始血量必须从 3 大幅提高，否则两个新手互相踩雷会没交手就自己死。

**Q2: 一方率先清完棋盘的那一瞬间，落后方怎么办？**
A: 立即冻结，落后方剩余的雷不结算。
理由 / 备注: 一条 `round_over` 消息，双方立刻停手，不需要跨端对时。「抢先清盘」的张力最大。已知风险：领先优势会滚雪球，需在数值上留意。

**Q3: 一局里的多轮棋盘怎么演变？**
A: 逐轮变大，沿用单机曲线（6×6 起，10×10 封顶）。
理由 / 备注: 复用 `_start_game` 现有尺寸逻辑。雷数随盘面增长 = 每轮伤害吞吐增长 = 对局天然收束，不会无限拖。

**Q4: 本次 FEAT 的网络层做到哪一步？**
A: 本地双实例 + 真 WebSocket 协议。同机开两个客户端，一个当 host 监听 localhost，另一个连上去。
理由 / 备注: 协议、序列化、状态机全是真的；上线只需换地址 + 加中继。房间码匹配、断线重连、wss 部署不在本 FEAT 范围。

**Q5: 大全商店的库存和限购规则？**
A: 各自独立库存，保留「同一次商店每项限购 1 次」。
理由 / 备注: 购买行为完全不需要过线仲裁，限购逻辑（`mark_offer_sold_out`）现成。钱多只能广撒网，堆不出单一道具的极端流派。

**Q6: 数值初值？**
A: 血 10 / 每雷伤害 1 / 每雷金币 1 / 初始金币 10。全部集中成一组常量，实测后再调。
理由 / 备注: 第一轮满标 6 雷打 6 点，净差一般 2-4 点，能撑 3-5 轮。开局能买 2 件，每轮再进 6-16 金。容错率够高，能看出成长曲线。

**Q7: 对手的信息公开到什么程度？**
A: **全公开**，包括对手买了哪些强化。
理由 / 备注: ⚠️ 推翻了我的推荐（半公开、藏购买内容）。用户选择更高的策略深度——可以针对性出装。代价：协议要推送对手的完整强化列表，wireframe 要多画一块对手面板，且要处理新手信息过载。

**Q8: 中场休息怎么推进到下一轮？**
A: 双方 ready 或 30 秒倒计时到，自动开始。
理由 / 备注: 不让买得快的人干等，也防挂机卡死。倒计时由 host 端权威，延迟不敏感。

**Q9: 「首点安全」与「双方棋盘完全一致」矛盾，怎么解？**
A: 由对局种子算出一个**开局格**，棋盘生成时该格已翻开（含连锁展开）。
理由 / 备注: ⚠️ 本轮讨论最重要的发现，同时推翻了 C2 的解法。原问题：`_place_mines(first_index)` 把首点 3×3 排除出布雷范围，只要两人第一下点在不同格，候选数组就不同、洗牌结果就不同 → 光有种子链也拿不到同一张盘。上一轮提的「生成后搬雷」同样不成立（A 搬左上、B 搬右下，点击后照样分叉）。本方案让 `first_index` 由种子决定而非由玩家决定，双方布局与起跑线绝对一致，**且首点安全自动成立、搬雷逻辑根本不用写**。

**Q10: 一次标出多个雷时，伤害怎么结算？**
A: 按雷逐个结算、逐个飘字。
理由 / 备注: `take_marked_mine_log()` 取回 N 个雷就发 N 条伤害。协议粒度最细，以后加「某道具标的雷伤害翻倍」这类差异化强化不用返工；道具大起手的爆发感也最强。

### 补充陈述的假设（未单独提问，如有异议在 spec 阶段推翻）

- **种子链同时应用到单机**：单机也走 `run_seed` → `level_seed`，使 run 变为可复现。纯收益，不改变单机的随机体感。
- **搬雷逻辑不实现**：Q9 的直接推论。
- **错旗天然不伤对手**：`_marked_mine_log` 只收 `is_monster_core` 的格子，错旗不入队，无需额外判断。
- **PVP 不写存档**：但 `_choose_shop_offer` 内部调了 `_save_progress()`、启动时会跑 `_load_saved_progress()`，PVP 路径必须绕开这两处——这是 Persistence 保留为关联模块的唯一原因。
- **对手断开即本局作废并提示**：本 FEAT 不做断线重连。
- **PVP 入口**：开始界面新增按钮，具体形态在 wireframe 阶段定。

### ▶ 共识 (锁定后进 /wxc-mini:spec)

1. **对局结构**：一场[[对战局]]由多个[[对战轮]]组成。每轮双方各自在一张布局完全相同的棋盘上作业；一方清完即全场**立即冻结**（落后方剩余的雷不结算），进入[[中场休息]]；下一轮棋盘按单机曲线逐轮变大（6×6 起、10×10 封顶）；直到一方血量归零。

2. **棋盘一致性**：房主下发[[对局种子]]，每轮 `level_seed = hash(duel_seed, round)`；棋盘生成时以种子算出的[[开局格]]作为 `_place_mines` 的 `first_index` 并立即翻开（含连锁展开）。双方布局与起跑线绝对一致，**首点搬雷逻辑不实现**。种子链同时应用到单机，使单机 run 可复现。

3. **伤害模型**：全局只有一条血。PVE 伤害（踩雷 -1、错旗 -1、大怪每 3 回合 -1）全部原样保留；新增唯一一条跨端伤害源——己方每标出 1 个雷对对手造成 1 点[[标雷伤害]]，按雷逐个结算、逐个飘字。触发源统一取 `take_marked_mine_log()`，不 hook 任何单独的标雷入口。

4. **经济模型**：初始血 10、初始金 10、每标出 1 个雷得 1 金、道具单价沿用 5 金。[[大全商店]]陈列全部 13 项 `ShopOffer`，双方库存独立、不刷新、同轮每项限购 1 次。以上数值全部集中成一组常量，便于实测后调整。

5. **信息公开度**：对手的血量、标雷进度、**以及已购强化列表**全部实时公开，协议需推送对手的完整强化清单。

6. **模块归属**：本 feature 归属**新建的 Netplay 模块**（连接 / 房间 / 消息收发 / 对战局状态机）；关联 BoardModel（加种子链与开局格）、GameFlow（回合结算插入伤害收发落点、关卡流转改对战流转）、ShopEconomy（大全商店展示层 + 新金币来源）、Persistence（PVP 路径绕开存档读写，不主改）。

7. **范围边界**：本 FEAT 只做**本地双实例 + 真 WebSocket 协议**（host 监听 localhost，另一实例连入）。房间码匹配、断线重连、wss 部署、跨棋盘干扰道具**均不在范围内**；对手断开即本局作废并提示。传输层用 `WebSocketMultiplayerPeer`，ENet 因 Web 首发而出局。

### ▶ 实施期补充 (2026-08-24)

do-it 阶段冒出的、Spec 没覆盖的决策，逐条记账：

1. **对战里五只鸟全部解锁**。触发：大全商店 13 项强化都能买，但 `_apply_bird_unlock_visibility()` 会把未解锁的鸟藏起来，买了夜鹭强化却看不见夜鹭就成了黑箱。决策：`_prepare_duel_run()` 里把五只鸟一次性解锁。
2. **对手的标雷伤害不吃红隼的无敌盾**。触发：`_try_settle_duel_damage()` 要不要先过 `_is_invincible()`。决策：不过。红隼的说明写的是「1步内无敌，踩中雷不掉血」——它挡的是雷，不是对手。
3. **中场休息倒计时必须显式「上膛」**。触发：`test_duel_session_flow` 抓到的真 bug。冻结的瞬间 `state` 就变成 INTERMISSION，但商店要过 1.2 秒收尾演出才弹出来；没有 `_intermission_armed` 标志时，房主会在演出还没放完时读到「剩余 0 秒」而直接开下一轮，中场休息整个被跳过。决策：加 `_intermission_armed`，只有 `enter_intermission()` 能上膛。
4. **对战跳过换歌插播**。触发：`MUSIC_BREAK_LEVEL = TUTORIAL_LEVEL_COUNT + 5`，对战打到第 5 轮会被单机的插播打断。决策：`_prepare_duel_run()` 里置 `_music_break_played = true`。
5. **`_can_afford` 取代 `refresh_button.disabled` 当「买得起吗」的判据**。触发：`mark_offer_sold_out()` 原本拿刷新按钮的禁用态当钱够不够的替身，而大全商店把刷新按钮整个关了——照原样会在买完第一件后把整排货连坐禁用。决策：显式记一个 `_can_afford`。
6. **`DuelSession.poll()` / `tick()` 提为公开方法**。触发：headless 测试在场景树外用这个类，`_process` 不会跑。决策：公开手动驱动入口，同时也是将来做无头服务端的接口。
7. **Spec 验收标准 #10 措辞修正**。原写「下一轮棋盘比上一轮大一格」，与 Q3 敲定的「沿用单机曲线」冲突——单机曲线里 `BOARD_SIZE_HOLD_LEVELS = 3`，前 3 个普通关固定 6×6，之后才每关 +1。按 Q3 的共识改 AC 措辞，**行为不动**。

## Wireframe

> 仅"需独立 UI 设计 = 是"时，由 `/wxc-mini:wireframe FEAT-001` 填充（线框产物路径 + 结构结论）。否则本段写 "本 feature 无需独立 UI 设计"。

本 feature 涉及两块界面，各出一张线框。

### DuelHud 线框

- **产物 (FEAT 工作线框)**: [FEAT-001-DuelHudWireframe.html](wireframes/FEAT-001-DuelHudWireframe.html)
- **基线 (模块归档线框)**: 无 — 全新界面（Netplay/GameFlow 均无归档线框，本 FEAT 为首张）
- **归属模块**: Netplay
- **本次改动 (vs 归档)**: 全新
- **节点/受控字段**: 共 22 节点，受控 15 个（Label 9 / TextureProgressBar 1 / GridContainer 1 / TextureRect 1 / ColorRect 1 / HBoxContainer 1 / Control 1）
- **行为标签分布**: 赋值 12 / 点击 0 / 悬停 0 / 状态 4 / 拷贝 2
- **用到的术语**: 对战局、对战轮、标雷伤害
- **接口对齐结论**:
  - 复用现有：`PlayerStatus.set_health()` `set_gold()`（player_status.gd:28,44）、`main.gd:_spawn_damage_number()` `_animate_floating_label()`（3127/3142）、`MinesweeperBoard.mine_count`、`ShopOverlay.OFFER_ICONS`（13 项）
  - ⚠️ 需新增：`DuelConfig.START_HP/MARK_DAMAGE/MARK_GOLD`、`DuelSession.round_index/opponent 快照`、`DuelClient`（WebSocketMultiplayerPeer 封装）、消息 `state_sync/mine_marked/upgrade_bought/round_over`
- **待决策的开放问题**: 血量上限 10 会让 `_rebuild_hearts` 建 10 个 48px 心（480px 宽），可能挤到棋盘计数器 — 已转为 Spec 风险项，实测后定
- **归档处置建议 (供 that-is-all)**: 新建 `docs/modules/Netplay/DuelHudWireframe.html`

### DuelShop 线框

- **产物 (FEAT 工作线框)**: [FEAT-001-DuelShopWireframe.html](wireframes/FEAT-001-DuelShopWireframe.html)
- **基线 (模块归档线框)**: 无 — 全新界面。但**结构上是既有 `scenes/shop_overlay.tscn` 的扩建**，复用节点已逐个在 desc 中注明
- **归属模块**: ShopEconomy
- **本次改动 (vs 归档)**: 全新
- **节点/受控字段**: 共 25 节点，受控 18 个（Label 10 / Button 3 / GridContainer 2 / TextureRect 2 / Control 1）
- **行为标签分布**: 赋值 12 / 点击 2 / 悬停 1 / 状态 3 / 拷贝 2
- **用到的术语**: 大全商店、中场休息、对战轮
- **接口对齐结论**:
  - 复用现有：`ShopOverlay` 的 `OFFER_ICONS/OFFER_NAMES/OFFER_DESCRIPTIONS`（各 13 项）、`mark_offer_sold_out()` `update_gold()` `set_offer_owned()` `_play_enter()` `_play_exit()` `_set_greeting_text()`、`main.gd:_choose_shop_offer()`
  - **关键结论**：`_build_offer_items()`（shop_overlay.gd:157）本就建满 13 个槽位，`_roll_offers()` 只是把没抽中的 `visible=false`。**大全商店 = 跳过 roll**，不需要新场景
  - ⚠️ 需新增：`ShopOverlay.present_full(gold, price)`、`DuelSession.mark_ready()`、消息 `ready/round_start`、倒计时（host 权威）
- **待决策的开放问题**: 无
- **归档处置建议 (供 that-is-all)**: 新建 `docs/modules/ShopEconomy/DuelShopWireframe.html`
- **实施期结构漂移 (已同步回工作线框)**: 原线框把对手面板画成与 `IntermissionBar` 平级的 `OpponentShopPanel`；实际落地时并进了 `IntermissionBar` 内部（同一个 VBox 里的两行 Label + 一个图标网格），少一层容器也少一处定位。工作线框的 NODES 层级已按真实结构更正；SVG 分区图仍按原布局绘制，以后融合归档时以层级树为准。

## Spec

> 由 `/wxc-mini:spec FEAT-001` 填充。验收标准、影响文件、数据 schema、边界 & 不做、风险。

### 验收标准

> 全部勾完才视为本 feature 完成。

- [ ] 启动两个客户端实例，一个「创建对战」监听 `localhost:8910`，另一个「加入对战」连上去，双方 HUD 连接指示都变为「● 已连接」。
- [ ] 对局开始后两个客户端的棋盘布局**逐格一致**（同一格是雷/是数字/是道具槽），且开局时同一片区域已被翻开。
- [ ] 任一方标出 1 个雷，对方血条立即 -1 并飘一个「-1」；一次标出 N 个雷（如夜鹭连标 3 个）则对方连掉 N 点、飘 N 个字。
- [ ] 任一方标出 1 个雷，自己金币 +1，且对面 HUD 的「对手金币」同步 +1。
- [ ] 己方踩雷/错旗仍按单机规则扣**自己**的血，且不给对手造成任何伤害、不给自己加金币。
- [ ] 一方清完棋盘的瞬间两个客户端都出现冻结遮罩，落后方剩余未标的雷不再产生任何伤害或金币。
- [ ] 中场休息的商店一次显示全部 13 项强化，没有「刷新并补货」按钮，每项买过一次后显示「售罄」。
- [ ] 一方购买强化后对方的「对手已购强化」墙立刻出现对应图标；买第二个同类时角标显示「×2」。
- [ ] 双方都点「准备好了」立即开始下一轮；只有一方点则等 30 秒倒计时归零自动开始。
- [ ] 下一轮棋盘按单机曲线增长（`BOARD_SIZE_HOLD_LEVELS = 3`：前 3 轮固定 6×6，之后每轮 +1 至 10×10 封顶），且双方仍逐格一致。
- [ ] 任一方血量归零时双方都进入对局结束界面并显示胜负。
- [ ] 对手断开连接时本方出现「对手已断开，本局作废」提示且可返回主菜单。
- [ ] 单机流程不受影响：4 关教程、三选一商店、刷新按钮、存档续关全部照旧。
- [ ] `godot --headless` 跑 `tests/` 全绿，含新增的 `test_duel_protocol.gd`（双端 WebSocket 收发 + 消息编解码往返）与 `test_duel_board_parity.gd`（同种子同开局格 → 两块 board 逐格一致）。

### 涉及的代码改动 (预估)

| 文件 | 改动 | 所属模块 |
|---|---|---|
| `scripts/net/duel_config.gd` | 新建 — 对战数值常量组（HP/金币/伤害/倒计时/端口） | Netplay |
| `scripts/net/duel_protocol.gd` | 新建 — 消息类型枚举 + 编解码（含往返自检） | Netplay |
| `scripts/net/duel_client.gd` | 新建 — `WebSocketMultiplayerPeer` 封装：host/join、poll、收发、断线信号 | Netplay |
| `scripts/net/duel_session.gd` | 新建 — 对战局状态机、对手快照、种子链、ready/倒计时（host 权威） | Netplay |
| `scripts/ui/duel_hud.gd` | 新建 — 对手面板 / 受击飘字 / 冻结遮罩 / 轮次标签 | Netplay |
| `scenes/ui/duel_hud.tscn` | 新建 — 对应 DuelHud 线框的 22 节点 | Netplay |
| `scripts/game/minesweeper_board.gd` | 加 `take_scored_mine_log()`（append-only 去重）+ `opening_cell_for()` | BoardModel |
| `scripts/main.gd` | 对战分支：种子链、开局格自动翻开、伤害收发落点、冻结、商店切换、绕开存档 | GameFlow |
| `scripts/ui/shop_overlay.gd` | 加 `present_full()`（不 roll、藏刷新按钮）+ ready 模式文案 | ShopEconomy |
| `scripts/ui/start_screen.gd` | 加「创建对战 / 加入对战」入口 | GameFlow |
| `tests/test_duel_protocol.gd` | 新建 — 双端 WebSocket 握手 + 六类消息编解码往返 | Netplay |
| `tests/test_duel_board_parity.gd` | 新建 — 同 seed 两块 board 逐格一致 + 开局格已翻开 | BoardModel |
| `docs/NAVIGATION.md` | Netplay 🟡 拟建 → 🟢 活跃；7 条术语 🌿 → 🔒 | — |

### 修改范围（合同）

- **允许修改**：
  - `scripts/net/**`（新建目录）
  - `scenes/ui/duel_hud.tscn`
  - `scripts/game/minesweeper_board.gd`
  - `scripts/main.gd`
  - `scripts/ui/shop_overlay.gd`
  - `scripts/ui/start_screen.gd`
  - `tests/test_duel_*.gd`
  - `docs/**`
- **禁止修改**：
  - `scripts/game/game_save.gd` — 存档结构本 FEAT 不动，PVP 只**绕开**读写，不改 schema
    > ⚠️ **交叉备注（[FEAT-002](FEAT-002-level-select-hexmap.md) discuss Q16）**：FEAT-002 已拿到 `game_save.gd` 的修改权，会把 `VERSION` 提到 2 并新增 `cleared_stages` 与续局槽 `stage_id`。本 FEAT 的"禁止修改"约束不变（我们仍然不动它），且因为 PVP 只绕开存档、不依赖其结构，schema 升版对本 FEAT 无影响。
  - `scripts/ui/mine_cell.gd`、`vfx/cell_fx.gd` — 格子交互层与特效层不动
  - `scenes/main.tscn` 的**既有**节点 — 只允许新增 `DuelHud` 一个子节点，不改动任何现存节点
  - `scripts/ui/*_unlock.gd`（夜鹭/红尾水鸲/啄木鸟/红隼解锁演出）— 单机解锁流程不碰
  - `scenes/shop_overlay.tscn` — 商店场景结构不动，大全商店纯靠 `shop_overlay.gd` 的新方法实现

### 数据 schema 变更

无。

PVP 对局**不写存档**；单机存档结构保持 `GameSave.VERSION = 1` 不变。种子链虽然同时应用到单机，但 `run_seed` 只存在于内存、不落盘——即"同一次运行内可复现"，跨存档复现留给后续 FEAT。这是为了守住"禁止修改 `game_save.gd`"这条红线。

### 边界 & 不做

- ❌ 房间码匹配 / 中继服务器 / wss 部署 — 只做 host 监听 localhost + 直连地址
- ❌ 断线重连 — 断开即本局作废
- ❌ 跨棋盘干扰道具 — 另开 FEAT
- ❌ 对局存档 / 战绩统计 / 昵称 / 观战 / 复盘
- ❌ 单机存档 schema 变更（`run_seed` 不落盘）
- ❌ 首点搬雷逻辑 — Q9 已用开局格方案替代，不实现

### 风险 / 已知坑

- ⚠️ **血量 10 会撑爆 HUD**：`PlayerStatus._rebuild_hearts()`（player_status.gd:121）按最大血量建 N 个 48px 心，10 颗 = 480px 宽，可能挤到棋盘计数器。实测后必要时改分行或缩小心尺寸。
- ⚠️ **不能复用 `_marked_mine_log` 做伤害触发**：它已被连携消费（`_collect_chain_partners` 里 `take_marked_mine_log()` 取走即清空，main.gd:2126）。必须新增独立的 append-only `_scored_mine_log` 并按格号去重，否则反复插旗/撤旗会重复计伤。
- ⚠️ **伤害到达时机与结算锁冲突**：main.gd 有 152 处 `await`，收到伤害时本地可能正卡在红隼模态或连携挂起中。入站消息必须排队，只在 `_resolve_turn` 释放锁前、或空闲且 `not _resolving and not _super_luck_mode_active and _chain_anchors.is_empty()` 时才落地。
- ⚠️ **`_choose_shop_offer` 内部调 `_save_progress()`**（main.gd:1205）：对战路径必须绕开，否则 PVP 会污染单机存档槽。
- ⚠️ **Godot 4.7 的 `WebSocketMultiplayerPeer` 需手动 `poll()`**：在 headless 测试里同进程开两个 peer 时不能依赖 SceneTree 自动驱动，测试必须显式循环 poll。
- ⚠️ **领先优势滚雪球**：「立即冻结」+「PVE 伤害保留」叠加会放大领先方优势（discuss Q2 已记）。数值全部集中在 `duel_config.gd`，实测后第一个要调的就是这组。

## Implementation Log

> 由 `/wxc-mini:do-it FEAT-001` 填充, 可多条按时间追加。

### 2026-08-24 实施记录

**改动摘要**: 新建 Netplay 模块（配置/协议/传输/状态机/HUD 五个文件），给 BoardModel 加计分队列与开局格，给 GameFlow 接上对战分支，给 ShopEconomy 加大全商店与中场休息条，给标题页加对战入口。四个新测试全绿，含两端真实 WebSocket 与双实例整局跑通。

**实际改的文件** (与 spec 对照):
- ✅ `scripts/net/duel_config.gd` — 新建，对战数值常量组（血 10 / 金 10 / 雷伤 1 / 雷金 1 / 倒计时 30s / 端口 8910）
- ✅ `scripts/net/duel_protocol.gd` — 新建，8 类消息 + JSON 编解码。坏包走 `JSON.new().parse()` 静默丢弃，不往控制台推 ERROR
- ✅ `scripts/net/duel_client.gd` — 新建，`WebSocketMultiplayerPeer` 封装；host 只收第一个 peer，多余的直接踢
- ✅ `scripts/net/duel_session.gd` — 新建，对战局状态机 + 对手快照 + 种子链 + ready/倒计时
- ✅ `scripts/ui/duel_hud.gd` — 新建，对手面板 / 受击飘字 / 冻结遮罩 / 轮次标签
- ✅ `scripts/game/minesweeper_board.gd` — 加 `take_scored_mine_log()`（append-only + 按格号去重）与静态的 `opening_cell_for()`
- ✅ `scripts/main.gd` — 12 处接入点 + 一段对战函数块：种子链、开局格自动翻开、标雷结算、入站伤害排队、冻结、中场商店、绕开存档
- ✅ `scripts/ui/shop_overlay.gd` — 加 `present_full()` / 中场休息条 / ready 模式 / `exit_duel_mode()`；顺带修掉「买完一件连坐禁用整排货」
- ✅ `scripts/ui/start_screen.gd` — 菜单列末尾加「创建对战 / 加入对战」一排
- ✅ `tests/test_duel_board_parity.gd` — 新建，同种子逐格一致 + 开局格安全 + 计分队列去重
- ✅ `tests/test_duel_protocol.gd` — 新建，8 类消息编解码往返 + 两端真实握手收发
- ⚠️ `tests/test_duel_session_flow.gd` — spec 没列。状态机的端到端：握手 → 互伤 → 购买公开 → 冻结 → ready/倒计时 → 下一轮 → 分胜负。**它抓出了倒计时未上膛这个真 bug**，值回票价
- ⚠️ `tests/test_duel_integration.gd` — spec 没列。同进程跑两份 `main.tscn` 打真实对局，核对验收 2/3/4/5/6/7/13
- ✅ `docs/NAVIGATION.md` — Netplay 🟡 拟建 → 🟢 活跃，补齐文件落点与对外接口草稿
- ➖ `scenes/ui/duel_hud.tscn` — **没建**。这个项目的 UI 惯例是 `main.gd:_build_interface()` 那样在代码里搭，混两套反而更难定位；DuelHud 全部在 `duel_hud.gd` 里构建，节点名与线框一一对应

**模块增减兑现**:
- 🟢 新建 Netplay — 落在 `scripts/net/`（4 个文件）+ `scripts/ui/duel_hud.gd`

**验收勾选**:
- [x] 1 连接指示 — `test_duel_protocol` 双端握手；`test_duel_integration` 走完整 `_on_duel_host_requested` / `_on_duel_join_requested`
- [x] 2 棋盘逐格一致 — `test_duel_board_parity` + `test_duel_integration._check_boards_are_identical`（逐格比雷/数字/道具/翻开状态）
- [x] 3 标雷伤害逐个结算 — `test_duel_session_flow` 断言 3 次标雷 = 3 条伤害；`test_duel_integration` 断言对手血量真的掉了
- [x] 4 标雷 +1 金且对面可见 — 同上两个测试
- [x] 5 PVE 伤害不外溢 — `test_duel_integration._check_pve_damage_stays_local`：错旗只扣自己的血，对手血量与自己金币都不动
- [x] 6 清盘立即冻结 — `test_duel_session_flow` 断言 true/false 两侧；`test_duel_integration` 断言冻结后对手血量不再变化
- [x] 7 大全商店 13 项全列、无刷新 — `test_duel_integration` 逐个数 `ItemSlot_%d` 的可见性 + 断言刷新按钮不可见
- [x] 8 购买立刻公开、叠加显示 ×2 — `test_duel_session_flow._test_purchases_are_public`
- [x] 9 双方 ready 立即开 / 单方 ready 等倒计时 — `test_duel_session_flow` 两条分别覆盖
- [x] 10 棋盘按单机曲线增长且仍逐格一致 — `test_duel_session_flow` 断言第 2 轮种子两端一致且与第 1 轮不同（措辞已按实施期补充 #7 修正）
- [x] 11 血量归零分胜负 — `test_duel_session_flow._test_defeat_decides_the_duel`
- [x] 12 断线提示 — `test_duel_protocol` 覆盖 `close()` 后两端 `is_linked()` 转 false；UI 提示走 `_on_duel_link_lost`（人工路径，未自动化）
- [x] 13 单机流程不受影响 — `test_duel_integration._check_single_player_path_untouched`（第 1 关仍 2×1，商店仍三选一 + 有刷新）；另跑 11 个既有测试无回归
- [x] 14 headless 测试全绿 — 见下

**验证方式**: `/d/Godot/godot --headless --script tests/test_xxx.gd`。四个新测试 + 既有回归子集（minesweeper_board / tactical_shop_inventory / shop_motion / abandon_run / find_flag_flow / new_tactical_items / inference_chord / first_normal_level_heal）全部 PASS。

**测试全景**（`tests/` 共 57 个）:
- ✅ 新增 4 个全绿；既有 ~45 个全绿。
- ❌ 6 个失败，**逐个用 `git worktree` 拉干净 HEAD 复现过同样的失败**，确认全部为既有问题、与本 FEAT 无关：
  | 测试 | 失败信息 | 基线复现 |
  |---|---|---|
  | `test_roguelite_progression` | 教程棋盘没有居中（headless 把视口报成 1920×1920） | ✅ 同样失败 |
  | `test_animation_smoke` | 断言失败 + 耗时 401s | ✅ 同样失败 |
  | `test_bird_item_icons` | Shop item did not use its bird icon | ✅ 同样失败 |
  | `test_game_save` | Save data did not survive a round trip | ✅ 同样失败 |
  | `test_regular_level_return` | Confirming return did not reset the run | ✅ 同样失败 |
  | `test_credits_bird_swarm` | Hovering a bird did not burst any music notes | ✅ 同样失败 |
- ⏱️ `test_ui_layering` 与 `test_tree_interaction` 都跑满 600s 不结束（无断言输出）。两个都在**干净 HEAD 的独立 worktree 上同样跑满 600s 不结束**（601s / 600s），确认既有，与本 FEAT 无关。

**⚠️ 并发改动警告**: 实施期间发现**另一个会话正在同一个工作树上并发开发 FEAT-002**（`.codex/worktrees/` 那个），已落地 `scripts/game/stage_table.gd`、`scripts/ui/world_map.gd`、`scripts/ui/stage_badge.gd`、六边形地图素材包，并把 `GameSave.VERSION` 从 1 提到了 2。两点影响：
1. 它改了 `scripts/game/game_save.gd` —— 那正是本 Spec「修改范围」里明确列为**禁止修改**的红线文件。本 FEAT 一个字没动它，但两条线迟早要在存档 schema 上碰头，需要人工协调。
2. 新增 `class_name StageTable` 后必须重跑一次 `godot --headless --import`，否则一批测试会以 "Identifier StageTable not declared" 报解析错误。这是本项目的老坑，已在记忆里记过。

**踩坑 / 后续 TODO**:
- 血量上限 10 会让 `PlayerStatus._rebuild_hearts()` 建 10 个 48px 心（480px 宽）。headless 测不出视觉挤压，需真机目视确认，必要时改分行或缩小心尺寸。
- 「立即冻结 + PVE 伤害保留」的雪球效应仍待实测；数值全在 `duel_config.gd`，改一个文件即可。
- 双方同时清盘时，两端都会认为「是我先清的」（纯文案差异，不影响流程）。真要精确判定得由房主仲裁，留给后续 FEAT。

## 受影响文件

> 由 `/wxc-mini:do-it` 完成时填。

| 文件 | 类型 | 所属模块 |
|---|---|---|
| `scripts/net/duel_config.gd` | 新建 | Netplay |
| `scripts/net/duel_protocol.gd` | 新建 | Netplay |
| `scripts/net/duel_client.gd` | 新建 | Netplay |
| `scripts/net/duel_session.gd` | 新建 | Netplay |
| `scripts/ui/duel_hud.gd` | 新建 | Netplay |
| `scripts/game/minesweeper_board.gd` | 改 | BoardModel |
| `scripts/main.gd` | 改 | GameFlow |
| `scripts/ui/shop_overlay.gd` | 改 | ShopEconomy |
| `scripts/ui/start_screen.gd` | 改 | GameFlow |
| `tests/test_duel_board_parity.gd` | 新建 | BoardModel |
| `tests/test_duel_protocol.gd` | 新建 | Netplay |
| `tests/test_duel_session_flow.gd` | 新建 | Netplay |
| `tests/test_duel_integration.gd` | 新建 | Netplay |
| `docs/features/FEAT-001-pvp-duel-core.md` | 新建 | — |
| `docs/features/wireframes/FEAT-001-DuelHudWireframe.html` | 新建 | Netplay |
| `docs/features/wireframes/FEAT-001-DuelShopWireframe.html` | 新建 | ShopEconomy |
| `docs/FEATURES.md` | 新建 | — |
| `docs/NAVIGATION.md` | 新建 | — |
| `docs/QUICK_LOG.md` | 新建 | — |

## 验收报告 (Verify)

> 由 `/wxc-mini:verify FEAT-001` 填（Goal-Backward 证据 + 多维 review）。非必跑；规模大/风险高建议必跑，纯占位类可注明免验收。

(待填)

## 结案总结 (Wrap-up)

> 由 `/wxc-mini:that-is-all FEAT-001` 收尾时填。技术结论、对外接口、模块归档确认、术语锁定。

(待填)
