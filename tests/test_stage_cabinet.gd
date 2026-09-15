extends SceneTree
## 陈列柜选关（左右切换版）：六件展品排成一列、一次只看一件；present 停在该打的那关；
## ‹ › 切换时相机滑动、切走的收回、滑进来的重搭；两端箭头禁用；锁定关的卡不能进；
## 进入发 stage_selected；单槽续局的续上 / 放弃 / 进别关先确认；右键与顶栏信号；dismiss 收干净。


## 无头跑时一帧远不到 1/60 秒，等动画要盯状态，不能数帧。
func _wait_until(predicate: Callable, cap_frames := 2400) -> bool:
	for _i in cap_frames:
		if predicate.call():
			return true
		await process_frame
	return predicate.call()


func _wait_camera(cabinet: StageCabinet) -> void:
	var settled: bool = await _wait_until(func() -> bool: return not cabinet.is_transitioning())
	assert(settled, "相机滑了太久还没到")
	await process_frame


func _wait_quiet(cabinet: StageCabinet) -> void:
	var quiet: bool = await _wait_until(func() -> bool:
		for slot in cabinet.slots():
			if slot.is_entrance_playing():
				return false
		return true)
	assert(quiet, "展品的入场迟迟播不完")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("Stage cabinet test timed out")
		quit(2)
	)
	var cabinet := (load("res://scenes/stage_cabinet.tscn") as PackedScene).instantiate() as StageCabinet
	assert(cabinet != null, "stage_cabinet.tscn 的根节点不是 StageCabinet")
	cabinet.mosquito_events = false
	root.add_child(cabinet)
	await process_frame

	_check_wiring(cabinet)
	await _check_present(cabinet)
	await _check_switching(cabinet)
	await _check_locked_and_enter(cabinet)
	await _check_resume_flow(cabinet)
	await _check_restore(cabinet)
	_check_leaderboard_and_topbar(cabinet)
	await _check_easter_egg_per_stage(cabinet)
	_check_mosquito_trio(cabinet)
	_check_wander_pluck(cabinet)
	_check_dismiss(cabinet)

	cabinet.queue_free()
	await process_frame
	print("Stage cabinet: 六件展品、左右切换、进关与续局确认全部通过")
	quit()


func _check_wiring(cabinet: StageCabinet) -> void:
	assert(cabinet.slot_count() == StageTable.STAGES.size(), "展品数与关卡表不符：%d" % cabinet.slot_count())
	var previous: StageDiorama = null
	for stage in StageTable.STAGES:
		var id := String(stage["id"])
		var slot := cabinet.slot_for(id)
		assert(slot != null, "缺少 %s 的展品" % id)
		assert(not slot.standalone, "柜子里的展品不该自带台面与相机")
		assert(slot.showcase_camera() == null, "托管展品不该建自己的相机")
		assert(slot.pick_body() is StaticBody3D, "%s 没有拾取体" % id)
		assert(String(slot.marker().get_meta("stage_id", "")) == id, "%s 锚点的 stage_id 不对" % id)
		if previous != null:
			# 一列摆开：相邻两件间距要比一屏宽，停下时邻件在画外。
			assert(previous.position.distance_to(slot.position) > 45.0, "%s 与前一件摆得太近" % id)
			assert(is_equal_approx(previous.position.y, slot.position.y), "六件展品应在同一台面高度")
		previous = slot
	assert(not cabinet.slot_for("grass_1").is_placeholder(), "青草坡应是真展品")
	assert(not cabinet.slot_for("grass_2").is_placeholder(), "麦垄应是真展品")
	assert(cabinet.slot_for(StageTable.ENDLESS_STAGE_ID).is_placeholder(), "无尽关暂为泥胚占位")
	for slot in cabinet.slots():
		assert(slot.get_node_or_null("Clouds") != null and slot.get_node("Clouds").get_child_count() == slot.cloud_count, "%s 上空没有云" % slot.stage_id)
	assert(cabinet.get_node_or_null("CabinetCamera") is Camera3D, "缺少柜子相机")
	assert(cabinet.get_node_or_null("KeyLight") is DirectionalLight3D, "缺少主光")
	assert(cabinet.get_node_or_null("Table") is MeshInstance3D, "缺少台面")
	for path in ["CabinetUi/TopBar/RegionNameLabel", "CabinetUi/TopBar/BackToTitleButton",
			"CabinetUi/TopBar/AllLeaderboardsButton", "CabinetUi/PrevButton", "CabinetUi/NextButton",
			"CabinetUi/StageCard/EnterStageButton", "CabinetUi/StageCard/ResumeBanner", "CabinetUi/AbandonConfirm"]:
		assert(cabinet.get_node_or_null(path) != null, "缺少 UI 节点 %s" % path)


## present：停在第一个能打的关，那件在播入场；牌子四态、泥胚观感、顶栏读数、卡片文案。
func _check_present(cabinet: StageCabinet) -> void:
	cabinet.present(["grass_1"], "", 0, {"grass_1": 2556})
	await process_frame
	assert(cabinet.visible, "present 之后应可见")
	assert(cabinet.current_stage() == "grass_2", "没有续局时应停在第一个可挑战的关，实际 %s" % cabinet.current_stage())
	assert(cabinet.slot_for("grass_2").is_entrance_playing(), "present 时当前展品应在播入场")
	assert(not cabinet.slot_for("grass_1").is_entrance_playing(), "画外的展品不该也在播")
	assert(cabinet.badge_for("grass_1").current_state() == StageBadge.State.CLEARED, "已通关的牌子状态不对")
	assert(cabinet.badge_for("grass_2").current_state() == StageBadge.State.AVAILABLE, "可挑战的牌子状态不对")
	assert(cabinet.badge_for("grass_3").current_state() == StageBadge.State.LOCKED, "未解锁的牌子状态不对")
	assert(not cabinet.slot_for("grass_2").is_locked_look(), "可挑战的展品不该是泥胚色")
	assert(cabinet.slot_for("grass_3").is_locked_look(), "未解锁的展品应是泥胚色")
	assert(not cabinet.slot_for("grass_1").is_withered(), "已通关的展品应是生机版")
	assert(cabinet.slot_for("grass_2").is_withered(), "未通关的展品应是荒废版")
	assert(cabinet.slot_for("grass_2").model_path.ends_with("_withered.glb"), "荒废版应读 _withered.glb")
	assert(cabinet.slot_for("grass_3").is_withered(), "未解锁的展品也应是荒废版")
	var camera := cabinet.camera()
	assert(camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "柜子相机应为正交")
	assert(is_equal_approx(camera.size, cabinet.slot_for("grass_2").camera_size), "相机尺寸应等于当前展品的展示尺寸")
	var anchor := cabinet.slot_for("grass_2").marker().global_position
	assert(root.get_visible_rect().grow(-40.0).has_point(camera.unproject_position(anchor)), "当前展品的锚点没在画面里")
	assert(not cabinet.badge_for("grass_1").visible or not root.get_visible_rect().has_point(camera.unproject_position(cabinet.slot_for("grass_1").marker().global_position)), "邻件不该还在画面里")
	var readout := cabinet.get_node("CabinetUi/TopBar/RegionProgressLabel") as Label
	var clearable := int(StageTable.region_progress("habitat", ["grass_1"])["total"])
	assert(readout.text.begins_with("已通关 1 / %d" % clearable), "地形区读数不对：%s" % readout.text)
	assert((cabinet.get_node("CabinetUi/StageCard/StageCardTitle") as Label).text.contains("麦垄"), "关卡卡没写当前关名")
	assert((cabinet.get_node("CabinetUi/StageCard/EnterStageButton") as Button).text == "进入关卡", "可挑战关的按钮应是进入关卡")
	assert(not (cabinet.get_node("CabinetUi/StageCard/ResumeBanner") as Control).visible, "没有续局时不该显示续局条")
	assert(not cabinet.prev_button().disabled and not cabinet.next_button().disabled, "中间的关左右箭头都该可用")
	await _wait_quiet(cabinet)


## ‹ ›：相机滑动、切走的收回、滑进来的重搭、卡片与箭头跟着变；两端禁用。
func _check_switching(cabinet: StageCabinet) -> void:
	var before := cabinet.camera().global_position
	cabinet.press_prev()
	await process_frame
	assert(cabinet.current_stage() == "grass_1", "按左箭头应切到上一关")
	assert(cabinet.is_transitioning(), "切换时相机应在滑")
	assert(cabinet.slot_for("grass_2").is_entrance_playing(), "切走的展品应在收回")
	assert(cabinet.slot_for("grass_1").build_progress < 0.01, "滑进来的展品应先收成空")
	assert((cabinet.get_node("CabinetUi/StageCard/StageCardTitle") as Label).text.contains("青草坡"), "切换后关卡卡应立刻换成目标关")
	assert(cabinet.prev_button().disabled, "第一关时左箭头应禁用")
	var palette_before: Dictionary = cabinet.table_palette().duplicate(true)
	await _wait_camera(cabinet)
	var palette_after: Dictionary = cabinet.table_palette()
	assert((palette_after["far"] as Color).is_equal_approx(cabinet.slot_for("grass_1").table_palette()["far"]), "切到位后台面配色应等于当前展品的桌布配色")
	assert(not (palette_before["far"] as Color).is_equal_approx(palette_after["far"]) or cabinet.slot_for("grass_2").table_palette()["far"] == cabinet.slot_for("grass_1").table_palette()["far"], "切换时台面配色应跟着换")
	assert(cabinet.camera().global_position.distance_to(before) > 30.0, "相机没有滑到相邻展品")
	var built: bool = await _wait_until(func() -> bool: return cabinet.slot_for("grass_1").is_entrance_playing() or cabinet.slot_for("grass_1").build_progress > 0.0)
	assert(built, "滑到位后新展品没有开始重搭")
	await _wait_quiet(cabinet)
	assert(is_equal_approx(cabinet.slot_for("grass_1").build_progress, 1.0), "重搭完应是完全体")
	assert(is_equal_approx(cabinet.slot_for("grass_2").build_progress, 0.0), "切走的展品应保持收起")
	cabinet.press_prev()
	assert(cabinet.current_stage() == "grass_1", "已是第一关再按左箭头不该动")
	# 一路按到最后一关：右箭头禁用。
	for _i in StageTable.STAGES.size() - 1:
		cabinet.press_next()
		await _wait_camera(cabinet)
	assert(cabinet.current_stage() == String(StageTable.STAGES[StageTable.STAGES.size() - 1]["id"]), "连按右箭头没到最后一关")
	assert(cabinet.next_button().disabled, "最后一关时右箭头应禁用")
	await _wait_quiet(cabinet)


## 锁定关：卡上的按钮禁用、进入不发信号；切回可挑战关按进入发 stage_selected；点本体也算进入。
func _check_locked_and_enter(cabinet: StageCabinet) -> void:
	var selected: Array = []
	var handler := func(id: String) -> void: selected.append(id)
	cabinet.stage_selected.connect(handler)
	assert((cabinet.get_node("CabinetUi/StageCard/EnterStageButton") as Button).disabled, "锁定关的进入按钮应禁用")
	assert((cabinet.get_node("CabinetUi/StageCard/EnterStageButton") as Button).text == "未解锁", "锁定关按钮文案不对")
	cabinet.press_enter()
	cabinet.press_slot(cabinet.current_stage())
	assert(selected.is_empty(), "锁定关不该进关")
	while cabinet.current_stage() != "grass_2":
		cabinet.press_prev()
		await _wait_camera(cabinet)
	await _wait_quiet(cabinet)
	cabinet.press_enter()
	assert(selected == ["grass_2"], "按进入应发 stage_selected(grass_2)，实际 %s" % str(selected))
	cabinet.press_slot("grass_2")
	assert(selected.size() == 2, "点当前展品本体应等于进入")
	cabinet.badge_for("grass_2").pressed.emit()
	assert(selected.size() == 3, "点当前展品的牌子应等于进入")
	cabinet.stage_selected.disconnect(handler)


## 单槽续局：present 停在进行中的关，卡上是「续上」+「放弃」；切到别关进入先确认，确认后 abandon → select。
func _check_resume_flow(cabinet: StageCabinet) -> void:
	cabinet.entrance_events = false
	cabinet.present(["grass_1"], "grass_2", 3, {})
	await process_frame
	assert(cabinet.current_stage() == "grass_2", "有续局时应停在进行中的关")
	var enter := cabinet.get_node("CabinetUi/StageCard/EnterStageButton") as Button
	var abandon := cabinet.get_node("CabinetUi/StageCard/AbandonStageButton") as Button
	var banner := cabinet.get_node("CabinetUi/StageCard/ResumeBanner") as Control
	assert(enter.text.contains("续上") and abandon.visible, "进行中的关卡上应是续上 + 放弃")
	assert(banner.visible and (cabinet.get_node("CabinetUi/StageCard/ResumeBanner/ResumeTextLabel") as Label).text.contains("第 3"), "续局条没写到第几盘")
	var events: Array = []
	var on_select := func(id: String) -> void: events.append("select:" + id)
	var on_abandon := func() -> void: events.append("abandon")
	var on_resume := func() -> void: events.append("resume")
	cabinet.stage_selected.connect(on_select)
	cabinet.abandon_requested.connect(on_abandon)
	cabinet.resume_requested.connect(on_resume)
	cabinet.press_enter()
	assert(events == ["resume"], "续上应发 resume_requested：%s" % str(events))
	events.clear()
	cabinet.press_prev()
	await _wait_camera(cabinet)
	assert(cabinet.current_stage() == "grass_1", "没切到第一关")
	assert(banner.visible and (cabinet.get_node("CabinetUi/StageCard/ResumeBanner/ResumeTextLabel") as Label).text.contains("麦垄"), "在别关时续局条应提醒会放弃哪一关")
	assert(not abandon.visible, "别关的卡上不该有放弃按钮")
	cabinet.press_enter()
	await process_frame
	var confirm := cabinet.get_node("CabinetUi/AbandonConfirm") as Control
	assert(confirm.visible, "有续局时进别的关应先弹确认")
	assert(events.is_empty(), "确认前不该发任何信号")
	assert((cabinet.get_node("CabinetUi/AbandonConfirm/ConfirmPanel/ConfirmTextLabel") as Label).text.contains("麦垄"), "确认文案没写进行中的关名")
	(cabinet.get_node("CabinetUi/AbandonConfirm/ConfirmPanel/ConfirmYesButton") as Button).pressed.emit()
	await process_frame
	assert(events == ["abandon", "select:grass_1"], "确认放弃后的信号顺序不对：%s" % str(events))
	assert(not confirm.visible, "确认后卡片应关掉")
	# 「放弃」按钮：只放弃、不进关。
	events.clear()
	cabinet.present(["grass_1"], "grass_2", 3, {})
	await process_frame
	(cabinet.get_node("CabinetUi/StageCard/AbandonStageButton") as Button).pressed.emit()
	await process_frame
	assert(confirm.visible, "点放弃应弹确认")
	(cabinet.get_node("CabinetUi/AbandonConfirm/ConfirmPanel/ConfirmYesButton") as Button).pressed.emit()
	await process_frame
	assert(events == ["abandon"], "放弃确认后只该发 abandon：%s" % str(events))
	cabinet.stage_selected.disconnect(on_select)
	cabinet.abandon_requested.disconnect(on_abandon)
	cabinet.resume_requested.disconnect(on_resume)
	# 续局清掉之后再 present：续局条收起。
	cabinet.present(["grass_1"], "", 0, {})
	await process_frame
	assert(not banner.visible, "没有续局时续局条应收起")


func _check_restore(cabinet: StageCabinet) -> void:
	# 刚通关麦垄回到柜子：排行榜（modal_overlay）还开着时先停在麦垄、保持荒废版；榜一关，
	# 荒废版收回、生机版带粒子重搭、标题与短句弹出（复原），播完自动滑到下一关。
	cabinet.entrance_events = true
	var blocker := CanvasLayer.new()
	blocker.name = "FakeLeaderboard"
	blocker.layer = 118
	blocker.add_to_group("modal_overlay")
	root.add_child(blocker)
	cabinet.present(["grass_1", "grass_2"], "", 0, {})
	for _i in 6:
		await process_frame
	assert(cabinet.current_stage() == "grass_2", "刚通关的关应先停在它自己身上，实际 %s" % cabinet.current_stage())
	var slot := cabinet.slot_for("grass_2")
	assert(slot.is_withered() and not slot.is_restoring() and cabinet.restoring_stage() == "", "排行榜开着时不该开始复原")
	assert(cabinet.pending_restore_stage() == "grass_2", "应记着等排行榜关掉再复原")
	# 榜开着时再 present 一次（主场景关榜后会再钉一次选关）：仍停在麦垄、仍等着。
	cabinet.present(["grass_1", "grass_2"], "", 0, {})
	await process_frame
	assert(cabinet.current_stage() == "grass_2" and cabinet.pending_restore_stage() == "grass_2", "再 present 不该丢掉待播的复原")
	blocker.visible = false
	var started: bool = await _wait_until(func() -> bool: return cabinet.restoring_stage() == "grass_2" and slot.is_restoring(), 600)
	assert(started, "排行榜关掉后应开始复原")
	assert((cabinet.get_node("CabinetUi/RestoreTitle") as Control).visible, "复原时应有标题反馈")
	assert((cabinet.get_node("CabinetUi/RestoreTitle/RestoreTitleLabel") as Label).text.contains("麦垄"), "标题该写关名")
	var fx: bool = await _wait_until(func() -> bool: return slot.get_node_or_null("RestoreFx") != null, 6000)
	assert(fx, "生机版重搭时该有粒子")
	assert(slot.get_node("RestoreFx").get_node_or_null("RestoreLeaves") is CPUParticles3D, "缺少叶片花瓣粒子")
	var lines: bool = await _wait_until(func() -> bool: return cabinet.get_node("CabinetUi/RestoreLines").get_child_count() > 0, 6000)
	assert(lines, "复原时该弹出文字短句")
	var restored: bool = await _wait_until(func() -> bool: return not slot.is_restoring() and not slot.is_entrance_playing(), 12000)
	assert(restored, "复原迟迟播不完")
	assert(not slot.is_withered(), "复原后应是生机版")
	assert(not slot.model_path.ends_with("_withered.glb"), "复原后应读生机版模型")
	var advanced: bool = await _wait_until(func() -> bool: return cabinet.current_stage() == "grass_3", 12000)
	assert(advanced, "复原后应自动滑到下一关")
	await _wait_camera(cabinet)
	await _wait_quiet(cabinet)
	assert(cabinet.slot_for("grass_3").is_withered(), "下一关还没打，应仍是荒废版")
	assert(not (cabinet.get_node("CabinetUi/RestoreTitle") as Control).visible or cabinet.restoring_stage() == "", "仪式结束后标题卡该收掉")
	blocker.queue_free()


func _check_leaderboard_and_topbar(cabinet: StageCabinet) -> void:
	var events: Array = []
	cabinet.leaderboard_requested.connect(func(id: String) -> void: events.append("board:" + id))
	cabinet.all_leaderboards_requested.connect(func() -> void: events.append("all"))
	cabinet.title_requested.connect(func() -> void: events.append("title"))
	cabinet.badge_for("grass_1").leaderboard_requested.emit("grass_1")
	(cabinet.get_node("CabinetUi/TopBar/AllLeaderboardsButton") as Button).pressed.emit()
	(cabinet.get_node("CabinetUi/TopBar/BackToTitleButton") as Button).pressed.emit()
	assert(events == ["board:grass_1", "all", "title"], "顶栏/看榜信号不对：%s" % str(events))


## 彩蛋按关分家：第 1 关只有蚊子，第 2 关只有游荡的动物，别的关两个都不出。
func _check_easter_egg_per_stage(cabinet: StageCabinet) -> void:
	cabinet.mosquito_events = true
	var bug := cabinet.mosquito()
	var beast := cabinet.wander_animal()
	cabinet.present([], "", 0, {})
	await _wait_camera(cabinet)
	assert(cabinet.current_stage() == StageCabinet.MOSQUITO_STAGE, "没通关时该停在第 1 关")
	assert(bug.is_processing(), "第 1 关上蚊子该飞")
	assert(not beast.is_processing(), "第 1 关上不该有游荡的动物")

	cabinet.press_next()
	await _wait_camera(cabinet)
	assert(cabinet.current_stage() == StageCabinet.WANDER_STAGE, "没切到第 2 关")
	assert(beast.is_processing(), "第 2 关上该有游荡的动物")
	assert(not bug.is_processing(), "第 2 关上不该再有蚊子")

	cabinet.press_next()
	await _wait_camera(cabinet)
	assert(not bug.is_processing() and not beast.is_processing(), "第 3 关上两个彩蛋都该收起来")
	cabinet.mosquito_events = false
	cabinet.press_prev()
	await _wait_camera(cabinet)


## 薅毛：四种动物各薅一撮，最后一撮那一下发成就；动物是站在岛面格子上的。
func _check_wander_pluck(cabinet: StageCabinet) -> void:
	var beast := cabinet.wander_animal()
	# 把舞台摆好（present 时 mosquito_events 关着，彩蛋不会自己开）。
	beast.set_ground_source(cabinet.slot_for(StageCabinet.WANDER_STAGE), cabinet.camera())
	var eggs: Array = []
	var handler := func(id: String) -> void: eggs.append(id)
	cabinet.easter_egg_triggered.connect(handler)
	beast.start()
	beast.set_process(false)
	var frame := 1.0 / 60.0
	var keys := []
	for spec in MapWanderAnimal.ANIMALS:
		keys.append(String(spec["key"]))
	for i in MapWanderAnimal.PLUCK_GOAL:
		beast.spawn_key(String(keys[i]))
		assert(beast.is_walking(), "第 %d 只没走起来" % (i + 1))
		assert(beast.current_key() == String(keys[i]), "放出来的不是点名的那只")
		assert(beast.is_on_land(beast.cell().x, beast.cell().y), "%s 没站在岛面的陆地格上" % keys[i])
		assert(beast.body_rect().size.x > 10.0, "%s 的贴图矩形没算出来" % keys[i])
		# 鼠标停到身上就开薅，不用点。
		beast.set_pointer_for_test(beast.body_rect().get_center())
		for _j in int(0.2 / frame):
			beast.drive(frame)
		assert(beast.is_busy(), "鼠标停在 %s 身上没开薅" % keys[i])
		# 薅是四拍动画，记账在「薅下」那一拍，要等动画走到那儿。
		for _j in int(1.0 / frame):
			beast.drive(frame)
		assert(beast.pluck_count() == i + 1, "薅到的种类数不对：%d" % beast.pluck_count())
		if i < MapWanderAnimal.PLUCK_GOAL - 1:
			assert(eggs.is_empty(), "还没薅够就发了成就：%s" % str(eggs))
		# 指针挪开，走完逃跑回到没人的状态。
		beast.set_pointer_for_test(Vector2(-500.0, -500.0))
		for _j in int(2.0 / frame):
			beast.drive(frame)
	assert(beast.is_complete(), "薅够 %d 种就该算成了" % MapWanderAnimal.PLUCK_GOAL)
	assert(eggs == [AchievementCatalog.MAP_FUR_HARVEST], "薅够没发对成就：%s" % str(eggs))
	cabinet.easter_egg_triggered.disconnect(handler)
	beast.stop()


## 拍死三只蚊子：第三只那一下发成就，之后这一轮关卡选择里蚊子不再出现。
func _check_mosquito_trio(cabinet: StageCabinet) -> void:
	var bug := cabinet.mosquito()
	assert(bug != null, "柜子上没有蚊子")
	var eggs: Array = []
	var handler := func(id: String) -> void: eggs.append(id)
	cabinet.easter_egg_triggered.connect(handler)
	bug.start()
	bug.set_process(false)
	var frame := 1.0 / 60.0
	for i in MapMosquito.SWAT_LIMIT:
		bug.spawn_now()
		assert(bug.is_flying(), "第 %d 只没飞起来" % (i + 1))
		# 进场那一段冲得太快（一帧一百多像素），挥过去会被当成指针大跳；先等它飞进飞行区内圈。
		var inner := bug.flight_rect().grow(-30.0)
		for _j in int(3.0 / frame):
			if inner.has_point(bug.body_center()):
				break
			bug.drive(frame)
		var center := bug.body_center()
		bug.set_pointer_for_test(center + Vector2(-130.0, 5.0))
		bug.drive(frame)
		center = bug.body_center()
		bug.set_pointer_for_test(center + Vector2(130.0, -5.0))
		bug.drive(frame)
		assert(bug.swat_count() == i + 1, "第 %d 只没拍死" % (i + 1))
		if i < MapMosquito.SWAT_LIMIT - 1:
			assert(eggs.is_empty(), "还没拍满就发了成就：%s" % str(eggs))
		# 让它掉完，最后一只掉完就该退场。
		for _j in int(1.2 * 60.0):
			bug.drive(frame)
	assert(eggs == [AchievementCatalog.MAP_MOSQUITO_TRIO], "拍满三只没发对成就：%s" % str(eggs))
	assert(bug.is_retired(), "拍满之后蚊子没退场")
	cabinet.easter_egg_triggered.disconnect(handler)


func _check_dismiss(cabinet: StageCabinet) -> void:
	cabinet.dismiss()
	assert(not cabinet.visible, "dismiss 之后应隐藏")
	for slot in cabinet.slots():
		assert(not slot.is_entrance_playing(), "dismiss 之后展品不该还在播入场")
