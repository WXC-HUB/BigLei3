extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(12.0).timeout.connect(func() -> void:
		push_error("New tactical item test timed out")
		quit(2)
	)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set("_xray_bonus", 1)
	game.set("_chain_bonus", 1)
	game.set("_enlarge_bonus", 1)
	var pair := PackedInt32Array()
	var board: MinesweeperBoard
	for _attempt in range(7):
		game.call("_start_game")
		board = game.get("_board")
		var center := int(board.height / 2) * board.width + int(board.width / 2)
		board.ensure_mines_placed(center)
		if board.mine_count < 5:
			continue
		pair = _find_clear_aligned_mine_pair(board)
		if pair.size() == 2:
			break
	assert(pair.size() == 2, "Could not find aligned mines for chain test")
	var detect_slot := _find_empty_safe_cell(board)
	assert(detect_slot >= 0 and board.force_item_at(detect_slot, MinesweeperBoard.ItemType.DETECT, false), "Could not prepare detect item")
	for item_type in [
		MinesweeperBoard.ItemType.XRAY,
		MinesweeperBoard.ItemType.CHAIN,
		MinesweeperBoard.ItemType.ENLARGE,
		MinesweeperBoard.ItemType.DETECT,
	]:
		assert(board.item_count(item_type) == 1, "New tactical item was not generated exactly once")

	await _activate_item(game, board, MinesweeperBoard.ItemType.CHAIN)
	game.call("_on_cell_flagged", pair[0])
	await process_frame
	var chain_markers: Array[int] = game.get("_chain_marked_mines")
	assert(chain_markers.has(pair[0]), "Chain did not create a marked mine")
	game.call("_on_cell_flagged", pair[1])
	await _wait_until_not_resolving(game)
	for target in game.call("_line_between_targets", pair[0], pair[1]):
		assert(board.state_at(target) == MinesweeperBoard.CellState.REVEALED, "Chain did not reveal an intermediate cell")

	await _activate_item(game, board, MinesweeperBoard.ItemType.XRAY)
	var xray_target: int = game.get("_last_xray_target")
	assert(xray_target >= 0, "X-ray did not choose a target")
	var cells: Array[MineCell] = game.get("_cells")
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
	game.call("_on_cell_hover_started", enlarge_target)
	await create_timer(0.12).timeout
	game.call("_on_cell_flagged", enlarge_target)
	await process_frame
	assert(int(game.get("_enlarge_mark_charges")) == enlarge_charges_before, "Right-click incorrectly consumed enlarge")
	assert(board.state_at(enlarge_target) == MinesweeperBoard.CellState.FLAGGED, "Right-click stopped behaving as a normal flag")
	game.call("_on_cell_revealed", enlarge_target)
	await _wait_until_not_resolving(game)
	assert(int(game.get("_enlarge_mark_charges")) == enlarge_charges_before - 1, "Enlarge did not consume exactly one left-click charge")
	assert(board.state_at(enlarge_target) == MinesweeperBoard.CellState.REVEALED, "Enlarge flagged instead of revealing its center")
	for preview_target in enlarge_preview_targets:
		var remaining_overlay := cells[preview_target].get("_preview_overlay") as Panel
		assert(not remaining_overlay.visible, "Enlarge hover outline remained after consumption")
	print("New tactical items: x-ray, chain, enlarge, and detect passed")
	quit()


func _find_clear_aligned_mine_pair(board: MinesweeperBoard) -> PackedInt32Array:
	var mines: Array[int] = []
	for index in range(board.width * board.height):
		if board.is_monster_core(index) and board.state_at(index) == MinesweeperBoard.CellState.COVERED:
			mines.append(index)
	for first in mines:
		for second in mines:
			if second <= first:
				continue
			var same_row := first / board.width == second / board.width
			var same_column := first % board.width == second % board.width
			if not same_row and not same_column:
				continue
			var step := 1 if same_row else board.width
			var clear := true
			for target in range(first + step, second, step):
				if board.is_monster_core(target):
					clear = false
					break
			if clear and absi(second - first) > step:
				return PackedInt32Array([first, second])
	return PackedInt32Array()


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
	await create_timer(0.65).timeout
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
