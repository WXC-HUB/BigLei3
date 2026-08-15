extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	scene.call("_on_cell_revealed", 44)
	await _wait_for_resolution(scene)
	var board: MinesweeperBoard = scene.get("_board")

	var triggered_small := -1
	for index in range(board.width * board.height):
		if (
			board.is_monster_core(index)
			and board.monster_peripheral_count(index) == 0
			and board.state_at(index) != MinesweeperBoard.CellState.REVEALED
		):
			triggered_small = index
			break
	assert(triggered_small >= 0)
	if board.state_at(triggered_small) == MinesweeperBoard.CellState.FLAGGED:
		scene.call("_on_cell_flagged", triggered_small)
	scene.call("_on_cell_revealed", triggered_small)
	await _wait_for_resolution(scene)
	var cells: Array[MineCell] = scene.get("_cells")
	assert(cells[triggered_small].is_showing_corpse(), "Defeated small monster did not leave a corpse")

	var big_core := -1
	for index in range(board.width * board.height):
		if board.is_monster_core(index) and board.monster_peripheral_count(index) == 8:
			big_core = index
			break
	assert(big_core >= 0)
	if board.state_at(big_core) == MinesweeperBoard.CellState.FLAGGED:
		scene.call("_on_cell_flagged", big_core)
	scene.call("_on_cell_revealed", big_core)
	await _wait_for_resolution(scene)

	print("Animation flow: smoke test passed")
	quit()


func _wait_for_resolution(scene: Node) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while bool(scene.get("_resolving")):
		assert(Time.get_ticks_msec() < deadline, "Animation resolution timed out")
		await create_timer(0.05).timeout
	await create_timer(0.08).timeout
