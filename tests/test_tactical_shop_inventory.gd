extends SceneTree

const CHAIN_MARKER := preload("res://assets/sprites/generated/marker_chain_special.png")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(8.0).timeout.connect(func() -> void:
		push_error("Tactical shop inventory test timed out")
		quit(2)
	)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	for _level in range(5):
		game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var safe_seed := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(safe_seed)
	for item_type in [
		MinesweeperBoard.ItemType.XRAY,
		MinesweeperBoard.ItemType.CHAIN,
		MinesweeperBoard.ItemType.ENLARGE,
	]:
		assert(board.item_count(item_type) == 0, "Tactical item did not start at zero")

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
	for item_type in [
		MinesweeperBoard.ItemType.XRAY,
		MinesweeperBoard.ItemType.CHAIN,
		MinesweeperBoard.ItemType.ENLARGE,
	]:
		assert(board.item_count(item_type) == 1, "Purchased tactical item was not added to the next board")

	var mine_index := board.random_hidden_mine_cell()
	assert(mine_index >= 0 and board.toggle_flag(mine_index), "Could not prepare a chain-marked mine")
	var chain_marked: Array[int] = game.get("_chain_marked_mines")
	chain_marked.append(mine_index)
	game.call("_refresh_cell", mine_index)
	var cells: Array[MineCell] = game.get("_cells")
	var marker := cells[mine_index].get("_marker") as TextureRect
	assert(marker.texture == CHAIN_MARKER, "Chain mine still used the regular flag marker")
	assert(marker.modulate == Color.WHITE and marker.material == null, "Chain marker was grayed out")
	print("Tactical shop inventory and special chain marker passed")
	quit()
