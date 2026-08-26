extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set("_run_number", 4)
	game.call("_start_game")
	await process_frame

	var panel := game.get("_item_counter_panel") as PanelContainer
	var value := game.get("_item_label") as Label
	var mine_panel := game.get("_mine_counter_panel") as PanelContainer
	var board_panel := game.get("_board_panel") as PanelContainer
	var board: MinesweeperBoard = game.get("_board")
	assert(panel != null and value != null, "Remaining-item counter was never built")
	assert(panel.visible and panel.is_visible_in_tree(), "Remaining-item counter is not visible")
	assert(
		panel.global_position.y + panel.size.y < board_panel.global_position.y,
		"Remaining-item counter is not above the grid"
	)
	assert(
		panel.global_position.x >= mine_panel.global_position.x + mine_panel.size.x,
		"Remaining-item counter overlaps the remaining-mine counter"
	)

	var planned := board.total_item_count()
	assert(planned > 0, "Level 4 should hand out items")
	assert(
		value.text == "%d/%d" % [planned, planned],
		"Remaining-item counter did not open at the full level budget, got %s" % value.text
	)

	# Placing mines scatters the item cards; the total must survive that step.
	var seed_index := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(seed_index)
	var total := board.total_item_count()
	assert(total == planned, "Item placement changed the level total")

	var item_index := -1
	for index in range(board.width * board.height):
		if (
			board.item_at(index) != MinesweeperBoard.ItemType.NONE
			and board.state_at(index) == MinesweeperBoard.CellState.COVERED
		):
			item_index = index
			break
	assert(item_index >= 0, "No covered item card to dig up")

	board.reveal_exact_forced_safe(item_index)
	await process_frame
	assert(
		value.text == "%d/%d" % [total - 1, total],
		"Remaining-item counter did not drop after an item card was revealed, got %s" % value.text
	)

	# Digging out every item card has to land the readout on zero, not go negative.
	for index in range(board.width * board.height):
		if board.item_at(index) != MinesweeperBoard.ItemType.NONE:
			board.reveal_exact_forced_safe(index)
	await process_frame
	assert(
		value.text == "0/%d" % total,
		"Remaining-item counter did not settle at zero, got %s" % value.text
	)

	print("Item counter UI: placement, live value update and depletion passed")
	quit()
