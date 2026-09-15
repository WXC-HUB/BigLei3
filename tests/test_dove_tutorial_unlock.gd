extends SceneTree
## 教学第 8 关（收尾关）：棋盘只发鸟牌、斑鸠还没露面；打赢后弹斑鸠解锁页，鸟从此常驻；
## 紧接着的第一盘正式关，首次翻开的区域里必定有一张它的牌（和长尾山雀、小嘴乌鸦那两张不同格），
## 且总数仍是一张。

const TUTORIAL_LEVEL_COUNT := 8


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(25.0).timeout.connect(func() -> void:
		push_error("Dove tutorial unlock test timed out")
		quit(2)
	)
	GameSave.save_path = "user://test_dove_tutorial_unlock_save.json"
	GameSave.clear()
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var title := game.get("_start_screen") as Control
	if title != null:
		game.set("_start_screen", null)
		title.get_parent().queue_free()
	assert(int(game.get("TUTORIAL_LEVEL_COUNT")) == TUTORIAL_LEVEL_COUNT, "Tutorial should span eight levels now")

	for _level in range(TUTORIAL_LEVEL_COUNT):
		game.call("_start_game")
	assert(int(game.get("_run_number")) == TUTORIAL_LEVEL_COUNT, "Did not reach the last tutorial level")
	var dove := game.get_node("DoveBirdPerch") as BirdPerch
	assert(not dove.visible, "Dove perch showed up before its unlock")
	var board: MinesweeperBoard = game.get("_board")
	board.ensure_mines_placed(0)
	assert(board.medical_kit_count == 0 and board.enlarge_count == 0 and board.xray_count == 0, "Last tutorial level handed out tactical items")

	# 直接把这一盘打赢：雷全部标出，其余全翻开。
	for index in range(board.width * board.height):
		if board.is_monster_core(index):
			board.mark_mine(index)
	for index in range(board.width * board.height):
		if not board.is_monster_core(index) and board.state_at(index) == MinesweeperBoard.CellState.COVERED:
			board.reveal_exact_forced_safe(index)
	board.won = true
	board.game_over = true
	game.call("_finish_game")

	var unlock := game.get("_dove_unlock") as DoveUnlock
	var continue_button := unlock.get_node("Finale/Continue") as Button
	var deadline := Time.get_ticks_msec() + 9000
	while Time.get_ticks_msec() < deadline and not (unlock.visible and not continue_button.disabled):
		await process_frame
	assert(unlock.visible and not continue_button.disabled, "Dove unlock page did not appear after the last tutorial level")
	assert(bool(game.get("_dove_bird_unlocked")), "Winning the last tutorial level did not unlock the dove")
	assert(dove.visible, "Dove perch did not appear with its unlock")
	continue_button.pressed.emit()
	await create_timer(0.5).timeout

	# 第一盘正式关：默认一张斑鸠牌，钉进首次翻开的区域，且不和长尾山雀、小嘴乌鸦那两张挤同一格。
	game.set("_tit_bird_unlocked", true)
	game.set("_crow_bird_unlocked", true)
	game.set("_run_number", TUTORIAL_LEVEL_COUNT)
	game.call("_start_game")
	assert(int(game.get("_run_number")) == TUTORIAL_LEVEL_COUNT + 1, "Did not advance to the first normal level")
	assert(bool(game.get("_dove_demo_pending")), "Dove demo was not armed for the first normal level")
	board = game.get("_board")
	var origin := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(origin)
	assert(board.medical_kit_count == 1, "First normal level does not carry exactly one dove card")
	var first_reveal: PackedInt32Array = board.reveal(origin)
	game.call("_place_unlocked_tit_in_first_reveal", first_reveal, origin)
	game.call("_place_unlocked_crow_in_first_reveal", first_reveal, origin)
	game.call("_place_unlocked_dove_in_first_reveal", first_reveal, origin)
	var demo_index := int(game.get("_dove_demo_index"))
	assert(demo_index >= 0 and first_reveal.has(demo_index), "Dove card was not placed inside the first revealed region")
	assert(demo_index != int(game.get("_tit_demo_index")), "Dove and tit demo cards landed on the same cell")
	assert(demo_index != int(game.get("_crow_demo_index")), "Dove and crow demo cards landed on the same cell")
	assert(board.item_at(demo_index) == MinesweeperBoard.ItemType.MEDICAL_KIT, "Demo cell does not hold the dove card")
	assert(board.item_count(MinesweeperBoard.ItemType.MEDICAL_KIT) == 1, "Dove demo changed the stock count")
	assert(not bool(game.get("_dove_demo_pending")), "Dove demo stayed armed after placing")
	GameSave.clear()
	print("Dove tutorial unlock: last tutorial level, unlock page, perch reveal and first-level demo passed")
	quit()
