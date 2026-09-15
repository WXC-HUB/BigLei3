extends SceneTree
## 单机大盘版式：棋盘和它头顶那叠读数（关卡名 / 剩余雷 / 分列道具）必须整块留在
## 画布内。10×10 那档按原尺寸会把「剩余雷」顶出屏幕，_apply_solo_board_fit 用一次
## 小幅收缩 + 下移把它按回来。

const TOLERANCE := 0.5


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame

	var consts := (game.get_script() as GDScript).get_script_constant_map()
	var design: Vector2 = consts["DESIGN_VIEWPORT"]
	var top_margin: float = consts["BOARD_FIT_TOP_MARGIN"]
	var bottom_margin: float = consts["BOARD_FIT_BOTTOM_MARGIN"]
	var cell_size: float = consts["CELL_SIZE"]
	# 这几块面板都是居中锚点，offset 就是相对画布中心的设计坐标。headless 下视口
	# 高度会被报成 1920（见 test_duel_split_layout 的注记），所以一律拿设计分辨率
	# 的中心还原屏幕位置，而不是读 global_position。
	var center_y := design.y * 0.5

	var board_panel := game.get("_board_panel") as Control
	var mine_panel := game.get("_mine_counter_panel") as Control
	var stage_label := game.get("_stage_board_label") as Control
	assert(board_panel != null and mine_panel != null and stage_label != null)

	# 塞得下的小盘保持原样：既不缩也不挪。
	for size in [5, 6, 7]:
		game.call("_resize_board_layout", size, size)
		assert(
			is_equal_approx(float(game.get("_cell_size")), cell_size),
			"%d×%d 不该被缩" % [size, size]
		)
		assert(
			(game.get("_board_center_offset") as Vector2) == Vector2.ZERO,
			"%d×%d 不该被挪" % [size, size]
		)

	# 大盘：整块（读数叠 + 棋盘）落在上下留白之间，收缩幅度限定在一档以内。
	for size in [8, 9, 10]:
		game.call("_resize_board_layout", size, size)
		var cell := float(game.get("_cell_size"))
		assert(cell <= cell_size, "%d×%d 的格子被放大了：%f" % [size, size, cell])
		assert(
			cell > cell_size * 0.85,
			"%d×%d 缩得太狠了：%f" % [size, size, cell]
		)
		var stack_top := center_y + stage_label.offset_top
		var mine_top := center_y + mine_panel.offset_top
		var board_bottom := center_y + board_panel.offset_bottom
		assert(
			stack_top >= top_margin - TOLERANCE,
			"%d×%d 的关卡名被顶出画布：%f" % [size, size, stack_top]
		)
		assert(
			mine_top >= top_margin - TOLERANCE,
			"%d×%d 的剩余雷读数被顶出画布：%f" % [size, size, mine_top]
		)
		assert(
			board_bottom <= design.y - bottom_margin + TOLERANCE,
			"%d×%d 的棋盘探出画布下沿：%f" % [size, size, board_bottom]
		)
		# 读数叠仍旧压在棋盘上方，没有和棋盘叠在一起。
		var board_top := center_y + board_panel.offset_top
		assert(
			center_y + mine_panel.offset_bottom <= board_top + TOLERANCE,
			"%d×%d 的读数压到棋盘上了" % [size, size]
		)

	# 最大的一档确实缩了——否则这条修复根本没生效。
	game.call("_resize_board_layout", 10, 10)
	assert(float(game.get("_cell_size")) < cell_size, "10×10 没有触发收缩")
	assert((game.get("_board_center_offset") as Vector2).y > 0.0, "10×10 没有整体下移")

	print("Board fit: 大盘整块留在画布内，格子只做小幅收缩")
	quit()
