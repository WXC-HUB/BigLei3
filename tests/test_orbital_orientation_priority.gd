extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.set("_run_number", 4)
	game.set("_attacker_bird_unlocked", true)
	game.set("_orbital_strike_bonus", 1)
	game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	_fill_line(board, game.call("_orbital_line_targets", center, false))
	assert(bool(game.call("_choose_orbital_vertical", center)), "Full horizontal line did not prioritize vertical")

	game.call("_start_game")
	board = game.get("_board")
	center = int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	_fill_line(board, game.call("_orbital_line_targets", center, true))
	assert(not bool(game.call("_choose_orbital_vertical", center)), "Full vertical line did not prioritize horizontal")

	game.call("_start_game")
	board = game.get("_board")
	center = int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	game.set("_orbital_cross_unlocked", true)
	var empty_queue: Array[int] = []
	game.call("_resolve_orbital_strike", center, empty_queue, {})
	await create_timer(2.8).timeout
	var cross_targets: Array[int] = game.call("_orbital_cross_targets", center)
	for target in cross_targets:
		assert(board.state_at(target) != MinesweeperBoard.CellState.COVERED, "Cross strike missed a row or column cell")
	assert(int(game.get("_last_orbital_step")) == cross_targets.back(), "Cross sweep ended on the wrong cell")
	print("Orbital cross: row and column cleanup passed")
	quit()


func _fill_line(board: MinesweeperBoard, targets: Array[int]) -> void:
	for target in targets:
		if board.is_monster_core(target):
			board.mark_mine(target)
		else:
			board.reveal_exact_forced_safe(target)
