extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_revealed_monster_footprint_constraints()
	_test_revealed_flag_affects_inference()
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var board: MinesweeperBoard = game.get("_board")
	board.reveal(44)
	assert(board.toggle_flag(44))
	game.call("_refresh_cell", 44)
	var rendered_cells: Array[MineCell] = game.get("_cells")
	var revealed_marker := rendered_cells[44].get("_marker") as TextureRect
	assert(revealed_marker.visible, "Flag on a revealed cell was not rendered")
	assert(board.toggle_flag(44))
	var inference_cell := -1
	for index in range(board.width * board.height):
		game.call("_refresh_cell", index)
		var inference: Dictionary = board.inference_at(index)
		if not inference["unique"] and not inference["potential_mines"].is_empty():
			inference_cell = index
			break
	if inference_cell < 0:
		_fail("No non-unique numbered cell was available for the chord test")
		return

	game.call("_on_cell_hover_started", inference_cell)
	game.call("_input", _mouse_event(MOUSE_BUTTON_LEFT, true))
	game.call("_input", _mouse_event(MOUSE_BUTTON_RIGHT, true))
	var highlighted: Array[int] = game.get("_inference_highlights")
	if highlighted.is_empty():
		_fail("The left+right chord did not produce inference highlights")
		return
	var cells: Array[MineCell] = game.get("_cells")
	var overlay := cells[highlighted[0]].get("_preview_overlay") as Panel
	if not overlay.visible:
		_fail("Inference ran, but its visual overlay was not visible")
		return
	var marked_neighbor := -1
	for neighbor in board.neighbors_of(inference_cell):
		if board.state_at(neighbor) == MinesweeperBoard.CellState.COVERED:
			marked_neighbor = neighbor
			break
	if marked_neighbor >= 0:
		assert(board.toggle_flag(marked_neighbor))
		var marked_targets: Array[int] = game.call("_inference_highlight_targets", inference_cell, board.inference_at(inference_cell))
		assert(marked_targets.has(marked_neighbor), "A flagged constraint cell was not included in inference highlighting")

	game.call("_input", _mouse_event(MOUSE_BUTTON_LEFT, false))
	if overlay.visible:
		_fail("Inference overlay remained visible after mouse-up")
		return
	_test_multicell_corpse_highlight(game, board)
	print("Inference chord: all tests passed")
	quit()


func _test_multicell_corpse_highlight(game: Node, board: MinesweeperBoard) -> void:
	var big_core := -1
	for index in range(board.width * board.height):
		if board.is_monster_core(index) and board.monster_peripheral_count(index) == 8:
			big_core = index
			break
	assert(big_core >= 0)
	board.reveal(big_core)
	var defeated: Dictionary = game.get("_defeated_mines")
	defeated[big_core] = true
	var empty_inference := {"potential_mines": PackedInt32Array()}
	var targets: Array[int] = game.call("_inference_highlight_targets", big_core, empty_inference)
	assert(targets.has(big_core))
	for footprint_cell in board.neighbors_of(big_core):
		assert(targets.has(footprint_cell), "A multi-cell corpse footprint was not fully highlighted")


func _test_revealed_monster_footprint_constraints() -> void:
	var board := MinesweeperBoard.new(10, 8, 12, 314159)
	board.reveal(44)
	for index in range(board.width * board.height):
		if board.is_monster_core(index) and board.monster_peripheral_count(index) == 8:
			board.reveal(index)
			break
	for index in range(board.width * board.height):
		if board.state_at(index) != MinesweeperBoard.CellState.REVEALED:
			continue
		var has_covered_neighbor := false
		for neighbor in board.neighbors_of(index):
			if board.state_at(neighbor) == MinesweeperBoard.CellState.COVERED:
				has_covered_neighbor = true
				break
		if not has_covered_neighbor:
			continue
		var inference: Dictionary = board.inference_at(index)
		if inference["potential_mines"].is_empty() and not inference["unique"]:
			_fail("A revealed monster-footprint constraint was incorrectly rejected")
			return


func _test_revealed_flag_affects_inference() -> void:
	var board := MinesweeperBoard.new(10, 8, 12, 12345)
	board.reveal(44)
	for index in range(board.width * board.height):
		if board.state_at(index) != MinesweeperBoard.CellState.REVEALED:
			continue
		var covered_count := 0
		var known_mines := 1 if board.has_mine(index) else 0
		var flag_target := -1
		for neighbor in board.neighbors_of(index):
			if board.state_at(neighbor) == MinesweeperBoard.CellState.COVERED:
				covered_count += 1
			elif board.state_at(neighbor) == MinesweeperBoard.CellState.REVEALED:
				if board.has_mine(neighbor):
					known_mines += 1
				elif flag_target < 0:
					flag_target = neighbor
		var expected_remaining := board.adjacent_mines(index) - known_mines - 1
		if flag_target < 0 or covered_count == 0 or expected_remaining < 0 or expected_remaining > covered_count:
			continue
		assert(board.toggle_flag(flag_target))
		var inference: Dictionary = board.inference_at(index)
		assert(inference["unique"] == (expected_remaining == 0 or expected_remaining == covered_count))
		assert(inference["potential_mines"].size() == (covered_count if expected_remaining > 0 else 0))
		return
	_fail("No suitable revealed-cell flag inference case was found")


func _mouse_event(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
