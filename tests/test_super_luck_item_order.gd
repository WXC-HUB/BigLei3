extends SceneTree

const BoardModel := preload("res://scripts/game/minesweeper_board.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("Super luck item order test timed out")
		quit(2)
	)
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.set("_super_luck_bonus", 2)
	game.set("_compass_bonus", 1)
	for _level in range(3):
		game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	var luck_indices := _find_items(board, BoardModel.ItemType.SUPER_LUCK)
	var compass_index := _find_item(board, BoardModel.ItemType.COMPASS)
	assert(luck_indices.size() >= 2 and compass_index >= 0, "Test board is missing required items")
	board.reveal_exact_forced_safe(luck_indices[0])
	board.reveal_exact_forced_safe(luck_indices[1])
	board.reveal_exact_forced_safe(compass_index)
	game.call("_refresh_cell", luck_indices[0])
	game.call("_refresh_cell", luck_indices[1])
	game.call("_refresh_cell", compass_index)
	var queue: Array[int] = [luck_indices[0], compass_index, luck_indices[1]]
	var queued := {luck_indices[0]: true, compass_index: true, luck_indices[1]: true}
	game.call("_resolve_item_queue", queue, queued)
	await _wait_for_super_luck(game, 18.0)
	assert(board.is_item_used(compass_index), "Super luck started before the compass settled")
	assert(int(game.get("_last_compass_target")) >= 0, "Compass effect did not finish before super luck")
	assert(board.is_item_used(luck_indices[0]), "First super luck item was not consumed")
	assert(board.is_item_used(luck_indices[1]), "Second super luck item was not merged before activation")
	await create_timer(2.0).timeout
	assert(int(game.get("_super_luck_activation_count")) == 1, "Merged super luck restarted the mode")
	assert(int(game.get("_super_luck_clicks_remaining")) == 2, "Merged super luck clicks did not stack to 2")
	print("Item order: regular items settle first and multiple super luck items merge passed")
	quit()


func _find_item(board: MinesweeperBoard, type: BoardModel.ItemType) -> int:
	for index in range(board.width * board.height):
		if board.item_at(index) == type:
			return index
	return -1


func _find_items(board: MinesweeperBoard, type: BoardModel.ItemType) -> Array[int]:
	var result: Array[int] = []
	for index in range(board.width * board.height):
		if board.item_at(index) == type:
			result.append(index)
	return result


func _wait_for_super_luck(game: Node, timeout_seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not bool(game.get("_super_luck_mode_active")) and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(bool(game.get("_super_luck_mode_active")), "Super luck mode did not start in time")
