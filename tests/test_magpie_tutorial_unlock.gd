extends SceneTree
## 教学第 6 关：棋盘只发鸟牌、灰喜鹊还没露面；打赢后弹灰喜鹊解锁页，鸟从此常驻；
## 紧接着的第一盘正式关起，每盘都有一组连携雷等着它来连——教学关不配连携组。

const TUTORIAL_LEVEL_COUNT := 8
const MAGPIE_LEVEL := TUTORIAL_LEVEL_COUNT - 2


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("Magpie tutorial unlock test timed out")
		quit(2)
	)
	GameSave.save_path = "user://test_magpie_tutorial_unlock_save.json"
	GameSave.clear()
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var title := game.get("_start_screen") as Control
	if title != null:
		game.set("_start_screen", null)
		title.get_parent().queue_free()
	assert(int(game.get("TUTORIAL_LEVEL_COUNT")) == TUTORIAL_LEVEL_COUNT, "Tutorial should span eight levels now")

	for _level in range(MAGPIE_LEVEL):
		game.call("_start_game")
	assert(int(game.get("_run_number")) == MAGPIE_LEVEL, "Did not reach the magpie's tutorial level")
	var magpie := game.get_node("MagpieBirdPerch") as BirdPerch
	assert(not magpie.visible, "Magpie perch showed up before its unlock")
	var board: MinesweeperBoard = game.get("_board")
	board.ensure_mines_placed(0)
	assert(board.chain_count == 0 and board.enlarge_count == 0 and board.medical_kit_count == 0, "Last tutorial level handed out tactical items")

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

	var unlock := game.get("_magpie_unlock") as MagpieUnlock
	var continue_button := unlock.get_node("Finale/Continue") as Button
	var deadline := Time.get_ticks_msec() + 9000
	while Time.get_ticks_msec() < deadline and not (unlock.visible and not continue_button.disabled):
		await process_frame
	assert(unlock.visible and not continue_button.disabled, "Magpie unlock page did not appear after its tutorial level")
	assert(bool(game.get("_magpie_bird_unlocked")), "Winning the magpie tutorial level did not unlock the magpie")
	assert(magpie.visible, "Magpie perch did not appear with its unlock")
	continue_button.pressed.emit()
	await create_timer(0.5).timeout

	# 第一盘正式关：灰喜鹊没有实体牌了，它等的是开局就分好的那一组连携雷。
	game.set("_tit_bird_unlocked", true)
	game.set("_run_number", TUTORIAL_LEVEL_COUNT)
	game.call("_start_game")
	assert(int(game.get("_run_number")) == TUTORIAL_LEVEL_COUNT + 1, "Did not advance to the first normal level")
	board = game.get("_board")
	var origin := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(origin)
	assert(board.chain_count == 2, "First normal level does not set up a two-mine chain group")
	assert(board.chain_mine_total() == 2, "Chain group was not laid onto the first normal board")
	assert(
		board.item_count(MinesweeperBoard.ItemType.CHAIN) == 0,
		"The magpie is still being dealt as an item card"
	)
	GameSave.clear()
	print("Magpie tutorial unlock: sixth tutorial level, unlock page, perch reveal and chain group on the first normal level")
	quit()
