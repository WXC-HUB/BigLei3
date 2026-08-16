extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set("_run_number", 4)
	game.call("_start_game")
	await process_frame

	var panel := game.get("_mine_counter_panel") as PanelContainer
	var value := game.get("_mine_label") as Label
	var board_panel := game.get("_board_panel") as PanelContainer
	var board: MinesweeperBoard = game.get("_board")
	assert(panel.visible and panel.is_visible_in_tree(), "Remaining-mine counter is not visible")
	assert(panel.global_position.y + panel.size.y < board_panel.global_position.y, "Remaining-mine counter is not above the grid")
	assert(value.text == "%03d" % board.mine_count, "Remaining-mine counter did not show the level total")

	var seed_index := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(seed_index)
	var mine_index := -1
	for index in range(board.width * board.height):
		if board.has_mine(index):
			mine_index = index
			break
	assert(mine_index >= 0)
	game.call("_on_cell_flagged", mine_index)
	await process_frame
	assert(value.text == "%03d" % (board.mine_count - 1), "Remaining-mine counter did not update after a flag")

	print("Mine counter UI: placement and live value update passed")
	quit()
