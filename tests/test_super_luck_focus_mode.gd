extends SceneTree

const BoardModel := preload("res://scripts/game/minesweeper_board.gd")
const EG_FLY := preload("res://my_asset/birds/eg_fly_big.png")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(8.0).timeout.connect(func() -> void:
		push_error("Super luck focus mode test did not reach quit")
		quit(2)
	)
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_start_game")
	game.call("_start_game")
	game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	var small_mine := _find_covered_small_mine(board)
	assert(small_mine >= 0, "Test board has no covered small monster")
	var bird_names := ["BlueBirdPerch", "RedBirdPerch", "BlackBirdPerch", "AttackerBirdPerch"]
	var expected_visible: Dictionary = {}
	for bird_name in bird_names:
		expected_visible[bird_name] = (game.get_node(bird_name) as Control).is_visible_in_tree()

	game.call("_enter_super_luck_mode", 2)
	await create_timer(0.48).timeout
	assert(bool(game.get("_super_luck_mode_active")), "Super luck focus mode did not start")
	game.call("_on_cell_revealed", small_mine)
	await create_timer(0.1).timeout
	assert(_find_small_eg_flyer(game) != null, "A small EG flyer did not cross the clicked cell")
	assert(int(game.get("_super_luck_click_fly_count")) == 1, "Click flyover count is incorrect")
	await _wait_until_not_resolving(game, 2.0)
	assert(_find_small_eg_flyer(game) != null, "Small EG flyover blocked cell resolution")
	assert(board.state_at(small_mine) == BoardModel.CellState.FLAGGED, "Left-clicked mine was not marked")
	assert(int(game.get("_super_luck_clicks_remaining")) == 1, "First click did not consume one charge")
	var defeated: Dictionary = game.get("_defeated_mines")
	assert(not defeated.has(small_mine), "Marked monster was incorrectly revealed or resolved")
	await create_timer(0.7).timeout
	assert(_find_small_eg_flyer(game) == null, "Small EG flyer did not leave the screen")
	await _spend_remaining_clicks(game, board)

	await _wait_until_mode_settled(game, 25.0)
	defeated = game.get("_defeated_mines")
	assert(board.state_at(small_mine) == BoardModel.CellState.FLAGGED, "Marked mine changed state after focus mode")
	assert(not defeated.has(small_mine), "Marked mine was incorrectly resolved after focus mode")
	for bird_name in bird_names:
		if not bool(expected_visible[bird_name]):
			continue
		var bird_sprite := game.get_node(NodePath(bird_name + "/Sprite")) as TextureRect
		var branch := game.get_node(NodePath(bird_name + "/Tree")) as TextureRect
		assert(bird_sprite.is_visible_in_tree(), "%s did not return after focus mode" % bird_name)
		assert(branch.is_visible_in_tree(), "%s branch did not return after focus mode" % bird_name)
	print("Super luck focus mode: left-click mine marking, full flyover, and bird return passed")
	quit()


func _find_covered_small_mine(board: MinesweeperBoard) -> int:
	for index in range(board.width * board.height):
		if (
			board.is_monster_core(index)
			and board.monster_peripheral_count(index) == 0
			and board.state_at(index) == BoardModel.CellState.COVERED
		):
			return index
	return -1


func _find_small_eg_flyer(game: Node) -> TextureRect:
	var effects_layer := game.get("_effects_layer") as Control
	for child in effects_layer.get_children():
		if (
			child is TextureRect
			and (child as TextureRect).texture == EG_FLY
			and (child as TextureRect).size.x < 200.0
		):
			return child as TextureRect
	return null


func _spend_remaining_clicks(game: Node, board: MinesweeperBoard) -> void:
	while int(game.get("_super_luck_clicks_remaining")) > 0:
		var target := -1
		for index in range(board.width * board.height):
			if board.state_at(index) == BoardModel.CellState.COVERED:
				target = index
				break
		assert(target >= 0, "No covered cell remained to spend super luck clicks")
		# Each click uses a fresh covered cell because a wrong mark now reveals and
		# permanently destroys that cell instead of leaving a removable flag.
		game.call("_on_cell_flagged", target)
		await process_frame


func _wait_until_not_resolving(game: Node, timeout_seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while bool(game.get("_resolving")) and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not bool(game.get("_resolving")), "Cell click did not finish in time")


func _wait_until_mode_settled(game: Node, timeout_seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while (
		(bool(game.get("_super_luck_mode_active")) or bool(game.get("_super_luck_settling")))
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	assert(not bool(game.get("_super_luck_mode_active")), "Focus mode did not end in time")
	assert(not bool(game.get("_super_luck_settling")), "Deferred settlement did not finish in time")
