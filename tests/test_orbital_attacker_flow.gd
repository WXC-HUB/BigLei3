extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(5.0).timeout.connect(func() -> void:
		push_error("Orbital attacker flow timed out")
		quit(2)
	)
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.set("_run_number", 4)
	game.set("_attacker_bird_unlocked", true)
	game.set("_orbital_strike_bonus", 1)
	game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var item_index := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(item_index)
	var row := int(item_index / board.width)
	var first_index := row * board.width
	var last_index := first_index + board.width - 1
	var bird := game.get_node("AttackerBirdPerch") as BirdPerch
	var sprite := bird.get_node("Sprite") as TextureRect
	var home := sprite.position
	var empty_queue: Array[int] = []
	game.set("_orbital_orientation_override", 0)
	game.call("_resolve_orbital_strike", item_index, empty_queue, {})
	await process_frame
	assert(not bool(game.get("_last_orbital_vertical")), "Horizontal test override was ignored")
	for target in range(first_index, last_index + 1):
		var cells: Array = game.get("_cells")
		var overlay := cells[target].get("_preview_overlay") as Panel
		assert(overlay.visible, "Target row border did not flash")
	assert((bird.get_node("TriggerSFX") as AudioStreamPlayer).playing, "Attacker trigger audio did not play")
	await create_timer(0.47).timeout
	assert(board.state_at(last_index) != MinesweeperBoard.CellState.COVERED, "Rightmost cell was not attacked first")
	assert(board.state_at(first_index) == MinesweeperBoard.CellState.COVERED, "Leftmost cell opened before the sweep reached it")
	assert(int(game.get("_last_orbital_step")) == last_index)
	assert((bird.get_node("ActionSFX") as AudioStreamPlayer).playing, "Peck audio did not trigger with _zhuo")
	assert(sprite.texture == bird.action_frames[1], "Peck sweep inserted a non-peck frame")
	var draw_scale := sprite.get_global_transform().get_scale()
	var sprite_center := sprite.global_position + sprite.size * draw_scale * 0.5
	var expected_center: Vector2 = game.call("_cell_center", last_index) + Vector2(0, -176.0)
	assert(absf(sprite_center.y - expected_center.y) < 2.0, "Peck sprite was not shifted upward by the additional cell")
	await create_timer(0.15).timeout
	assert(sprite.texture == bird.action_frames[1], "Peck frame changed between cells")
	await create_timer(0.97).timeout
	for target in range(first_index, last_index + 1):
		assert(board.state_at(target) != MinesweeperBoard.CellState.COVERED, "Attacker did not open or flag the full row")
	assert(int(game.get("_last_orbital_step")) == first_index)
	await create_timer(0.45).timeout
	assert(not bool(bird.get("_acting")))
	assert(sprite.position.is_equal_approx(home))
	print("Orbital attacker flow: right entry, right-to-left pecks, and return passed")
	quit()
