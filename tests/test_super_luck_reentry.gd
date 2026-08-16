extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void:
		push_error("Super luck re-entry test timed out")
		quit(2)
	)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	for _level in range(3):
		game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var safe_seed := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(safe_seed)
	var item_index := _find_covered_safe_cell(board)
	assert(item_index >= 0, "Could not find a safe cell for deferred super luck")
	assert(board.force_item_at(item_index, MinesweeperBoard.ItemType.SUPER_LUCK, false), "Could not place deferred super luck")
	await game.call("_enter_super_luck_mode", 1)
	var changed := board.reveal_exact_forced_safe(item_index)
	game.call("_refresh_cell", item_index)
	game.call("_defer_super_luck_reveals", changed)

	game.call("_consume_super_luck_click")
	assert(not bool(game.get("_super_luck_mode_active")), "Zero-click mode stayed active before settlement")
	await _wait_for_reentered_mode(game)
	assert(int(game.get("_super_luck_clicks_remaining")) == 1, "Old settlement erased the new super-luck click")
	assert(not bool(game.get("_super_luck_settling")), "Old settlement left the new mode marked as settling")
	assert(not bool(game.get("_resolving")), "Board stayed locked after super-luck re-entry")
	print("Super luck re-entry: deferred luck starts a fresh 1-click mode passed")
	quit()


func _find_covered_safe_cell(board: MinesweeperBoard) -> int:
	for index in range(board.width * board.height):
		if not board.is_monster_core(index) and board.state_at(index) == MinesweeperBoard.CellState.COVERED:
			return index
	return -1


func _wait_for_reentered_mode(game: Node) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if (
			bool(game.get("_super_luck_mode_active"))
			and int(game.get("_super_luck_clicks_remaining")) == 1
			and not bool(game.get("_resolving"))
		):
			return
		await process_frame
	assert(false, "Deferred super luck did not hand off to a usable new mode")
