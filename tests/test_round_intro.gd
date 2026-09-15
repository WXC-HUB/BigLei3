extends SceneTree
## 开局演出：先洗牌发牌（所有草地牌从棋盘中心的牌堆甩到各自格子），再亮一次
## 「这一盘的草地下」横幅，列出雷、连携雷和各类埋着的伙伴牌。演完棋盘才交还玩家。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(40.0).timeout.connect(func() -> void:
		push_error("Round intro test timed out")
		quit(2)
	)
	GameSave.save_path = "user://test_round_intro_save.json"
	GameSave.clear()
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame

	# 教学关数直接从 main.gd 读：每加一只鸟它就会 +1，写死在这里的话下次加鸟就假失败。
	var tutorial_levels := int(game.get("TUTORIAL_LEVEL_COUNT"))

	# 教学第一盘走强引导，开局演出要让位给它。
	game.call("_start_game")
	assert(bool(game.call("_is_guided_tutorial_round")), "First tutorial level is no longer the guided round")
	var banner: RoundIntroBanner = game.get("_round_intro_banner")
	assert(banner != null, "Round intro banner was never built")
	assert(not banner.visible, "Round intro banner ran during the guided tutorial round")

	for _level in range(tutorial_levels):
		game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var cells: Array = game.get("_cells")
	assert(not cells.is_empty(), "Board was not built")

	# --- 发牌：牌先叠在牌堆上，动画跑完才各就各位 ---
	var far_index := _farthest_active_cell(game, board)
	var far_visual := cells[far_index].get("_visual_root") as Control
	assert(
		not far_visual.position.is_equal_approx(Vector2.ZERO),
		"The farthest card was not stacked on the deal pile"
	)
	assert(far_visual.modulate.a < 1.0, "Cards were already opaque before being dealt")
	assert(not bool(cells[far_index].get("_interactive")), "Board accepted clicks while cards were flying")

	await _wait_until(func() -> bool: return banner.visible, 12.0, "Round intro banner never appeared")
	for index in range(cells.size()):
		if not board.is_active(index):
			continue
		var visual := cells[index].get("_visual_root") as Control
		assert(visual.position.is_equal_approx(Vector2.ZERO), "A card never reached its slot")
		assert(is_equal_approx(visual.rotation, 0.0), "A card kept its dealing tilt")
		assert(is_equal_approx(visual.modulate.a, 1.0), "A card stayed see-through after being dealt")

	# --- 横幅：雷 + 连携雷 + 本盘每一种伙伴牌 ---
	var expected: Array[Dictionary] = game.call("_round_intro_entries")
	assert(expected.size() >= 2, "Round intro listed neither mines nor items")
	assert(String(expected[0]["name"]) == "雷", "Mines are not the first thing the banner reports")
	assert(int(expected[0]["count"]) == board.mine_count, "Banner reported the wrong mine count")
	assert(String(expected[1]["name"]) == "连携雷", "Chain mines are not reported next to the mines")
	assert(int(expected[1]["count"]) == board.chain_mine_total(), "Banner reported the wrong chain mine count")
	for entry in expected:
		assert(entry["icon"] != null, "A banner entry came through without an icon")
		assert(int(entry["count"]) > 0, "A banner entry was listed with nothing in it")
	assert(banner.entry_count() == expected.size(), "Banner did not lay out one chip per entry")

	# --- 收场：横幅收走，棋盘交还玩家 ---
	await _wait_until(func() -> bool: return not banner.visible, 12.0, "Round intro banner never went away")
	assert(bool(cells[far_index].get("_interactive")), "Board was not handed back after the intro")
	GameSave.clear()
	print("Round intro: cards deal in, banner lists mines/chain mines/items, board unlocks")
	quit()


func _farthest_active_cell(game: Node, board: MinesweeperBoard) -> int:
	var origin: Vector2 = game.call("_board_deal_origin")
	var best := -1
	var best_distance := -1.0
	for index in range(board.width * board.height):
		if not board.is_active(index):
			continue
		var distance: float = (game.call("_cell_center", index) as Vector2).distance_squared_to(origin)
		if distance > best_distance:
			best_distance = distance
			best = index
	return best


func _wait_until(predicate: Callable, seconds: float, message: String) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not bool(predicate.call()) and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(bool(predicate.call()), message)
