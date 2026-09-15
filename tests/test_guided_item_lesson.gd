extends SceneTree
## 新手第 2 盘伙伴牌课：翻出夜鹭牌前停下来讲、按「看它表演」放行演出、
## 演出完总结并弹伙伴图鉴（上图下文）、关掉图鉴后棋盘恢复自由点击。

const STEP_TIMEOUT_MSEC := 8000


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(45.0).timeout.connect(func() -> void:
		push_error("Guided item lesson test timed out")
		quit(2)
	)
	GameSave.save_path = "user://test_guided_item_lesson_save.json"
	GameSave.clear()
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var title := game.get("_start_screen") as Control
	if title != null:
		game.set("_start_screen", null)
		title.get_parent().queue_free()

	# 步骤表自洽。
	assert(GuidedItemLesson.step_count() == 3, "伙伴牌课应是三步")
	assert(GuidedItemLesson.allows_click(0, 0, MOUSE_BUTTON_LEFT) and GuidedItemLesson.allows_click(0, 15, MOUSE_BUTTON_LEFT), "第一步应放行任意格子的左键")
	assert(not GuidedItemLesson.allows_click(0, 5, MOUSE_BUTTON_RIGHT), "第一步不该放行右键")
	assert(not GuidedItemLesson.allows_click(1, 5, MOUSE_BUTTON_LEFT) and not GuidedItemLesson.allows_click(2, 5, MOUSE_BUTTON_LEFT), "说明步不该放行点击")
	assert(GuidedItemLesson.step_bbcode(1).contains("[color=%s]" % GuidedItemLesson.EMPHASIS_COLOR), "牌的说明缺强调色")
	assert(GuidedItemLesson.ITEM_ENTRIES.size() == 8, "图鉴应列 8 位伙伴")
	for entry in GuidedItemLesson.ITEM_ENTRIES:
		assert(entry["texture"] != null, "图鉴条目缺图：%s" % String(entry["name"]))
		assert(GuidedItemLesson.format_bbcode(entry).contains("[color="), "图鉴条目缺强调色：%s" % String(entry["name"]))

	# 直接从第 2 盘开局：第 1 盘打完的状态是夜鹭已解锁、带 1 张夜鹭牌。
	game.set("_run_number", 1)
	game.set("_night_heron_unlocked", true)
	game.set("_lantern_bonus", 1)
	game.call("_start_game")
	await process_frame
	assert(int(game.get("_run_number")) == 2, "没有开到第 2 盘")
	var board: MinesweeperBoard = game.get("_board")
	assert(board.width == 4 and board.height == 4, "第 2 盘不是 4×4")
	var guide := game.get("_tutorial_guide") as TextureRect
	assert(guide != null and not guide.visible, "第 2 盘走强引导时不该显示静态说明图")

	var overlay := game.get("_guided_overlay") as GuidedTutorialOverlay
	var cells: Array[MineCell] = game.get("_cells")
	assert(await _wait_until(func() -> bool: return overlay.is_presenting() and int(game.get("_guided_step")) == 0, "伙伴牌课第一步没有出现"))
	assert(game.get("_guided_lesson") == GuidedItemLesson, "第 2 盘走的不是伙伴牌课")
	var hole := overlay.current_hole()
	assert(hole.encloses(cells[0].get_global_rect()) and hole.encloses(cells[15].get_global_rect()), "第一步的洞没圈住整个棋盘：%s" % hole)
	assert(overlay.pointer().visible, "第一步没有小手")
	assert(not overlay.next_button().visible, "点击步不该有下一步按钮")

	# 右键被拦；左键任意格放行，翻出夜鹭牌后在鸟起飞前停下来讲。
	game.call("_on_cell_mouse_button_changed", 5, MOUSE_BUTTON_RIGHT, true)
	await process_frame
	assert(board.state_at(5) == MinesweeperBoard.CellState.COVERED and board.flag_count() == 0, "第一步放行了右键")
	game.call("_on_cell_mouse_button_changed", 10, MOUSE_BUTTON_LEFT, true)
	assert(await _wait_until(func() -> bool: return int(game.get("_guided_step")) == 1, "翻出夜鹭牌后没有停下来讲"))
	var heron_index := int(game.get("_tutorial_night_heron_edge_index"))
	assert(heron_index >= 0, "首次翻开区域里没有钉夜鹭牌")
	assert(board.state_at(heron_index) == MinesweeperBoard.CellState.REVEALED, "夜鹭牌没翻开")
	assert(not board.is_item_used(heron_index), "讲牌的时候夜鹭已经生效了")
	var black_bird = game.get("_black_bird")
	assert(not bool(black_bird.get("_queued_departure_active")), "讲牌的时候夜鹭已经起飞了")
	assert(overlay.current_hole().encloses(cells[heron_index].get_global_rect()), "第二步的洞没圈住夜鹭牌")
	assert(overlay.next_button().visible and overlay.next_button().text.contains("看它表演"), "第二步按钮不是「看它表演」")
	assert(overlay.message_label().text.contains("夜鹭"), "第二步没有点名夜鹭")
	# 说明步：洞外洞内都不放行。
	game.call("_on_cell_mouse_button_changed", 0, MOUSE_BUTTON_LEFT, true)
	await process_frame
	assert(int(game.get("_guided_step")) == 1, "说明步被点击推进了")

	# 看它表演：夜鹭生效，棋盘回到可点后亮出总结步。
	overlay.next_button().pressed.emit()
	await process_frame
	assert(not overlay.is_presenting(), "看表演时引导层没有让开")
	assert(await _wait_until(func() -> bool: return board.is_item_used(heron_index), "夜鹭牌没有生效", 12000))
	assert(await _wait_until(func() -> bool: return int(game.get("_guided_step")) == 2 and overlay.is_presenting(), "演出结束后没有亮出总结步", 12000))
	assert(not bool(game.get("_resolving")), "总结步出现时棋盘还锁着")
	assert(overlay.next_button().text.contains("图鉴"), "总结步按钮不是「查看伙伴图鉴」")

	# 查看伙伴图鉴：上图下文的说明页；关掉后课结束、棋盘自由。
	var screen := game.get("_item_guide_screen") as ItemGuideScreen
	assert(screen != null and not screen.is_open(), "图鉴不该提前打开")
	overlay.next_button().pressed.emit()
	await process_frame
	assert(screen.is_open() and screen.visible, "总结步没有打开伙伴图鉴")
	assert(not overlay.is_presenting(), "图鉴打开时引导层没有收起")
	assert(screen.cards().size() == GuidedItemLesson.ITEM_ENTRIES.size(), "图鉴卡片数与条目不符")
	for card in screen.cards():
		var icon := card.find_child("Icon", true, false) as TextureRect
		var name_label := card.find_child("Name", true, false) as Label
		var text := card.find_child("Text", true, false) as RichTextLabel
		assert(icon != null and icon.texture != null, "卡片缺图")
		assert(name_label != null and not name_label.text.is_empty(), "卡片缺名字")
		assert(text != null and text.text.contains("[color="), "卡片说明缺强调色")
		await process_frame
		assert(icon.get_global_rect().end.y <= text.get_global_rect().position.y + 1.0, "卡片不是上图下文：%s" % name_label.text)
	screen.close_button().pressed.emit()
	await process_frame
	assert(not screen.is_open(), "关闭按钮没有关掉图鉴")
	assert(int(game.get("_guided_step")) == -1 and game.get("_guided_lesson") == null, "图鉴关掉后课没有结束")
	assert(not overlay.is_presenting(), "图鉴关掉后引导层又冒出来了")

	# 课结束后点击不再被拦：右键任意未翻格能插旗（或踩错旗）。
	var covered := -1
	for index in range(board.width * board.height):
		if board.state_at(index) == MinesweeperBoard.CellState.COVERED and board.has_mine(index):
			covered = index
			break
	assert(covered >= 0, "盘上没有剩下的雷格")
	game.call("_on_cell_mouse_button_changed", covered, MOUSE_BUTTON_RIGHT, true)
	assert(await _wait_until(func() -> bool: return board.state_at(covered) == MinesweeperBoard.CellState.FLAGGED, "课结束后右键仍被拦"))

	GameSave.clear()
	print("Guided item lesson: heron card intro, demo on demand, illustrated item guide, board freed")
	quit()


func _wait_until(predicate: Callable, message: String, timeout_msec: int = STEP_TIMEOUT_MSEC) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	push_error(message)
	return false
