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
const MAP_HEALTH_CHECK := "map_health_check"
const MAP_PIGEON_BUFFET := "map_pigeon_buffet"
const MAP_GET_DAZE := "map_get_daze"
const MAP_HERON_BREAD := "map_heron_bread"
const MAP_MOSQUITO_TRIO := "map_mosquito_trio"
const MAP_FUR_HARVEST := "map_fur_harvest"
const TIT_TANGYUAN := "tit_tangyuan"
const MAGPIE_SENPAI := "magpie_senpai"
const CROW_CHASED_BY_PANDA := "crow_chased_by_panda"
const DOVE_SNATCHED := "dove_snatched"

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
	{
		"id": MAP_HEALTH_CHECK,
		"title": "健康检查",
		"description": "关卡选择界面，啄掉3棵树",
		"icon": preload("res://my_asset/birds/attacker_zhuo.png"),
	},
	{
		"id": MAP_PIGEON_BUFFET,
		"title": "美味自助",
		"description": "关卡选择界面，吃掉3只鸽子",
		"icon": preload("res://my_asset/birds/pigeons/pigeon_russet.png"),
	},
	{
		"id": MAP_GET_DAZE,
		"title": "Get Daze！",
		"description": "关卡选择界面，完成一次成功对焦",
		"icon": preload("res://my_asset/birds/red_idle_1.png"),
	},
	{
		"id": MAP_HERON_BREAD,
		"title": "我的了！",
		"description": "关卡选择界面，被夜鹭吃掉5块面包",
		"icon": preload("res://my_asset/birds/black_idle_2.png"),
	},
	{
		"id": MAP_MOSQUITO_TRIO,
		"title": "三振出局",
		"description": "关卡选择界面，一口气拍死 3 只蚊子",
		"icon": preload("res://assets/sprites/generated/mosquito/mosquito_icon.png"),
	},
	{
		"id": MAP_FUR_HARVEST,
		"title": "薅遍四野",
		"description": "关卡选择界面，薅到 3 种动物的毛",
		"icon": preload("res://my_asset/crow_fur_tuft.png"),
	},
	{
		"id": TIT_TANGYUAN,
		"title": "一碗汤圆",
		"description": "长尾山雀解锁页，把一群团子撩成一碗汤圆",
		"icon": preload("res://my_asset/tangyuan_bowl.png"),
	},
	{
		"id": MAGPIE_SENPAI,
		"title": "幻视学姐",
		"description": "灰喜鹊解锁页，撩到虚焦、戴上眼镜之后看见的不是鸟",
		"icon": preload("res://my_asset/magpie_glasses_icon.png"),
	},
	{
		"id": CROW_CHASED_BY_PANDA,
		"title": "薅到熊猫头上",
		"description": "小嘴乌鸦解锁页，一路薅到熊猫，被追着满屏幕跑",
		"icon": preload("res://my_asset/crow_fur_icon.png"),
	},
	{
		"id": DOVE_SNATCHED,
		"title": "好吃",
		"description": "斑鸠解锁页，窝还没搭利索就被红隼叼走了",
		"icon": preload("res://my_asset/dove_nest_icon.png"),
	},
]


static func entry(achievement_id: String) -> Dictionary:
	for candidate in ENTRIES:
		if candidate["id"] == achievement_id:
			return candidate
	return {}


static func has(achievement_id: String) -> bool:
	return not entry(achievement_id).is_empty()
