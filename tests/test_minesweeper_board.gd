extends SceneTree

const BoardModel := preload("res://scripts/game/minesweeper_board.gd")


func _init() -> void:
	_test_first_click_is_safe()
	_test_flags_toggle()
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


func _test_flags_toggle() -> void:
	var board = BoardModel.new(10, 8, 12, 1)
	assert(board.toggle_flag(3))
	assert(board.state_at(3) == BoardModel.CellState.FLAGGED)
	assert(board.flag_count() == 1)
	assert(board.toggle_flag(3))
	assert(board.state_at(3) == BoardModel.CellState.COVERED)
	assert(board.flag_count() == 0)


func _test_items_are_placed_and_resolved() -> void:
	var board = BoardModel.new(10, 8, 12, 2468, 2, 2)
	board.reveal(0)
	assert(board.item_count(BoardModel.ItemType.LANTERN) == 2)
	assert(board.item_count(BoardModel.ItemType.COMPASS) == 2)

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
		if board.has_mine(target):
			assert(board.state_at(target) == BoardModel.CellState.FLAGGED)
		else:
			assert(board.state_at(target) == BoardModel.CellState.REVEALED)

	var compass_target := board.random_hidden_safe_cell()
	if compass_target >= 0:
		assert(not board.has_mine(compass_target))
		assert(board.state_at(compass_target) != BoardModel.CellState.REVEALED)
		board.toggle_flag(compass_target)
		var compass_reveal: PackedInt32Array = board.reveal_forced_safe(compass_target)
		assert(compass_reveal.has(compass_target))
		assert(board.state_at(compass_target) == BoardModel.CellState.REVEALED)


func _test_win_condition() -> void:
	var board = BoardModel.new(6, 6, 5, 777)
	board.reveal(0)
	for index in range(board.width * board.height):
		if not board.has_mine(index):
			board.reveal(index)
	assert(board.won)
	assert(board.game_over)
