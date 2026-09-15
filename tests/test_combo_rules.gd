extends SceneTree
## 连击与计分规则的集成测试。两套账各走各的，所以要分开钉：
##
## 连击：点一下翻开 +1、推理翻开 +1、标对雷 +1、标错断连击。
## 计分：盘中一分不动，只在每盘结束按用时结一次账。
##
## 这些规则散落在 main.gd 的好几条路径上，只有把真场景跑起来才测得到。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("连击规则测试超时")
		quit(2)
	)
	# 绝不碰真实存档：这个测试会真的开一局，而开局路径上就有 _save_progress()。
	var original_save_path := GameSave.save_path
	GameSave.save_path = "user://test_combo_rules_save.json"

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set("_run_number", 4)
	game.call("_start_game")
	await process_frame

	var board: MinesweeperBoard = game.get("_board")
	var tracker: ScoreComboTracker = game.get("_score_combo")
	assert(tracker != null, "拿不到计分器")
	assert(tracker.combo == 0 and tracker.score == 0, "开局连击和分数都该是 0")
	_assert_score_frozen(tracker, "开局")
	var before := _snapshot(game, tracker)
	var delta := _delta(game, tracker, before)

	# —— 规则四：手动标错就断连击，且不该动分数 ——
	# 这两条**必须排在最前面**：标错要吃掉一格覆盖着的安全格，而后面的翻开和推理
	# 会把盘面清得很空。排在后面时，随机盘一小就找不到可标错的格子，测试随机翻车。
	for _step in range(3):
		game.call("_register_click_combo")
	assert(tracker.combo == 3, "得先攒一点连击才有得断")
	var wrong := _find_covered_safe_cell(board)
	assert(wrong >= 0, "找不到一格可以标错的安全格")
	before = _snapshot(game, tracker)
	game.call("_on_cell_flagged", wrong)
	await _settle(game)
	assert(tracker.combo == 0, "标错没有断掉连击")
	assert(_delta(game, tracker, before)["score"] == 0, "标错动了分数，但盘中不该有任何计分")

	# —— 规则四之二：无敌挡掉伤害时，连击照样要断 ——
	# 护盾免的是血，不是这条纪律；这一条正是走 _apply_player_damage 测不到的那半边。
	game.call("_register_click_combo")
	assert(tracker.combo > 0)
	var hp_before: int = game.get("_player_hp")
	game.set("_enlarge_click_invincible", true)
	var shielded_wrong := _find_covered_safe_cell(board)
	assert(shielded_wrong >= 0, "找不到第二格可以标错的安全格")
	game.call("_on_cell_flagged", shielded_wrong)
	await _settle(game)
	game.set("_enlarge_click_invincible", false)
	assert(tracker.combo == 0, "无敌状态下标错没有断掉连击")
	assert(game.get("_player_hp") == hp_before, "无敌状态下标错不该掉血，测试前提已经不成立")

	# —— 规则一：点一下翻开格子，连击 +1，翻出多少格都只算一次 ——
	var first_cell := _find_covered_safe_cell(board)
	assert(first_cell >= 0, "找不到一格可翻的安全格")
	before = _snapshot(game, tracker)
	game.call("_on_cell_revealed", first_cell)
	await _settle(game)
	delta = _delta(game, tracker, before)
	assert(
		delta["combo"] == delta["cleared"] + 1,
		"点一下翻开应当只加一次点击分（连击 +%d，其中排雷 %d）" % [delta["combo"], delta["cleared"]]
	)
	_assert_score_frozen(tracker, "点击翻开之后")

	# —— 规则二：推理翻开安全格同样 +1 ——
	var clue := _prepare_safe_inference(board, game)
	assert(clue >= 0, "造不出「数字已被旗子满足、剩余邻格必安全」的推理局面")
	before = _snapshot(game, tracker)
	game.call("_on_cell_revealed", clue)
	await _settle(game)
	delta = _delta(game, tracker, before)
	assert(
		delta["combo"] == delta["cleared"] + 1,
		"推理翻开应当照样加一次点击分（连击 +%d，其中排雷 %d）" % [delta["combo"], delta["cleared"]]
	)
	_assert_score_frozen(tracker, "推理翻开之后")

	# 点一格已经推完的空地不该白刷连击，否则对着它连点就能无限涨。
	before = _snapshot(game, tracker)
	game.call("_on_cell_revealed", clue)
	await _settle(game)
	delta = _delta(game, tracker, before)
	assert(delta["combo"] == 0, "推理没翻出任何格子却加了连击，这会变成连点刷分")
	assert(delta["score"] == 0, "什么都没发生却改了分数")

	# —— 规则三：手动标对雷，连击 +1 ——
	var mine := _find_covered_mine(board)
	assert(mine >= 0, "找不到一颗可标的雷")
	before = _snapshot(game, tracker)
	game.call("_on_cell_flagged", mine)
	await _settle(game)
	delta = _delta(game, tracker, before)
	assert(delta["combo"] >= 1, "手动标对雷没有加连击")
	assert(delta["cleared"] >= 1, "手动标对雷没有记进排雷账")
	_assert_score_frozen(tracker, "标对雷之后")

	# 连击拉高也照样不产生分数。
	for _step in range(12):
		game.call("_register_click_combo")
	assert(tracker.combo >= 12, "连击没有被拉高，下面的对照就不成立")
	_assert_score_frozen(tracker, "连击拉到两位数之后")

	# —— 踩雷也不计分：它只掉血、断连击 ——
	# 走真实的翻雷路径，确认这条路上没人再往分数里写东西。
	var live_mine := _find_covered_mine(board)
	assert(live_mine >= 0, "找不到一颗可以踩的雷")
	game.call("_on_cell_revealed", live_mine)
	await _settle(game, 1.2)
	_assert_score_frozen(tracker, "踩雷之后")

	# —— 结算：按用时进账，且同一盘只能结一次 ——
	# 重入闸是这条路上最容易出事的地方：`_finish_game` 不保证只走一次，
	# 闸一漏就会出现「同一盘结算两次分」。
	game.set("_elapsed", 12.0)
	var expected_bonus := ScoreComboTracker.time_bonus_for(12.0)
	var awarded: int = game.call("_award_time_bonus")
	assert(awarded == expected_bonus, "结算的分和用时曲线对不上：%d 应为 %d" % [awarded, expected_bonus])
	assert(tracker.score == expected_bonus, "结算的分没有进到总分里")
	assert(tracker.boards_scored == 1, "结算盘数没记上")
	var repeated: int = game.call("_award_time_bonus")
	assert(repeated == 0, "同一盘被结算了第二次，重入闸没拦住")
	assert(tracker.score == expected_bonus, "重复结算把分数抬上去了")

	GameSave.save_path = original_save_path
	print("Combo rules: combo counting, wrong-flag break, and time-only scoring passed")
	quit()


## 计分只看时间，所以盘中任何动作之后分数都必须纹丝不动。这条比逐步对差值更硬：
## 任何一处偷偷往分数里掺连击、排雷或踩雷，它都会当场崩掉。
func _assert_score_frozen(tracker: ScoreComboTracker, stage: String) -> void:
	assert(
		tracker.score == 0,
		"%s 分数动了（%d）——盘中不该产生任何分，计分只在结算时按用时进账" % [stage, tracker.score]
	)


## 排雷数从 main.gd 的去重账本读——计分器已经不记它了，但连击仍然一雷一涨。
func _snapshot(game: Node, tracker: ScoreComboTracker) -> Dictionary:
	var scored: Dictionary = game.get("_combo_scored_cells")
	return {"combo": tracker.combo, "score": tracker.score, "cleared": scored.size()}


func _delta(game: Node, tracker: ScoreComboTracker, before: Dictionary) -> Dictionary:
	var now := _snapshot(game, tracker)
	var out := {}
	for key in now:
		out[key] = int(now[key]) - int(before[key])
	return out


## 等 main.gd 把这一手的演出走完。`_resolving` 是它自己那把锁；锁放开之后再多等
## 一会儿，让 fire-and-forget 的那几段收尾也跑完。
func _settle(game: Node, tail: float = 0.25) -> void:
	await create_timer(0.35).timeout
	for _step in range(1800):
		if not bool(game.get("_resolving")):
			break
		await process_frame
	await create_timer(tail).timeout


func _find_covered_safe_cell(board: MinesweeperBoard) -> int:
	for index in range(board.width * board.height):
		if board.state_at(index) == MinesweeperBoard.CellState.COVERED and not board.has_mine(index):
			return index
	return -1


func _find_covered_mine(board: MinesweeperBoard) -> int:
	for index in range(board.width * board.height):
		if board.state_at(index) == MinesweeperBoard.CellState.COVERED and board.has_mine(index):
			return index
	return -1


## 造一个「数字已被旗子满足、剩下的覆盖邻格必然安全」的局面，返回那个数字格。
## 直接走 board.toggle_flag 插旗，不经过 _on_cell_flagged——布置局面本身不该计分。
func _prepare_safe_inference(board: MinesweeperBoard, game: Node) -> int:
	for index in range(board.width * board.height):
		if board.state_at(index) != MinesweeperBoard.CellState.REVEALED:
			continue
		if board.adjacent_mines(index) <= 0:
			continue
		var covered_safe := 0
		var covered_mines: Array[int] = []
		for neighbor in board.neighbors_of(index):
			if board.state_at(neighbor) != MinesweeperBoard.CellState.COVERED:
				continue
			if board.has_mine(neighbor):
				covered_mines.append(neighbor)
			else:
				covered_safe += 1
		if covered_safe <= 0 or covered_mines.is_empty():
			continue
		for mine in covered_mines:
			board.toggle_flag(mine)
			game.call("_refresh_cell", mine)
		var inference: Dictionary = board.inference_at(index)
		if inference["unique"] and not (inference["safe_cells"] as PackedInt32Array).is_empty():
			return index
	return -1
