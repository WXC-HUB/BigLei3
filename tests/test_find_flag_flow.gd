extends SceneTree

const RED_CROSS := preload("res://my_asset/effects/triggered_mine_red_cross.png")


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

	var mine_index := -1
	var safe_index := -1
	for index in range(board.width * board.height):
		if board.state_at(index) != MinesweeperBoard.CellState.COVERED:
			continue
		if board.has_mine(index) and mine_index < 0:
			mine_index = index
		elif not board.has_mine(index) and safe_index < 0:
			safe_index = index
	assert(mine_index >= 0 and safe_index >= 0)

	game.call("_on_cell_flagged", mine_index)
	var bird := game.get_node("BlueBirdPerch")
	assert(board.state_at(mine_index) == MinesweeperBoard.CellState.FLAGGED)
	assert(not bool(game.get("_resolving")), "Bird feedback blocked board input")

	# Apply a second right-click while the first bird animation is still running.
	assert(board.force_item_at(safe_index, MinesweeperBoard.ItemType.MEDICAL_KIT, false))
	game.call("_refresh_cell", safe_index)
	game.call("_on_cell_flagged", safe_index)
	assert(board.state_at(safe_index) == MinesweeperBoard.CellState.REVEALED, "Wrong mark did not reveal the safe cell")
	assert(board.is_item_used(safe_index), "Item under the wrong mark was not destroyed")
	var wrong_cells: Dictionary = game.get("_wrong_flagged_cells")
	assert(wrong_cells.has(safe_index), "Wrong mark was not retained as a destroyed cell")
	var cells: Array = game.get("_cells")
	var wrong_cell: MineCell = cells[safe_index]
	var content := wrong_cell.get("_content") as TextureRect
	var fault := wrong_cell.get("_fault_plate") as TextureRect
	var number_label := wrong_cell.get("_number_label") as Label
	var expected_number := board.adjacent_mines(safe_index)
	assert(fault.visible and fault.texture == RED_CROSS, "Wrong mark missing red-cross plate")
	assert(content.texture == null, "Wrong mark still showed item or skull content")
	if expected_number > 0:
		assert(number_label.visible and number_label.text == str(expected_number), "Wrong mark did not show adjacent number")
	else:
		assert(not number_label.visible, "Wrong mark showed a number on a zero cell")
	var item_queue: Array[int] = []
	var queued_items: Dictionary = {}
	game.call("_present_revealed", PackedInt32Array([safe_index]), item_queue, queued_items)
	assert(item_queue.is_empty(), "Destroyed item was still queued for settlement")
	assert(not bool(game.get("_resolving")), "Queued bird feedback blocked board input")
	await _wait_for_find_result(bird, false)
	assert(not bool(bird.get("_last_find_result")))
	print("Find flag flow: mine and safe branches passed")
	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame
	quit()


func _wait_for_find_result(bird: Node, expected: bool) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while bool(bird.get("_finding")) or bool(bird.get("_last_find_result")) != expected:
		assert(Time.get_ticks_msec() < deadline, "Blue bird find animation timed out")
		await create_timer(0.05).timeout
