extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.set("_run_number", 4)
	game.set("_red_bird_unlocked", true)
	game.set("_compass_bonus", 1)
	game.set("_compass_mark_bonus", 1)
	game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.reveal(center)
	var empty_queue: Array[int] = []
	game.call("_resolve_compass", center, empty_queue, {})
	await process_frame
	var target: int = game.get("_last_compass_target")
	assert(target >= 0)
	assert(int(game.get("_last_dashed_line_target_count")) == 2, "Redstart upgrade did not lock two mine targets")
	var cells: Array = game.get("_cells")
	var target_overlay := cells[target].get("_preview_overlay") as Panel
	assert(target_overlay.visible, "Compass border did not flash as the bird left its perch")
	assert(board.state_at(target) == MinesweeperBoard.CellState.COVERED)
	await create_timer(1.05).timeout
	assert(int(game.get("_last_dashed_line_target_count")) == 2, "Redstart did not draw both target lines")
	assert(target_overlay.visible, "Compass target border did not flash")
	assert(board.state_at(target) == MinesweeperBoard.CellState.COVERED, "Target opened before the bird passed it")
	await create_timer(0.5).timeout
	assert(board.state_at(target) == MinesweeperBoard.CellState.FLAGGED, "Redstart did not mark the guaranteed mine after flyover")
	assert(board.flag_count() == 2, "Redstart mark-count upgrade did not mark two mines")
	assert(int(game.get("_last_compass_flyover_count")) == 2, "Redstart did not create one flyover bird per marked mine")
	await create_timer(0.6).timeout
	var red_bird := game.get_node("RedBirdPerch") as BirdPerch
	assert((red_bird.get_node("Sprite") as TextureRect).visible, "Red bird did not return to its perch")
	print("Compass red bird flow: launch, flyover, reveal, and return passed")
	quit()
