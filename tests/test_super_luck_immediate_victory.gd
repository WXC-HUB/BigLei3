extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	var final_mine := _prepare_one_remaining_mine(board)
	assert(final_mine >= 0, "Test board has no final mine")

	game.call("_enter_super_luck_mode")
	await create_timer(0.48).timeout
	assert(bool(game.get("_super_luck_mode_active")), "Super luck mode did not start")
	game.call("_on_cell_revealed", final_mine)
	await process_frame

	assert(bool(game.get("_game_finish_started")), "Super luck left-click did not check victory immediately")
	assert(board.won, "Super luck left-click did not set the win state")
	assert(
		board.state_at(final_mine) == MinesweeperBoard.CellState.FLAGGED,
		"Super luck left-click did not mark the final mine"
	)
	assert(not bool(game.get("_super_luck_mode_active")), "Victory did not end super luck mode")
	assert(int(game.get("_super_luck_clicks_remaining")) == 0, "Victory retained super luck clicks")
	print("Super luck immediate victory passed")
	quit()


func _prepare_one_remaining_mine(board: MinesweeperBoard) -> int:
	var cores: Array[int] = []
	for index in range(board.width * board.height):
		if board.is_monster_core(index):
			cores.append(index)
	if cores.is_empty():
		return -1
	var final_mine := cores[0]
	for core in cores:
		if core != final_mine:
			board.mark_mine(core)
	board.won = false
	board.game_over = false
	return final_mine
