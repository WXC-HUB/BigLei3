extends SceneTree
## 新手第 1 盘强引导：固定 5×4 布局、遮罩挖洞、逐步放行点击。
## 走完全部六步：翻格 → 认数字 → 踩雷掉血 → 看血条 → 右键标雷 → 点数字推理，直到通关演出。

const STEP_TIMEOUT_MSEC := 6000


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(40.0).timeout.connect(func() -> void:
		push_error("Guided tutorial test timed out")
		quit(2)
	)
	GameSave.save_path = "user://test_guided_tutorial_save.json"
	GameSave.clear()
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var title := game.get("_start_screen") as Control
	if title != null:
		game.set("_start_screen", null)
		title.get_parent().queue_free()

	# 步骤表自洽：目标格与步骤动作一一对应。
	assert(GuidedTutorial.step_count() == 6, "强引导应是六步")
	assert(GuidedTutorial.allows_click(0, 6, MOUSE_BUTTON_LEFT), "第一步应放行目标格左键")
	assert(not GuidedTutorial.allows_click(0, 6, MOUSE_BUTTON_RIGHT), "第一步不该放行右键")
	assert(not GuidedTutorial.allows_click(0, 7, MOUSE_BUTTON_LEFT), "第一步不该放行别的格子")
	assert(not GuidedTutorial.allows_click(1, 13, MOUSE_BUTTON_LEFT), "说明步不该放行任何点击")
	assert(GuidedTutorial.allows_click(4, 18, MOUSE_BUTTON_RIGHT), "标雷步应放行目标格右键")
	assert(not GuidedTutorial.allows_click(4, 18, MOUSE_BUTTON_LEFT), "标雷步不该放行左键（那是雷）")
	assert(GuidedTutorial.step_bbcode(0).contains("[color=%s]" % GuidedTutorial.EMPHASIS_COLOR), "引导文本没有强调色")

	# 教学关第一盘（关卡表 + 直接开局两条路都得是固定布局）。
	assert(StageTable.board_at("grass_1", 1)["shape"] == "rect_5x4", "教学关第一盘的形状不是强引导盘")
	assert(int(StageTable.board_at("grass_1", 1)["mines"]) == GuidedTutorial.MINES.size(), "教学关第一盘雷数与强引导布局不符")
	game.call("_start_game")
	await process_frame
	var board: MinesweeperBoard = game.get("_board")
	assert(board.width == GuidedTutorial.WIDTH and board.height == GuidedTutorial.HEIGHT, "第一盘不是 5×4")
	assert(board.mines_placed, "强引导盘开局就该布好雷")
	assert(GuidedTutorial.layout_matches(board), "第一盘的雷位不是写死的布局")
	for item_type in range(1, MinesweeperBoard.ItemType.size()):
		assert(board.item_count(item_type as MinesweeperBoard.ItemType) == 0, "强引导盘不该有道具")
	var guide := game.get("_tutorial_guide") as TextureRect
	assert(guide != null and not guide.visible, "强引导盘不该同时显示静态说明图")

	var overlay := game.get("_guided_overlay") as GuidedTutorialOverlay
	assert(overlay != null, "没有建强引导演出层")
	assert(await _wait_until(func() -> bool: return overlay.is_presenting() and int(game.get("_guided_step")) == 0, "强引导第一步没有出现"))
	var cells: Array[MineCell] = game.get("_cells")
	var hole := overlay.current_hole()
	assert(hole.encloses(cells[6].get_global_rect()), "第一步的洞没圈住目标格：%s" % hole)
	assert(not hole.intersects(cells[8].get_global_rect()), "第一步的洞圈到了别的格子")
	assert(overlay.pointer().visible, "第一步没有小手")
	assert(not overlay.next_button().visible, "点击步不该显示下一步按钮")
	assert(overlay.message_label().text.contains(GuidedTutorial.EMPHASIS_COLOR), "第一步文本缺强调色")

	# 洞外 / 错键的点击被拦下，棋盘不动。
	game.call("_on_cell_mouse_button_changed", 8, MOUSE_BUTTON_LEFT, true)
	game.call("_on_cell_mouse_button_changed", 6, MOUSE_BUTTON_RIGHT, true)
	await process_frame
	for index in range(board.width * board.height):
		assert(board.state_at(index) == MinesweeperBoard.CellState.COVERED, "被拦下的点击改变了棋盘")
	assert(int(game.get("_guided_step")) == 0, "被拦下的点击推进了步骤")

	# 第 1 步：翻开 (1,1)，连锁翻出左半边。
	game.call("_on_cell_mouse_button_changed", 6, MOUSE_BUTTON_LEFT, true)
	assert(await _wait_until(func() -> bool: return int(game.get("_guided_step")) == 1, "翻开目标格后没有进入第二步"))
	assert(board.state_at(6) == MinesweeperBoard.CellState.REVEALED, "目标格没翻开")
	assert(board.state_at(13) == MinesweeperBoard.CellState.REVEALED and board.adjacent_mines(13) == 2, "示范用的数字 2 没翻出来")
	for mine in GuidedTutorial.MINES:
		assert(board.state_at(mine) == MinesweeperBoard.CellState.COVERED, "连锁翻开碰到了雷")
	assert(overlay.next_button().visible and not overlay.next_button().disabled, "说明步没有下一步按钮")
	hole = overlay.current_hole()
	assert(hole.encloses(cells[13].get_global_rect()) and hole.encloses(cells[19].get_global_rect()), "第二步的洞没圈住 3×3 邻域")
	# 说明步：洞不可点，点雷也不放行。
	game.call("_on_cell_mouse_button_changed", 9, MOUSE_BUTTON_LEFT, true)
	await process_frame
	assert(board.state_at(9) == MinesweeperBoard.CellState.COVERED, "说明步放行了点击")

	# 第 2 步：知道了。
	overlay.next_button().pressed.emit()
	await process_frame
	assert(int(game.get("_guided_step")) == 2, "下一步按钮没有推进到第三步")

	# 第 3 步：踩雷 B，掉 1 点血，进入血条说明。
	var hp_before := int(game.get("_player_hp"))
	game.call("_on_cell_mouse_button_changed", 9, MOUSE_BUTTON_LEFT, true)
	assert(await _wait_until(func() -> bool: return int(game.get("_guided_step")) == 3, "踩雷后没有进入血条说明"))
	assert(int(game.get("_player_hp")) == hp_before - 1, "踩雷没有扣 1 点血")
	assert(board.state_at(9) == MinesweeperBoard.CellState.REVEALED, "雷没有被翻出来")
	assert(not bool(game.get("_game_finish_started")), "踩雷把这一盘结束了")
	var health_bar := game.get("_health_bar") as Control
	assert(overlay.current_hole().encloses(health_bar.get_global_rect()), "血条说明的洞没圈住血条")
	assert(not overlay.pointer().visible, "血条说明不该有小手")
	overlay.next_button().pressed.emit()
	await process_frame
	assert(int(game.get("_guided_step")) == 4, "血条说明之后没有进入标雷步")

	# 第 5 步：右键标雷 C；左键被拦。
	game.call("_on_cell_mouse_button_changed", 18, MOUSE_BUTTON_LEFT, true)
	await process_frame
	assert(board.state_at(18) == MinesweeperBoard.CellState.COVERED, "标雷步放行了左键点雷")
	game.call("_on_cell_mouse_button_changed", 18, MOUSE_BUTTON_RIGHT, true)
	assert(await _wait_until(func() -> bool: return int(game.get("_guided_step")) == 5, "标雷后没有进入推理步"))
	assert(board.state_at(18) == MinesweeperBoard.CellState.FLAGGED, "雷 C 没被标记")
	hole = overlay.current_hole()
	assert(hole.encloses(cells[3].get_global_rect()) and hole.encloses(cells[4].get_global_rect()), "推理步的洞没圈住数字与剩余的雷")

	# 第 6 步：点数字 2，自动标出雷 A，通关。
	game.call("_on_cell_mouse_button_changed", 3, MOUSE_BUTTON_LEFT, true)
	assert(await _wait_until(func() -> bool: return board.state_at(4) == MinesweeperBoard.CellState.FLAGGED, "推理没有自动标出最后一颗雷"))
	assert(await _wait_until(func() -> bool: return bool(game.get("_game_finish_started")), "标完全部雷后没有进入结算"))
	assert(board.won, "这一盘没有判胜")
	assert(await _wait_until(func() -> bool: return not overlay.is_presenting(), "通关后引导层没有收起"))
	assert(int(game.get("_guided_step")) == -1, "通关后引导状态没有复位")
	var unlock: NightHeronUnlock = game.get("_night_heron_unlock")
	var unlock_continue := unlock.get_node("Finale/Continue") as Button
	assert(await _wait_until(func() -> bool: return unlock.visible and not unlock_continue.disabled, "通关后没有弹夜鹭解锁页", 12000))
	unlock_continue.pressed.emit()
	assert(await _wait_until(func() -> bool: return int(game.get("_run_number")) == 2, "解锁页之后没有开第二盘"))
	await process_frame
	await process_frame
	assert(await _wait_until(func() -> bool: return overlay.is_presenting() and int(game.get("_guided_step")) == 0, "第二盘没有进入伙伴牌课"))
	assert(game.get("_guided_lesson") == GuidedItemLesson, "第二盘走的不是伙伴牌课")
	assert(not guide.visible, "第二盘走强引导时不该显示静态说明图")
	var second: MinesweeperBoard = game.get("_board")
	assert(second.width == 4 and second.height == 4, "第二盘不是 4×4")

	GameSave.clear()
	print("Guided tutorial: fixed 5x4 layout, six gated steps, cleared through inference")
	quit()


func _wait_until(predicate: Callable, message: String, timeout_msec: int = STEP_TIMEOUT_MSEC) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	push_error(message)
	return false
