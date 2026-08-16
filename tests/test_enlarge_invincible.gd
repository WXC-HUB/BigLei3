extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(10.0).timeout.connect(func() -> void:
		push_error("Enlarge invincibility test timed out")
		quit(2)
	)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set("_run_number", 5)
	game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	board.ensure_mines_placed(0)
	var mine_index := -1
	for index in range(board.width * board.height):
		if board.is_monster_core(index):
			mine_index = index
			break
	assert(mine_index >= 0, "Could not find a mine for enlarge invincibility test")
	game.set("_player_hp", 1)
	game.call("_refresh_health_bar")
	game.set("_enlarge_mark_charges", 1)
	game.call("_on_cell_revealed", mine_index)
	var deadline := Time.get_ticks_msec() + 7000
	while bool(game.get("_resolving")) and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not bool(game.get("_resolving")), "Enlarge reveal did not finish")
	assert(int(game.get("_player_hp")) == 1, "Enlarge click did not prevent mine damage")
	assert(int(game.get("_enlarge_mark_charges")) == 0, "Enlarge click did not consume one charge")
	assert(not bool(game.get("_enlarge_click_invincible")), "Enlarge invincibility remained after the click")
	assert(board.state_at(mine_index) == MinesweeperBoard.CellState.REVEALED, "Enlarge did not reveal the selected mine")
	print("Enlarge: next area reveal is invincible passed")
	quit()
