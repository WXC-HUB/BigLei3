extends SceneTree
## 教学第 5 关：棋盘只发鸟牌、长尾山雀还没露面；打赢后弹长尾山雀解锁页，鸟从此常驻，
## 点继续直接开第 6 盘教学；第一盘正式关首次翻开的区域里必定有一张长尾山雀牌，且总数仍是一张。

const TUTORIAL_LEVEL_COUNT := 8
const TIT_LEVEL := TUTORIAL_LEVEL_COUNT - 3


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("Tit tutorial unlock test timed out")
		quit(2)
	)
	GameSave.save_path = "user://test_tit_tutorial_unlock_save.json"
	GameSave.clear()
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var title := game.get("_start_screen") as Control
	if title != null:
		game.set("_start_screen", null)
		title.get_parent().queue_free()
	assert(int(game.get("TUTORIAL_LEVEL_COUNT")) == TUTORIAL_LEVEL_COUNT, "Tutorial should span eight levels now")

	for _level in range(TIT_LEVEL):
		game.call("_start_game")
	assert(int(game.get("_run_number")) == TIT_LEVEL, "Did not reach the tit's tutorial level")
	var tit := game.get_node("TitBirdPerch") as BirdPerch
	assert(not tit.visible, "Tit perch showed up before its unlock")
	var board: MinesweeperBoard = game.get("_board")
	board.ensure_mines_placed(0)
	assert(board.enlarge_count == 0 and board.medical_kit_count == 0 and board.xray_count == 0, "Tit tutorial level handed out tactical items")

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

	var unlock := game.get("_tit_unlock") as TitUnlock
	var continue_button := unlock.get_node("Finale/Continue") as Button
	var deadline := Time.get_ticks_msec() + 9000
	while Time.get_ticks_msec() < deadline and not (unlock.visible and not continue_button.disabled):
		await process_frame
	assert(unlock.visible and not continue_button.disabled, "Tit unlock page did not appear after its tutorial level")
	assert(bool(game.get("_tit_bird_unlocked")), "Winning the tit's tutorial level did not unlock the tit")
	assert(tit.visible, "Tit perch did not appear with its unlock")
	continue_button.pressed.emit()
	await create_timer(0.6).timeout
	# 和前四只鸟一样，点继续直接开下一盘教学，不走账单。
	assert(int(game.get("_run_number")) == TIT_LEVEL + 1, "Continuing did not start the next tutorial level")
	assert(not bool(game.get("_magpie_bird_unlocked")), "Magpie was unlocked before its own tutorial level")

	# 第一盘正式关：默认一张长尾山雀牌，且被钉进首次翻开的区域。
	# 长尾山雀之后还有灰喜鹊、小嘴乌鸦两盘教学，这里直接跳到最后一盘再开下一盘。
	game.set("_run_number", TUTORIAL_LEVEL_COUNT)
	game.call("_start_game")
	assert(int(game.get("_run_number")) == TUTORIAL_LEVEL_COUNT + 1, "Did not advance to the first normal level")
	assert(bool(game.get("_tit_demo_pending")), "Tit demo was not armed for the first normal level")
	board = game.get("_board")
	var origin := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(origin)
	assert(board.enlarge_count == 1, "First normal level does not carry exactly one tit card")
	var first_reveal: PackedInt32Array = board.reveal(origin)
	game.call("_place_unlocked_tit_in_first_reveal", first_reveal, origin)
	var demo_index := int(game.get("_tit_demo_index"))
	assert(demo_index >= 0 and first_reveal.has(demo_index), "Tit card was not placed inside the first revealed region")
	assert(board.item_at(demo_index) == MinesweeperBoard.ItemType.ENLARGE, "Demo cell does not hold the tit card")
	assert(board.item_count(MinesweeperBoard.ItemType.ENLARGE) == 1, "Tit demo changed the stock count")
	assert(not bool(game.get("_tit_demo_pending")), "Tit demo stayed armed after placing")
	GameSave.clear()
	print("Tit tutorial unlock: fifth tutorial level, unlock page, perch reveal and first-level demo passed")
	quit()
