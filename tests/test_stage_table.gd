extends SceneTree
## 关卡表的纯数据体检：id 唯一、序号连续、目标盘数合理、解锁链无断点。
## 这些断言是「布局手摆在场景里」的对价——摆位不可测，但数值与拓扑必须可测。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_stage_ids()
	_check_orders()
	_check_target_rounds()
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


## 序号是给玩家看的，必须从 1 连续排到 N——中间断号会让「3 · 风车丘」后面直接跳到 5。
func _check_orders() -> void:
	for index in StageTable.STAGES.size():
		var order := int(StageTable.STAGES[index]["order"])
		assert(order == index + 1, "第 %d 个关卡的序号是 %d，应为 %d" % [index, order, index + 1])


func _check_target_rounds() -> void:
	for stage in StageTable.STAGES:
		var target := int(stage["target_round"])
		assert(target > 0, "%s 的目标盘数不是正数" % String(stage["id"]))
		# 教学关的前 4 盘是硬编码教程盘，目标盘数必须留出至少一盘正式盘面，
		# 否则玩家打完教程就通关了、一盘真棋都没下。
		if bool(stage.get("teaches", false)):
			assert(
				target > 4,
				"教学关 %s 的目标盘数 %d 没超过 4 盘教程" % [String(stage["id"]), target]
			)


func _check_regions() -> void:
	var region_ids := {}
	for region in StageTable.REGIONS:
		var id := String(region["id"])
		assert(not region_ids.has(id), "地形区 id 重复: %s" % id)
		region_ids[id] = true
		assert(String(region["name"]) != "", "地形区 %s 没有名字" % id)
		assert(String(region["theme"]) != "", "地形区 %s 没有主题" % id)
		assert(not StageTable.stages_in_region(id).is_empty(), "地形区 %s 里一个关卡都没有" % id)
	for stage in StageTable.STAGES:
		var region_id := String(stage["region"])
		assert(region_ids.has(region_id), "%s 挂在不存在的区 %s 上" % [String(stage["id"]), region_id])
		assert(StageTable.theme_of(String(stage["id"])) != "", "%s 取不到主题" % String(stage["id"]))
	# 只有一个区可以是开局就开的入口，否则新手一上来就看到三片全开的地图。
	var entry_count := 0
	for region in StageTable.REGIONS:
		if (region.get("unlock_after", {}) as Dictionary).is_empty():
			entry_count += 1
	assert(entry_count == 1, "开局即解锁的地形区有 %d 个，应当只有 1 个" % entry_count)


## 解锁链无断点：每个非入口区的前置区都存在，且门槛不超过前置区的关卡总数——
## 门槛比总数还大就是永远开不了的死区。
func _check_unlock_chain() -> void:
	for region in StageTable.REGIONS:
		var gate: Dictionary = region.get("unlock_after", {})
		if gate.is_empty():
			continue
		var previous := String(gate.get("region", ""))
		assert(
			not StageTable.region(previous).is_empty(),
			"%s 的前置区 %s 不存在" % [String(region["id"]), previous]
		)
		var need := int(gate.get("count", 0))
		var available := StageTable.stages_in_region(previous).size()
		assert(need > 0, "%s 的解锁门槛不是正数" % String(region["id"]))
		assert(
			need <= available,
			"%s 要求前置区通关 %d 关，但那边只有 %d 关" % [String(region["id"]), need, available]
		)

	# 空存档：只有入口区可进。
	var empty: Array = []
	var entry_id := ""
	for region in StageTable.REGIONS:
		if (region.get("unlock_after", {}) as Dictionary).is_empty():
			entry_id = String(region["id"])
	for region in StageTable.REGIONS:
		var id := String(region["id"])
		var unlocked := StageTable.is_region_unlocked(id, empty)
		assert(
			unlocked == (id == entry_id),
			"空存档下 %s 的解锁状态错了（%s）" % [id, str(unlocked)]
		)
	for stage in StageTable.stages_in_region(entry_id):
		assert(
			StageTable.is_stage_unlocked(String(stage["id"]), empty),
			"入口区的 %s 在空存档下没解锁" % String(stage["id"])
		)

	# 逐区推进：把前一区打到门槛，下一区就该开。
	var cleared: Array = []
	for index in range(1, StageTable.REGIONS.size()):
		var region: Dictionary = StageTable.REGIONS[index]
		var gate: Dictionary = region["unlock_after"]
		var previous := String(gate["region"])
		var need := int(gate["count"])
		var previous_stages := StageTable.stages_in_region(previous)
		# 差一关时必须还是锁着的。
		cleared = cleared.duplicate()
		for offset in need - 1:
			var id := String(previous_stages[offset]["id"])
			if not cleared.has(id):
				cleared.append(id)
		assert(
			not StageTable.is_region_unlocked(String(region["id"]), cleared),
			"%s 在前置区只通 %d 关时就解锁了" % [String(region["id"]), need - 1]
		)
		cleared.append(String(previous_stages[need - 1]["id"]))
		assert(
			StageTable.is_region_unlocked(String(region["id"]), cleared),
			"%s 在前置区通关 %d 关后仍未解锁" % [String(region["id"]), need]
		)


func _check_progress_readout() -> void:
	var first := String(StageTable.REGIONS[0]["id"])
	var empty: Array = []
	var progress := StageTable.region_progress(first, empty)
	assert(int(progress["cleared"]) == 0, "空存档下第一区的已通关数不是 0")
	assert(
		int(progress["total"]) == StageTable.stages_in_region(first).size(),
		"region_progress 的总数与区内关卡数不符"
	)
	assert(String(progress["next_region"]) != "", "第一区报不出下一个区")
	assert(String(progress["next_region_name"]) != "", "下一个区没有名字")
	assert(int(progress["remaining_for_next"]) > 0, "空存档下开启下一区居然不用再通关")

	# 通一关，剩余门槛就该减一。
	var one: Array = [String(StageTable.stages_in_region(first)[0]["id"])]
	var after := StageTable.region_progress(first, one)
	assert(int(after["cleared"]) == 1, "通一关后已通关数没变成 1")
	assert(
		int(after["remaining_for_next"]) == int(progress["remaining_for_next"]) - 1,
		"通一关后剩余门槛没减少"
	)

	# 最后一区没有下一个。
	var last := String(StageTable.REGIONS[StageTable.REGIONS.size() - 1]["id"])
	assert(
		String(StageTable.region_progress(last, empty)["next_region"]) == "",
		"最后一区居然报出了下一个区"
	)


func _check_first_open_stage() -> void:
	var empty: Array = []
	var first := StageTable.first_open_stage(empty)
	assert(first == String(StageTable.STAGES[0]["id"]), "空存档下的初始焦点不是第一关")
	# 全部通关后不该返回空串——地图仍要有个地方对焦。
	var all_ids: Array = []
	for stage in StageTable.STAGES:
		all_ids.append(String(stage["id"]))
	var done := StageTable.first_open_stage(all_ids)
	assert(StageTable.has_stage(done), "全通关后 first_open_stage 返回了无效 id")
