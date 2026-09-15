class_name StageTable
extends RefCounted
## 关卡表。单片连续地图上的 7 关；第 1 关含教程，第 2～6 关每关手写盘列表，
## 第 7 关「无尽远海」没有盘列表：每盘由 `endless_board()` 按盘序现生成，越打越难、没有终点。
## 解锁按关卡序号链式推进（打通上一关才开下一关）。
## 每关只用一族形状讲一种地形，不再从总阶梯切片；无尽关把全部形状族都放进抽签池。

const REGIONS := [
	{"id": "habitat", "name": "栖息地", "theme": "grass", "unlock_after": {}},
]

## 非教程关：第 2 关起 10 盘，之后每关 +1。
const NON_TUTORIAL_BOARD_BASE := 10

## --- 无尽关（第 7 关）---
## 无尽关的 id。它没有目标盘数（`target_round` 派生为 0），`_stage_complete()` 永不成立，
## 只有血量归零才收场；成绩看「最远打到第几盘」与本局累计分。
const ENDLESS_STAGE_ID := "endless"
## 难度曲线：每 ENDLESS_ROUNDS_PER_SIZE 盘盘面放大一号（7 → 10 封顶）；雷密度（占可玩格）
## 每盘 +ENDLESS_DENSITY_STEP，从 ENDLESS_START_DENSITY 爬到 ENDLESS_MAX_DENSITY 封顶。
## 对照：第 2 关开局约 0.155、第 6 关收尾约 0.25；经典专家局 99/480 ≈ 0.206。
const ENDLESS_START_SIZE := 7
const ENDLESS_MAX_SIZE := 10
const ENDLESS_ROUNDS_PER_SIZE := 3
const ENDLESS_START_DENSITY := 0.13
const ENDLESS_DENSITY_STEP := 0.008
const ENDLESS_MAX_DENSITY := 0.28
const ENDLESS_MIN_MINES := 4

## 每关允许的形状前缀。测试用它锁主题，避免再混进下一关才该出现的伤。
const THEME_SHAPE_PREFIXES := {
	"grass_1": ["rect_"],
	"grass_2": ["notch_bite_", "notch_corner_", "notch_l_", "notch_u_", "notch_furrow_", "notch_ridge_"],
	"grass_3": ["hole_center_", "hole_lagoon_"],
	"river_1": ["notch_gate_", "notch_bridge_", "notch_bend_"],
	"river_2": ["hole_lagoon_", "holes_twin_"],
	"coast_1": ["notch_c_", "notch_u_", "notch_bite_", "hole_lagoon_", "holes_scatter_", "holes_reef_"],
	## 无尽关：全部形状族都进抽签池，靠尺寸与雷密度而不是形状讲难度。
	"endless": ["rect_", "notch_", "hole_", "holes_"],
}

const STAGES := [
	{
		"id": "grass_1", "order": 1, "name": "青草坡", "region": "habitat", "teaches": true,
		"boards": [
			## 第一盘是强引导：形状与雷数必须跟 GuidedTutorial 的写死布局一致。
			{"shape": "rect_5x4", "mines": 3},
			{"shape": "rect_4", "mines": 3},
			{"shape": "rect_5", "mines": 4},
			{"shape": "rect_5", "mines": 4},
			{"shape": "rect_6", "mines": 6},
			{"shape": "rect_6", "mines": 6},
			{"shape": "rect_6", "mines": 6},
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
	{
		## 第 7 关 · 无尽：没有手写盘列表，每盘由 endless_board(round, seed) 现抽形状、按曲线配雷；
		## target_round 派生为 0，`_stage_complete()` 永不成立，只有血量归零才收场。
		"id": ENDLESS_STAGE_ID, "order": 7, "name": "无尽远海", "region": "habitat", "endless": true,
		"boards": [],
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


## 教学关不进排行榜。那 8 盘是写死的固定布局、还带着强引导，用时几乎只反映「读没读
## 提示」，跟别人的分没有可比性；榜上排出来的是谁跳得快，不是谁排得好。
static func has_leaderboard(stage_id: String) -> bool:
	var entry := stage(stage_id)
	return not entry.is_empty() and not bool(entry.get("teaches", false))


## 上榜关卡，按关卡序。榜页的分页与「全部排行榜」的落点都走这一份。
static func leaderboard_stages() -> Array:
	var out := []
	for entry in STAGES:
		if not bool(entry.get("teaches", false)):
			out.append(entry)
	return out


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


## 某关第 round_index 盘的形状与雷数。无尽关没有盘列表，按盘序与种子现生成；
## `level_seed` 只对无尽关有意义（同一局里同一盘抽到同一个形状），其他关忽略。
static func board_at(stage_id: String, round_index: int, level_seed: int = 0) -> Dictionary:
	if is_endless(stage_id):
		return endless_board(round_index, level_seed)
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


# --- 无尽关 ---


static func is_endless(stage_id: String) -> bool:
	for entry in STAGES:
		if String(entry["id"]) == stage_id:
			return bool(entry.get("endless", false))
	return false


## 无尽关第 round_index 盘的盘面边长：每 ENDLESS_ROUNDS_PER_SIZE 盘放大一号，到上限封顶。
static func endless_size_for(round_index: int) -> int:
	var steps := maxi(round_index - 1, 0) / ENDLESS_ROUNDS_PER_SIZE
	return mini(ENDLESS_START_SIZE + steps, ENDLESS_MAX_SIZE)


## 无尽关第 round_index 盘的目标雷密度（占可玩格的比例），线性爬升到上限封顶。
static func endless_density_for(round_index: int) -> float:
	var climbed := ENDLESS_START_DENSITY + ENDLESS_DENSITY_STEP * float(maxi(round_index - 1, 0))
	return minf(climbed, ENDLESS_MAX_DENSITY)


## 0～1 的难度进度：雷密度封顶时为 1。给进度横幅画「越打越难」的条。
static func endless_difficulty_fraction(round_index: int) -> float:
	var span := ENDLESS_MAX_DENSITY - ENDLESS_START_DENSITY
	if span <= 0.0:
		return 1.0
	return clampf((endless_density_for(round_index) - ENDLESS_START_DENSITY) / span, 0.0, 1.0)


## 边长为 size 的全部形状（rect / notch / hole / holes 各族都在），按 id 排序保证抽签可复现。
static func endless_shape_pool(size: int) -> PackedStringArray:
	var pool := PackedStringArray()
	var suffix := "_%d" % size
	for shape_id in BoardShape.all_ids():
		var id := String(shape_id)
		if id.ends_with(suffix) and shape_fits_theme(ENDLESS_STAGE_ID, id):
			pool.append(id)
	return pool


## 无尽关第 round_index 盘：从当前尺寸的形状池里按 (level_seed, 盘序) 抽一个，
## 雷数 = 可玩格 × 密度，夹在 ENDLESS_MIN_MINES 与该形状的雷上限之间。
## 同一种子同一盘永远抽到同一个结果，所以一局之内可复现、不同局之间形状会换。
static func endless_board(round_index: int, level_seed: int = 0) -> Dictionary:
	var round_number := maxi(round_index, 1)
	var size := endless_size_for(round_number)
	var pool := endless_shape_pool(size)
	assert(not pool.is_empty(), "形状库里没有边长 %d 的形状" % size)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([level_seed, round_number])
	var shape_id := String(pool[rng.randi_range(0, pool.size() - 1)])
	var density := endless_density_for(round_number)
	var active := BoardShape.active_count_of(shape_id)
	var mines := clampi(roundi(float(active) * density), ENDLESS_MIN_MINES, BoardShape.max_mines_for(shape_id))
	return {"shape": shape_id, "mines": mines, "size": size, "density": density}


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
	# 无尽关没有「通关」，不计入总数，否则读数永远停在 6 / 7。
	var clearable := 0
	for entry in stage_list:
		if not bool(entry.get("endless", false)):
			clearable += 1
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
		"total": clearable,
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
