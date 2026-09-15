extends SceneTree
## 无尽关的计分口径：分数**只**来自排雷，每枚 100，用时奖励一分不结。
## 其余关卡照旧只按用时——两边必须在同一个真场景里分别钉住，否则改动很容易
## 只在计分器里对、到了 main.gd 那条路上又走回老路。

const ENDLESS := StageTable.ENDLESS_STAGE_ID
const PER_MINE := ScoreComboTracker.POINTS_PER_MINE


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("无尽关计分测试超时")
		quit(2)
	)
	var original_save_path := GameSave.save_path
	GameSave.save_path = "user://test_endless_scoring_save.json"
	GameSave.clear()

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	# 无尽关要先解锁：把六关全标成已通关再进。
	var cleared := []
	for stage in StageTable.STAGES:
		if String(stage["id"]) != ENDLESS:
			cleared.append(String(stage["id"]))
	game.set("_cleared_stages", cleared)
	game.call("_enter_stage", ENDLESS, false)
	await process_frame

	var tracker: ScoreComboTracker = game.get("_score_combo")
	assert(tracker != null, "拿不到计分器")
	assert(String(game.get("_stage_id")) == ENDLESS, "没进到无尽关")
	assert(tracker.mode == ScoreComboTracker.Mode.MINES, "无尽关没有切到排雷口径")
	assert(tracker.score == 0, "开局分数该是 0")

	# —— 每标对一枚雷 +100，同一格撤旗重标不再加 ——
	# 雷是首翻那一下才落位的，所以先真翻一格；翻格本身只涨连击，不进分。
	var board: MinesweeperBoard = game.get("_board")
	game.call("_on_cell_revealed", _first_covered(board))
	await _settle(game)
	# 首翻本身不进分，但它铺开的空地可能顺带自动标出几枚雷——那些是真排雷，该记分。
	assert(
		tracker.score == (game.get("_combo_scored_cells") as Dictionary).size() * PER_MINE,
		"首翻之后分数就和排雷账本对不上了：%d 分" % tracker.score
	)
	# 一次插旗不一定只排掉一枚雷：道具和鸟会顺手自动标出旁边几枚，每一枚都各记一次分。
	# 所以钉的是不变式「分数 == 去重账本里的雷数 × 100」，而不是「第 n 面旗 = n×100」。
	# 每一轮都重新找一枚**还没被自动标掉**的雷——`_on_cell_flagged` 是开关，
	# 对着已经插旗的格子再点一次是撤旗，那一手当然不涨分。
	var ledger: Dictionary = game.get("_combo_scored_cells")
	var marked := 0
	for _step in range(2):
		var target := _next_unmarked_mine(board, ledger)
		assert(target >= 0, "盘上找不到下一枚还没被标掉的雷")
		var before := tracker.score
		var before_mines := ledger.size()
		game.call("_on_cell_flagged", target)
		await _settle(game)
		assert(
			tracker.score == ledger.size() * PER_MINE,
			"排雷计分对不上账本：%d 分 / %d 枚" % [tracker.score, ledger.size()]
		)
		assert(
			ledger.size() > before_mines and tracker.score > before,
			"标对第 %d 枚雷之后分数没涨" % [marked + 1]
		)
		marked += 1
	var banked := tracker.score
	assert(banked >= 2 * PER_MINE, "两枚雷至少该有 %d 分，实际 %d" % [2 * PER_MINE, banked])
	# 撤旗再插回同一格：去重账本已经记过它，不该再进分。
	var revisit := ledger.keys()[0] as int
	game.call("_on_cell_flagged", revisit)
	await _settle(game)
	game.call("_on_cell_flagged", revisit)
	await _settle(game)
	assert(tracker.score == banked, "同一格撤旗重标又加了一次分：%d → %d" % [banked, tracker.score])

	# —— 用时奖励在无尽关恒为 0，多慢都不结 ——
	game.set("_elapsed", 3.0)
	var fast: int = game.call("_award_time_bonus")
	assert(fast == 0, "无尽关还在结算用时奖励：+%d 分" % fast)
	assert(tracker.score == banked, "用时奖励把无尽关的分抬上去了")
	assert(tracker.boards_scored == 0, "无尽关不该记用时结算的盘数")

	# —— 账单印的是排雷那一行，数量对得上去重账本 ——
	var scored_cells: Dictionary = game.get("_combo_scored_cells")
	var tally: Array = game.call("_endless_board_mine_points")
	assert(int(tally[0]) == scored_cells.size(), "账单的雷数和去重账本对不上")
	assert(int(tally[1]) == scored_cells.size() * PER_MINE, "账单的分数不是雷数 × %d" % PER_MINE)

	# —— 关卡口径不受影响：普通关仍然只按用时 ——
	game.call("_return_to_main_menu")
	await process_frame
	game.set("_run_number", 4)
	game.call("_start_game")
	await process_frame
	tracker = game.get("_score_combo")
	assert(tracker.mode == ScoreComboTracker.Mode.TIME, "离开无尽关后口径没退回按用时")
	board = game.get("_board")
	game.call("_on_cell_revealed", _first_covered(board))
	await _settle(game)
	var stage_mine := _covered_mines(board, 1)
	assert(tracker.score == 0, "普通关首翻就加分了：排雷计分漏到关卡口径里了")
	if not stage_mine.is_empty():
		game.call("_on_cell_flagged", stage_mine[0])
		await _settle(game)
		assert(tracker.score == 0, "普通关标对雷也加分了：排雷计分漏到关卡口径里了")
	game.set("_elapsed", 12.0)
	var stage_bonus: int = game.call("_award_time_bonus")
	assert(
		stage_bonus == ScoreComboTracker.time_bonus_for(12.0),
		"普通关的用时奖励被无尽关那条分支挡掉了"
	)

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame
	GameSave.clear()
	GameSave.save_path = original_save_path
	print("Endless scoring: mines-only at %d each, no time bonus, stages unchanged passed" % PER_MINE)
	quit()


## 首翻用的格子。此刻雷还没落位，随便哪一格覆盖格都行。
func _first_covered(board: MinesweeperBoard) -> int:
	for index in range(board.width * board.height):
		if board.state_at(index) == MinesweeperBoard.CellState.COVERED:
			return index
	return -1


## 下一枚「还盖着、还没插旗、账本也还没记过」的雷。自动标记会把盘上的雷一片片吃掉，
## 所以每插一面旗都要重新找，不能一次抓好三枚存着用。
func _next_unmarked_mine(board: MinesweeperBoard, ledger: Dictionary) -> int:
	for index in range(board.width * board.height):
		if ledger.has(index) or board.is_flagged(index):
			continue
		if board.state_at(index) == MinesweeperBoard.CellState.COVERED and board.has_mine(index):
			return index
	return -1


func _covered_mines(board: MinesweeperBoard, want: int) -> Array[int]:
	var out: Array[int] = []
	for index in range(board.width * board.height):
		if out.size() >= want:
			break
		if board.state_at(index) == MinesweeperBoard.CellState.COVERED and board.has_mine(index):
			out.append(index)
	return out


## 等 main.gd 把这一手的演出走完（和 test_combo_rules 同一套等法）。
func _settle(game: Node, tail: float = 0.2) -> void:
	await create_timer(0.3).timeout
	for _step in range(1800):
		if not bool(game.get("_resolving")):
			break
		await process_frame
	await create_timer(tail).timeout
