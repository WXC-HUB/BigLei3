class_name GuidedItemLesson
extends RefCounted
## 新手第 2 盘（第一只鸟解锁后）的强引导脚本：认识伙伴牌。
##
## 棋盘照旧随机（4×4），但首次翻开的区域边缘必定钉着一张夜鹭牌
## （见 main.gd 的 _place_tutorial_night_heron_on_reveal_edge）。三步：
##  1. 左键翻开任意一格 —— 把夜鹭牌翻出来。
##  2. 牌翻出来、鸟还没起飞：圈住这张牌，讲「伙伴牌翻出即自动生效」，按「看它表演」放行演出。
##  3. 演出结束、棋盘回到可点：总结一句，按「查看伙伴图鉴」弹出全部伙伴的上图下文说明页。
##
## 步骤字段与 GuidedTutorial.STEPS 同构（Action / Focus 共用它的枚举），另加：
##  `target: ANY_CELL` 放行任意格子；`pointer_cell` 小手指向的示意格；
##  `next_text` 下一步按钮文案；`resume_on_board: true` 表示按下按钮后先收起引导层、
##  等棋盘回到可点状态再亮出下一步；`opens_guide: true` 表示按钮打开伙伴图鉴。
## 图鉴内容（ITEM_ENTRIES）也放在这里，ItemGuideScreen 只负责摆出来。

const ANY_CELL := -2
const EMPHASIS_COLOR := GuidedTutorial.EMPHASIS_COLOR

const STEPS: Array[Dictionary] = [
	{
		"id": "find_card",
		"action": GuidedTutorial.Action.LEFT_CLICK,
		"focus": GuidedTutorial.Focus.BOARD_ALL,
		"target": ANY_CELL,
		"pointer_cell": 5,
		"spot": [],
		"interactive": true,
		"hint": "左键",
		"text": "第一位伙伴 %s 加入了！它的牌就藏在这片草地里。%s任意一格，把它找出来。",
		"emphasis": ["夜鹭", "左键点击"],
	},
	{
		"id": "card_intro",
		"action": GuidedTutorial.Action.NEXT,
		"focus": GuidedTutorial.Focus.ITEM,
		"target": -1,
		"spot": [],
		"interactive": false,
		"hint": "",
		"text": "找到了！这就是 %s 的牌。伙伴的牌%s，不用你动手：夜鹭会飞过来，%s。",
		"emphasis": ["夜鹭", "翻出来就会自动生效", "随机照亮周围 1 个安全格"],
		"next_text": "看它表演  »",
		"resume_on_board": true,
	},
	{
		"id": "overview",
		"action": GuidedTutorial.Action.NEXT,
		"focus": GuidedTutorial.Focus.BOARD_ALL,
		"target": -1,
		"spot": [],
		"interactive": false,
		"hint": "",
		"text": "看到了吗？伙伴的牌会%s。往后每过一关都有新伙伴加入，先认识一下它们吧！",
		"emphasis": ["自动帮你一把"],
		"next_text": "查看伙伴图鉴  »",
		"opens_guide": true,
	},
]

## 伙伴图鉴：上图下文。顺序按解锁先后，最后是两件非鸟类道具。
## 「探测」只在自定义模式里配得出来，正常流程碰不到，图鉴不列。
const ITEM_ENTRIES: Array[Dictionary] = [
	{
		"type": MinesweeperBoard.ItemType.LANTERN,
		"name": "夜鹭",
		"texture": preload("res://assets/sprites/generated/bird_items/item_bird_lantern.png"),
		"text": "翻出后飞过来，%s并翻开。",
		"emphasis": ["随机照亮周围 1 个安全格"],
	},
	{
		"type": MinesweeperBoard.ItemType.COMPASS,
		"name": "红尾水鸲",
		"texture": preload("res://assets/sprites/generated/bird_items/item_bird_compass.png"),
		"text": "翻出后自动%s。",
		"emphasis": ["标出 1 颗雷"],
	},
	{
		"type": MinesweeperBoard.ItemType.ORBITAL_STRIKE,
		"name": "啄木鸟",
		"texture": preload("res://assets/sprites/generated/bird_items/item_bird_orbital.png"),
		"text": "清理所在的%s：翻开安全格、标出雷。",
		"emphasis": ["整行或整列"],
	},
	{
		"type": MinesweeperBoard.ItemType.SUPER_LUCK,
		"name": "红隼",
		"texture": preload("res://assets/sprites/generated/bird_items/item_bird_super_luck.png"),
		"text": "接下来 %s，踩到雷也不掉血。",
		"emphasis": ["1 步无敌"],
	},
	{
		"type": MinesweeperBoard.ItemType.CHAIN,
		"name": "灰喜鹊",
		"texture": preload("res://assets/sprites/generated/bird_items/item_bird_magpie.png"),
		"text": "每盘开局都有一组连携雷。%s，灰喜鹊就飞过来，把同组剩下的雷一并标出。",
		"emphasis": ["标中其中任意一颗"],
	},
	{
		"type": MinesweeperBoard.ItemType.ENLARGE,
		"name": "长尾山雀",
		"texture": preload("res://assets/sprites/generated/bird_items/item_bird_tit.png"),
		"text": "下一次点击无敌：它会摔到你选的格子上，%s，踩到的雷直接标出来。",
		"emphasis": ["砸开周围 3×3"],
	},
	{
		"type": MinesweeperBoard.ItemType.MEDICAL_KIT,
		"name": "疗愈鸟",
		"texture": preload("res://assets/sprites/generated/potion_heal_green.png"),
		"text": "%s，不超过生命上限。",
		"emphasis": ["恢复 1 颗爱心"],
	},
	{
		"type": MinesweeperBoard.ItemType.XRAY,
		"name": "透视",
		"texture": preload("res://assets/sprites/generated/item_treasure_map.png"),
		"text": "随机显示 %s 3 秒，不翻开。",
		"emphasis": ["1 格里的内容"],
	},
]


static func step_count() -> int:
	return STEPS.size()


static func step(index: int) -> Dictionary:
	if index < 0 or index >= STEPS.size():
		return {}
	return STEPS[index]


static func step_bbcode(index: int) -> String:
	return format_bbcode(step(index))


## 把条目 `text` 里的 %s 逐个换成强调色文字。步骤表和图鉴条目共用。
static func format_bbcode(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	var pieces: Array = []
	for word in entry.get("emphasis", []):
		pieces.append("[color=%s]%s[/color]" % [EMPHASIS_COLOR, word])
	return String(entry["text"]) % pieces


## 第一步放行任意格子的左键；说明步一律拦下。
static func allows_click(index: int, cell_index: int, button_index: int) -> bool:
	var entry := step(index)
	if entry.is_empty() or int(entry["action"]) != GuidedTutorial.Action.LEFT_CLICK:
		return false
	var target := int(entry["target"])
	if target != ANY_CELL and target != cell_index:
		return false
	return button_index == MOUSE_BUTTON_LEFT


## 第一步正常由 main.gd 在夜鹭牌翻出的那一刻推进（要在鸟起飞前停下来讲）；
## 这里只兜底：盘上已经没有藏着的夜鹭牌了（牌已生效或压根没发），前两步就都算完成，
## 直接跳到总结。说明步靠按钮，永远不算自动完成。
static func is_step_done(index: int, board: MinesweeperBoard) -> bool:
	var entry := step(index)
	if entry.is_empty() or board == null:
		return false
	match String(entry["id"]):
		"find_card", "card_intro":
			return _any_revealed(board) and board.hidden_item_count_of(MinesweeperBoard.ItemType.LANTERN) == 0
	return false


static func _any_revealed(board: MinesweeperBoard) -> bool:
	for index in range(board.width * board.height):
		if board.state_at(index) == MinesweeperBoard.CellState.REVEALED:
			return true
	return false
