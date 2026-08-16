class_name AchievementCatalog
extends RefCounted
## 成就总表：id、名称、描述、图标。成就页按这张表铺列表，Main 按这张表弹提示，
## 加成就只需要往 ENTRIES 里加一条，两边都会自动跟上。

const OPEN_ACHIEVEMENTS := "open_achievements"
const START_GAME := "start_game"
const NIGHT_MASTER_FISH := "night_master_fish"
const WOODPECKER_SCREEN_BREAK := "woodpecker_screen_break"
const HERON_YOROSHIKU := "heron_yoroshiku"
const REDSTART_AQUEDUCT := "redstart_aqueduct"
const KESTREL_PIGEON_RAIN := "kestrel_pigeon_rain"
const KESTREL_STUFFED := "kestrel_stuffed"

## 顺序就是成就页里的排列顺序。
const ENTRIES: Array[Dictionary] = [
	{
		"id": OPEN_ACHIEVEMENTS,
		"title": "让我看看！",
		"description": "翻开这一页，看看自己都干过些什么",
		"icon": preload("res://assets/sprites/generated/reward_star.png"),
	},
	{
		"id": START_GAME,
		"title": "开始一局游戏",
		"description": "总之我觉得我应该加个成啾",
		"icon": preload("res://assets/sprites/generated/achievements/achievement_start_game.png"),
	},
	{
		"id": NIGHT_MASTER_FISH,
		"title": "想你的夜",
		"description": "让夜师傅收下一条无处可投的鱼",
		"icon": preload("res://assets/sprites/generated/achievements/night_master_fish_icon.tres"),
	},
	{
		"id": WOODPECKER_SCREEN_BREAK,
		"title": "专注轻机枪",
		"description": "笃笃笃笃笃笃笃笃笃笃笃笃笃笃",
		"icon": preload("res://my_asset/birds/attacker_idle_1.png"),
	},
	{
		"id": HERON_YOROSHIKU,
		"title": "夜 鹭 死 苦",
		"description": "ko no 夜 鹭 ………………",
		"icon": preload("res://my_asset/birds/black_idle_1.png"),
	},
	{
		"id": REDSTART_AQUEDUCT,
		"title": "宏伟水渠",
		"description": "武魂真身！！！！！！",
		"icon": preload("res://my_asset/shuiqu.png"),
	},
	{
		"id": KESTREL_PIGEON_RAIN,
		"title": "阳台主人",
		"description": "这是什么，吃一下。这是什么，吃一下。这是什么，吃一下。",
		"icon": preload("res://my_asset/birds/pigeons/pigeon_blue_gray.png"),
	},
	{
		"id": KESTREL_STUFFED,
		"title": "鸽 ？嗝~",
		"description": "嗝~~~~~~~~~~~~~~~~",
		"icon": preload("res://my_asset/birds/eg_idle_1.png"),
	},
]


static func entry(achievement_id: String) -> Dictionary:
	for candidate in ENTRIES:
		if candidate["id"] == achievement_id:
			return candidate
	return {}


static func has(achievement_id: String) -> bool:
	return not entry(achievement_id).is_empty()
