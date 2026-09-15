extends SceneTree
## 巨大道具 → 长尾山雀：有巨大道具的局里栖枝可见；消耗那一次左键时鸟摔到目标格，
## 落地后 3×3 翻开，鸟顺势掉出屏幕底再淡回栖枝。半空中棋盘处于锁定。

const TUTORIAL_LEVEL_COUNT := 8


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(14.0).timeout.connect(func() -> void:
		push_error("Tit bird crash test timed out")
		quit(2)
	)
	GameSave.save_path = "user://test_tit_bird_crash_save.json"
	GameSave.clear()
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var tit := game.get_node("TitBirdPerch") as BirdPerch
	var sprite := tit.get_node("Sprite") as TextureRect
	var tree := tit.get_node("Tree") as TextureRect

	# 教学期间还没解锁：栖枝整体不露面。解锁后普通关默认带一张巨大道具，鸟常驻左下角。
	game.call("_start_game")
	assert(not tit.visible, "Tit perch showed up before it was unlocked")
	game.set("_tit_bird_unlocked", true)
	for _level in range(TUTORIAL_LEVEL_COUNT):
		game.call("_start_game")
	assert(tit.visible, "Tit perch stayed hidden after unlocking")
	assert(tree.is_visible_in_tree(), "Tit branch is hidden")
	var board: MinesweeperBoard = game.get("_board")
	var centre := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(centre)
	assert(board.item_count(MinesweeperBoard.ItemType.ENLARGE) == 1, "Enlarge item was not generated")
	assert(game.call("_item_display_name", MinesweeperBoard.ItemType.ENLARGE) == "长尾山雀", "Enlarge item was not renamed")

	var target := _find_safe_area_center(board)
	assert(target >= 0, "Could not find a safe 3×3 area")
	var home := sprite.position
	var tree_home := tree.position
	game.set("_enlarge_mark_charges", 1)
	var cell_centre: Vector2 = game.call("_cell_center", target)
	game.call("_on_cell_revealed", target)
	await create_timer(0.3).timeout
	# 半空：鸟离开了栖枝、用的是摔落帧、棋盘锁着、格子还没翻。
	assert(bool(game.get("_resolving")), "Board was not locked while the bird is mid-air")
	assert(int(game.get("_enlarge_mark_charges")) == 0, "Charge was not consumed on click")
	assert(sprite.visible and not sprite.position.is_equal_approx(home), "Bird did not leave its perch")
	assert(tit.action_frames.has(sprite.texture), "Bird is not using a fall frame mid-air")
	assert(tree.position == tree_home, "Branch moved with the falling bird")
	assert(board.state_at(target) == MinesweeperBoard.CellState.COVERED, "3×3 revealed before the bird landed")
	assert(bool(game.get("_enlarge_click_invincible")), "Player was not protected during the fall")

	# 落地瞬间：趴地帧盖在目标格中心上。等的是「趴地帧出现」这个状态，不是一个写死的
	# 秒数——趴地帧正是 `await fall.finished` 之后才设的，等到它就保证落点已经到位。
	# 按秒数等会随栖枝缩放/位置的改动飘几个像素，正好卡在容差边上。
	var landing_deadline := Time.get_ticks_msec() + 4000
	while sprite.texture != tit.action_frames[3] and Time.get_ticks_msec() < landing_deadline:
		await process_frame
	assert(sprite.texture == tit.action_frames[3], "Bird did not land on the crash frame")
	var draw_scale := sprite.get_global_transform().get_scale()
	var sprite_centre := sprite.global_position + sprite.size * draw_scale * 0.5
	assert(sprite_centre.distance_to(cell_centre) < 12.0, "Bird landed away from the target cell: %s vs %s" % [sprite_centre, cell_centre])

	await _wait_until_not_resolving(game)
	assert(board.state_at(target) == MinesweeperBoard.CellState.REVEALED, "Target cell was not revealed after the crash")
	for neighbour in board.neighbors_of(target):
		assert(board.state_at(neighbour) == MinesweeperBoard.CellState.REVEALED, "3×3 area was not fully revealed")
	assert(not bool(game.get("_enlarge_click_invincible")), "Invincibility remained after the reveal")
	# 离场是掉出屏幕底，不是飞回；然后在枝头原位淡回来。
	var viewport_height := root.get_visible_rect().size.y
	var left_the_screen := false
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline and not left_the_screen:
		left_the_screen = not sprite.visible or sprite.global_position.y > viewport_height * 0.9
		await process_frame
	assert(left_the_screen, "Bird did not drop off the bottom of the screen")
	await create_timer(1.2).timeout
	assert(sprite.visible and sprite.position.is_equal_approx(home), "Bird did not reappear on its perch")
	assert(is_equal_approx(sprite.rotation, 0.0) and is_equal_approx(sprite.modulate.a, 1.0), "Perch sprite kept the tumble rotation or fade")
	assert(tit.idle_frames.has(sprite.texture), "Bird did not resume idling")
	GameSave.clear()
	print("Tit bird crash: perch visibility, mid-air lock, landing, 3×3 reveal, drop-off and reappear passed")
	quit()


func _find_safe_area_center(board: MinesweeperBoard) -> int:
	for centre in range(board.width * board.height):
		if board.state_at(centre) != MinesweeperBoard.CellState.COVERED or board.is_monster_core(centre):
			continue
		if board.item_at(centre) != MinesweeperBoard.ItemType.NONE:
			continue
		var safe := true
		var targets := board.neighbors_of(centre)
		targets.append(centre)
		for target in targets:
			if board.is_monster_core(target) or board.item_at(target) != MinesweeperBoard.ItemType.NONE:
				safe = false
				break
		if safe:
			return centre
	return -1


func _wait_until_not_resolving(game: Node) -> void:
	var deadline := Time.get_ticks_msec() + 8000
	while bool(game.get("_resolving")) and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not bool(game.get("_resolving")), "Board stayed locked")
