class_name MinesweeperBoard
extends RefCounted

enum CellState { COVERED, REVEALED, FLAGGED }
enum ItemType {
	NONE,
	LANTERN,
	COMPASS,
	ORBITAL_STRIKE,
	SUPER_LUCK,
	MEDICAL_KIT,
	XRAY,
	CHAIN,
	ENLARGE,
	DETECT,
}

var width: int
var height: int
var mine_count: int
var lantern_count: int
var compass_count: int
var orbital_strike_count: int
var super_luck_count: int
var medical_kit_count: int
var xray_count: int
var chain_count: int
var enlarge_count: int
var detect_count: int
var mines_placed := false
var game_over := false
var won := false
var seed: int
## 可玩格数量（掩码里为 1 的格子）。满矩形时等于 width * height。
var active_cell_count: int

var _mines := PackedByteArray()
var _monster_cores := PackedByteArray()
var _monster_peripherals := PackedByteArray()
var _monster_core_lookup := PackedInt32Array()
var _states := PackedByteArray()
var _adjacent := PackedByteArray()
var _items := PackedByteArray()
var _items_used := PackedByteArray()
var _active := PackedByteArray()
var _revealed_safe_cells := 0
var _monster_peripheral_counts: Dictionary = {}
## 新被标出的雷，按标记发生的顺序排队。标雷的入口太多（手动右键、红尾水鸲、探测、
## 夜鹭、啄木鸟、推理……），「连携」这类只关心「下一个被标出的雷」的效果就在这里
## 统一取，不用去 hook 每一处调用点。
var _marked_mine_log: Array[int] = []
## 「已计分的雷」队列，只增不减，且按格号去重。对战的标雷伤害要按雷逐个结算，
## 但不能蹭上面那个队列——`_marked_mine_log` 被连携取走即清空，两边共用会互相
## 偷走对方的事件。去重则保证反复插旗/撤旗同一格也只计一次分。
var _scored_mine_log: Array[int] = []
var _scored_mines: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(
	board_width: int,
	board_height: int,
	mines: int,
	run_seed: int = 0,
	lanterns: int = 3,
	compasses: int = 3,
	orbital_strikes: int = 2,
	super_lucks: int = 2,
	medical_kits: int = 0,
	xrays: int = 0,
	chains: int = 0,
	enlarges: int = 0,
	detects: int = 0,
	active_mask: PackedByteArray = PackedByteArray()
) -> void:
	width = board_width
	height = board_height
	lantern_count = maxi(lanterns, 0)
	compass_count = maxi(compasses, 0)
	orbital_strike_count = maxi(orbital_strikes, 0)
	super_luck_count = maxi(super_lucks, 0)
	medical_kit_count = maxi(medical_kits, 0)
	xray_count = maxi(xrays, 0)
	chain_count = maxi(chains, 0)
	enlarge_count = maxi(enlarges, 0)
	detect_count = maxi(detects, 0)
	seed = run_seed if run_seed != 0 else int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_msec()
	_rng.seed = seed
	_mines.resize(width * height)
	_monster_cores.resize(width * height)
	_monster_peripherals.resize(width * height)
	_monster_core_lookup.resize(width * height)
	_states.resize(width * height)
	_adjacent.resize(width * height)
	_items.resize(width * height)
	_items_used.resize(width * height)
	_active.resize(width * height)
	_mines.fill(0)
	_monster_cores.fill(0)
	_monster_peripherals.fill(0)
	_monster_core_lookup.fill(-1)
	_states.fill(CellState.COVERED)
	_adjacent.fill(0)
	_items.fill(ItemType.NONE)
	_items_used.fill(0)
	if active_mask.is_empty():
		_active.fill(1)
		active_cell_count = width * height
	else:
		assert(active_mask.size() == width * height, "active_mask 尺寸必须等于 width*height")
		_active = active_mask.duplicate()
		active_cell_count = 0
		for bit in _active:
			if bit == 1:
				active_cell_count += 1
	mine_count = clampi(mines, 1, maxi(active_cell_count - 1, 1))


func reveal(index: int) -> PackedInt32Array:
	var changed := PackedInt32Array()
	if not _is_valid(index) or game_over or state_at(index) != CellState.COVERED:
		return changed
	if not mines_placed:
		_place_mines(index)
	if is_monster_core(index):
		_states[index] = CellState.REVEALED
		changed.append(index)
		for peripheral_index in neighbors_of(index):
			if (
				monster_core_at(peripheral_index) == index
				and is_monster_peripheral(peripheral_index)
				and state_at(peripheral_index) != CellState.REVEALED
			):
				_states[peripheral_index] = CellState.REVEALED
				_revealed_safe_cells += 1
				changed.append(peripheral_index)
		_refresh_mine_completion()
		return changed

	var pending: Array[int] = [index]
	var queued := PackedByteArray()
	queued.resize(width * height)
	queued.fill(0)
	queued[index] = 1
	while not pending.is_empty():
		var current: int = pending.pop_back()
		if state_at(current) != CellState.COVERED or is_monster_core(current):
			continue
		_states[current] = CellState.REVEALED
		_revealed_safe_cells += 1
		changed.append(current)
		if adjacent_mines(current) == 0:
			for neighbor in neighbors_of(current):
				if queued[neighbor] == 0 and state_at(neighbor) == CellState.COVERED:
					queued[neighbor] = 1
					pending.append(neighbor)

	_refresh_mine_completion()
	return changed


func toggle_flag(index: int) -> bool:
	if not _is_valid(index) or game_over:
		return false
	if state_at(index) == CellState.REVEALED:
		return false
	_states[index] = CellState.COVERED if state_at(index) == CellState.FLAGGED else CellState.FLAGGED
	if is_monster_core(index):
		if state_at(index) == CellState.FLAGGED:
			_marked_mine_log.append(index)
			_record_scored_mine(index)
		else:
			_marked_mine_log.erase(index)
	_refresh_mine_completion()
	return true


func state_at(index: int) -> CellState:
	return _states[index] as CellState


func is_flagged(index: int) -> bool:
	if not _is_valid(index):
		return false
	return state_at(index) == CellState.FLAGGED


func has_mine(index: int) -> bool:
	return _mines[index] == 1


func ensure_mines_placed(safe_index: int) -> void:
	if not mines_placed:
		_place_mines(safe_index)


func is_monster_core(index: int) -> bool:
	return _monster_cores[index] == 1


func is_monster_peripheral(index: int) -> bool:
	return _monster_peripherals[index] == 1


func monster_peripheral_count(core_index: int) -> int:
	return int(_monster_peripheral_counts.get(core_index, 0))


func monster_core_at(index: int) -> int:
	return _monster_core_lookup[index]


func adjacent_mines(index: int) -> int:
	return _adjacent[index]


func item_at(index: int) -> ItemType:
	return _items[index] as ItemType


func force_item_at(index: int, type: ItemType, preserve_count: bool = true) -> bool:
	if not _is_valid(index) or not mines_placed or has_mine(index) or state_at(index) == CellState.FLAGGED:
		return false
	if item_at(index) == type:
		return true
	if preserve_count:
		for other_index in range(width * height):
			if other_index != index and item_at(other_index) == type:
				_items[other_index] = ItemType.NONE
				_items_used[other_index] = 0
				break
	_items[index] = type
	_items_used[index] = 0
	return true


func is_item_used(index: int) -> bool:
	return _items_used[index] == 1


func consume_item(index: int) -> ItemType:
	if not _is_valid(index) or state_at(index) != CellState.REVEALED or is_item_used(index):
		return ItemType.NONE
	var item := item_at(index)
	if item != ItemType.NONE:
		_items_used[index] = 1
	return item


func item_count(type: ItemType) -> int:
	var total := 0
	for item in _items:
		if item == type:
			total += 1
	return total


## 本关配置给该类型的数量（布雷前）或盘上实际张数（布雷后，含已翻开）。
func total_item_count_of(type: ItemType) -> int:
	if not mines_placed:
		return configured_item_count(type)
	return item_count(type)


## 该类型尚未翻开的张数。
func hidden_item_count_of(type: ItemType) -> int:
	if type == ItemType.NONE:
		return 0
	if not mines_placed:
		return configured_item_count(type)
	var total := 0
	for index in range(_items.size()):
		if _items[index] == type and state_at(index) != CellState.REVEALED:
			total += 1
	return total


func configured_item_count(type: ItemType) -> int:
	match type:
		ItemType.LANTERN:
			return lantern_count
		ItemType.COMPASS:
			return compass_count
		ItemType.ORBITAL_STRIKE:
			return orbital_strike_count
		ItemType.SUPER_LUCK:
			return super_luck_count
		ItemType.MEDICAL_KIT:
			return medical_kit_count
		ItemType.XRAY:
			return xray_count
		ItemType.CHAIN:
			return chain_count
		ItemType.ENLARGE:
			return enlarge_count
		ItemType.DETECT:
			return detect_count
	return 0


## How many item cards this level holds in total. Items only get scattered on the
## first reveal, so before that the configured budget is the honest answer — the
## board may still trim it if the level is too small to fit every card.
func total_item_count() -> int:
	if not mines_placed:
		return (
			lantern_count
			+ compass_count
			+ orbital_strike_count
			+ super_luck_count
			+ medical_kit_count
			+ xray_count
			+ chain_count
			+ enlarge_count
			+ detect_count
		)
	var total := 0
	for item in _items:
		if item != ItemType.NONE:
			total += 1
	return total


## Item cards the player has yet to dig up. Revealing a card hands its item over
## immediately, so "not revealed" is exactly what is still waiting on the board.
func hidden_item_count() -> int:
	if not mines_placed:
		return total_item_count()
	var total := 0
	for index in range(_items.size()):
		if _items[index] != ItemType.NONE and state_at(index) != CellState.REVEALED:
			total += 1
	return total


func random_lantern_targets(center_index: int, count: int) -> PackedInt32Array:
	var candidates: Array[int] = []
	if not _is_valid(center_index) or not mines_placed:
		return PackedInt32Array()
	for target in neighbors_of(center_index):
		if state_at(target) == CellState.COVERED:
			candidates.append(target)
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temporary := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = temporary
	var targets := PackedInt32Array()
	for index in range(mini(maxi(count, 0), candidates.size())):
		targets.append(candidates[index])
	return targets


func apply_lantern(center_index: int, count: int = 1) -> Dictionary:
	return apply_lantern_targets(random_lantern_targets(center_index, count))


func apply_lantern_targets(targets: PackedInt32Array) -> Dictionary:
	var revealed := PackedInt32Array()
	var flagged := PackedInt32Array()
	if not mines_placed:
		return {"revealed": revealed, "flagged": flagged}
	for target in targets:
		if not _is_valid(target):
			continue
		if is_monster_core(target):
			if mark_mine(target):
				flagged.append(target)
		elif state_at(target) != CellState.REVEALED:
			for changed in reveal_exact_forced_safe(target):
				if not revealed.has(changed):
					revealed.append(changed)
	return {"revealed": revealed, "flagged": flagged}


func apply_orbital_strike(center_index: int) -> Dictionary:
	var revealed := PackedInt32Array()
	var flagged := PackedInt32Array()
	if not _is_valid(center_index) or not mines_placed:
		return {"revealed": revealed, "flagged": flagged}
	var row: int = center_index / width
	for column in range(width):
		var target := row * width + column
		if not is_active(target):
			continue
		var result := apply_orbital_strike_cell(target)
		revealed.append_array(result["revealed"])
		flagged.append_array(result["flagged"])
	return {"revealed": revealed, "flagged": flagged}


func apply_orbital_strike_cell(target: int) -> Dictionary:
	var revealed := PackedInt32Array()
	var flagged := PackedInt32Array()
	if not _is_valid(target) or not mines_placed:
		return {"revealed": revealed, "flagged": flagged}
	if is_monster_core(target):
		if mark_mine(target):
			flagged.append(target)
	elif state_at(target) != CellState.REVEALED:
		var changed := reveal_exact_forced_safe(target)
		if not changed.is_empty():
			revealed.append(target)
	return {"revealed": revealed, "flagged": flagged}


func mark_mine(index: int) -> bool:
	if not _is_valid(index) or not is_monster_core(index) or state_at(index) != CellState.COVERED:
		return false
	_states[index] = CellState.FLAGGED
	_marked_mine_log.append(index)
	_record_scored_mine(index)
	_refresh_mine_completion()
	return true


## 取走并清空「新标出的雷」队列。取走即消费：同一次标记只会被结算一次。
func take_marked_mine_log() -> Array[int]:
	var marked := _marked_mine_log.duplicate()
	_marked_mine_log.clear()
	return marked


## 取走并清空「已计分的雷」队列，用来结算对战的标雷伤害与金币收入。与
## `take_marked_mine_log()` 互不干扰：那一条被连携消费，这一条只服务计分。
func take_scored_mine_log() -> Array[int]:
	var scored := _scored_mine_log.duplicate()
	_scored_mine_log.clear()
	return scored


func _record_scored_mine(index: int) -> void:
	if _scored_mines.has(index):
		return
	_scored_mines[index] = true
	_scored_mine_log.append(index)


## 由种子推出的开局格。对战双方用同一个种子建盘，于是也拿到同一个开局格；它直接
## 充当 `_place_mines()` 的 `first_index`，双方的雷区布局与起跑线因此完全一致。
##
## 这解决了一个绕不过去的矛盾：首点安全是靠「把首点 3×3 排除出布雷范围」实现的，
## 所以只要两人第一下点在不同格，候选数组的内容和长度就都不同，洗牌结果随之发散
## ——光有同一个种子也拿不到同一张盘。把 first_index 交给种子决定就没这回事了，
## 而且首点安全自动成立，不需要任何「生成后搬雷」的补丁。
static func opening_cell_for(board_seed: int, board_width: int, board_height: int) -> int:
	var total := board_width * board_height
	if total <= 0:
		return -1
	# 用一支独立的 RNG，别去动棋盘自己那支——布雷的随机流不能被这次取样带偏。
	var picker := RandomNumberGenerator.new()
	picker.seed = board_seed
	return picker.randi_range(0, total - 1)


func resolve_monster_core(index: int) -> bool:
	if not _is_valid(index) or not is_monster_core(index):
		return false
	_states[index] = CellState.REVEALED
	_marked_mine_log.erase(index)
	_refresh_mine_completion()
	return true


func random_hidden_safe_cell() -> int:
	var candidates: Array[int] = []
	for index in range(width * height):
		if not is_monster_core(index) and state_at(index) != CellState.REVEALED:
			candidates.append(index)
	if candidates.is_empty():
		return -1
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func random_hidden_cell() -> int:
	var candidates: Array[int] = []
	for index in range(width * height):
		if state_at(index) == CellState.COVERED:
			candidates.append(index)
	if candidates.is_empty():
		return -1
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func random_hidden_mine_cell() -> int:
	return random_hidden_mine_cell_excluding([])


func random_hidden_mine_cell_excluding(excluded: Array[int]) -> int:
	var candidates: Array[int] = []
	for index in range(width * height):
		if is_monster_core(index) and state_at(index) == CellState.COVERED and not excluded.has(index):
			candidates.append(index)
	if candidates.is_empty():
		return -1
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func reveal_forced_safe(index: int) -> PackedInt32Array:
	if not _is_valid(index) or is_monster_core(index):
		return PackedInt32Array()
	if state_at(index) == CellState.FLAGGED:
		_states[index] = CellState.COVERED
	return reveal(index)


func reveal_exact_forced_safe(index: int) -> PackedInt32Array:
	var changed := PackedInt32Array()
	if not _is_valid(index) or not mines_placed or is_monster_core(index):
		return changed
	if state_at(index) == CellState.REVEALED:
		return changed
	_states[index] = CellState.REVEALED
	_revealed_safe_cells += 1
	changed.append(index)
	_refresh_mine_completion()
	return changed


func flag_count() -> int:
	var total := 0
	for index in range(_states.size()):
		if state_at(index) == CellState.FLAGGED:
			total += 1
	return total


func is_active(index: int) -> bool:
	return index >= 0 and index < _active.size() and _active[index] == 1


func all_safe_cells_revealed() -> bool:
	return _revealed_safe_cells == active_cell_count - mine_count


func all_mines_triggered_or_flagged() -> bool:
	if not mines_placed:
		return false
	for index in range(width * height):
		if is_monster_core(index) and state_at(index) == CellState.COVERED:
			return false
	return true


func _refresh_mine_completion() -> void:
	if all_mines_triggered_or_flagged():
		won = true
		game_over = true


func inference_at(index: int) -> Dictionary:
	var potential_mines := PackedInt32Array()
	var safe_cells := PackedInt32Array()
	if (
		not _is_valid(index)
		or not mines_placed
		or state_at(index) != CellState.REVEALED
	):
		return {"potential_mines": potential_mines, "safe_cells": safe_cells, "unique": false}

	var covered := PackedInt32Array()
	# Numbers count every hazard cell in this game's monster footprints, including
	# the center cell itself. Revealed footprint cells and flags are already-known
	# hazards and must be removed before reasoning about covered neighbors.
	var known_mines := 1 if has_mine(index) else 0
	for neighbor in neighbors_of(index):
		match state_at(neighbor):
			CellState.COVERED:
				covered.append(neighbor)
			CellState.FLAGGED:
				known_mines += 1
			CellState.REVEALED:
				if has_mine(neighbor):
					known_mines += 1

	var remaining_mines := adjacent_mines(index) - known_mines
	if remaining_mines < 0 or remaining_mines > covered.size():
		return {"potential_mines": potential_mines, "safe_cells": safe_cells, "unique": false}
	if remaining_mines > 0:
		potential_mines = covered.duplicate()

	# A single-number constraint has exactly one arrangement only at either edge:
	# every covered neighbor is safe, or every covered neighbor is a mine.
	var unique := remaining_mines == 0 or remaining_mines == covered.size()
	if unique and remaining_mines == 0:
		safe_cells = covered.duplicate()
	return {"potential_mines": potential_mines, "safe_cells": safe_cells, "unique": unique}


func neighbors_of(index: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if not is_active(index):
		return result
	var x := index % width
	var y := index / width
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var neighbor_x := x + offset_x
			var neighbor_y := y + offset_y
			if neighbor_x >= 0 and neighbor_x < width and neighbor_y >= 0 and neighbor_y < height:
				var neighbor := neighbor_y * width + neighbor_x
				if is_active(neighbor):
					result.append(neighbor)
	return result


func _place_mines(first_index: int) -> void:
	var forbidden: Dictionary = {first_index: true}
	# A full 3x3 first-click safe zone would consume the entire opening board.
	# On the tutorial-sized first level only the clicked card is guaranteed safe.
	if active_cell_count > 9:
		for neighbor in neighbors_of(first_index):
			forbidden[neighbor] = true
	var candidates: Array[int] = []
	for index in range(width * height):
		if is_active(index) and not forbidden.has(index):
			candidates.append(index)
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temporary := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = temporary

	var occupied: Dictionary = {}
	var placed_cores := 0
	# Every hazard is a single-cell small mine. Large 3x3 footprints are no longer
	# part of the board generation rules.
	while placed_cores < mine_count:
		var core_index := _find_single_monster_core(candidates, occupied)
		if core_index < 0:
			break
		_place_monster(core_index, occupied)
		placed_cores += 1
	mine_count = placed_cores

	for index in range(width * height):
		if not is_active(index):
			_adjacent[index] = 0
			continue
		# Hazard cells count themselves as well as their eight neighbors.
		var count := 1 if has_mine(index) else 0
		for neighbor in neighbors_of(index):
			if has_mine(neighbor):
				count += 1
		_adjacent[index] = count
	_place_items(first_index)
	mines_placed = true


func _find_single_monster_core(candidates: Array[int], occupied: Dictionary) -> int:
	for candidate in candidates:
		if not occupied.has(candidate):
			return candidate
	return -1


func _place_monster(core_index: int, occupied: Dictionary) -> void:
	_monster_cores[core_index] = 1
	_mines[core_index] = 1
	_monster_core_lookup[core_index] = core_index
	occupied[core_index] = true
	_monster_peripheral_counts[core_index] = 0


func _place_items(first_index: int) -> void:
	var forbidden: Dictionary = {first_index: true}
	for neighbor in neighbors_of(first_index):
		forbidden[neighbor] = true
	var candidates: Array[int] = []
	for index in range(width * height):
		if is_active(index) and not has_mine(index) and not forbidden.has(index):
			candidates.append(index)
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temporary := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = temporary
	var cursor := 0
	for count in range(mini(lantern_count, candidates.size())):
		_items[candidates[cursor]] = ItemType.LANTERN
		cursor += 1
	for count in range(mini(compass_count, candidates.size() - cursor)):
		_items[candidates[cursor]] = ItemType.COMPASS
		cursor += 1
	for count in range(mini(orbital_strike_count, candidates.size() - cursor)):
		_items[candidates[cursor]] = ItemType.ORBITAL_STRIKE
		cursor += 1
	for count in range(mini(super_luck_count, candidates.size() - cursor)):
		_items[candidates[cursor]] = ItemType.SUPER_LUCK
		cursor += 1
	for count in range(mini(medical_kit_count, candidates.size() - cursor)):
		_items[candidates[cursor]] = ItemType.MEDICAL_KIT
		cursor += 1
	for count in range(mini(xray_count, candidates.size() - cursor)):
		_items[candidates[cursor]] = ItemType.XRAY
		cursor += 1
	for count in range(mini(chain_count, candidates.size() - cursor)):
		_items[candidates[cursor]] = ItemType.CHAIN
		cursor += 1
	for count in range(mini(enlarge_count, candidates.size() - cursor)):
		_items[candidates[cursor]] = ItemType.ENLARGE
		cursor += 1
	for count in range(mini(detect_count, candidates.size() - cursor)):
		_items[candidates[cursor]] = ItemType.DETECT
		cursor += 1


func _is_valid(index: int) -> bool:
	return is_active(index)
