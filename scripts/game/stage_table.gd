class_name StageTable
extends RefCounted
## 关卡表。单片连续地图上的 6 关；第 1 关含教程，其后每关手写盘列表。
## 解锁按关卡序号链式推进（打通上一关才开下一关）。
## 每关只用一族形状讲一种地形，不再从总阶梯切片。

const REGIONS := [
	{"id": "habitat", "name": "栖息地", "theme": "grass", "unlock_after": {}},
]

## 非教程关：第 2 关起 10 盘，之后每关 +1。
const NON_TUTORIAL_BOARD_BASE := 10

## 每关允许的形状前缀。测试用它锁主题，避免再混进下一关才该出现的伤。
const THEME_SHAPE_PREFIXES := {
	"grass_1": ["rect_"],
	"grass_2": ["notch_bite_", "notch_corner_", "notch_l_", "notch_u_", "notch_furrow_", "notch_ridge_"],
	"grass_3": ["hole_center_", "hole_lagoon_"],
	"river_1": ["notch_gate_", "notch_bridge_", "notch_bend_"],
	"river_2": ["hole_lagoon_", "holes_twin_"],
	"coast_1": ["notch_c_", "notch_u_", "notch_bite_", "hole_lagoon_", "holes_scatter_", "holes_reef_"],
}

const STAGES := [
	{
		"id": "grass_1", "order": 1, "name": "青草坡", "region": "habitat", "teaches": true,
		"boards": [
			{"shape": "rect_2x1", "mines": 1},
			{"shape": "rect_4", "mines": 3},
			{"shape": "rect_5", "mines": 4},
			{"shape": "rect_5", "mines": 4},
			{"shape": "rect_6", "mines": 6},
		],
	},
	{
		"id": "grass_2", "order": 2, "name": "麦垄", "region": "habitat",
		"boards": [
			{"shape": "notch_bite_7", "mines": 7},
			{"shape": "notch_corner_7", "mines": 8},
			{"shape": "notch_furrow_7", "mines": 8},
			{"shape": "notch_l_7", "mines": 8},
			{"shape": "notch_u_7", "mines": 9},
			{"shape": "notch_ridge_8", "mines": 10},
			{"shape": "notch_furrow_8", "mines": 10},
			{"shape": "notch_bite_8", "mines": 11},
			{"shape": "notch_l_8", "mines": 12},
			{"shape": "notch_furrow_8", "mines": 13},
		],
	},
	{
		"id": "grass_3", "order": 3, "name": "老井村", "region": "habitat",
		"boards": [
			{"shape": "hole_center_7", "mines": 8},
			{"shape": "hole_center_7", "mines": 9},
			{"shape": "hole_center_7", "mines": 9},
			{"shape": "hole_center_8", "mines": 10},
			{"shape": "hole_center_8", "mines": 11},
			{"shape": "hole_lagoon_8", "mines": 11},
			{"shape": "hole_lagoon_8", "mines": 12},
			{"shape": "hole_center_9", "mines": 12},
			{"shape": "hole_lagoon_9", "mines": 13},
			{"shape": "hole_lagoon_9", "mines": 14},
			{"shape": "hole_lagoon_9", "mines": 15},
		],
	},
	{
		"id": "river_1", "order": 4, "name": "双桥", "region": "habitat",
		"boards": [
			{"shape": "notch_gate_7", "mines": 8},
			{"shape": "notch_gate_7", "mines": 9},
			{"shape": "notch_bridge_8", "mines": 10},
			{"shape": "notch_gate_8", "mines": 10},
			{"shape": "notch_bend_8", "mines": 11},
			{"shape": "notch_bridge_8", "mines": 11},
			{"shape": "notch_bend_8", "mines": 12},
			{"shape": "notch_bridge_9", "mines": 12},
			{"shape": "notch_bend_9", "mines": 13},
			{"shape": "notch_gate_9", "mines": 14},
			{"shape": "notch_bridge_9", "mines": 15},
			{"shape": "notch_bridge_10", "mines": 16},
		],
	},
	{
		"id": "river_2", "order": 5, "name": "深潭", "region": "habitat",
		"boards": [
			{"shape": "hole_lagoon_8", "mines": 11},
			{"shape": "hole_lagoon_8", "mines": 12},
			{"shape": "hole_lagoon_8", "mines": 12},
			{"shape": "hole_lagoon_9", "mines": 13},
			{"shape": "hole_lagoon_9", "mines": 14},
			{"shape": "hole_lagoon_9", "mines": 14},
			{"shape": "holes_twin_9", "mines": 14},
			{"shape": "holes_twin_9", "mines": 15},
			{"shape": "holes_twin_9", "mines": 15},
			{"shape": "holes_twin_10", "mines": 16},
			{"shape": "holes_twin_10", "mines": 17},
			{"shape": "holes_twin_10", "mines": 17},
			{"shape": "holes_twin_10", "mines": 18},
		],
	},
	{
		"id": "coast_1", "order": 6, "name": "尽头港", "region": "habitat",
		"boards": [
			{"shape": "notch_c_9", "mines": 13},
			{"shape": "notch_u_9", "mines": 13},
			{"shape": "notch_bite_9", "mines": 14},
			{"shape": "notch_c_9", "mines": 14},
			{"shape": "hole_lagoon_9", "mines": 15},
			{"shape": "hole_lagoon_9", "mines": 15},
			{"shape": "notch_c_10", "mines": 16},
			{"shape": "hole_lagoon_10", "mines": 17},
			{"shape": "hole_lagoon_10", "mines": 18},
			{"shape": "holes_scatter_10", "mines": 18},
			{"shape": "holes_reef_10", "mines": 19},
			{"shape": "holes_scatter_10", "mines": 20},
			{"shape": "holes_reef_10", "mines": 20},
			{"shape": "holes_reef_10", "mines": 21},
		],
	},
]


static func all_stages() -> Array:
	return STAGES


static func all_regions() -> Array:
	return REGIONS


static func stage(stage_id: String) -> Dictionary:
	for entry in STAGES:
		if String(entry["id"]) == stage_id:
			var out: Dictionary = entry.duplicate(true)
			out["boards"] = boards_of(stage_id)
			out["target_round"] = out["boards"].size()
			return out
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


static func theme_of(stage_id: String) -> String:
	var entry := stage(stage_id)
	if entry.is_empty():
		return ""
	return String(region(String(entry["region"])).get("theme", ""))


static func boards_of(stage_id: String) -> Array:
	for entry in STAGES:
		if String(entry["id"]) == stage_id:
			return entry.get("boards", [])
	return []


static func shape_fits_theme(stage_id: String, shape_id: String) -> bool:
	if not THEME_SHAPE_PREFIXES.has(stage_id):
		return false
	for prefix in THEME_SHAPE_PREFIXES[stage_id]:
		if shape_id.begins_with(String(prefix)):
			return true
	return false


static func board_at(stage_id: String, round_index: int) -> Dictionary:
	var boards := boards_of(stage_id)
	if round_index < 1 or round_index > boards.size():
		return {}
	return boards[round_index - 1]


static func target_round_of(stage_id: String) -> int:
	return boards_of(stage_id).size()


## 非教程关应有的盘数：第 2 关 10，之后每关 +1。
static func expected_board_count_for_order(order: int) -> int:
	if order <= 1:
		return 0
	return NON_TUTORIAL_BOARD_BASE + (order - 2)


static func cleared_count_in_region(region_id: String, cleared: Array) -> int:
	var total := 0
	for entry in stages_in_region(region_id):
		if cleared.has(String(entry["id"])):
			total += 1
	return total


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


## 关卡解锁：所属区已开，且上一序号关已通关（第 1 关无前置）。
static func is_stage_unlocked(stage_id: String, cleared: Array) -> bool:
	var entry := stage(stage_id)
	if entry.is_empty():
		return false
	if not is_region_unlocked(String(entry["region"]), cleared):
		return false
	var order := int(entry["order"])
	if order <= 1:
		return true
	for previous in STAGES:
		if int(previous["order"]) == order - 1:
			return cleared.has(String(previous["id"]))
	return false


static func region_progress(region_id: String, cleared: Array) -> Dictionary:
	var stage_list := stages_in_region(region_id)
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
		"total": stage_list.size(),
		"next_region": next_id,
		"next_region_name": String(region(next_id).get("name", "")) if next_id != "" else "",
		"remaining_for_next": remaining,
	}


static func first_open_stage(cleared: Array) -> String:
	for entry in STAGES:
		var id := String(entry["id"])
		if not cleared.has(id) and is_stage_unlocked(id, cleared):
			return id
	return String(STAGES[STAGES.size() - 1]["id"])
