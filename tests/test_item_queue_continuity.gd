extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(10.0).timeout.connect(func() -> void:
		push_error("Item queue continuity test timed out")
		quit(2)
	)
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.set("_run_number", 6)
	game.call("_start_game")
	await process_frame

	var board: MinesweeperBoard = game.get("_board")
	var origin := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(origin)
	var safe_cells: Array[int] = []
	for index in range(board.width * board.height):
		if not board.has_mine(index) and board.state_at(index) == MinesweeperBoard.CellState.COVERED:
			safe_cells.append(index)
			if safe_cells.size() == 3:
				break
	assert(safe_cells.size() == 3)
	assert(board.force_item_at(safe_cells[0], MinesweeperBoard.ItemType.LANTERN, false))
	assert(board.force_item_at(safe_cells[1], MinesweeperBoard.ItemType.COMPASS, false))
	assert(board.force_item_at(safe_cells[2], MinesweeperBoard.ItemType.ORBITAL_STRIKE, false))
	var changed := PackedInt32Array()
	for index in safe_cells:
		for revealed in board.reveal_exact_forced_safe(index):
			if not changed.has(revealed):
				changed.append(revealed)
	var queue: Array[int] = []
	var queued: Dictionary = {}
	game.call("_present_revealed", changed, queue, queued)

	var black_bird := game.get_node("BlackBirdPerch") as BirdPerch
	var red_bird := game.get_node("RedBirdPerch") as BirdPerch
	var attacker_bird := game.get_node("AttackerBirdPerch") as BirdPerch
	assert(not bool(black_bird.get("_queued_departure_active")), "Bird departure queue fired synchronously during collection")
	assert(not bool(red_bird.get("_queued_departure_active")), "Redstart skipped the departure queue")
	assert(not bool(attacker_bird.get("_queued_departure_active")), "Woodpecker skipped the departure queue")
	await create_timer(0.25).timeout
	var departure_times: Array[int] = game.get("_last_bird_departure_dispatch_times")
	var departure_frames: Array[int] = game.get("_last_bird_departure_dispatch_frames")
	assert(departure_times.size() == 3, "Departure queue did not dispatch all three birds")
	assert(departure_frames.size() == 3, "Departure queue did not record all dispatch frames")
	assert(departure_frames[1] > departure_frames[0], "First and second bird effects started in the same frame")
	assert(departure_frames[2] > departure_frames[1], "Second and third bird effects started in the same frame")
	assert(bool(black_bird.get("_queued_departure_active")), "Night heron did not enter its departure action")
	assert(bool(red_bird.get("_queued_departure_active")), "Redstart did not enter its departure action")
	assert(bool(attacker_bird.get("_queued_departure_active")), "Woodpecker did not enter its departure action")
	game.call("_resolve_item_queue", queue, queued)
	await create_timer(0.5).timeout
	assert(int(game.get("_active_item_settlements")) >= 3, "Bird effects were still serialized instead of overlapping")
	var settlement_frames: Array[int] = game.get("_last_item_settlement_dispatch_frames")
	assert(settlement_frames.size() >= 3, "Settlement queue did not launch all three effects")
	assert(settlement_frames[1] > settlement_frames[0], "First and second settlement effects started in the same frame")
	assert(settlement_frames[2] > settlement_frames[1], "Second and third settlement effects started in the same frame")
	var deadline := Time.get_ticks_msec() + 8000
	while int(game.get("_active_item_settlements")) > 0 or not queue.is_empty():
		assert(Time.get_ticks_msec() < deadline, "Overlapping item queue did not settle cleanly")
		await create_timer(0.05).timeout
	assert(not bool(black_bird.get("_queued_departure_active")), "Night heron did not return after its queued events settled")
	assert(not bool(red_bird.get("_queued_departure_active")), "Redstart did not return after its queued events settled")
	assert(not bool(attacker_bird.get("_queued_departure_active")), "Woodpecker did not return after its queued events settled")

	print("Item queue continuity: short stagger, overlapping effects, and clean return passed")
	quit()
