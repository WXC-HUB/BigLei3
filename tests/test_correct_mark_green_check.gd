extends SceneTree

const BoardModel := preload("res://scripts/game/minesweeper_board.gd")
const GREEN_CHECK := preload("res://my_asset/effects/marked_mine_green_check.png")
const MONSTER_SMALL := preload("res://my_asset/monster_small.png")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_start_game")
	game.call("_start_game")
	game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.reveal(center)
	var mine_index := _find_small_mine(board)
	assert(mine_index >= 0, "Test board has no small mine")
	game.call("_on_cell_flagged", mine_index)
	assert(board.state_at(mine_index) == MinesweeperBoard.CellState.FLAGGED)
	var cells: Array = game.get("_cells")
	var cell: MineCell = cells[mine_index]
	var content := cell.get("_content") as TextureRect
	var fault := cell.get("_fault_plate") as TextureRect
	var marker := cell.get("_marker") as TextureRect
	assert(content.visible, "Correctly marked mine is hidden")
	assert(content.texture == MONSTER_SMALL, "Correctly marked mine did not keep the monster sprite")
	assert(fault.visible and fault.texture == GREEN_CHECK, "Correctly marked mine missing green-check plate")
	assert(not marker.visible, "Correctly marked mine still showed the flag marker")
	assert(content.modulate.is_equal_approx(Color.WHITE), "Correct mark inherited corpse tint")

	game.call("_refresh_cell", mine_index)
	assert(fault.visible and fault.texture == GREEN_CHECK, "Refreshing a marked mine dropped the green check")
	assert(content.texture == MONSTER_SMALL, "Refreshing a marked mine dropped the monster sprite")
	assert(
		fault.scale.is_equal_approx(Vector2(MineCell.CORRECT_MARK_PLATE_SCALE, MineCell.CORRECT_MARK_PLATE_SCALE)),
		"Green check plate was not scaled down"
	)
	assert(
		is_equal_approx(fault.modulate.a, MineCell.CORRECT_MARK_PLATE_ALPHA),
		"Green check plate alpha was not reduced"
	)

	game.call("_on_cell_flagged", mine_index)
	assert(board.state_at(mine_index) == MinesweeperBoard.CellState.COVERED)
	assert(not fault.visible, "Unmarking left the green-check plate")
	assert(not content.visible, "Unmarking left the mine sprite")
	print("Correct mark display: mine + green check plate passed")
	quit()


func _find_small_mine(board: MinesweeperBoard) -> int:
	for index in range(board.width * board.height):
		if (
			board.is_monster_core(index)
			and board.monster_peripheral_count(index) == 0
			and board.state_at(index) == MinesweeperBoard.CellState.COVERED
		):
			return index
	return -1
