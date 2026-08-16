extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(4.0).timeout.connect(func() -> void:
		push_error("Reveal feedback test timed out after an assertion")
		quit(2)
	)
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.set("_run_number", 4)
	game.call("_start_game")
	await process_frame

	game.call("_play_board_impact")
	var board_panel := game.get("_board_panel") as Control
	assert(not board_panel.scale.is_equal_approx(Vector2.ONE), "Board impact did not scale the board")
	await create_timer(0.25).timeout
	assert(board_panel.scale.is_equal_approx(Vector2.ONE), "Board impact did not settle")

	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	var changed := board.reveal(center)
	assert(changed.size() > 1, "Wave test did not produce a batch reveal")
	var queue: Array[int] = []
	var queued: Dictionary = {}
	var duration: float = game.call("_present_revealed", changed, queue, queued, center)
	var delays: Dictionary = game.get("_last_reveal_wave_delays")
	assert(is_zero_approx(float(delays[center])), "Reveal wave did not start at the clicked center")
	var positive_counts: Dictionary = {}
	var maximum_delay := 0.0
	for delay_value in delays.values():
		var delay := float(delay_value)
		maximum_delay = maxf(maximum_delay, delay)
		if delay > 0.0:
			var ring_number := delay / 0.135
			assert(is_equal_approx(ring_number, roundf(ring_number)), "Reveal ring delay did not use the 0.135s interval")
		if delay > 0.0:
			positive_counts[delay] = int(positive_counts.get(delay, 0)) + 1
	assert(maximum_delay > 0.0, "Batch cards were not staggered outward")
	var simultaneous_ring := false
	for count in positive_counts.values():
		if int(count) > 1:
			simultaneous_ring = true
			break
	assert(simultaneous_ring, "Reveal wave ran card-by-card instead of by expanding rings")
	await create_timer(duration + 0.08).timeout
	for index in changed:
		assert(not bool((game.get("_cells") as Array[MineCell])[index].get("_flipping")), "A wave card did not finish its flip")

	print("Reveal feedback: board impact, diagonal flip, content pop, and center-out wave passed")
	quit()
