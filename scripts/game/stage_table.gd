class_name StageTable
extends RefCounted
## 关卡表（Stage Table）——与场景摆放分离的关卡数据。
##
## `world_map.tscn` 里的每个 StageMarker 只挂一个 `stage_id`，名字、目标盘数、所属
## 地形区、解锁关系全部到这里查。这样"地格摆在哪"是美术资产、"这一关多长"是可以
## headless 测试的数据，两件事互不牵连。
##
## 本表只有两个可调变量（FEAT-002 共识 1）：**目标盘数**与**地形主题**。棋盘尺寸、
## 雷密度、起始血金一律不进这张表——每关起跑线完全相同，长度是唯一的难度旋钮。

## 地形区：一个区一个视觉主题，成组解锁。
## `unlock_after` 为空 = 开局即可进；否则要求先在指定区通关 `count` 关。
const REGIONS := [
	{
		"id": "grass",
		"name": "青草区",
		"theme": "grass",
		"unlock_after": {},
	},
	{
		"id": "river",
		"name": "河谷区",
		"theme": "river",
		"unlock_after": {"region": "grass", "count": 4},
	},
	{
		"id": "coast",
		"name": "海岸区",
		"theme": "coast",
		"unlock_after": {"region": "river", "count": 4},
	},
]

## 关卡：`order` 是给玩家看的序号，`target_round` 是[[目标盘数]]。
## `teaches` 只有第一关是 true——那 4 盘硬编码教程盘连着 4 段解锁演出，只在这里出现
## 一次；其余关卡跳过教程段，改由 `main.gd` 直接补发教程的产出。
const STAGES := [
	{"id": "grass_1", "order": 1, "name": "青草坡", "region": "grass", "target_round": 5, "teaches": true},
	{"id": "grass_2", "order": 2, "name": "麦垄", "region": "grass", "target_round": 6},
	{"id": "grass_3", "order": 3, "name": "风车丘", "region": "grass", "target_round": 6},
	{"id": "grass_4", "order": 4, "name": "石篱地", "region": "grass", "target_round": 7},
	{"id": "grass_5", "order": 5, "name": "老井村", "region": "grass", "target_round": 7},
	{"id": "grass_6", "order": 6, "name": "草原关隘", "region": "grass", "target_round": 8},
	{"id": "river_1", "order": 7, "name": "浅滩", "region": "river", "target_round": 8},
	{"id": "river_2", "order": 8, "name": "双桥", "region": "river", "target_round": 9},
	{"id": "river_3", "order": 9, "name": "磨坊湾", "region": "river", "target_round": 9},
	{"id": "river_4", "order": 10, "name": "河曲", "region": "river", "target_round": 10},
	{"id": "river_5", "order": 11, "name": "深潭", "region": "river", "target_round": 10},
	{"id": "river_6", "order": 12, "name": "谷口渡", "region": "river", "target_round": 11},
	{"id": "coast_1", "order": 13, "name": "白沙岸", "region": "coast", "target_round": 11},
	{"id": "coast_2", "order": 14, "name": "礁石滩", "region": "coast", "target_round": 12},
	{"id": "coast_3", "order": 15, "name": "灯塔角", "region": "coast", "target_round": 12},
	{"id": "coast_4", "order": 16, "name": "潮汐洼", "region": "coast", "target_round": 13},
	{"id": "coast_5", "order": 17, "name": "断崖", "region": "coast", "target_round": 14},
	{"id": "coast_6", "order": 18, "name": "尽头港", "region": "coast", "target_round": 15},
]


static func all_stages() -> Array:
	return STAGES


static func all_regions() -> Array:
	return REGIONS


## 查不到返回空字典——调用方一律用 `is_empty()` 判，不抛异常。
static func stage(stage_id: String) -> Dictionary:
	for entry in STAGES:
		if String(entry["id"]) == stage_id:
			return entry
	return {}


static func region(region_id: String) -> Dictionary:
	for entry in REGIONS:
		if String(entry["id"]) == region_id:
			return entry
	return {}


static func has_stage(stage_id: String) -> bool:
	return not stage(stage_id).is_empty()


static func stages_in_region(region_id: String) -> Array:
	var out := []
	for entry in STAGES:
		if String(entry["region"]) == region_id:
			out.append(entry)
	return out


## 该关的地形主题，直接取所属区的。关卡自己不带主题字段——一个区一个主题是共识 2 的
## 前提，让关卡也能各带一个主题就会出现"区里混着两种地格"的破图。
static func theme_of(stage_id: String) -> String:
	var entry := stage(stage_id)
	if entry.is_empty():
		return ""
	return String(region(String(entry["region"])).get("theme", ""))


static func cleared_count_in_region(region_id: String, cleared: Array) -> int:
	var total := 0
	for entry in stages_in_region(region_id):
		if cleared.has(String(entry["id"])):
			total += 1
	return total


## 地形区解锁：没有 `unlock_after` 就是开局可进；否则看前置区通关数够不够。
## 只回溯一层——REGIONS 是线性链，`test_stage_table.gd` 会断言这条链无断点。
static func is_region_unlocked(region_id: String, cleared: Array) -> bool:
	var entry := region(region_id)
	if entry.is_empty():
		return false
	var gate: Dictionary = entry.get("unlock_after", {})
	if gate.is_empty():
		return true
	var previous := String(gate.get("region", ""))
	if not is_region_unlocked(previous, cleared):
		return false
	return cleared_count_in_region(previous, cleared) >= int(gate.get("count", 0))


## 关卡解锁 = 它所在的区解锁。区内全开可任选（共识 2），所以关卡自己没有额外门槛。
static func is_stage_unlocked(stage_id: String, cleared: Array) -> bool:
	var entry := stage(stage_id)
	if entry.is_empty():
		return false
	return is_region_unlocked(String(entry["region"]), cleared)


## 顶栏那行进度文字要的三个数：本区已通关、本区总数、下一区还差几关。
## `next_region` 为空串 = 已经是最后一区。
static func region_progress(region_id: String, cleared: Array) -> Dictionary:
	var stages := stages_in_region(region_id)
	var done := cleared_count_in_region(region_id, cleared)
	var next_id := ""
	var remaining := 0
	for entry in REGIONS:
		var gate: Dictionary = entry.get("unlock_after", {})
		if String(gate.get("region", "")) == region_id:
			next_id = String(entry["id"])
			remaining = maxi(int(gate.get("count", 0)) - done, 0)
			break
	return {
		"cleared": done,
		"total": stages.size(),
		"next_region": next_id,
		"next_region_name": String(region(next_id).get("name", "")) if next_id != "" else "",
		"remaining_for_next": remaining,
	}


## 第一个还没通关的已解锁关卡，用来决定地图初次显示时相机对准哪里。
## 全通关了就退回最后一关。
static func first_open_stage(cleared: Array) -> String:
	for entry in STAGES:
		var id := String(entry["id"])
		if not cleared.has(id) and is_stage_unlocked(id, cleared):
			return id
	return String(STAGES[STAGES.size() - 1]["id"])
