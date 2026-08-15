class_name MinesweeperBoard
extends RefCounted

enum CellState { COVERED, REVEALED, FLAGGED }
enum ItemType { NONE, LANTERN, COMPASS }

var width: int
var height: int
var mine_count: int
var lantern_count: int
var compass_count: int
var mines_placed := false
var game_over := false
var won := false
var seed: int

var _mines := PackedByteArray()
var _monster_cores := PackedByteArray()
var _monster_peripherals := PackedByteArray()
var _monster_core_lookup := PackedInt32Array()
var _states := PackedByteArray()
var _adjacent := PackedByteArray()
var _items := PackedByteArray()
var _items_used := PackedByteArray()
var _revealed_flags := PackedByteArray()
var _revealed_safe_cells := 0
var _monster_peripheral_counts: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(
	board_width: int,
	board_height: int,
	mines: int,
	run_seed: int = 0,
	lanterns: int = 3,
	compasses: int = 3
) -> void:
	width = board_width
	height = board_height
	mine_count = clampi(mines, 1, width * height - 1)
	lantern_count = maxi(lanterns, 0)
	compass_count = maxi(compasses, 0)
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
	_revealed_flags.resize(width * height)
	_mines.fill(0)
	_monster_cores.fill(0)
	_monster_peripherals.fill(0)
	_monster_core_lookup.fill(-1)
	_states.fill(CellState.COVERED)
	_adjacent.fill(0)
	_items.fill(ItemType.NONE)
	_items_used.fill(0)
	_revealed_flags.fill(0)


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
		_revealed_flags[index] = 0 if _revealed_flags[index] == 1 else 1
		_refresh_mine_completion()
		return true
	_states[index] = CellState.COVERED if state_at(index) == CellState.FLAGGED else CellState.FLAGGED
	_refresh_mine_completion()
	return true


func state_at(index: int) -> CellState:
	return _states[index] as CellState


func is_flagged(index: int) -> bool:
	if not _is_valid(index):
		return false
	return state_at(index) == CellState.FLAGGED or _revealed_flags[index] == 1


func has_mine(index: int) -> bool:
	return _mines[index] == 1


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


func apply_lantern(center_index: int) -> Dictionary:
	var revealed := PackedInt32Array()
	var flagged := PackedInt32Array()
	if not _is_valid(center_index) or not mines_placed:
		return {"revealed": revealed, "flagged": flagged}
	var targets := neighbors_of(center_index)
	targets.append(center_index)
	targets.sort()
	for target in targets:
		if is_monster_core(target):
			if mark_mine(target):
				flagged.append(target)
		elif state_at(target) != CellState.REVEALED:
			for changed in reveal_forced_safe(target):
				if not revealed.has(changed):
					revealed.append(changed)
	return {"revealed": revealed, "flagged": flagged}


func mark_mine(index: int) -> bool:
	if not _is_valid(index) or not is_monster_core(index) or state_at(index) != CellState.COVERED:
		return false
	_states[index] = CellState.FLAGGED
	_refresh_mine_completion()
	return true


func resolve_monster_core(index: int) -> bool:
	if not _is_valid(index) or not is_monster_core(index):
		return false
	_states[index] = CellState.REVEALED
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


func reveal_forced_safe(index: int) -> PackedInt32Array:
	if not _is_valid(index) or is_monster_core(index):
		return PackedInt32Array()
	if state_at(index) == CellState.FLAGGED:
		_states[index] = CellState.COVERED
	return reveal(index)


func flag_count() -> int:
	var total := 0
	for index in range(_states.size()):
		if state_at(index) == CellState.FLAGGED or _revealed_flags[index] == 1:
			total += 1
	return total


func all_safe_cells_revealed() -> bool:
	return _revealed_safe_cells == width * height - mine_count


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
				if is_flagged(neighbor) or has_mine(neighbor):
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
	var x := index % width
	var y := index / width
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var neighbor_x := x + offset_x
			var neighbor_y := y + offset_y
			if neighbor_x >= 0 and neighbor_x < width and neighbor_y >= 0 and neighbor_y < height:
				result.append(neighbor_y * width + neighbor_x)
	return result


func _place_mines(first_index: int) -> void:
	var forbidden: Dictionary = {first_index: true}
	for neighbor in neighbors_of(first_index):
		forbidden[neighbor] = true
	var candidates: Array[int] = []
	for index in range(width * height):
		if not forbidden.has(index):
			candidates.append(index)
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temporary := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = temporary

	var occupied: Dictionary = {}
	var placed_cores := 0
	# The initial encounter contains at most one 3x3 monster. Every remaining
	# monster core is placed as a single-cell small mine.
	var desired_large_monsters := mini(1, mine_count)
	for monster_index in range(desired_large_monsters):
		var core_index := _find_large_monster_core(candidates, forbidden, occupied)
		if core_index < 0:
			break
		_place_monster(core_index, true, occupied)
		placed_cores += 1

	while placed_cores < mine_count:
		var core_index := _find_single_monster_core(candidates, occupied)
		if core_index < 0:
			break
		_place_monster(core_index, false, occupied)
		placed_cores += 1
	mine_count = placed_cores

	for index in range(width * height):
		# Hazard cells count themselves as well as their eight neighbors.  This lets
		# revealed monster-periphery cells legitimately display values up to 9.
		var count := 1 if has_mine(index) else 0
		for neighbor in neighbors_of(index):
			if has_mine(neighbor):
				count += 1
		_adjacent[index] = count
	_place_items(first_index)
	mines_placed = true


func _find_large_monster_core(candidates: Array[int], forbidden: Dictionary, occupied: Dictionary) -> int:
	for candidate in candidates:
		var footprint := Array(neighbors_of(candidate))
		if footprint.size() != 8:
			continue
		footprint.append(candidate)
		var available := true
		for cell_index in footprint:
			if forbidden.has(cell_index) or occupied.has(cell_index):
				available = false
				break
		if available:
			return candidate
	return -1


func _find_single_monster_core(candidates: Array[int], occupied: Dictionary) -> int:
	for candidate in candidates:
		if not occupied.has(candidate):
			return candidate
	return -1


func _place_monster(core_index: int, has_full_periphery: bool, occupied: Dictionary) -> void:
	_monster_cores[core_index] = 1
	_mines[core_index] = 1
	_monster_core_lookup[core_index] = core_index
	occupied[core_index] = true
	var peripheral_count := 0
	if has_full_periphery:
		for peripheral_index in neighbors_of(core_index):
			_monster_peripherals[peripheral_index] = 1
			_mines[peripheral_index] = 1
			_monster_core_lookup[peripheral_index] = core_index
			occupied[peripheral_index] = true
			peripheral_count += 1
	_monster_peripheral_counts[core_index] = peripheral_count


func _place_items(first_index: int) -> void:
	var forbidden: Dictionary = {first_index: true}
	for neighbor in neighbors_of(first_index):
		forbidden[neighbor] = true
	var candidates: Array[int] = []
	for index in range(width * height):
		if not has_mine(index) and not forbidden.has(index):
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


func _is_valid(index: int) -> bool:
	return index >= 0 and index < width * height
