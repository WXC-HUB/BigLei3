class_name BirdCatalog
extends RefCounted
## 鸟类图鉴总表：id、名字、外号、能力、解锁条件、待机帧。
##
## 图鉴页只按这张表铺卡片，「哪几只已经解锁」由 Main 喂进来——存档里那一排
## `*_unlocked` 布尔仍然是唯一真相，图鉴不自己记账。加一只鸟要动两处：往
## ENTRIES 里补一条，再去 `main.gd` 的 `_bird_unlock_states()` 把它的解锁位接上；
## 只加前者，那张卡会永远停在剪影状态。
##
## `frames` 就是栖枝预制体上那套 220×220 待机帧（见 BIRD_PREFAB_STANDARD.md），
## 卡片照 BirdPerch 的节奏循环播放，所以图鉴里的鸟和局内那只是同一只。
## `faces_right` 跟预制体的 `art_faces_right` 一个意思：乌鸦那套图朝左画，
## 图鉴里翻个面，一排鸟才会朝同一个方向。

const BLUE := "blue"
const NIGHT_HERON := "night_heron"
const REDSTART := "redstart"
const WOODPECKER := "woodpecker"
const KESTREL := "kestrel"
const TIT := "tit"
const MAGPIE := "magpie"
const CROW := "crow"
const DOVE := "dove"

## 顺序 = 解锁顺序 = 图鉴里的排列顺序。
const ENTRIES: Array[Dictionary] = [
	{
		"id": BLUE,
		"name": "点点小蓝鸟",
		"alias": "枝头哨兵 · 有没有它说了算",
		"ability": "你插上旗之后它飞过去确认：这一格到底有没有小雷。",
		"unlock": "开局就蹲在枝头",
		"faces_right": true,
		"frames": [
			preload("res://my_asset/birds/blue_idle_1.png"),
			preload("res://my_asset/birds/blue_idle_2.png"),
			preload("res://my_asset/birds/blue_idle_3.png"),
			preload("res://my_asset/birds/blue_idle_4.png"),
		],
	},
	{
		"id": NIGHT_HERON,
		"name": "夜鹭",
		"alias": "中华田园企鹅",
		"ability": "翻出它的牌就飞过来，随机照亮周围 1 个安全格并翻开。",
		"unlock": "打完教学第 1 关加入",
		"faces_right": true,
		"frames": [
			preload("res://my_asset/birds/black_idle_1.png"),
			preload("res://my_asset/birds/black_idle_2.png"),
			preload("res://my_asset/birds/black_idle_3.png"),
			preload("res://my_asset/birds/black_idle_4.png"),
		],
	},
	{
		"id": REDSTART,
		"name": "红尾水鸲",
		"alias": "宏伟水渠",
		"ability": "翻出它的牌就自动替你标出 1 颗雷。",
		"unlock": "打完教学第 2 关加入",
		"faces_right": true,
		"frames": [
			preload("res://my_asset/birds/red_idle_1.png"),
			preload("res://my_asset/birds/red_idle_2.png"),
			preload("res://my_asset/birds/red_idle_3.png"),
			preload("res://my_asset/birds/red_idle_4.png"),
		],
	},
	{
		"id": WOODPECKER,
		"name": "啄木鸟",
		"alias": "笃笃笃 · 专注轻机枪",
		"ability": "清理自己所在的整行或整列：安全格翻开，雷直接标出来。",
		"unlock": "打完教学第 3 关加入",
		"faces_right": true,
		"frames": [
			preload("res://my_asset/birds/attacker_idle_1.png"),
			preload("res://my_asset/birds/attacker_idle_2.png"),
			preload("res://my_asset/birds/attacker_idle_3.png"),
			preload("res://my_asset/birds/attacker_idle_4.png"),
		],
	},
	{
		"id": KESTREL,
		"name": "红隼",
		"alias": "阳台猛禽 斑鸠之友",
		"ability": "接下来 1 步无敌：踩中雷也不掉血。",
		"unlock": "打完教学第 4 关加入",
		"faces_right": true,
		"frames": [
			preload("res://my_asset/birds/eg_idle_1.png"),
			preload("res://my_asset/birds/eg_idle_2.png"),
		],
	},
	{
		"id": TIT,
		"name": "长尾山雀",
		"alias": "雪白团子 一坠千金",
		"ability": "下一次点击无敌：它摔到你选的格子上砸开周围 3×3，踩到的雷直接标出来。",
		"unlock": "打完教学第 5 关加入",
		"faces_right": true,
		"frames": [
			preload("res://my_asset/birds/tit_idle_1.png"),
			preload("res://my_asset/birds/tit_idle_2.png"),
			preload("res://my_asset/birds/tit_idle_3.png"),
			preload("res://my_asset/birds/tit_idle_4.png"),
		],
	},
	{
		"id": MAGPIE,
		"name": "灰喜鹊",
		"alias": "翘尾横行 一步一格",
		"ability": "每盘都有一组连携雷：标中其中任意一颗，它就把同组剩下的雷一并标出。",
		"unlock": "打完教学第 6 关加入",
		"faces_right": true,
		"frames": [
			preload("res://my_asset/birds/magpie_idle_1.png"),
			preload("res://my_asset/birds/magpie_idle_2.png"),
			preload("res://my_asset/birds/magpie_idle_3.png"),
			preload("res://my_asset/birds/magpie_idle_4.png"),
		],
	},
	{
		"id": CROW,
		"name": "小嘴乌鸦",
		"alias": "掀牌惯犯 · 薅毛现行犯",
		"ability": "飞去随机一格掀开偷看：那一格的内容亮 3 秒，但不会被翻开。",
		"unlock": "打完教学第 7 关加入",
		"faces_right": false,
		"frames": [
			preload("res://my_asset/birds/crow_idle_1.png"),
			preload("res://my_asset/birds/crow_idle_2.png"),
			preload("res://my_asset/birds/crow_idle_3.png"),
			preload("res://my_asset/birds/crow_idle_4.png"),
		],
	},
	{
		"id": DOVE,
		"name": "斑鸠",
		"alias": "窝搭得潦草 · 枝叼得认真",
		"ability": "叼一根树枝飞到血条边递过去，补回爱心，但不会超过生命上限。",
		"unlock": "打完教学最后一关加入",
		"faces_right": false,
		# 斑鸠的待机只用 1-3 帧，第 4 帧不要。
		"frames": [
			preload("res://my_asset/birds/dove_idle_1.png"),
			preload("res://my_asset/birds/dove_idle_2.png"),
			preload("res://my_asset/birds/dove_idle_3.png"),
		],
	},
]


static func count() -> int:
	return ENTRIES.size()


static func entry(bird_id: String) -> Dictionary:
	for data in ENTRIES:
		if String(data["id"]) == bird_id:
			return data
	return {}


static func ids() -> PackedStringArray:
	var result := PackedStringArray()
	for data in ENTRIES:
		result.append(String(data["id"]))
	return result
