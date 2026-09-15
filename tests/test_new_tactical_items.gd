extends SceneTree

const TUTORIAL_LEVEL_COUNT := 8


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(24.0).timeout.connect(func() -> void:
		push_error("New tactical item test timed out")
		quit(2)
	)
	# 换到临时存档位并清空：否则本机的续关存档会把测试丢到随机的关卡进度上。
	GameSave.save_path = "user://test_new_tactical_items_save.json"
	GameSave.clear()
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	# 教学关不发战术道具，所以先把关卡推到第一个普通关。透视和长尾山雀（巨大）普通关
	# 本来就各有一张，不再额外加成，好让下面的「每种恰好一张」断言成立。
	# 连携已经从道具牌改成了雷的属性，归 test_chain_mine_link 管，这里不再涉及。
	for _level in range(TUTORIAL_LEVEL_COUNT + 1):
		game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	var detect_slot := _find_empty_safe_cell(board)
	assert(detect_slot >= 0 and board.force_item_at(detect_slot, MinesweeperBoard.ItemType.DETECT, false), "Could not prepare detect item")
	for item_type in [
		MinesweeperBoard.ItemType.XRAY,
		MinesweeperBoard.ItemType.ENLARGE,
		MinesweeperBoard.ItemType.DETECT,
	]:
		assert(board.item_count(item_type) == 1, "New tactical item was not generated exactly once")
	assert(
		board.item_count(MinesweeperBoard.ItemType.CHAIN) == 0,
		"Chain is still being dealt as an item card"
	)
	var cells: Array[MineCell] = game.get("_cells")

	await _activate_item(game, board, MinesweeperBoard.ItemType.XRAY)
	var xray_target: int = game.get("_last_xray_target")
	assert(xray_target >= 0, "X-ray did not choose a target")
	var hint := cells[xray_target].get("_xray_hint") as TextureRect
	var hint_number := cells[xray_target].get("_xray_number") as Label
	assert((hint != null and hint.visible) or (hint_number != null and hint_number.visible), "X-ray content was not shown")
	await create_timer(3.05).timeout
	assert(not hint.visible and not hint_number.visible, "X-ray content did not disappear after 3 seconds")

	await _activate_item(game, board, MinesweeperBoard.ItemType.DETECT)
	var detect_target: int = game.get("_last_detect_target")
	assert(detect_target >= 0, "Detect did not choose a mine")
	assert(board.state_at(detect_target) == MinesweeperBoard.CellState.FLAGGED, "Detect did not mark its mine")

	await _activate_item(game, board, MinesweeperBoard.ItemType.ENLARGE)
	var enlarge_target := _find_safe_area_center(board)
	assert(enlarge_target >= 0, "Could not find a safe 3x3 test area")
	var enlarge_charges_before: int = game.get("_enlarge_mark_charges")
	assert(enlarge_charges_before > 0, "Enlarge did not arm a left-click charge")
	game.call("_on_cell_hover_started", enlarge_target)
	await create_timer(0.12).timeout
	var enlarge_preview_targets: Array[int] = game.call("_area_3x3_targets", enlarge_target)
	for preview_target in enlarge_preview_targets:
		var preview_overlay := cells[preview_target].get("_preview_overlay") as Panel
		assert(preview_overlay.visible, "Enlarge hover did not outline its full 3x3 area")
	game.call("_on_cell_hover_ended", enlarge_target)
	await process_frame
	for preview_target in enlarge_preview_targets:
		var cleared_overlay := cells[preview_target].get("_preview_overlay") as Panel
		assert(not cleared_overlay.visible, "Enlarge hover outline remained after mouse exit")
	# 右键仍然只是普通标记，不该花掉「变大」的那一次左键。用一颗真雷来测：标错安全格
	# 现在会直接揭示格子并扣血，那是另一条规则，会盖掉这里想检查的东西。
	var flag_probe := board.random_hidden_mine_cell()
	assert(flag_probe >= 0, "Could not find a covered mine for the right-click check")
	game.call("_on_cell_flagged", flag_probe)
	await _wait_until_not_resolving(game)
	assert(int(game.get("_enlarge_mark_charges")) == enlarge_charges_before, "Right-click incorrectly consumed enlarge")
	assert(board.state_at(flag_probe) == MinesweeperBoard.CellState.FLAGGED, "Right-click stopped behaving as a normal flag")
	game.call("_on_cell_hover_started", enlarge_target)
	await create_timer(0.12).timeout
	game.call("_on_cell_revealed", enlarge_target)
	await _wait_until_not_resolving(game)
	assert(int(game.get("_enlarge_mark_charges")) == enlarge_charges_before - 1, "Enlarge did not consume exactly one left-click charge")
	assert(board.state_at(enlarge_target) == MinesweeperBoard.CellState.REVEALED, "Enlarge flagged instead of revealing its center")
	for preview_target in enlarge_preview_targets:
		var remaining_overlay := cells[preview_target].get("_preview_overlay") as Panel
		assert(not remaining_overlay.visible, "Enlarge hover outline remained after consumption")
	GameSave.clear()
	print("New tactical items: x-ray, chain, enlarge, and detect passed")
	quit()


func _find_item_index(board: MinesweeperBoard, type: MinesweeperBoard.ItemType) -> int:
	for index in range(board.width * board.height):
		if board.item_at(index) == type:
			return index
	return -1


## Marker point B for the chain test: a still-covered mine whose path back to the
## anchor is monster-free, so the reveal cannot cost the test run a heart. Cells
## that need the L-shaped detour are preferred — that is the case worth covering.
func _activate_item(game: Node, board: MinesweeperBoard, type: MinesweeperBoard.ItemType) -> void:
	var item_index := -1
	for index in range(board.width * board.height):
		if board.item_at(index) == type:
			item_index = index
			break
	assert(item_index >= 0, "Tactical item is missing from the board")
	board.reveal_exact_forced_safe(item_index)
	game.call("_refresh_cell", item_index)
	var queue: Array[int] = []
	var queued: Dictionary = {}
	game.call("_resolve_queued_item", item_index, type, queue, queued)
	# 结算前摇 0.3 秒，之后鸟还要飞到目标格才开始干活（小嘴乌鸦掀卡片要 0.36 秒），
	# 所以这里等的时间必须盖过「前摇 + 飞过去」，否则会在效果生效前就去断言。
	await create_timer(1.05).timeout
	assert(board.is_item_used(item_index), "Tactical item was not consumed")
	var cells: Array[MineCell] = game.get("_cells")
	var content := cells[item_index].get("_content") as TextureRect
	assert(content.material is ShaderMaterial, "Consumed tactical item was not grayed out")


func _find_safe_area_center(board: MinesweeperBoard) -> int:
	for center in range(board.width * board.height):
		if board.state_at(center) != MinesweeperBoard.CellState.COVERED or board.is_monster_core(center):
			continue
		var safe := true
		var targets := board.neighbors_of(center)
		targets.append(center)
		for target in targets:
			if board.is_monster_core(target):
				safe = false
				break
		if safe:
			return center
	return -1


func _find_empty_safe_cell(board: MinesweeperBoard) -> int:
	for index in range(board.width * board.height):
		if not board.has_mine(index) and board.item_at(index) == MinesweeperBoard.ItemType.NONE:
			return index
	return -1


func _wait_until_not_resolving(game: Node) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while bool(game.get("_resolving")) and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not bool(game.get("_resolving")), "Item resolution did not finish")
