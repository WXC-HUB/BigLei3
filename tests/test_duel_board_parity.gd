extends SceneTree
## FEAT-001 的地基验收：同一个对局种子必须在两个客户端上长出逐格一致的棋盘。
## 这条断言塌了，后面的标雷互伤就全是假的。

const BoardModel := preload("res://scripts/game/minesweeper_board.gd")
const SessionScript := preload("res://scripts/net/duel_session.gd")


func _init() -> void:
	_test_same_seed_same_layout()
	_test_opening_cell_is_safe_and_shared()
	_test_layout_survives_different_item_budgets()
	_test_level_seed_chain_is_stable()
	_test_scored_mine_log_dedupes()
	_test_scored_log_does_not_steal_from_chain_log()
	print("DuelBoardParity: all tests passed")
	quit()


## 两块盘用同一个种子、同一个开局格开局 —— 每一格的雷、数字、翻开状态都必须相同。
func _test_same_seed_same_layout() -> void:
	var level_seed := 987654321
	var left = _open_board(level_seed)
	var right = _open_board(level_seed)
	assert(left.mine_count == right.mine_count)
	for index in range(left.width * left.height):
		assert(left.has_mine(index) == right.has_mine(index))
		assert(left.is_monster_core(index) == right.is_monster_core(index))
		assert(left.adjacent_mines(index) == right.adjacent_mines(index))
		assert(left.state_at(index) == right.state_at(index))
		assert(left.item_at(index) == right.item_at(index))


func _test_opening_cell_is_safe_and_shared() -> void:
	var level_seed := 424242
	var opening := BoardModel.opening_cell_for(level_seed, 6, 6)
	assert(opening >= 0 and opening < 36)
	# 同一个种子问两次必须得到同一格，否则两端起跑线就不一样了。
	assert(BoardModel.opening_cell_for(level_seed, 6, 6) == opening)
	var board = _open_board(level_seed)
	# 开局格走的是 `_place_mines()` 的首点保护，所以它和八邻都不该有雷。
	assert(not board.has_mine(opening))
	for neighbor in board.neighbors_of(opening):
		assert(not board.has_mine(neighbor))
	assert(board.state_at(opening) == BoardModel.CellState.REVEALED)


## 双方买的东西不同，道具数量就不同。这不能影响雷区布局——`_place_items()` 在
## 布雷之后才跑，两边洗出的候选顺序一致，只是往里填的种类不同。
func _test_layout_survives_different_item_budgets() -> void:
	var level_seed := 20260824
	var poor = BoardModel.new(6, 6, 6, level_seed, 1, 1, 0, 0, 0, 0, 0, 0, 0)
	var rich = BoardModel.new(6, 6, 6, level_seed, 3, 3, 2, 2, 1, 1, 0, 0, 0)
	var opening := BoardModel.opening_cell_for(level_seed, 6, 6)
	poor.reveal(opening)
	rich.reveal(opening)
	for index in range(36):
		assert(poor.has_mine(index) == rich.has_mine(index))
		assert(poor.adjacent_mines(index) == rich.adjacent_mines(index))


## 种子链：同一个 duel_seed + 同一轮 → 同一个 level_seed；换一轮就必须换值。
func _test_level_seed_chain_is_stable() -> void:
	var left = SessionScript.new()
	var right = SessionScript.new()
	left.duel_seed = 13579
	right.duel_seed = 13579
	for round_number in range(1, 6):
		assert(left.level_seed_for(round_number) == right.level_seed_for(round_number))
	assert(left.level_seed_for(1) != left.level_seed_for(2))
	right.duel_seed = 24680
	assert(left.level_seed_for(1) != right.level_seed_for(1))
	left.free()
	right.free()


## 反复插旗/撤旗同一格只能计一次分，否则对着一个雷来回点右键就能无限打对手。
func _test_scored_mine_log_dedupes() -> void:
	var board = _open_board(555)
	var mine := _first_covered_mine(board)
	assert(mine >= 0)
	board.toggle_flag(mine)
	assert(board.take_scored_mine_log().size() == 1)
	board.toggle_flag(mine)
	board.toggle_flag(mine)
	assert(board.take_scored_mine_log().is_empty())


## 计分队列和连携队列必须互不相干：连携取走一次，计分那边还得能取到。
func _test_scored_log_does_not_steal_from_chain_log() -> void:
	var board = _open_board(31337)
	var mine := _first_covered_mine(board)
	assert(mine >= 0)
	board.mark_mine(mine)
	assert(board.take_marked_mine_log().size() == 1)
	assert(board.take_scored_mine_log().size() == 1)


func _open_board(level_seed: int):
	var board = BoardModel.new(6, 6, 6, level_seed, 2, 2, 1, 1, 0, 0, 0, 0, 0)
	board.reveal(BoardModel.opening_cell_for(level_seed, 6, 6))
	return board


func _first_covered_mine(board) -> int:
	for index in range(board.width * board.height):
		if board.is_monster_core(index) and board.state_at(index) == BoardModel.CellState.COVERED:
			return index
	return -1
