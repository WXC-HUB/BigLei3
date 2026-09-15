class_name GuidedTutorial
extends RefCounted
## 新手第一盘的强引导脚本：固定棋盘 + 固定步骤。
##
## 棋盘 5×4、三颗雷，布局写死，于是每一步指向的格子都是确定的：
##
##       x=0  1  2  3  4
##  y=0   ·   ·  ·  2  雷A
##  y=1   ·   ·  ·  2  雷B
##  y=2   ·   ·  1  2  2
##  y=3   ·   ·  1  雷C 1
##
## 步骤（玩家每一步只被允许做一件事）：
##  1. 左键翻开 (1,1) —— 连锁翻出左边整片空地，剩右边一小块没翻。
##  2. 看数字 (3,2)=2：周围 8 格里藏着 2 颗雷（下一步按钮）。
##  3. 「不小心」左键点雷 B (4,1) —— 爆炸、掉 1 点血。
##  4. 看血条：踩雷会损失生命（下一步按钮）。
##  5. 看数字 (2,3)=1：周围只剩 (3,3) 没翻开，那必定是雷 C —— 右键标记。
##  6. 看数字 (3,0)=2：雷 B 已炸掉、只剩 (4,0) 没翻开 —— 左键点数字自动标出雷 A，通关。
##
## 这里只放数据和纯判断，不碰任何节点；演出由 GuidedTutorialOverlay 负责，
## 编排（何时进下一步、拦截哪些点击）由 main.gd 的「强引导」段负责。

const WIDTH := 5
const HEIGHT := 4
## 雷 A(4,0)、雷 B(4,1)、雷 C(3,3)。
const MINES: Array[int] = [4, 9, 18]

const EMPHASIS_COLOR := "#d9482b"

enum Action { LEFT_CLICK, RIGHT_CLICK, NEXT }
## BOARD 圈 `spot` 里的格子；HEALTH 圈血条；BOARD_ALL 圈整个棋盘；ITEM 圈教学钉下的那张伙伴牌。
enum Focus { BOARD, HEALTH, BOARD_ALL, ITEM }

## 步骤表。`target` 是允许点击的格子（NEXT 步为 -1）；`spot` 是遮罩挖洞要圈住的格子；
## `interactive` 为 false 时洞只是看的，点进去也拦；小手只指 target（说明步没有小手），
## `pointer_side: "left"` 让手从左下方伸来、别盖住目标右下方要看的格子；`highlight` 里的
## 格子在这一步开始时闪几下边框。目标达成由 is_step_done 判。
const STEPS: Array[Dictionary] = [
	{
		"id": "reveal",
		"action": Action.LEFT_CLICK,
		"focus": Focus.BOARD,
		"target": 6,
		"spot": [6],
		"interactive": true,
		"hint": "左键",
		"text": "欢迎来到雷区！%s 这块草地，把它翻开看看。",
		"emphasis": ["左键点击"],
	},
	{
		"id": "numbers",
		"action": Action.NEXT,
		"focus": Focus.BOARD,
		"target": -1,
		"highlight": [13],
		"spot": [7, 8, 9, 12, 13, 14, 17, 18, 19],
		"interactive": false,
		"hint": "",
		"text": "翻开的%s表示：它周围 8 格里一共藏着几颗雷。中间这个 %s，说明它周围有 %s 颗雷。",
		"emphasis": ["数字", "2", "2"],
	},
	{
		"id": "hit_mine",
		"action": Action.LEFT_CLICK,
		"focus": Focus.BOARD,
		"target": 9,
		"spot": [7, 8, 9, 12, 13, 14, 17, 18, 19],
		"interactive": true,
		"hint": "左键",
		"text": "可到底是哪两格藏着雷呢？不确定的时候……先%s，翻开看看。",
		"emphasis": ["左键点击这一格"],
	},
	{
		"id": "damage",
		"action": Action.NEXT,
		"focus": Focus.HEALTH,
		"target": -1,
		"spot": [],
		"interactive": false,
		"hint": "",
		"text": "轰！踩到雷会%s。生命归零，这次冒险就结束了。不过炸掉的雷不再是威胁，还成了线索。",
		"emphasis": ["损失 1 点生命"],
	},
	{
		"id": "flag",
		"action": Action.RIGHT_CLICK,
		"focus": Focus.BOARD,
		"target": 18,
		"highlight": [17],
		"spot": [17, 18],
		"interactive": true,
		"hint": "右键",
		"text": "看这个 %s：它周围只剩%s没翻开，那一格必定是雷。%s它，插上旗子做标记。",
		"emphasis": ["1", "一格", "右键点击"],
	},
	{
		"id": "infer",
		"action": Action.LEFT_CLICK,
		"focus": Focus.BOARD,
		"target": 3,
		"pointer_side": "left",
		"highlight": [3],
		"spot": [3, 4, 9],
		"interactive": true,
		"hint": "左键",
		"text": "再看这个 %s：旁边已经炸掉 1 颗雷，只剩%s没翻开——它一定也是雷。%s，剩下的雷会自动被标出来！",
		"emphasis": ["2", "一格", "左键点击数字"],
	},
]


static func step_count() -> int:
	return STEPS.size()


static func step(index: int) -> Dictionary:
	if index < 0 or index >= STEPS.size():
		return {}
	return STEPS[index]


## 把 `text` 里的 %s 逐个换成强调色文字，产出 RichTextLabel 用的 bbcode。
static func step_bbcode(index: int) -> String:
	var entry := step(index)
	if entry.is_empty():
		return ""
	var pieces: Array = []
	for word in entry["emphasis"]:
		pieces.append("[color=%s]%s[/color]" % [EMPHASIS_COLOR, word])
	return String(entry["text"]) % pieces


## 这一步允不允许玩家在 `cell_index` 上按 `button_index`（MOUSE_BUTTON_LEFT/RIGHT）。
static func allows_click(index: int, cell_index: int, button_index: int) -> bool:
	var entry := step(index)
	if entry.is_empty():
		return false
	if cell_index != int(entry["target"]):
		return false
	match int(entry["action"]):
		Action.LEFT_CLICK:
			return button_index == MOUSE_BUTTON_LEFT
		Action.RIGHT_CLICK:
			return button_index == MOUSE_BUTTON_RIGHT
	return false


## 棋盘状态是否已经满足这一步的目标。NEXT 步靠按钮推进，这里永远返回 false。
static func is_step_done(index: int, board: MinesweeperBoard) -> bool:
	var entry := step(index)
	if entry.is_empty() or board == null:
		return false
	match String(entry["id"]):
		"reveal":
			return board.state_at(6) == MinesweeperBoard.CellState.REVEALED
		"hit_mine":
			return board.state_at(9) == MinesweeperBoard.CellState.REVEALED
		"flag":
			return board.state_at(18) == MinesweeperBoard.CellState.FLAGGED
		"infer":
			return board.state_at(4) == MinesweeperBoard.CellState.FLAGGED
	return false


## 校验写死的布局与步骤表互相吻合（测试用）：雷位、数字、每一步的目标格状态。
static func layout_matches(board: MinesweeperBoard) -> bool:
	if board == null or board.width != WIDTH or board.height != HEIGHT:
		return false
	if not board.mines_placed or board.mine_count != MINES.size():
		return false
	for index in range(WIDTH * HEIGHT):
		if board.has_mine(index) != MINES.has(index):
			return false
	return board.adjacent_mines(13) == 2 and board.adjacent_mines(17) == 1 and board.adjacent_mines(3) == 2
