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
	var mine_panel := game.get("_mine_counter_panel") as PanelContainer
	var board_panel := game.get("_board_panel") as PanelContainer
	var board: MinesweeperBoard = game.get("_board")
	assert(panel != null, "Remaining-item counter was never built")
	assert(panel.visible and panel.is_visible_in_tree(), "Remaining-item counter is not visible")
	assert(
		panel.global_position.y + panel.size.y < board_panel.global_position.y,
		"Remaining-item counter is not above the grid"
	)
	assert(
		panel.global_position.y >= mine_panel.global_position.y + mine_panel.size.y - 1.0,
		"Remaining-item counter should sit on the row below the remaining-mine counter"
	)

	var chips: Dictionary = game.get("_item_type_chips")
	assert(not chips.is_empty(), "Per-type item chips were not built")
	var planned_lantern := board.total_item_count_of(MinesweeperBoard.ItemType.LANTERN)
	var planned_compass := board.total_item_count_of(MinesweeperBoard.ItemType.COMPASS)
	assert(planned_lantern > 0 or planned_compass > 0, "Level 4 should hand out bird items")
	if planned_lantern > 0:
		var lantern_chip: Dictionary = chips[MinesweeperBoard.ItemType.LANTERN]
		assert(
			(lantern_chip["label"] as Label).text == "%d/%d" % [planned_lantern, planned_lantern],
			"Lantern chip did not open at full budget"
		)

	var seed_index := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(seed_index)
	await process_frame
	game.call("_refresh_item_counter", true)

	var item_index := -1
	var found_type := MinesweeperBoard.ItemType.NONE
	for index in range(board.width * board.height):
		var item_type := board.item_at(index)
		if item_type != MinesweeperBoard.ItemType.NONE and board.state_at(index) == MinesweeperBoard.CellState.COVERED:
			item_index = index
			found_type = item_type
			break
	assert(item_index >= 0, "No covered item card to dig up")

	var before := board.hidden_item_count_of(found_type)
	board.reveal_exact_forced_safe(item_index)
	await process_frame
	game.call("_refresh_item_counter", true)
	var after_label: Label = (game.get("_item_type_chips") as Dictionary)[found_type]["label"]
	assert(
		after_label.text == "%d/%d" % [before - 1, board.total_item_count_of(found_type)],
		"Per-type counter did not drop after reveal, got %s" % after_label.text
	)

	for index in range(board.width * board.height):
		if board.item_at(index) != MinesweeperBoard.ItemType.NONE:
			board.reveal_exact_forced_safe(index)
	await process_frame
	game.call("_refresh_item_counter", true)
	for item_type in (game.get("_item_type_chips") as Dictionary).keys():
		var label: Label = (game.get("_item_type_chips") as Dictionary)[item_type]["label"]
		var total := board.total_item_count_of(item_type)
		assert(
			label.text == "0/%d" % total,
			"Type %s did not settle at zero, got %s" % [item_type, label.text]
		)

	var hover_type := -1
	for item_type in (game.get("_item_type_chips") as Dictionary).keys():
		hover_type = int(item_type)
		break
	assert(hover_type >= 0, "No item chip available for hover tooltip")
	game.call("_on_item_counter_chip_hovered", hover_type)
	var tooltip := game.get("_item_tooltip") as PanelContainer
	var title := game.get("_item_tooltip_title") as Label
	var body := game.get("_item_tooltip_body") as Label
	assert(tooltip.visible, "Item-counter hover did not show the function tooltip")
	assert(not title.text.is_empty(), "Item-counter tooltip title is empty")
	assert(not body.text.is_empty(), "Item-counter tooltip body is empty")
	game.call("_on_item_counter_chip_unhovered")
	assert(not tooltip.visible, "Item-counter tooltip stayed visible after unhover")

	print("Item counter UI: per-type chips, live updates, depletion and hover tooltips passed")
	quit()
