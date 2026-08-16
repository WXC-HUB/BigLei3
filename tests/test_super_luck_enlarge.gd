extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void:
		push_error("Super luck enlarge test timed out")
		quit(2)
	)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	for _level in range(3):
		game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var safe_seed := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(safe_seed)

	var target_pair := _find_mine_with_safe_neighbor(board)
	assert(target_pair.size() == 2, "Could not find a mine and nearby safe item cell")
	var mine_index := target_pair[0]
	var item_index := target_pair[1]
	var area: Array[int] = game.call("_area_3x3_targets", mine_index)
	for target in area:
		if not board.is_monster_core(target):
			board.force_item_at(target, MinesweeperBoard.ItemType.NONE, false)
	assert(board.force_item_at(item_index, MinesweeperBoard.ItemType.MEDICAL_KIT, false), "Could not place delayed medical item")
	game.call("_refresh_cell", item_index)
	game.set("_player_hp", 1)
	game.call("_refresh_health_bar")
	game.set("_enlarge_mark_charges", 1)
	await game.call("_enter_super_luck_mode", 2)
	await process_frame
	var watermark := game.get("_super_luck_watermark") as CenterContainer
	var watermark_count := game.get("_super_luck_watermark_count") as Label
	assert(watermark.visible, "Super luck did not show its board watermark")
	assert(watermark.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Super luck watermark blocks board input")
	assert((watermark.get_node("Stack/Title") as Label).text == "无敌次数", "Super luck watermark title is incorrect")
	assert(watermark_count.text == "2", "Super luck watermark did not show the initial click count")
	var cells: Array = game.get("_cells")
	var lucky_border := cells[item_index].get("_super_luck_border") as Control
	game.call("_on_cell_hover_started", item_index)
	assert(lucky_border.visible and lucky_border.is_processing(), "Lucky hover did not immediately show the rotating dashed border")
	game.call("_on_cell_hover_ended", item_index)
	assert(not lucky_border.visible, "Lucky hover border remained after the pointer left")

	var clicks_before: int = game.get("_super_luck_clicks_remaining")
	game.call("_on_cell_revealed", mine_index)
	await _wait_until_not_resolving(game)
	assert(board.state_at(mine_index) == MinesweeperBoard.CellState.FLAGGED, "Enlarge detonated a mine during super luck")
	var defeated: Dictionary = game.get("_defeated_mines")
	assert(not defeated.has(mine_index), "Super luck enlarge registered the mine as defeated")
	assert(int(game.get("_player_hp")) == 1, "Super luck enlarge dealt damage")
	assert(board.state_at(item_index) == MinesweeperBoard.CellState.REVEALED, "Enlarge did not reveal the item cell")
	assert(not board.is_item_used(item_index), "Enlarge settled its item before super luck ended")
	var deferred: Array[int] = game.get("_super_luck_deferred_indices")
	assert(deferred.has(item_index), "Enlarge item was not added to the super luck deferred queue")
	assert(lucky_border.visible and lucky_border.is_processing(), "Deferred lucky card did not show a rotating dashed border")
	var lucky_border_color: Color = lucky_border.get("border_color")
	assert(lucky_border_color.g > 0.8, "Deferred lucky card border was not green")
	assert(int(game.get("_super_luck_clicks_remaining")) == clicks_before - 1, "Enlarge did not consume exactly one lucky click")
	await process_frame
	assert(watermark_count.text == "1", "Super luck watermark did not update after a click")

	game.call("_consume_super_luck_click")
	await _wait_until_super_luck_settled(game)
	assert(not watermark.visible, "Super luck watermark remained after the mode ended")
	assert(board.is_item_used(item_index), "Deferred enlarge item did not settle after super luck")
	assert(not lucky_border.visible and not lucky_border.is_processing(), "Lucky dashed border remained after settlement")
	assert(int(game.get("_player_hp")) == 2, "Deferred medical item did not heal after settlement")
	print("Super luck enlarge: mines mark safely and items settle later passed")
	quit()


func _find_mine_with_safe_neighbor(board: MinesweeperBoard) -> PackedInt32Array:
	var total_covered_mines := 0
	for index in range(board.width * board.height):
		if board.is_monster_core(index) and board.state_at(index) == MinesweeperBoard.CellState.COVERED:
			total_covered_mines += 1
	if total_covered_mines < 2:
		return PackedInt32Array()
	for mine_index in range(board.width * board.height):
		if not board.is_monster_core(mine_index) or board.state_at(mine_index) != MinesweeperBoard.CellState.COVERED:
			continue
		var area_mines := 0
		for target in board.neighbors_of(mine_index):
			if board.is_monster_core(target):
				area_mines += 1
		for neighbor in board.neighbors_of(mine_index):
			if (
				not board.is_monster_core(neighbor)
				and board.state_at(neighbor) == MinesweeperBoard.CellState.COVERED
				and area_mines + 1 < total_covered_mines
			):
				return PackedInt32Array([mine_index, neighbor])
	return PackedInt32Array()


func _wait_until_not_resolving(game: Node) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while bool(game.get("_resolving")) and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not bool(game.get("_resolving")), "Enlarge resolution did not finish")


func _wait_until_super_luck_settled(game: Node) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while (
		bool(game.get("_super_luck_mode_active"))
		or bool(game.get("_super_luck_settling"))
		or bool(game.get("_resolving"))
	) and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not bool(game.get("_super_luck_mode_active")), "Super luck mode did not end")
	assert(not bool(game.get("_super_luck_settling")), "Super luck settlement did not finish")
	assert(not bool(game.get("_resolving")), "Game remained resolving after super luck settlement")
