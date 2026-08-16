extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := await _new_game()
	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	var final_mine := _prepare_one_remaining_mine(board)
	assert(final_mine >= 0, "Test board has no final mine")
	var hp_before: int = game.get("_player_hp")
	game.call("_on_cell_revealed", final_mine)
	# The last mine is still a mine: it hits the player first, and the win
	# settles right behind that hit rather than on the same frame.
	await _wait_for_finish(game, 5.0)
	assert(int(game.get("_player_hp")) == hp_before - 1, "Final revealed mine did not cost a heart")
	assert(board.won, "Immediate cell victory did not set the win state")
	game.queue_free()
	await process_frame

	game = await _new_game()
	board = game.get("_board")
	center = int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	final_mine = _prepare_one_remaining_mine(board, true)
	assert(final_mine >= 0, "Test board has no suitable orbital target mine")
	game.set("_orbital_orientation_override", 1)
	var empty_queue: Array[int] = []
	game.call("_resolve_orbital_strike", final_mine, empty_queue, {})
	await _wait_for_finish(game, 3.0)
	assert(int(game.get("_last_orbital_step")) == final_mine, "Orbital strike continued after the winning cell")
	var next_row := final_mine / board.width + 1
	if next_row < board.height:
		var next_index := next_row * board.width + final_mine % board.width
		assert(board.state_at(next_index) == MinesweeperBoard.CellState.COVERED, "Orbital strike modified cells after victory")
	print("Immediate victory: direct reveal and mid-item settlement passed")
	quit()


func _new_game() -> Node:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_start_game")
	game.call("_start_game")
	game.call("_start_game")
	return game


func _prepare_one_remaining_mine(board: MinesweeperBoard, require_nonfinal_row: bool = false) -> int:
	var cores: Array[int] = []
	for index in range(board.width * board.height):
		if board.is_monster_core(index):
			cores.append(index)
	var final_mine := -1
	for core in cores:
		if not require_nonfinal_row or core / board.width < board.height - 1:
			final_mine = core
			break
	if final_mine < 0:
		return -1
	for core in cores:
		if core != final_mine:
			board.mark_mine(core)
	board.won = false
	board.game_over = false
	return final_mine


func _wait_for_finish(game: Node, timeout_seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not bool(game.get("_game_finish_started")) and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(bool(game.get("_game_finish_started")), "Item victory did not start in time")
