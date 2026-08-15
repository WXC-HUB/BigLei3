extends SceneTree

const BoardModel := preload("res://scripts/game/minesweeper_board.gd")


func _init() -> void:
	_test_first_click_is_safe()
	_test_monster_footprints()
	_test_revealed_monster_core_does_not_end_board()
	_test_flags_toggle()
	_test_revealed_flags_toggle()
	_test_items_are_placed_and_resolved()
	_test_win_condition()
	print("MinesweeperBoard: all tests passed")
	quit()


func _test_first_click_is_safe() -> void:
	var board = BoardModel.new(10, 8, 12, 12345)
	var first := 44
	var changed: PackedInt32Array = board.reveal(first)
	assert(not changed.is_empty())
	assert(not board.has_mine(first))
	for neighbor in board.neighbors_of(first):
		assert(not board.has_mine(neighbor))
	assert(board.adjacent_mines(first) == 0)


func _test_monster_footprints() -> void:
	var board = BoardModel.new(10, 8, 12, 314159)
	board.reveal(0)
	var core_count := 0
	var large_count := 0
	var found_single := false
	var found_large := false
	var small_core := -1
	var large_core := -1
	for index in range(board.width * board.height):
		if board.is_monster_core(index):
			core_count += 1
			assert(board.monster_core_at(index) == index)
			var peripheral_count := board.monster_peripheral_count(index)
			assert(peripheral_count == 0 or peripheral_count == 8)
			if peripheral_count == 8:
				large_count += 1
				assert(board.adjacent_mines(index) == 9)
				large_core = index
			else:
				small_core = index
			found_single = found_single or peripheral_count == 0
			found_large = found_large or peripheral_count == 8
		elif board.is_monster_peripheral(index):
			assert(board.has_mine(index))
			assert(board.is_monster_core(board.monster_core_at(index)))
			var expected_value := 1
			for neighbor in board.neighbors_of(index):
				if board.has_mine(neighbor):
					expected_value += 1
			assert(board.adjacent_mines(index) == expected_value)
			if board.state_at(index) == BoardModel.CellState.COVERED:
				assert(board.reveal(index).has(index))
			assert(board.state_at(index) == BoardModel.CellState.REVEALED)
	assert(core_count == board.mine_count)
	assert(large_count == 1)
	assert(found_single)
	assert(found_large)
	assert(small_core >= 0)
	assert(board.mark_mine(small_core))
	assert(board.resolve_monster_core(small_core))
	assert(board.state_at(small_core) == BoardModel.CellState.REVEALED)
	assert(large_core >= 0)
	var footprint_reveal := board.reveal(large_core)
	assert(footprint_reveal.has(large_core))
	for peripheral_index in board.neighbors_of(large_core):
		assert(board.is_monster_peripheral(peripheral_index))
		assert(board.state_at(peripheral_index) == BoardModel.CellState.REVEALED)


func _test_revealed_monster_core_does_not_end_board() -> void:
	var board = BoardModel.new(10, 8, 12, 54321)
	board.reveal(0)
	var mine_index := -1
	for index in range(board.width * board.height):
		if board.is_monster_core(index):
			mine_index = index
			break
	assert(mine_index >= 0)
	var changed := board.reveal(mine_index)
	assert(changed.has(mine_index))
	assert(board.state_at(mine_index) == BoardModel.CellState.REVEALED)
	assert(not board.game_over)


func _test_flags_toggle() -> void:
	var board = BoardModel.new(10, 8, 12, 1)
	assert(board.toggle_flag(3))
	assert(board.state_at(3) == BoardModel.CellState.FLAGGED)
	assert(board.flag_count() == 1)
	assert(board.toggle_flag(3))
	assert(board.state_at(3) == BoardModel.CellState.COVERED)
	assert(board.flag_count() == 0)


func _test_revealed_flags_toggle() -> void:
	var board = BoardModel.new(10, 8, 12, 12345)
	board.reveal(44)
	assert(board.state_at(44) == BoardModel.CellState.REVEALED)
	assert(board.toggle_flag(44))
	assert(board.state_at(44) == BoardModel.CellState.REVEALED)
	assert(board.is_flagged(44))
	assert(board.flag_count() == 1)
	assert(board.toggle_flag(44))
	assert(not board.is_flagged(44))
	assert(board.flag_count() == 0)


func _test_items_are_placed_and_resolved() -> void:
	var board = BoardModel.new(10, 8, 12, 2468, 2, 2, 2, 2)
	board.reveal(0)
	assert(board.item_count(BoardModel.ItemType.LANTERN) == 2)
	assert(board.item_count(BoardModel.ItemType.COMPASS) == 2)
	assert(board.item_count(BoardModel.ItemType.ORBITAL_STRIKE) == 2)
	assert(board.item_count(BoardModel.ItemType.SUPER_LUCK) == 2)
	assert(board.item_count(BoardModel.ItemType.NONE) == board.width * board.height - 8)

	var lantern_index := -1
	for index in range(board.width * board.height):
		if board.item_at(index) == BoardModel.ItemType.LANTERN:
			lantern_index = index
			break
	assert(lantern_index >= 0)
	if board.state_at(lantern_index) == BoardModel.CellState.COVERED:
		board.reveal(lantern_index)
	assert(board.consume_item(lantern_index) == BoardModel.ItemType.LANTERN)
	assert(board.consume_item(lantern_index) == BoardModel.ItemType.NONE)
	board.apply_lantern(lantern_index)
	for target in board.neighbors_of(lantern_index):
		if board.is_monster_core(target):
			assert(board.state_at(target) == BoardModel.CellState.FLAGGED)
		else:
			assert(board.state_at(target) == BoardModel.CellState.REVEALED)

	var compass_target := board.random_hidden_safe_cell()
	if compass_target >= 0:
		assert(not board.is_monster_core(compass_target))
		assert(board.state_at(compass_target) != BoardModel.CellState.REVEALED)
		board.toggle_flag(compass_target)
		var compass_reveal: PackedInt32Array = board.reveal_forced_safe(compass_target)
		assert(compass_reveal.has(compass_target))
		assert(board.state_at(compass_target) == BoardModel.CellState.REVEALED)

	var orbital_index := -1
	for index in range(board.width * board.height):
		if board.item_at(index) == BoardModel.ItemType.ORBITAL_STRIKE:
			orbital_index = index
			break
	assert(orbital_index >= 0)
	if board.state_at(orbital_index) != BoardModel.CellState.REVEALED:
		board.reveal_forced_safe(orbital_index)
	assert(board.consume_item(orbital_index) == BoardModel.ItemType.ORBITAL_STRIKE)
	board.apply_orbital_strike(orbital_index)
	var orbital_row: int = orbital_index / board.width
	for column in range(board.width):
		var target: int = orbital_row * board.width + column
		if board.is_monster_core(target):
			assert(board.state_at(target) == BoardModel.CellState.FLAGGED)
		else:
			assert(board.state_at(target) == BoardModel.CellState.REVEALED)


func _test_win_condition() -> void:
	var board = BoardModel.new(6, 6, 5, 777)
	board.reveal(0)
	for index in range(board.width * board.height):
		if not board.is_monster_core(index):
			board.reveal(index)
	assert(not board.won)
	assert(not board.game_over)
	var triggered_one := false
	for index in range(board.width * board.height):
		if board.is_monster_core(index) and board.state_at(index) == BoardModel.CellState.COVERED:
			if not triggered_one:
				board.reveal(index)
				triggered_one = true
			else:
				board.toggle_flag(index)
	assert(board.all_mines_triggered_or_flagged())
	assert(board.won)
	assert(board.game_over)
