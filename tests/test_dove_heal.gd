extends SceneTree
## 治愈 → 斑鸠：普通关默认带一张；翻出来后斑鸠缩小直飞血条，爱心在它抵达的那一刻才回、
## 同时飘一个「+N」，然后就地淡出回栖位。

const TUTORIAL_LEVEL_COUNT := 8


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("Dove heal test timed out")
		quit(2)
	)
	GameSave.save_path = "user://test_dove_heal_save.json"
	GameSave.clear()
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var dove := game.get_node("DoveBirdPerch") as BirdPerch
	var sprite := dove.get_node("Sprite") as TextureRect

	game.call("_start_game")
	assert(not dove.visible, "Dove perch showed up before it was unlocked")
	game.set("_dove_bird_unlocked", true)
	for _level in range(TUTORIAL_LEVEL_COUNT):
		game.call("_start_game")
	assert(dove.visible, "Dove perch stayed hidden after unlocking")
	var board: MinesweeperBoard = game.get("_board")
	board.ensure_mines_placed(int(board.height / 2) * board.width + int(board.width / 2))
	assert(board.item_count(MinesweeperBoard.ItemType.MEDICAL_KIT) == 1, "Normal level does not carry exactly one dove card")
	assert(game.call("_item_display_name", MinesweeperBoard.ItemType.MEDICAL_KIT) == "斑鸠", "Medical kit was not renamed")

	var card := -1
	for index in range(board.width * board.height):
		if board.item_at(index) == MinesweeperBoard.ItemType.MEDICAL_KIT:
			card = index
			break
	assert(card >= 0, "Dove card is missing from the board")
	var home := sprite.position
	game.set("_player_hp", 1)
	game.call("_refresh_health_bar")
	board.reveal_exact_forced_safe(card)
	game.call("_refresh_cell", card)
	var queue: Array[int] = []
	var queued: Dictionary = {}
	game.call("_resolve_queued_item", card, MinesweeperBoard.ItemType.MEDICAL_KIT, queue, queued)

	# 起飞这一段：鸟离开栖位、缩小了、用的是动作帧，爱心还没回。
	await create_timer(0.35).timeout
	assert(sprite.visible and not sprite.position.is_equal_approx(home), "Dove did not leave its perch")
	assert(dove.action_frames.has(sprite.texture), "Dove is not using an action frame in flight")
	var cell: float = game.get("CELL_SIZE")
	var drawn := sprite.size.x * sprite.get_global_transform().get_scale().x
	assert(drawn < cell * 2.0, "Dove is still perch-sized on the board: %.0fpx against a %.0fpx cell" % [drawn, cell])
	assert(int(game.get("_player_hp")) == 1, "Hearts came back before the dove had delivered anything")

	# 抵达血条：爱心才回，并且飘一个字出来。
	await create_timer(0.5).timeout
	assert(int(game.get("_player_hp")) > 1, "The dove reached the health bar but no heart came back")
	var floated := ""
	for child in (game.get("_effects_layer") as CanvasItem).get_children():
		if child is Label:
			floated = (child as Label).text
	assert(floated.begins_with("+"), "Healing did not float a number over the health bar: %s" % floated)
	var bar := game.get("_health_bar") as Control
	var bar_centre := bar.global_position + bar.size * 0.5
	# 用栖位自己的换算：飞行中 Sprite 还带着缩小的 scale，自己乘一遍会算歪。
	var dove_centre := dove.get_launch_global_position()
	assert(dove_centre.distance_to(bar_centre) < 160.0, "The dove did not fly to the health bar itself: %s vs %s" % [dove_centre, bar_centre])

	# 递完就走：淡出、回栖位、恢复原来的大小。
	await create_timer(1.1).timeout
	assert(sprite.visible and sprite.position.is_equal_approx(home), "Dove did not return to its perch")
	assert(dove.idle_frames.has(sprite.texture), "Dove did not resume idling")
	assert(sprite.scale.is_equal_approx(Vector2.ONE), "Dove stayed shrunk after coming home")
	# 栖位上的斑鸠是左右颠倒摆的，所以归位之后 flip_h 应该回到 true 而不是 false。
	assert(sprite.flip_h, "Dove did not get its perch facing back after returning home")
	GameSave.clear()
	print("Dove heal: perch visibility, straight flight, hearts and float text on arrival, and return passed")
	quit()
