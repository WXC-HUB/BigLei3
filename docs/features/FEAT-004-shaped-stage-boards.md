# FEAT-004: shaped-stage-boards

| 字段 | 值 |
|---|---|
| ID | FEAT-004 |
| 状态 | ✅ 完成 |
| 起 | 2026-08-29 |
| 止 | 2026-08-29 |
| 一句话目的 | 关卡每盘表驱动形状与雷数；支持矩形缺口/单洞/多洞；打完全部盘即通关 |
| 需独立 UI 设计 | 否 |
| 归属模块 | BoardModel |
| 关联模块 | WorldMap, GameFlow |
| 新建模块 | —（扩展 BoardModel / WorldMap 数据层） |

## 术语 (Terminology)

| 中文 | English | 定义 | 所属模块 | 状态 |
|---|---|---|---|---|
| 盘面形状 | Board Shape | 包围盒 + 可玩格掩码；引擎只认掩码，kind 仅分类 | BoardModel | 🔒 锁定 |
| 可玩格 | Active Cell | 掩码为 1、可交互、计入胜负与布雷的格子 | BoardModel | 🔒 锁定 |
| 盘列表 | Board List | 关卡表里按顺序配置的每一盘：`shape` + `mines` | WorldMap | 🔒 锁定 |

> [[盘]] / [[目标盘数]] / [[关卡表]] 沿用 FEAT-002；目标盘数改为 `boards.size()` 派生。

## Discuss

### 共识（已锁定）

1. **子关 = 盘**；关卡通关 = 按序打完该关全部盘。
2. **关内仍是肉鸽 run**（账单→商店→下一盘；末盘不通商店、回地图）。
3. **主题** = 地形区主题，纯视觉；盘面皮肤本期不换。
4. **数据开放模型**：引擎只吃 bbox + active mask；`BoardShape` 库 + 盘条目 `shape_id`/`mines`；未来新形只加 mask。
5. **形状族**：矩形缺口 / 单缺口 / 多缺口；硬约束：单一八邻域连通、雷数预留下限。
6. **范围**：第 1 关保留教程；第 2 关起表驱动异形；18 关盘表一期填满；对战不进异形。
7. **每盘最小配置**：形状 + 雷数；道具/五鸟/得分沿用旧逻辑。

## Spec

### 验收标准

- [x] `MinesweeperBoard` 接受 `active_mask`；空洞格不可点、不进邻接、不计胜负分母
- [x] `BoardShape` ≥40 种可连通形状；关卡表 18 关均有完整 `boards`
- [x] 关卡通路每盘从 `StageTable.board_at` 取形状与雷数；对战仍用尺寸曲线
- [x] 通关条件 = 打完盘列表；悬浮牌显示派生目标盘数
- [x] `test_board_shape` / `test_stage_table` / `test_stage_run_flow` / `test_minesweeper_board` 通过

### 修改范围

- **允许**：`scripts/game/board_shape.gd`（新）、`minesweeper_board.gd`、`stage_table.gd`、`main.gd`、`stage_badge.gd`、相关 tests、docs
- **禁止**：对战规则核改异形、`scripts/net/**`

### 边界 & 不做

- ❌ 对战异形、双岛、六角邻接、程序化随机异形、局外成长、按主题改规则

## Implementation Log

### 2026-08-29

- 新建 `BoardShape`：55 个形状（rect / notch_* / hole_* / holes_*），ASCII/程序生成 + 连通断言
- `MinesweeperBoard`：`active_mask`、`is_active`、`active_cell_count`；邻接/布雷/道具/胜负只认可玩格
- `StageTable`：18 关全部填 `boards`；`target_round` 由 `boards.size()` 派生；`board_at` / `boards_of`
- `main.gd`：关卡通路表驱动；空洞格隐藏；行清/预览跳过空洞
- 测试：`test_board_shape.gd`；扩展 `test_stage_table.gd`

**验证**：`test_board_shape` / `test_stage_table` / `test_minesweeper_board` / `test_stage_run_flow` / `test_world_map` 通过。

## 结案总结 (Wrap-up)

- **技术结论**：异形 = 稠密包围盒 + active 掩码；关卡差异由盘列表配置，不再靠 `_run_number` 尺寸曲线（对战除外）。
- **对外接口**：
  - `BoardShape.get_shape` / `has_shape` / `is_mask_connected` / `max_mines_for`
  - `MinesweeperBoard.is_active` / `active_cell_count`；构造函数末参 `active_mask`
  - `StageTable.boards_of` / `board_at` / `target_round_of`；`stage()` 附带派生 `target_round`
- **术语**：盘面形状、可玩格、盘列表 → 🔒
- **模块**：BoardModel / WorldMap 数据层扩展；无新模块
