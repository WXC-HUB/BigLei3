extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(6.0).timeout.connect(func() -> void:
		push_error("Inference batch settlement test timed out")
		quit(2)
	)
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.set("_run_number", 4)
	game.call("_start_game")
	await process_frame

	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	var targets := PackedInt32Array()
	for index in range(board.width * board.height):
		if not board.has_mine(index) and board.state_at(index) == MinesweeperBoard.CellState.COVERED:
			targets.append(index)
			if targets.size() == 2:
				break
	assert(targets.size() == 2, "Could not prepare two inferred safe cards")
	for target in targets:
		assert(board.force_item_at(target, MinesweeperBoard.ItemType.MEDICAL_KIT, false))

	game.set("_player_hp", 1)
	game.call("_refresh_health_bar")
	game.call("_resolve_inferred_safe_cells", targets)
	var board_panel := game.get("_board_panel") as Control
	assert(not board_panel.scale.is_equal_approx(Vector2.ONE), "Inference that flips safe cards did not punch the board")
	# Collection happens synchronously before the reveal animation yields: every
	# inferred card is face-up, while their item payloads remain untouched.
	for target in targets:
		assert(board.state_at(target) == MinesweeperBoard.CellState.REVEALED, "Inference did not flip the whole safe batch up front")
		assert(not board.is_item_used(target), "An inferred item settled before the batch finished flipping")
	await create_timer(0.3).timeout
	for target in targets:
		assert(not board.is_item_used(target), "An inferred item settled during the reveal wave")
	await create_timer(2.2).timeout
	for target in targets:
		assert(board.is_item_used(target), "An inferred item was not settled after the reveal wave")

	print("Inference batch: all cards flip before queued item settlement passed")
	quit()
