# Features 索引

鸟类扫雷肉鸽 的 Feature 工作流索引。

**主管线**：`/wxc-mini:start` → `/wxc-mini:discuss` →（需UI则）`/wxc-mini:wireframe` → `/wxc-mini:spec` → `/wxc-mini:do-it` →（推荐）`/wxc-mini:verify` → `/wxc-mini:that-is-all`
**旁路**：`/wxc-mini:quick`（小改，不开 FEAT，留痕于 [QUICK_LOG.md](QUICK_LOG.md)）
**导航**：模块库 & 术语库见 [NAVIGATION.md](NAVIGATION.md)；随时 `/wxc-mini:term-list` 只读查看。
**巡览**：`/wxc-mini:list-feature`（全部 FEAT 状态鸟瞰）· `/wxc-mini:what-now`（当前 FEAT 位置 + 下一步）。

状态图例：🟡 草创 · 🟢 讨论完 · 🔵 已 spec · 🚧 开发中 · 🟣 待收尾 · ✅ 完成 · ❌ 取消

> 🟣 待收尾 = do-it 已把代码落地并写完 Implementation Log，但尚未 that-is-all 收束技术结论/对外接口/模块归档/术语锁定。**必须** that-is-all 才算 ✅ 完成。
> "需独立 UI 设计 = 是" 的 feature，discuss 之后、spec 之前须插入 `/wxc-mini:wireframe` 阶段。

## 进行中

| ID | Feature 名 | 归属模块 | 状态 | 起 | 止 |
|---|---|---|---|---|---|
| [FEAT-001](features/FEAT-001-pvp-duel-core.md) | pvp-duel-core | Netplay | 🟣 待收尾 | 2026-08-24 | - |
| [FEAT-002](features/FEAT-002-level-select-hexmap.md) | level-select-hexmap | WorldMap | 🟣 待收尾 | 2026-08-24 | - |
| [FEAT-003](features/FEAT-003-duel-split-screen-fog.md) | duel-split-screen-fog | SplitScreen | 🟣 待收尾 | 2026-08-25 | - |
| [FEAT-005](features/FEAT-005-stage-cabinet.md) | stage-cabinet | WorldMap | 🟣 待收尾 | 2026-09-11 | - |

## 已完成

| ID | Feature 名 | 归属模块 | 状态 | 起 | 止 |
|---|---|---|---|---|---|
| [FEAT-004](features/FEAT-004-shaped-stage-boards.md) | shaped-stage-boards | BoardModel | ✅ 完成 | 2026-08-29 | 2026-08-29 |