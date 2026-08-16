extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.set("_lantern_bonus", 1)
	game.set("_compass_bonus", 1)
	game.set("_orbital_strike_bonus", 1)
	game.set("_super_luck_bonus", 1)
	game.set("_medical_kit_bonus", 1)
	game.set("_xray_bonus", 1)
	game.set("_chain_bonus", 1)
	game.set("_enlarge_bonus", 1)
	game.call("_start_game")
	game.call("_start_game")
	game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	var detect_slot := _find_empty_safe_cell(board)
	assert(detect_slot >= 0 and board.force_item_at(detect_slot, MinesweeperBoard.ItemType.DETECT, false), "Could not prepare detect item")
	var cells: Array = game.get("_cells")
	for item_type in [
		MinesweeperBoard.ItemType.LANTERN,
		MinesweeperBoard.ItemType.COMPASS,
		MinesweeperBoard.ItemType.ORBITAL_STRIKE,
		MinesweeperBoard.ItemType.SUPER_LUCK,
		MinesweeperBoard.ItemType.MEDICAL_KIT,
		MinesweeperBoard.ItemType.XRAY,
		MinesweeperBoard.ItemType.CHAIN,
		MinesweeperBoard.ItemType.ENLARGE,
		MinesweeperBoard.ItemType.DETECT,
	]:
		var item_index := _find_item(board, item_type)
		assert(item_index >= 0, "Test board is missing item type %d" % item_type)
		board.reveal_exact_forced_safe(item_index)
		game.call("_refresh_cell", item_index)
		var content := cells[item_index].get("_content") as TextureRect
		assert(content.material == null, "Unused item type %d was already grayed out" % item_type)
		board.consume_item(item_index)
		game.call("_refresh_cell", item_index)
		var expected := game.call("_item_texture", item_type) as Texture2D
		assert(content.visible, "Used item type %d disappeared" % item_type)
		assert(content.texture == expected, "Used item type %d changed its texture" % item_type)
		assert(content.material is ShaderMaterial, "Used item type %d was not grayed out" % item_type)
		var queue: Array[int] = []
		var queued: Dictionary = {}
		game.call("_present_revealed", PackedInt32Array([item_index]), queue, queued)
		assert(queue.is_empty(), "Used item type %d was queued for a second activation" % item_type)
	print("Used item display: all item icons persist without reactivation passed")
	quit()


func _find_item(board: MinesweeperBoard, type: MinesweeperBoard.ItemType) -> int:
	for index in range(board.width * board.height):
		if board.item_at(index) == type:
			return index
	return -1


func _find_empty_safe_cell(board: MinesweeperBoard) -> int:
	for index in range(board.width * board.height):
		if not board.has_mine(index) and board.item_at(index) == MinesweeperBoard.ItemType.NONE:
			return index
	return -1
