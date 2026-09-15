extends SceneTree

const TUTORIAL_LEVEL_COUNT := 8
## 连携不在这张表里：它买到的是「本盘多一颗连携雷」，不是多一张埋在草地下的牌。
const TACTICAL_ITEMS := [
	MinesweeperBoard.ItemType.XRAY,
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
	var chain_baseline := board.chain_mine_total()

	game.set("_gold", 15)
	game.call("_choose_shop_offer", 10)
	game.call("_choose_shop_offer", 11)
	game.call("_choose_shop_offer", 12)
	assert(int(game.get("_xray_bonus")) == 1, "Shop did not add an x-ray")
	assert(int(game.get("_chain_bonus")) == 1, "Shop did not add a chain mine")
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

	# 连携买到的是「本盘多一颗连携雷」：组变大，盘上依旧没有连携的道具牌。
	assert(
		board.chain_mine_total() == chain_baseline + 1,
		"Purchased chain upgrade did not grow the chain mine group"
	)
	assert(
		board.covered_chain_mines().size() == chain_baseline + 1,
		"Chain group was not actually laid onto the board"
	)
	assert(
		board.item_count(MinesweeperBoard.ItemType.CHAIN) == 0,
		"Chain upgrade dealt an item card instead of marking mines"
	)
	GameSave.clear()
	print("Tactical shop inventory: bought cards land on the next board, chain upgrade grows the mine group")
	quit()
