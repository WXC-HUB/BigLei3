extends SceneTree

const CHAIN_MARKER := preload("res://assets/sprites/generated/marker_chain_special.png")
const TUTORIAL_LEVEL_COUNT := 4
const TACTICAL_ITEMS := [
	MinesweeperBoard.ItemType.XRAY,
	MinesweeperBoard.ItemType.CHAIN,
	MinesweeperBoard.ItemType.ENLARGE,
]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(8.0).timeout.connect(func() -> void:
		push_error("Tactical shop inventory test timed out")
		quit(2)
	)
	# 换到临时存档位并清空：否则本机的续关存档会把测试丢到随机的关卡进度上。
	GameSave.save_path = "user://test_tactical_shop_inventory_save.json"
	GameSave.clear()
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	# 教学关不发战术道具，先推到第一个普通关，商店买的东西才有对比基准。
	for _level in range(TUTORIAL_LEVEL_COUNT + 1):
		game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var safe_seed := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(safe_seed)
	# 各道具本来就有出场基数，所以按「买之前 → 买之后」的增量断言，而不是写死数字。
	var baseline: Dictionary = {}
	for item_type in TACTICAL_ITEMS:
		baseline[item_type] = board.item_count(item_type)

	game.set("_gold", 15)
	game.call("_choose_shop_offer", 10)
	game.call("_choose_shop_offer", 11)
	game.call("_choose_shop_offer", 12)
	assert(int(game.get("_xray_bonus")) == 1, "Shop did not add an x-ray")
	assert(int(game.get("_chain_bonus")) == 1, "Shop did not add a chain item")
	assert(int(game.get("_enlarge_bonus")) == 1, "Shop did not add an enlarge item")
	game.call("_start_game")
	board = game.get("_board")
	safe_seed = int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(safe_seed)
	for item_type in TACTICAL_ITEMS:
		assert(
			board.item_count(item_type) == int(baseline[item_type]) + 1,
			"Purchased tactical item was not added to the next board"
		)

	# 连携的标记点 A 是道具牌自己的格子，所以角标要画在那张已翻开的牌上。
	var chain_index := -1
	for index in range(board.width * board.height):
		if board.item_at(index) == MinesweeperBoard.ItemType.CHAIN:
			chain_index = index
			break
	assert(
		chain_index >= 0 and not board.reveal_exact_forced_safe(chain_index).is_empty(),
		"Could not prepare a chain anchor cell"
	)
	var chain_anchors: Array[int] = game.get("_chain_anchors")
	chain_anchors.append(chain_index)
	game.call("_refresh_cell", chain_index)
	var cells: Array[MineCell] = game.get("_cells")
	var marker := cells[chain_index].get("_marker") as TextureRect
	assert(marker.visible and marker.texture == CHAIN_MARKER, "Chain anchor did not show the special marker")
	assert(marker.modulate == Color.WHITE and marker.material == null, "Chain marker was grayed out")
	GameSave.clear()
	print("Tactical shop inventory and special chain marker passed")
	quit()
