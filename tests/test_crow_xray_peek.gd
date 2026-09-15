extends SceneTree
## 透视 → 小嘴乌鸦：普通关默认带一张；翻出来后乌鸦缩小飞到随机一格旁边掀开偷看，
## 顿一拍就地消失回栖位，那一格的内容自己留着亮满 3 秒，全程不翻开它。

const TUTORIAL_LEVEL_COUNT := 8


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("Crow x-ray peek test timed out")
		quit(2)
	)
	GameSave.save_path = "user://test_crow_xray_peek_save.json"
	GameSave.clear()
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var crow := game.get_node("CrowBirdPerch") as BirdPerch
	var sprite := crow.get_node("Sprite") as TextureRect

	game.call("_start_game")
	assert(not crow.visible, "Crow perch showed up before it was unlocked")
	game.set("_crow_bird_unlocked", true)
	for _level in range(TUTORIAL_LEVEL_COUNT):
		game.call("_start_game")
	assert(crow.visible, "Crow perch stayed hidden after unlocking")
	var board: MinesweeperBoard = game.get("_board")
	var centre := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(centre)
	assert(board.item_count(MinesweeperBoard.ItemType.XRAY) == 1, "Normal level does not carry exactly one crow card")
	assert(game.call("_item_display_name", MinesweeperBoard.ItemType.XRAY) == "小嘴乌鸦", "X-ray item was not renamed")

	var card := _find_item_index(board, MinesweeperBoard.ItemType.XRAY)
	assert(card >= 0, "Crow card is missing from the board")
	var home := sprite.position
	board.reveal_exact_forced_safe(card)
	game.call("_refresh_cell", card)
	var queue: Array[int] = []
	var queued: Dictionary = {}
	game.call("_resolve_queued_item", card, MinesweeperBoard.ItemType.XRAY, queue, queued)

	# 掀开的那一刻：乌鸦离开栖位、用动作帧、凑在被偷看的那一格边上，格子亮着但没翻开。
	await create_timer(0.72).timeout
	var target := int(game.get("_last_xray_target"))
	assert(target >= 0, "The crow did not choose a cell to peek at")
	assert(sprite.visible and not sprite.position.is_equal_approx(home), "Crow did not leave its perch")
	assert(crow.action_frames.has(sprite.texture), "Crow is not using an action frame while peeking")
	var sprite_centre := crow.get_launch_global_position()
	var cell_centre: Vector2 = game.call("_cell_center", target)
	var cell: float = game.get("CELL_SIZE")
	# 它得凑在那一格旁边，但绝不能蹲在格子正上方——这只鸟比一格大好几倍，压上去就把
	# 本来要给玩家看的内容挡住了。
	assert(sprite_centre.distance_to(cell_centre) < cell * 2.4, "Crow is not next to its target cell: %s vs %s" % [sprite_centre, cell_centre])
	assert(absf(sprite_centre.x - cell_centre.x) > cell * 0.6, "Crow parked on top of the cell it is meant to be showing")
	# 下了棋盘就得缩到一格上下，不然一只鸟横跨三格，挡的比露的多。
	var drawn := sprite.size.x * sprite.get_global_transform().get_scale().x
	assert(drawn < cell * 2.0, "Crow is still board-sized while working: %.0fpx against a %.0fpx cell" % [drawn, cell])
	assert(board.state_at(target) != MinesweeperBoard.CellState.REVEALED, "Peeking flipped the cell open")
	var cells: Array[MineCell] = game.get("_cells")
	var hint := cells[target].get("_xray_hint") as TextureRect
	var hint_number := cells[target].get("_xray_number") as Label
	assert((hint != null and hint.visible) or (hint_number != null and hint_number.visible), "The peeked cell is not showing its content")
	# 亮着的这几秒棋盘不该被锁住。
	assert(not bool(game.get("_resolving")), "The board stayed locked while the content was on show")

	# 掀完就走：鸟先消失回栖位，内容自己留在那儿继续亮——它不该杵着陪看完 3 秒。
	await create_timer(1.0).timeout
	assert(sprite.visible and sprite.position.is_equal_approx(home), "Crow did not leave the board right after the peek")
	assert(crow.idle_frames.has(sprite.texture), "Crow did not resume idling")
	assert(not sprite.flip_h, "Crow kept a travel flip after returning home")
	assert(sprite.scale.is_equal_approx(Vector2.ONE), "Crow stayed shrunk after coming home")
	assert((hint != null and hint.visible) or (hint_number != null and hint_number.visible), "The content vanished with the bird instead of staying up")

	# 3 秒到了内容才收掉。
	await create_timer(2.6).timeout
	assert(not hint.visible and not hint_number.visible, "The peeked content did not disappear after 3 seconds")
	GameSave.clear()
	print("Crow x-ray peek: perch visibility, fly-in, a cell-sized peek, prompt exit and lingering content passed")
	quit()


func _find_item_index(board: MinesweeperBoard, type: MinesweeperBoard.ItemType) -> int:
	for index in range(board.width * board.height):
		if board.item_at(index) == type:
			return index
	return -1
