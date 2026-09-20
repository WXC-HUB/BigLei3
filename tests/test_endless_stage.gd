extends SceneTree
## 第 7 关「无尽远海」：关卡表里的无尽条目、按 (盘序, 种子) 现生成的盘与难度曲线、
## 进度横幅的无尽文案，以及主场景里的流程——永不「打满」、赢一盘记最远盘数、倒下上榜回柜子。
## 跑法：godot --headless --script tests/test_endless_stage.gd

const StageProgressBannerView := preload("res://scenes/ui/stage_progress_banner.tscn")
const ENDLESS := StageTable.ENDLESS_STAGE_ID


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("Endless stage test timed out")
		quit(2)
	)
	var original_path := GameSave.save_path
	GameSave.save_path = "user://test_endless_stage_save.json"
	GameSave.clear()

	_check_table_entry()
	_check_board_generator()
	_check_difficulty_curve()
	_check_save_migration()
	await _check_banner_copy()

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await _check_run_flow(game)
	await _check_fall_returns_to_cabinet(game)

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame
	GameSave.clear()
	GameSave.save_path = original_path
	print("Endless stage: 关卡表条目、随机盘与难度曲线、存档迁移、横幅文案、永不打满、最远盘数记账、倒下上榜回柜子全部通过")
	quit()


## 除无尽关之外的全部关卡 id（按顺序）。
func _all_six() -> Array:
	var out: Array = []
	for stage in StageTable.STAGES:
		if not bool(stage.get("endless", false)):
			out.append(String(stage["id"]))
	return out


func _check_table_entry() -> void:
	assert(StageTable.has_stage(ENDLESS), "关卡表里没有无尽关")
	assert(StageTable.is_endless(ENDLESS), "is_endless 认不出无尽关")
	assert(not StageTable.is_endless("grass_1"), "青草坡被当成了无尽关")
	var stage := StageTable.stage(ENDLESS)
	assert(int(stage["order"]) == StageTable.STAGES.size(), "无尽关应是最后一关")
	assert(int(stage["target_round"]) == 0, "无尽关不该有目标盘数")
	assert(StageTable.boards_of(ENDLESS).is_empty(), "无尽关不该有手写盘列表")
	var six := _all_six()
	assert(six.size() == 6, "无尽关之外应有 6 关，实际 %d" % six.size())
	assert(not StageTable.is_stage_unlocked(ENDLESS, []), "空档下无尽关就开了")
	assert(not StageTable.is_stage_unlocked(ENDLESS, six.slice(0, 5)), "没通第 6 关无尽关就开了")
	assert(StageTable.is_stage_unlocked(ENDLESS, six), "通完 6 关后无尽关没开")
	assert(StageTable.first_open_stage(six) == ENDLESS, "通完 6 关后的焦点应落在无尽关")
	var progress := StageTable.region_progress("habitat", six)
	assert(int(progress["total"]) == 6 and int(progress["cleared"]) == 6, "无尽关不该计入通关总数：%s" % str(progress))


func _check_board_generator() -> void:
	var a := StageTable.endless_board(5, 99)
	var b := StageTable.endless_board(5, 99)
	assert(a == b, "同一种子同一盘应抽到同一个结果")
	assert(StageTable.board_at(ENDLESS, 5, 99) == a, "board_at 对无尽关没走 endless_board")
	assert(StageTable.board_at("grass_2", 1, 99) == StageTable.board_at("grass_2", 1), "种子参数不该影响有盘列表的关")
	var shapes := {}
	for level_seed in range(1, 41):
		shapes[String(StageTable.endless_board(1, level_seed)["shape"])] = true
	assert(shapes.size() >= 3, "不同种子的第 1 盘形状太单一：%s" % str(shapes.keys()))
	for round_index in range(1, 61):
		var cfg := StageTable.endless_board(round_index, 12345)
		var shape_id := String(cfg["shape"])
		assert(BoardShape.has_shape(shape_id), "第 %d 盘抽到了不存在的形状 %s" % [round_index, shape_id])
		var size := int(cfg["size"])
		assert(shape_id.ends_with("_%d" % size), "第 %d 盘形状 %s 与尺寸 %d 不符" % [round_index, shape_id, size])
		var shape := BoardShape.get_shape(shape_id)
		assert(int(shape["width"]) == size and int(shape["height"]) == size, "第 %d 盘的包围盒不是 %d×%d" % [round_index, size, size])
		var mines := int(cfg["mines"])
		assert(mines >= StageTable.ENDLESS_MIN_MINES, "第 %d 盘雷数 %d 低于下限" % [round_index, mines])
		assert(mines <= BoardShape.max_mines_for(shape_id), "第 %d 盘雷数 %d 超过 %s 的上限" % [round_index, mines, shape_id])


func _check_difficulty_curve() -> void:
	assert(StageTable.endless_size_for(1) == StageTable.ENDLESS_START_SIZE, "第 1 盘不是起始尺寸")
	assert(StageTable.endless_size_for(StageTable.ENDLESS_ROUNDS_PER_SIZE) == StageTable.ENDLESS_START_SIZE, "尺寸提前放大了")
	assert(StageTable.endless_size_for(StageTable.ENDLESS_ROUNDS_PER_SIZE + 1) == StageTable.ENDLESS_START_SIZE + 1, "尺寸没按节奏放大")
	assert(StageTable.endless_size_for(999) == StageTable.ENDLESS_MAX_SIZE, "尺寸没有封顶")
	assert(is_equal_approx(StageTable.endless_density_for(1), StageTable.ENDLESS_START_DENSITY), "第 1 盘密度不是起始密度")
	assert(is_equal_approx(StageTable.endless_density_for(999), StageTable.ENDLESS_MAX_DENSITY), "密度没有封顶")
	assert(is_zero_approx(StageTable.endless_difficulty_fraction(1)), "第 1 盘的难度进度应为 0")
	assert(is_equal_approx(StageTable.endless_difficulty_fraction(999), 1.0), "封顶后的难度进度应为 1")
	var prev_size := 0
	var prev_density := 0.0
	for round_index in range(1, 61):
		var size := StageTable.endless_size_for(round_index)
		var density := StageTable.endless_density_for(round_index)
		assert(size >= prev_size, "第 %d 盘尺寸回缩了" % round_index)
		assert(density >= prev_density - 1e-9, "第 %d 盘密度回落了" % round_index)
		prev_size = size
		prev_density = density
	# 雷数整体爬升：后段 10 盘的平均雷数明显高于前 10 盘（形状抽签会抖，看平均）。
	var early := 0.0
	var late := 0.0
	for round_index in range(1, 11):
		early += float(StageTable.endless_board(round_index, 7)["mines"])
		late += float(StageTable.endless_board(round_index + 30, 7)["mines"])
	assert(late > early * 1.5, "难度没有随盘序爬升：前 10 盘均雷 %.1f，后段 %.1f" % [early / 10.0, late / 10.0])


## v3 老档补 endless_best_round；新字段能落盘、能读回。
func _check_save_migration() -> void:
	var file := FileAccess.open(GameSave.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 3,
		"data": {"current_level": 1, "achievements": [], "cleared_stages": [], "stage_high_scores": {}},
	}))
	file.close()
	var data := GameSave.load_data()
	assert(not data.is_empty(), "v3 存档没能加载")
	assert(int(data.get("endless_best_round", -1)) == 0, "v3 迁移后无尽关记录应从 0 起")
	GameSave.write({"current_level": 1, "endless_best_round": 9})
	assert(int(GameSave.load_data().get("endless_best_round", -1)) == 9, "无尽关记录没有随存档往返")
	GameSave.clear()


func _check_banner_copy() -> void:
	var banner = StageProgressBannerView.instantiate()
	root.add_child(banner)
	await process_frame
	var finished := [false]
	var runner := func() -> void:
		await banner.present("无尽远海", 12, 0)
		finished[0] = true
	runner.call()
	await process_frame
	assert(banner.title.text == "无尽远海", "横幅关名不对")
	assert(banner.subtitle.text == "第 12 盘 · 无尽", "无尽横幅的盘序文案不对：%s" % banner.subtitle.text)
	assert(banner.round_index.text == "12", "无尽横幅的盘序数字不对：%s" % banner.round_index.text)
	assert(banner.round_suffix.text.contains("∞"), "无尽横幅没有 ∞：%s" % banner.round_suffix.text)
	assert(banner.segments.get_child_count() == 0, "无尽横幅不该摆分段点")
	var frames := 0
	while not finished[0] and frames < 2400:
		await process_frame
		frames += 1
	assert(finished[0], "无尽横幅的 present() 没有返回")
	assert(not banner.visible, "横幅播完后应收起")
	banner.queue_free()
	await process_frame


func _check_run_flow(game: Node) -> void:
	game.set("_cleared_stages", _all_six())
	game.call("_enter_stage", ENDLESS, false)
	await process_frame
	assert(String(game.get("_stage_id")) == ENDLESS, "没进到无尽关")
	assert(bool(game.call("_is_endless_stage")), "_is_endless_stage 没认出无尽关")
	assert(int(game.get("_stage_target_round")) == 0, "无尽关不该有目标盘数")
	assert(int(game.get("_stage_round")) == 1, "无尽关第一盘的本关盘数不是 1")
	# 非教学关从 TUTORIAL_LEVEL_COUNT 起跳，第一盘就是它 +1。教学盘数会变，现取。
	var tutorial_count: int = (game.get_script() as GDScript).get_script_constant_map()["TUTORIAL_LEVEL_COUNT"]
	assert(
		int(game.get("_run_number")) == tutorial_count + 1,
		"无尽关没有跳过教学段，全局盘序是 %d，应为 %d" % [
			int(game.get("_run_number")), tutorial_count + 1
		]
	)
	assert(bool(game.get("_magpie_bird_unlocked")) and bool(game.get("_tit_bird_unlocked")), "无尽关起手没补发全部伙伴")
	assert(not bool(game.call("_stage_complete")), "无尽关第一盘就被判成通关了")
	var level_seed := int(game.call("_level_seed_for_current_round"))
	var expected := StageTable.endless_board(1, level_seed)
	var shape := BoardShape.get_shape(String(expected["shape"]))
	var board = game.get("_board")
	assert(board.width == int(shape["width"]) and board.height == int(shape["height"]), "第 1 盘的盘面尺寸没按 endless_board 来")
	assert(board.mine_count == int(expected["mines"]), "第 1 盘雷数 %d 与 endless_board 的 %d 不符" % [board.mine_count, int(expected["mines"])])
	assert(board.active_cell_count == int(shape["active_count"]), "第 1 盘的可玩格数与形状不符")
	var label := game.get("_stage_board_label") as Label
	assert(label.text.contains("无尽") and label.text.contains("第 1 盘"), "盘序读数不是无尽写法：%s" % label.text)
	# 往后推很多盘也永远不「打满」。
	game.set("_stage_round", 500)
	assert(not bool(game.call("_stage_complete")), "无尽关打到第 500 盘也不该算通关")
	game.set("_stage_round", 1)
	# 真发一盘：盘序 +1、盘面按第 2 盘的曲线重抽。
	game.call("_start_game")
	await process_frame
	assert(int(game.get("_stage_round")) == 2, "推一盘之后本关盘数不是 2")
	var second := StageTable.endless_board(2, int(game.call("_level_seed_for_current_round")))
	var second_shape := BoardShape.get_shape(String(second["shape"]))
	board = game.get("_board")
	assert(board.width == int(second_shape["width"]) and board.mine_count == int(second["mines"]), "第 2 盘没按 endless_board 重抽")
	# 打赢一盘记最远盘数并落盘；再赢更小的盘序不回退。
	game.call("_bank_endless_round")
	assert(int(game.get("_endless_best_round")) == 2, "赢下第 2 盘后最远盘数不是 2")
	game.call("_save_progress")
	var saved := GameSave.load_data()
	assert(int(saved.get("endless_best_round", -1)) == 2, "最远盘数没落盘")
	game.set("_stage_round", 1)
	game.call("_bank_endless_round")
	assert(int(game.get("_endless_best_round")) == 2, "最远盘数被更小的盘序覆盖了")
	game.set("_stage_round", 2)


## 倒下：续局槽清掉、最远盘数留着、弹「止步第 N 盘」的榜页、榜开着时进不了关、关掉后回到柜子并停在无尽关。
func _check_fall_returns_to_cabinet(game: Node) -> void:
	assert(String(game.get("_stage_id")) == ENDLESS, "前置：应仍在无尽关里")
	game.set("_player_hp", 0)
	game.call("_on_game_over_return")
	await process_frame
	await process_frame
	var map := game.get("_world_map") as StageCabinet
	assert(map != null and map.visible, "倒下后没有回到陈列柜")
	assert(String(game.get("_stage_id")) == "", "倒下后还留在关卡里")
	assert(String(game.get("_resume_stage_id")) == "", "倒下后仍保留续局槽")
	assert(int(game.get("_endless_best_round")) == 2, "倒下把最远盘数清掉了")
	var panel: Node = game.get("_leaderboard_panel")
	if panel != null:
		assert(bool(panel.get("visible")), "无尽关倒下后没有弹榜页")
		var title := panel.get("_title") as Label
		assert(title.text.contains("止步第 2 盘"), "榜页标题不是止步写法：%s" % title.text)
		game.call("_enter_stage", ENDLESS, false)
		await process_frame
		assert(String(game.get("_stage_id")) == "", "榜开着时不应再进关")
		panel.call("hide_immediately")
		for _i in 4:
			await process_frame
	assert(not bool(game.get("_map_settle_lock")), "榜关掉后结算锁没解开")
	# 六关全通、没有续局：柜子停在无尽关，牌子与关卡卡都用无尽写法并带上最远盘数。
	assert(map.current_stage() == ENDLESS, "六关全通后柜子应停在无尽关，实际 %s" % map.current_stage())
	var badge := map.badge_for(ENDLESS)
	assert(badge != null, "柜子里没有无尽关的牌子")
	var score_label := badge.get("_score_label") as Label
	assert(score_label.text.contains("最远 2 盘"), "牌子没写最远盘数：%s" % score_label.text)
	assert((badge.get("_round_label") as Label).text == "无尽", "牌子的盘数芯片应写「无尽」")
	assert(badge.current_state() == StageBadge.State.AVAILABLE, "六关全通后无尽关的牌子应是可挑战")
	var detail := map.get_node("CabinetUi/StageCard/StageCardDetail") as Label
	assert(detail.text.contains("无尽") and detail.text.contains("最远第 2 盘"), "关卡卡没有无尽写法：%s" % detail.text)
	assert((map.get_node("CabinetUi/StageCard/EnterStageButton") as Button).text == "进入关卡", "无尽关的按钮应是进入关卡")
	var readout := map.get_node("CabinetUi/TopBar/RegionProgressLabel") as Label
	assert(readout.text.begins_with("已通关 6 / 6"), "无尽关不该计入地形区读数：%s" % readout.text)
	# 展品：排在一列的最右端，与其他展品同一台面高度，不是泥胚色。
	var top := map.slot_for(ENDLESS)
	assert(top != null, "柜子里没有无尽关的展品")
	var yaw := deg_to_rad(StageCabinet.CAMERA_YAW_DEG)
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var top_x := top.position.dot(right)
	for slot in map.slots():
		if slot != top:
			assert(slot.position.dot(right) < top_x - 30.0, "%s 不该排在无尽关右边" % slot.stage_id)
		assert(is_equal_approx(slot.position.y, top.position.y), "无尽关展品应与其他展品同一台面高度")
	assert(not top.is_locked_look(), "六关全通后无尽关的展品不该是泥胚色")
