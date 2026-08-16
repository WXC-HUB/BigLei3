extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(5.0).timeout.connect(func() -> void:
		push_error("Inference test timed out after an assertion")
		quit(2)
	)
	_test_revealed_constraints()
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set("_run_number", 4)
	game.call("_start_game")

	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.reveal(center)
	assert(not board.toggle_flag(center))
	game.call("_refresh_cell", center)
	var rendered_cells: Array[MineCell] = game.get("_cells")
	var revealed_marker := rendered_cells[center].get("_marker") as TextureRect
	assert(not revealed_marker.visible, "A revealed cell displayed a flag marker")
	var inference_cell := -1
	for index in range(board.width * board.height):
		game.call("_refresh_cell", index)
		var inference: Dictionary = board.inference_at(index)
		if not inference["unique"] and not inference["potential_mines"].is_empty():
			inference_cell = index
			break
	if inference_cell < 0:
		_fail("No non-unique numbered cell was available for the inference test")
		return

	game.call("_on_cell_hover_started", inference_cell)
	var hover_targets: Array[int] = game.get("_inference_hover_targets")
	assert(not hover_targets.is_empty(), "Hovering a numbered clue did not outline its potential mine area")
	var hover_border := rendered_cells[hover_targets[0]].get("_inference_border") as Control
	assert(hover_border.visible and hover_border.is_processing(), "Potential mine area did not show its moving dashed border")
	game.call("_input", _mouse_event(MOUSE_BUTTON_LEFT, true))
	var board_panel := game.get("_board_panel") as Control
	assert(board_panel.scale.is_equal_approx(Vector2.ONE), "Non-resolving inference incorrectly punched the whole board")
	var highlighted: Array[int] = game.get("_inference_highlights")
	if highlighted.is_empty():
		_fail("Left-clicking a revealed card did not produce inference highlights")
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

	game.call("_on_cell_hover_ended", inference_cell)
	assert(not hover_border.visible and not hover_border.is_processing(), "Potential mine dashed border remained after hover ended")
	if overlay.visible:
		_fail("Inference overlay remained visible after leaving the card")
		return

	var unique_cell := _prepare_unique_mine_constraint(board, game)
	if unique_cell < 0:
		_fail("Could not prepare a unique mine inference")
		return
	var unique_inference: Dictionary = board.inference_at(unique_cell)
	var mine_targets: PackedInt32Array = unique_inference["potential_mines"]
	assert(unique_inference["unique"] and not mine_targets.is_empty())
	game.call("_on_cell_revealed", unique_cell)
	await create_timer(0.35).timeout
	for target in mine_targets:
		assert(board.state_at(target) == MinesweeperBoard.CellState.FLAGGED, "Unique mine inference did not auto-mark its target")
	_test_hover_target_filtering(game, board)
	print("Inference left click and automatic mine marking: all tests passed")
	quit()


func _test_hover_target_filtering(game: Node, board: MinesweeperBoard) -> void:
	for source in range(board.width * board.height):
		if (
			board.state_at(source) != MinesweeperBoard.CellState.REVEALED
			or board.has_mine(source)
			or board.item_at(source) != MinesweeperBoard.ItemType.NONE
			or board.adjacent_mines(source) <= 0
		):
			continue
		var mine_neighbor := -1
		var safe_neighbor := -1
		for neighbor in board.neighbors_of(source):
			if board.state_at(neighbor) != MinesweeperBoard.CellState.COVERED:
				continue
			if board.has_mine(neighbor):
				mine_neighbor = neighbor
			else:
				safe_neighbor = neighbor
		if mine_neighbor < 0 or safe_neighbor < 0:
			continue
		assert(board.toggle_flag(mine_neighbor))
		board.reveal_exact_forced_safe(safe_neighbor)
		var targets: Array[int] = game.call("_inference_hover_targets_for", source)
		assert(targets.has(mine_neighbor), "Flagged mine was excluded from the hover potential area")
		assert(not targets.has(safe_neighbor), "Revealed safe cell remained in the hover potential area")
		assert(board.toggle_flag(mine_neighbor))
		assert(board.resolve_monster_core(mine_neighbor))
		targets = game.call("_inference_hover_targets_for", source)
		assert(targets.has(mine_neighbor), "Triggered revealed mine was excluded from the hover potential area")
		return
	_fail("Could not prepare hover filtering coverage")


func _prepare_unique_mine_constraint(board: MinesweeperBoard, game: Node) -> int:
	for index in range(board.width * board.height):
		if board.state_at(index) != MinesweeperBoard.CellState.REVEALED:
			continue
		var covered_mines := 0
		for neighbor in board.neighbors_of(index):
			if board.state_at(neighbor) == MinesweeperBoard.CellState.COVERED and board.has_mine(neighbor):
				covered_mines += 1
		if covered_mines == 0:
			continue
		for neighbor in board.neighbors_of(index):
			if board.state_at(neighbor) == MinesweeperBoard.CellState.COVERED and not board.has_mine(neighbor):
				board.reveal_exact_forced_safe(neighbor)
				game.call("_refresh_cell", neighbor)
		var inference: Dictionary = board.inference_at(index)
		if inference["unique"] and not (inference["potential_mines"] as PackedInt32Array).is_empty():
			return index
	return -1


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


func _test_revealed_constraints() -> void:
	var board := MinesweeperBoard.new(10, 8, 12, 314159)
	board.reveal(44)
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


func _mouse_event(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
