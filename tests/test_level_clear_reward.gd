extends SceneTree
## 打完一盘的固定通关奖励：标雷和夜师傅的鱼照旧按个算，再加 `LEVEL_CLEAR_GOLD` 一笔，
## 三项都要分行印在账单上。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameSave.save_path = "user://test_level_clear_reward.json"
	GameSave.clear()
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("Level clear reward test timed out")
		quit(2)
	)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var start_screen := game.get("_start_screen") as Control
	if start_screen != null:
		start_screen.get_parent().queue_free()
		game.set("_start_screen", null)

	# 跳过整个教学段：教学关走的是解锁演出，不进账单。
	game.set("_run_number", 9)
	game.call("_start_game")
	await process_frame
	var board: MinesweeperBoard = game.get("_board")
	# 雷是第一次翻开时才布的，先翻一格再去标，否则棋盘上一个雷都没有。
	board.reveal(int(board.width * board.height / 2))
	var flagged := 0
	for index in range(board.width * board.height):
		if board.is_monster_core(index) and board.state_at(index) == MinesweeperBoard.CellState.COVERED:
			if board.mark_mine(index):
				flagged += 1
			if flagged == 3:
				break
	if not _require(flagged == 3, "没能先标出三个雷"): return
	game.set("_night_master_fish_count", 2)
	game.set("_gold", 0)
	game.set("_gold_rewarded_this_run", false)
	board.won = true
	board.game_over = true
	game.call("_finish_game")

	var bill := game.get("_level_bill") as LevelBill
	var bill_continue := bill.get_node("Center/Panel/Margin/Stack/Continue") as Button
	if not await _wait_until(
		func() -> bool: return bill.visible and not bill_continue.disabled, 20000, "账单没有弹出来"
	): return
	if not _require(int(game.get("_gold")) == 8, "结算金币不是 3 标雷 + 2 鱼 + 3 通关，而是 %d" % int(game.get("_gold"))): return
	var lines := bill.get_node("Center/Panel/Margin/Stack/Lines") as VBoxContainer
	if not _require(lines.has_node("ClearBonus"), "账单上没有通关奖励这一行"): return
	var clear_amount := (lines.get_node("ClearBonus") as HBoxContainer).get_node("Amount") as Label
	if not _require(clear_amount.text == "+3G", "通关奖励不是 3G：%s" % clear_amount.text): return
	print("Level clear reward: flat per-level bonus is billed separately")
	quit()


func _wait_until(predicate: Callable, timeout_ms: int, message: String) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	push_error(message)
	quit(1)
	return false


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
