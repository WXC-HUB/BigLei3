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
var _states := PackedByteArray()
var _adjacent := PackedByteArray()
var _items := PackedByteArray()
var _items_used := PackedByteArray()
var _revealed_safe_cells := 0
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
	_states.resize(width * height)
	_adjacent.resize(width * height)
	_items.resize(width * height)
	_items_used.resize(width * height)
	_mines.fill(0)
	_states.fill(CellState.COVERED)
	_adjacent.fill(0)
	_items.fill(ItemType.NONE)
	_items_used.fill(0)


func reveal(index: int) -> PackedInt32Array:
	var changed := PackedInt32Array()
	if not _is_valid(index) or game_over or state_at(index) != CellState.COVERED:
		return changed
	if not mines_placed:
		_place_mines(index)
	if has_mine(index):
		_states[index] = CellState.REVEALED
		game_over = true
		changed.append(index)
		return changed

	var pending: Array[int] = [index]
	var queued := PackedByteArray()
	queued.resize(width * height)
	queued.fill(0)
	queued[index] = 1
	while not pending.is_empty():
		var current: int = pending.pop_back()
		if state_at(current) != CellState.COVERED or has_mine(current):
			continue
		_states[current] = CellState.REVEALED
		_revealed_safe_cells += 1
		changed.append(current)
		if adjacent_mines(current) == 0:
			for neighbor in neighbors_of(current):
				if queued[neighbor] == 0 and state_at(neighbor) == CellState.COVERED:
					queued[neighbor] = 1
					pending.append(neighbor)

	if _revealed_safe_cells == width * height - mine_count:
		won = true
		game_over = true
	return changed


func toggle_flag(index: int) -> bool:
	if not _is_valid(index) or game_over or state_at(index) == CellState.REVEALED:
		return false
	_states[index] = CellState.COVERED if state_at(index) == CellState.FLAGGED else CellState.FLAGGED
	return true


func state_at(index: int) -> CellState:
	return _states[index] as CellState


func has_mine(index: int) -> bool:
	return _mines[index] == 1


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
		if has_mine(target):
			if mark_mine(target):
				flagged.append(target)
		elif state_at(target) != CellState.REVEALED:
			for changed in reveal_forced_safe(target):
				if not revealed.has(changed):
					revealed.append(changed)
	return {"revealed": revealed, "flagged": flagged}


func mark_mine(index: int) -> bool:
	if not _is_valid(index) or not has_mine(index) or state_at(index) != CellState.COVERED:
		return false
	_states[index] = CellState.FLAGGED
	return true


func random_hidden_safe_cell() -> int:
	var candidates: Array[int] = []
	for index in range(width * height):
		if not has_mine(index) and state_at(index) != CellState.REVEALED:
			candidates.append(index)
	if candidates.is_empty():
		return -1
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func reveal_forced_safe(index: int) -> PackedInt32Array:
	if not _is_valid(index) or has_mine(index):
		return PackedInt32Array()
	if state_at(index) == CellState.FLAGGED:
		_states[index] = CellState.COVERED
	return reveal(index)


func flag_count() -> int:
	var total := 0
	for state in _states:
		if state == CellState.FLAGGED:
			total += 1
	return total


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
	if candidates.size() < mine_count:
		candidates.clear()
		for index in range(width * height):
			if index != first_index:
				candidates.append(index)
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temporary := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = temporary
	for mine_index in candidates.slice(0, mine_count):
		_mines[mine_index] = 1
	for index in range(width * height):
		if has_mine(index):
			continue
		var count := 0
		for neighbor in neighbors_of(index):
			if has_mine(neighbor):
				count += 1
		_adjacent[index] = count
	_place_items(first_index)
	mines_placed = true


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
