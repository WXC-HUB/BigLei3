extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := "scene setup"
	create_timer(5.0).timeout.connect(func() -> void:
		push_error("Medical kit test timed out during: %s" % stage)
		quit(2)
	)
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.set("_medical_kit_bonus", 3)
	game.set("_run_number", 4)
	game.call("_start_game")
	stage = "mine placement"
	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	var medical_kits := _find_items(board, MinesweeperBoard.ItemType.MEDICAL_KIT)
	assert(medical_kits.size() >= 3, "Main board did not place enough medical kits")
	var player_status := game.get("_player_status") as PlayerStatus
	assert(int(game.get("_player_hp")) == 3, "Initial HP is not 3")
	assert(player_status.heart_count() == 3, "Heart HUD did not start full")
	assert(player_status.maximum_heart_count() == 3, "Heart HUD maximum is not 3")

	game.set("_player_hp", 1)
	game.call("_refresh_health_bar")
	stage = "first medical kit"
	await _resolve_item(game, board, medical_kits[0])
	assert(int(game.get("_player_hp")) == 2, "Medical kit did not restore exactly 1 HP")
	assert(player_status.heart_count() == 2, "Heart HUD did not show restored HP")

	game.set("_healing_power_bonus", 1)
	game.set("_player_hp", 1)
	game.call("_refresh_health_bar")
	stage = "upgraded medical kit"
	await _resolve_item(game, board, medical_kits[1])
	assert(int(game.get("_player_hp")) == 3, "Healing upgrade did not add 1 HP to the trigger")

	game.set("_player_hp", 3)
	game.call("_refresh_health_bar")
	stage = "full-health medical kit"
	await _resolve_item(game, board, medical_kits[2])
	assert(int(game.get("_player_hp")) == 3, "Medical kit exceeded maximum HP")
	assert(player_status.heart_count() == 3, "Heart HUD exceeded its maximum")
	print("Medical kit and three-heart HUD passed")
	quit()


func _resolve_item(game: Node, board: MinesweeperBoard, item_index: int) -> void:
	board.reveal_exact_forced_safe(item_index)
	game.call("_refresh_cell", item_index)
	var queue: Array[int] = []
	var queued: Dictionary = {}
	game.call(
		"_resolve_queued_item",
		item_index,
		MinesweeperBoard.ItemType.MEDICAL_KIT,
		queue,
		queued
	)
	await create_timer(0.75).timeout
	assert(board.is_item_used(item_index), "Medical kit was not consumed")


func _find_items(board: MinesweeperBoard, type: MinesweeperBoard.ItemType) -> Array[int]:
	var result: Array[int] = []
	for index in range(board.width * board.height):
		if board.item_at(index) == type:
			result.append(index)
	return result
