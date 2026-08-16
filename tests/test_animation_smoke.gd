extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	_seed_item_inventory(scene)
	scene.call("_start_game")
	var board: MinesweeperBoard = scene.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	scene.call("_on_cell_revealed", center)
	await _wait_for_resolution(scene)

	var orbital_index := _find_item(board, MinesweeperBoard.ItemType.ORBITAL_STRIKE)
	assert(orbital_index >= 0)
	if not board.is_item_used(orbital_index):
		scene.call("_on_cell_revealed", orbital_index)
		await _wait_for_resolution(scene)
	assert(board.is_item_used(orbital_index))
	var orbital_row: int = orbital_index / board.width
	for column in range(board.width):
		assert(board.state_at(orbital_row * board.width + column) != MinesweeperBoard.CellState.COVERED)

	var luck_index := _find_item(board, MinesweeperBoard.ItemType.SUPER_LUCK)
	assert(luck_index >= 0)
	if not board.is_item_used(luck_index):
		scene.call("_on_cell_revealed", luck_index)
		await _wait_for_resolution(scene)
	assert(bool(scene.call("_is_invincible")))
	var hp_before: int = scene.get("_player_hp")

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
	assert(int(scene.get("_player_hp")) == hp_before, "Invincibility did not block small-monster damage")
	assert(board.state_at(triggered_small) == MinesweeperBoard.CellState.FLAGGED, "Invincibility did not mark the small monster")
	var large_core_count := 0
	for index in range(board.width * board.height):
		if board.is_monster_core(index) and board.monster_peripheral_count(index) == 8:
			large_core_count += 1
	assert(large_core_count == 0, "Large 3x3 mines must not be generated")

	print("Animation flow: smoke test passed")
	quit()


func _seed_item_inventory(game: Node) -> void:
	game.set("_orbital_strike_bonus", 2)
	game.set("_super_luck_bonus", 2)


func _find_item(board: MinesweeperBoard, type: MinesweeperBoard.ItemType) -> int:
	for index in range(board.width * board.height):
		if board.item_at(index) == type:
			return index
	return -1


func _wait_for_resolution(scene: Node) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while bool(scene.get("_resolving")):
		assert(Time.get_ticks_msec() < deadline, "Animation resolution timed out")
		await create_timer(0.05).timeout
	await create_timer(0.08).timeout
