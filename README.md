# Minesweeper Roguelite

Godot 4 的扫雷肉鸽项目基础工程，首发平台为 Web。

## 打开与运行

1. 使用 Godot 4.3 或更高版本导入 `project.godot`。
2. 运行主场景验证自适应 UI 壳。
3. 在 Project → Export 选择 **Web** 预设，导出至 `build/web/index.html`。

## 当前玩法

- **世界地图选关**：标题页点「开始」进入林间土路选关图；6 关沿路摆放（打通上一关才开下一关）。第 1 关含教程；其余关卡按盘列表推进。对战仍为正方形盘面。
- 10 × 8 棋盘，共 12 枚地雷。
- 左键翻开地格，右键插旗或撤旗。
- 首次翻开的地格及其周围八格不会布雷。
- 空白地格会自动连锁展开；翻开全部安全地格即获胜。
- 每局包含 3 盏灯和 3 个罗盘：灯揭示周围 3 × 3 区域并自动标雷，罗盘随机寻找一个尚未揭开的安全格。
- 同一次翻格发现多个道具时，道具按照格子顺序逐一结算；道具造成的新发现会继续加入结算队列。
- 地格采用泥坑底、内侧阴影、内容、接触阴影、前景泥块和草皮盖板的分层结构；翻格包含草皮掀飞、内容弹出、碎草、泥块与扬尘效果。
- 鼠标光标是自定义圆点，附带暖金拖尾和点击涟漪（左键金色、右键青色）；特效全部程序化绘制，鼠标停下后自动休眠。
- 失败或胜利后可通过“重新布置雷区”开始新局。

棋盘规则位于 `scripts/game/minesweeper_board.gd`，显示与交互分别位于 `scripts/main.gd` 和 `scripts/ui/mine_cell.gd`。
世界地图位于 `scripts/ui/world_map.gd` 与 `scenes/world_map.tscn`（布局是可在编辑器里手改的美术资产，初稿由 `tools/build_world_map.gd` 生成一次），关卡数据在 `scripts/game/stage_table.gd`，盘面形状库在 `scripts/game/board_shape.gd`。

## 第三方素材

- **KayKit Medieval Hexagon Pack 1.0 (FREE)** — 作者 Kay Lousberg（[kaylousberg.com](https://www.kaylousberg.com)），许可 **CC0 / Creative Commons Zero**，个人、教育与商业用途均免费，署名非强制。早期平面六边地图素材在 `assets/hexmap/`。许可原文见 `assets/hexmap/LICENSE-KayKit.txt`。
- **KayKit Medieval Builder Pack 1.0 (FREE)** — 同一作者，同样 **CC0**。备用六边地格与建筑在 `assets/builder/`。许可原文见 `assets/builder/LICENSE-KayKit.txt`。
- **Stylized Nature MegaKit (Standard)** — 作者 Quaternius（[quaternius.com](https://quaternius.com)），许可 **CC0**。选关图林间树、草、花、石在 `assets/nature/`。许可原文见 `assets/nature/LICENSE-Quaternius.txt`。

详细工程与体验约束见 [docs/PROJECT_CONSTRAINTS.md](docs/PROJECT_CONSTRAINTS.md)。
