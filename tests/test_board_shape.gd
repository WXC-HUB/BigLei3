extends SceneTree
## 盘面形状库与异形棋盘：连通、布雷、胜负、邻接都只认可玩格。


const BoardModel := preload("res://scripts/game/minesweeper_board.gd")


func _init() -> void:
	_check_shape_catalog()
	_check_masked_board_rules()
	_check_stage_boards_resolve()
	print("Board shapes: 形状库、异形棋盘规则与关卡盘表全部通过")
	quit()


func _check_shape_catalog() -> void:
	var ids := BoardShape.all_ids()
	assert(ids.size() >= 40, "形状库太少: %d" % ids.size())
	for id in ids:
		var shape := BoardShape.get_shape(id)
		assert(not shape.is_empty(), "形状 %s 取不到" % id)
		assert(int(shape["active_count"]) > 0, "形状 %s 没有可玩格" % id)
		assert(
			BoardShape.is_mask_connected(shape["mask"], shape["width"], shape["height"]),
			"形状 %s 不是单一连通块" % id
		)
		assert(BoardShape.max_mines_for(id) >= 1, "形状 %s 装不下任何雷" % id)


func _check_masked_board_rules() -> void:
	var shape := BoardShape.get_shape("notch_l_6")
	var board = BoardModel.new(
		int(shape["width"]),
		int(shape["height"]),
		5,
		4242,
		1, 1, 1, 1, 0, 0, 0, 0, 0,
		shape["mask"]
	)
	assert(board.active_cell_count == int(shape["active_count"]), "可玩格数与形状不符")
	var start := -1
	for index in range(board.width * board.height):
		if board.is_active(index):
			start = index
			break
	assert(start >= 0, "找不到可玩起手格")
	board.reveal(start)
	assert(not board.has_mine(start), "首点落在了雷上")
	for index in range(board.width * board.height):
		if not board.is_active(index):
			assert(board.neighbors_of(index).is_empty(), "空洞格不该有邻居")
			continue
		for neighbor in board.neighbors_of(index):
			assert(board.is_active(neighbor), "邻居里混进了空洞格")
	assert(
		board.active_cell_count < board.width * board.height,
		"L 形测试盘居然没有空洞"
	)


func _check_stage_boards_resolve() -> void:
	for stage in StageTable.STAGES:
		var id := String(stage["id"])
		var boards := StageTable.boards_of(id)
		assert(boards.size() == StageTable.target_round_of(id), "%s 盘数不一致" % id)
		for round_index in range(1, boards.size() + 1):
			var cfg := StageTable.board_at(id, round_index)
			assert(not cfg.is_empty(), "%s 第 %d 盘缺失" % [id, round_index])
			assert(BoardShape.has_shape(String(cfg["shape"])), "%s 第 %d 盘形状无效" % [id, round_index])
	assert(StageTable.board_at("grass_1", 1)["shape"] == "rect_2x1", "教学关第一盘应是 2x1")
	assert(StageTable.STAGES.size() == 6, "精简后应为 6 关")
	var non_tutorial_boards := 0
	for stage in StageTable.STAGES:
		if bool(stage.get("teaches", false)):
			continue
		var id := String(stage["id"])
		var n := StageTable.target_round_of(id)
		assert(n >= StageTable.NON_TUTORIAL_BOARD_BASE, "%s 少于 %d 盘" % [id, StageTable.NON_TUTORIAL_BOARD_BASE])
		non_tutorial_boards += n
	assert(non_tutorial_boards >= 50, "非教程盘总数偏少：%d" % non_tutorial_boards)
