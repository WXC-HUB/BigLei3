extends SceneTree
## 世界地图场景本体：关卡节点与关卡表对得上、悬浮牌四态正确、相机限位与缩放区间成立、
## 拖拽超阈值不会误进关。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("World map test timed out")
		quit(2)
	)
	var map := (load("res://scenes/world_map.tscn") as PackedScene).instantiate() as WorldMap
	assert(map != null, "world_map.tscn 的根节点不是 WorldMap")
	root.add_child(map)
	await process_frame

	_check_scene_wiring(map)
	await _check_badge_states(map)
	await _check_camera(map)
	await _check_drag_guard(map)
	await _check_region_readout(map)

	map.queue_free()
	await process_frame
	print("World map: %d 个关卡节点、四态悬浮牌、相机限位与拖拽判定全部通过" % map_marker_count)
	quit()


var map_marker_count := 0


## 场景与关卡表的挂接：每个 StageMarker 的 stage_id 都能查到、无重复，且表里每一关都在
## 场景里有节点。少一个关卡在地图上就是一个点不到的关。
func _check_scene_wiring(map: WorldMap) -> void:
	var markers := map.get_node("StageMarkers")
	assert(markers != null, "场景里没有 StageMarkers")
	assert(map.get_node_or_null("MapCamera") is Camera3D, "场景里没有 MapCamera")
	assert(map.get_node_or_null("HexTerrain") != null, "场景里没有 HexTerrain")

	var seen := {}
	for child in markers.get_children():
		var id := String(child.get_meta("stage_id", ""))
		assert(id != "", "关卡节点 %s 没有 stage_id 元数据" % child.name)
		assert(StageTable.has_stage(id), "场景里的 %s 在关卡表里查不到" % id)
		assert(not seen.has(id), "场景里有两个节点都挂着 %s" % id)
		seen[id] = true
	for stage in StageTable.STAGES:
		assert(seen.has(String(stage["id"])), "关卡表里的 %s 在地图上没有节点" % String(stage["id"]))
	map_marker_count = markers.get_child_count()
	assert(map.marker_count() == StageTable.STAGES.size(), "WorldMap 认领的关卡数与关卡表不符")

	# 地格数量：共识 2 定的是"约 150 块"。给一个宽区间，手改场景后不该动不动就红。
	var tiles := 0
	for group in map.get_node("HexTerrain").get_children():
		tiles += group.get_child_count()
	assert(tiles >= 100, "地格只有 %d 块，比约定的规模少太多" % tiles)


func _check_badge_states(map: WorldMap) -> void:
	var first_region := String(StageTable.REGIONS[0]["id"])
	var locked_region := String(StageTable.REGIONS[1]["id"])
	var entry_stages := StageTable.stages_in_region(first_region)
	var cleared_id := String(entry_stages[0]["id"])
	var resume_id := String(entry_stages[1]["id"])
	var open_id := String(entry_stages[2]["id"])
	var locked_id := String(StageTable.stages_in_region(locked_region)[0]["id"])

	map.present([cleared_id], resume_id, 3)
	await process_frame

	var cleared_badge := map.badge_for(cleared_id)
	var resume_badge := map.badge_for(resume_id)
	var open_badge := map.badge_for(open_id)
	var locked_badge := map.badge_for(locked_id)
	assert(cleared_badge != null and locked_badge != null, "悬浮牌没有铺满全部关卡")

	assert(cleared_badge.current_state() == StageBadge.State.CLEARED, "已通关的关卡没显示为已通关")
	assert(resume_badge.current_state() == StageBadge.State.IN_PROGRESS, "续局中的关卡没显示为进行中")
	assert(open_badge.current_state() == StageBadge.State.AVAILABLE, "已解锁未打的关卡状态不对")
	assert(locked_badge.current_state() == StageBadge.State.LOCKED, "下一区的关卡居然是解锁的")

	# 未解锁的牌子必须自己吃掉点击，不能靠回调里再判一次。
	assert(locked_badge.disabled, "未解锁的悬浮牌没有 disabled")
	assert(not open_badge.disabled, "可挑战的悬浮牌被禁用了")

	# 四态各有不同的状态词，且牌面同时带着序号名字与目标盘数。
	var words := {}
	for state in [
		StageBadge.State.CLEARED, StageBadge.State.AVAILABLE,
		StageBadge.State.LOCKED, StageBadge.State.IN_PROGRESS,
	]:
		var word := String(StageBadge.STATE_WORDS[state])
		assert(not words.has(word), "两个状态共用了同一个词: %s" % word)
		words[word] = true
	var stage := StageTable.stage(open_id)
	var name_label := open_badge.get_node("BadgeNameLabel") as Label
	var round_label := open_badge.get_node("BadgeRoundLabel") as Label
	assert(
		name_label.text == "%d · %s" % [int(stage["order"]), String(stage["name"])],
		"悬浮牌上的序号或名字不对: %s" % name_label.text
	)
	assert(
		round_label.text == "%d 盘" % int(stage["target_round"]),
		"悬浮牌上的目标盘数不对: %s" % round_label.text
	)

	# 点已解锁但不是续局中的那一关：有续局槽在，应当先弹确认而不是直接进关。
	var entered: Array = []
	map.stage_selected.connect(func(id: String) -> void: entered.append(id))
	open_badge.pressed.emit()
	await process_frame
	assert(entered.is_empty(), "有续局槽时点别的关卡直接进去了，没弹确认")
	var confirm := map.get_node("WorldMapUi/AbandonConfirm") as Control
	assert(confirm.visible, "放弃确认卡没有弹出")

	# 确认放弃 → 先发 abandon，再进那一关。
	var abandoned := [false]
	map.abandon_requested.connect(func() -> void: abandoned[0] = true)
	(confirm.get_node("ConfirmPanel/ConfirmYesButton") as Button).pressed.emit()
	await process_frame
	assert(abandoned[0], "确认放弃后没有发出 abandon_requested")
	assert(entered == [open_id], "确认放弃后没有进入刚点的那一关")

	# 没有续局槽时，点关卡应当直接进。
	entered.clear()
	map.present([cleared_id], "", 0)
	await process_frame
	assert(not (map.get_node("WorldMapUi/ResumeBanner") as Control).visible, "无续局时提示条没收起")
	map.badge_for(open_id).pressed.emit()
	await process_frame
	assert(entered == [open_id], "无续局槽时点关卡没有直接进入")

	# 未解锁的关卡即使被强行 emit 也不能进。
	entered.clear()
	map.badge_for(locked_id).pressed.emit()
	await process_frame
	assert(entered.is_empty(), "未解锁的关卡被点进去了")


func _check_camera(map: WorldMap) -> void:
	map.present([], "", 0)
	await process_frame
	var camera := map.get_node("MapCamera") as Camera3D

	# 缩放夹在区间内，且滚到底不会越界。
	for _i in 40:
		map._zoom_by(-WorldMap.ZOOM_STEP)
	assert(
		is_equal_approx(map.camera_distance(), WorldMap.ZOOM_MIN),
		"一直往近拉之后视距是 %f，没停在 ZOOM_MIN" % map.camera_distance()
	)
	for _i in 80:
		map._zoom_by(WorldMap.ZOOM_STEP)
	assert(
		is_equal_approx(map.camera_distance(), WorldMap.ZOOM_MAX),
		"一直往远推之后视距是 %f，没停在 ZOOM_MAX" % map.camera_distance()
	)

	# 平移限位：往一个方向猛拖，中心必须停在边界上而不是飞出去。
	for _i in 200:
		map._pan_by(Vector2(-400.0, -400.0))
	var pivot := map.camera_pivot()
	assert(pivot.x <= map._pan_max.x + 0.001, "镜头中心 x 冲出了右边界")
	assert(pivot.z <= map._pan_max.y + 0.001, "镜头中心 z 冲出了下边界")
	for _i in 400:
		map._pan_by(Vector2(400.0, 400.0))
	pivot = map.camera_pivot()
	assert(pivot.x >= map._pan_min.x - 0.001, "镜头中心 x 冲出了左边界")
	assert(pivot.z >= map._pan_min.y - 0.001, "镜头中心 z 冲出了上边界")
	assert(is_zero_approx(pivot.y), "镜头中心离开了地面")

	# 相机始终在中心的上方后方，俯角固定。
	assert(camera.position.y > pivot.y, "相机没有在地面之上")
	assert(
		is_equal_approx(rad_to_deg(camera.rotation.x), WorldMap.CAMERA_PITCH_DEG),
		"相机俯角被改掉了"
	)


## 「这一下是拖还是点」：位移超过阈值后抬手不该进关。
func _check_drag_guard(map: WorldMap) -> void:
	map.present([], "", 0)
	await process_frame
	var stage_id := String(StageTable.STAGES[0]["id"])
	var entered: Array = []
	map.stage_selected.connect(func(id: String) -> void: entered.append(id))

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(960.0, 540.0)
	map._input(press)

	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(WorldMap.DRAG_SLOP + 12.0, 0.0)
	map._input(motion)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = press.position + motion.relative
	map._input(release)

	map.badge_for(stage_id).pressed.emit()
	await process_frame
	assert(entered.is_empty(), "拖了 %f 像素之后抬手仍然进关了" % (WorldMap.DRAG_SLOP + 12.0))

	# 原地按下抬起（位移为 0）应当正常进关。
	map._input(press)
	map._input(release)
	map.badge_for(stage_id).pressed.emit()
	await process_frame
	assert(entered == [stage_id], "原地点击没有进关")


func _check_region_readout(map: WorldMap) -> void:
	map.present([], "", 0)
	await process_frame
	var name_label := map.get_node("WorldMapUi/TopBar/RegionNameLabel") as Label
	var progress_label := map.get_node("WorldMapUi/TopBar/RegionProgressLabel") as Label
	var first_name := String(StageTable.REGIONS[0]["name"])
	assert(
		name_label.text.begins_with(first_name),
		"初次显示时顶栏没报出第一区，而是「%s」" % name_label.text
	)
	assert(progress_label.text.contains("已通关"), "顶栏没有进度文字: %s" % progress_label.text)
	assert(
		progress_label.text.contains(String(StageTable.REGIONS[1]["name"])),
		"第一区的进度文字没提到下一个区: %s" % progress_label.text
	)

	# 局外数值位本期只占位不填数（共识 5）。
	var meta_value := map.get_node("WorldMapUi/TopBar/MetaCurrencyBox/MetaValueLabel") as Label
	assert(meta_value.text == "— —", "局外数值位本期不该填真数字: %s" % meta_value.text)

	# 把镜头拖到最后一区，顶栏应当跟着换。
	var last_id := String(StageTable.STAGES[StageTable.STAGES.size() - 1]["id"])
	map._focus_on(last_id)
	map._refresh_region_readout()
	await process_frame
	var last_name := String(StageTable.region(String(StageTable.stage(last_id)["region"]))["name"])
	assert(
		name_label.text.begins_with(last_name),
		"镜头挪到最后一区后顶栏还写着「%s」" % name_label.text
	)
	assert(name_label.text.contains("未解锁"), "空存档下最后一区没标未解锁")
