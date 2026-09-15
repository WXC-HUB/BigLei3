extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(10.0).timeout.connect(func() -> void:
		push_error("Enlarge invincibility test timed out")
		quit(2)
	)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set("_run_number", 6)
	game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	board.ensure_mines_placed(0)
	# 3×3 里混进道具牌会把这两条断言都带偏（疗愈鸟回血、长尾山雀再送一次点击），
	# 那就测不出「这一下有没有挡住雷」了。挑一块只有雷、没有牌的区域。
	var mine_index := -1
	for index in range(board.width * board.height):
		if not board.is_monster_core(index):
			continue
		var clean := true
		for target in game.call("_area_3x3_targets", index):
			if board.item_at(target) != MinesweeperBoard.ItemType.NONE:
				clean = false
				break
		if clean:
			mine_index = index
			break
	assert(mine_index >= 0, "Could not find a mine for enlarge invincibility test")
	game.set("_player_hp", 1)
	game.call("_refresh_health_bar")
	game.set("_enlarge_mark_charges", 1)
	game.call("_on_cell_revealed", mine_index)
	var deadline := Time.get_ticks_msec() + 7000
	while bool(game.get("_resolving")) and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not bool(game.get("_resolving")), "Enlarge reveal did not finish")
	assert(int(game.get("_player_hp")) == 1, "Enlarge click did not prevent mine damage")
	assert(int(game.get("_enlarge_mark_charges")) == 0, "Enlarge click did not consume one charge")
	assert(not bool(game.get("_enlarge_click_invincible")), "Enlarge invincibility remained after the click")
	assert(board.state_at(mine_index) == MinesweeperBoard.CellState.FLAGGED, "Enlarge detonated the mine instead of marking it")
	print("Enlarge: next area reveal is invincible passed")
	quit()
