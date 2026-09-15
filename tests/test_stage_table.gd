extends SceneTree
## 关卡表的纯数据体检：id 唯一、序号连续、盘表合理、单区链式解锁无断点。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_stage_ids()
	_check_orders()
	_check_target_rounds()
	_check_stage_themes()
	_check_regions()
	_check_unlock_chain()
	_check_progress_readout()
	_check_first_open_stage()
	print("Stage table: %d 关 / %d 区，id、序号、目标盘数、解锁链全部通过" % [
		StageTable.STAGES.size(), StageTable.REGIONS.size()
	])
	quit()


func _check_stage_ids() -> void:
	var seen := {}
	for stage in StageTable.STAGES:
		var id := String(stage["id"])
		assert(id != "", "关卡有空 id")
		assert(not seen.has(id), "关卡 id 重复: %s" % id)
		seen[id] = true
		assert(StageTable.has_stage(id), "has_stage 认不出自己表里的 %s" % id)
		assert(StageTable.stage(id)["id"] == id, "stage() 取回了别的关卡")
	assert(StageTable.stage("nope_not_a_stage").is_empty(), "stage() 对不存在的 id 没返回空")
	assert(not StageTable.has_stage(""), "has_stage 把空串当成了关卡")


func _check_orders() -> void:
	for index in StageTable.STAGES.size():
		var order := int(StageTable.STAGES[index]["order"])
		assert(order == index + 1, "第 %d 个关卡的序号是 %d，应为 %d" % [index, order, index + 1])


func _check_target_rounds() -> void:
	for stage in StageTable.STAGES:
		var id := String(stage["id"])
		var boards := StageTable.boards_of(id)
		if bool(stage.get("endless", false)):
			# 无尽关没有盘列表也没有目标盘数：盘由 endless_board 现生成，见 test_endless_stage。
			assert(boards.is_empty(), "%s 是无尽关，不该有手写盘列表" % id)
			assert(StageTable.target_round_of(id) == 0, "%s 的目标盘数应为 0" % id)
			assert(int(StageTable.stage(id)["target_round"]) == 0, "%s stage() 派生的 target_round 应为 0" % id)
			continue
		assert(not boards.is_empty(), "%s 没有盘列表" % id)
		var target := StageTable.target_round_of(id)
		assert(target == boards.size(), "%s 的目标盘数与盘列表长度不符" % id)
		assert(int(StageTable.stage(id)["target_round"]) == target, "%s stage() 未派生 target_round" % id)
		var order := int(stage["order"])
		if bool(stage.get("teaches", false)):
			assert(
				target > 4,
				"教学关 %s 的目标盘数 %d 没超过 4 盘教程" % [id, target]
			)
		else:
			var expected := StageTable.expected_board_count_for_order(order)
			assert(
				target == expected,
				"非教程关 %s 盘数应为 %d，实际 %d" % [id, expected, target]
			)
			assert(target >= StageTable.NON_TUTORIAL_BOARD_BASE, "非教程关至少 %d 盘" % StageTable.NON_TUTORIAL_BOARD_BASE)
		for board in boards:
			var shape_id := String(board["shape"])
			assert(BoardShape.has_shape(shape_id), "%s 引用了不存在的形状 %s" % [id, shape_id])
			var mines := int(board["mines"])
			assert(mines >= 1, "%s 的盘雷数不是正数" % id)
			assert(
				mines <= BoardShape.max_mines_for(shape_id),
				"%s 的盘 %s 雷数 %d 超过可玩格预留下限" % [id, shape_id, mines]
			)
	# 盘数递增：后一关不少于前一非教程关。
	var prev := 0
	for stage in StageTable.STAGES:
		if bool(stage.get("teaches", false)) or bool(stage.get("endless", false)):
			continue
		var n := StageTable.target_round_of(String(stage["id"]))
		assert(n >= prev, "非教程关盘数应递增")
		prev = n


## 每关只讲一种伤：形状必须落在该关允许的前缀里，且每关手写盘表。
func _check_stage_themes() -> void:
	for stage in StageTable.STAGES:
		var id := String(stage["id"])
		var prefixes: Array = StageTable.THEME_SHAPE_PREFIXES.get(id, [])
		assert(not prefixes.is_empty(), "%s 没有主题形状前缀" % id)
		if bool(stage.get("endless", false)):
			# 无尽关的「主题」是全部形状族：每个尺寸的抽签池都得够花样。
			for size in range(StageTable.ENDLESS_START_SIZE, StageTable.ENDLESS_MAX_SIZE + 1):
				var pool := StageTable.endless_shape_pool(size)
				assert(pool.size() >= 3, "无尽关边长 %d 的形状池太小：%d" % [size, pool.size()])
				for shape_id in pool:
					assert(StageTable.shape_fits_theme(id, String(shape_id)), "无尽关池里混进了 %s" % String(shape_id))
			continue
		assert(stage.has("boards"), "%s 应手写盘列表，不要再靠阶梯生成" % id)
		var seen := {}
		for board in StageTable.boards_of(id):
			var shape_id := String(board["shape"])
			assert(
				StageTable.shape_fits_theme(id, shape_id),
				"%s 的 %s 不属于本关主题" % [id, shape_id]
			)
			seen[shape_id] = true
		assert(seen.size() >= 3, "%s 主题形太少，长关会显得重复" % id)
	var coast_finale := StageTable.boards_of("coast_1")
	for index in range(maxi(coast_finale.size() - 3, 0), coast_finale.size()):
		var shape_id := String(coast_finale[index]["shape"])
		assert(
			shape_id.begins_with("holes_"),
			"尽头港收尾第 %d 盘应是碎礁，实际是 %s" % [index + 1, shape_id]
		)
		assert(
			not shape_id.contains("_7"),
			"尽头港收尾不应绕回 7×7：%s" % shape_id
		)


func _check_regions() -> void:
	assert(StageTable.REGIONS.size() == 1, "选关地图应只有 1 个连续地形区")
	var region: Dictionary = StageTable.REGIONS[0]
	var id := String(region["id"])
	assert(String(region["name"]) != "", "地形区没有名字")
	assert(String(region["theme"]) != "", "地形区没有主题")
	assert(StageTable.stages_in_region(id).size() == StageTable.STAGES.size(), "关卡没有全部挂在唯一区上")
	assert((region.get("unlock_after", {}) as Dictionary).is_empty(), "唯一区不应再设区级解锁门槛")


## 空档只有第 1 关可进；通关第 N 关后第 N+1 关解锁。
func _check_unlock_chain() -> void:
	var empty: Array = []
	assert(StageTable.is_stage_unlocked(String(StageTable.STAGES[0]["id"]), empty), "第一关在空档下没解锁")
	for index in range(1, StageTable.STAGES.size()):
		var id := String(StageTable.STAGES[index]["id"])
		assert(not StageTable.is_stage_unlocked(id, empty), "空档下后面的关 %s 居然开了" % id)

	var cleared: Array = []
	for index in range(StageTable.STAGES.size() - 1):
		var current := String(StageTable.STAGES[index]["id"])
		var nxt := String(StageTable.STAGES[index + 1]["id"])
		assert(not StageTable.is_stage_unlocked(nxt, cleared), "还没通 %s 时下一关就开了" % current)
		cleared.append(current)
		assert(StageTable.is_stage_unlocked(nxt, cleared), "通关 %s 后下一关仍锁着" % current)


func _check_progress_readout() -> void:
	var region_id := String(StageTable.REGIONS[0]["id"])
	var empty: Array = []
	var progress := StageTable.region_progress(region_id, empty)
	assert(int(progress["cleared"]) == 0, "空存档下已通关数不是 0")
	var clearable := 0
	for stage in StageTable.STAGES:
		if not bool(stage.get("endless", false)):
			clearable += 1
	assert(int(progress["total"]) == clearable, "region_progress 总数应只数能通关的关：%d" % int(progress["total"]))
	assert(String(progress["next_region"]) == "", "单区地图不应再报下一个区")

	var one: Array = [String(StageTable.STAGES[0]["id"])]
	var after := StageTable.region_progress(region_id, one)
	assert(int(after["cleared"]) == 1, "通一关后已通关数没变成 1")


func _check_first_open_stage() -> void:
	var empty: Array = []
	var first := StageTable.first_open_stage(empty)
	assert(first == String(StageTable.STAGES[0]["id"]), "空存档下的初始焦点不是第一关")
	var all_ids: Array = []
	for stage in StageTable.STAGES:
		all_ids.append(String(stage["id"]))
	var done := StageTable.first_open_stage(all_ids)
	assert(StageTable.has_stage(done), "全通关后 first_open_stage 返回了无效 id")
