extends SceneTree
## 关卡流程：进关的起手状态（教学关 vs 非教学关）、到点叫停的边界、通关记账、死亡回
## 地图、续局恢复，以及 v1 老档的迁移。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("Stage run flow test timed out")
		quit(2)
	)
	var original_path := GameSave.save_path
	GameSave.save_path = "user://test_stage_run_flow_save.json"
	GameSave.clear()

	_check_v1_migration()
	_check_partial_save_fallback()

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame

	await _check_start_goes_to_map(game)
	await _check_teaching_stage(game)
	await _check_normal_stage(game)
	await _check_locked_stage_refused(game)
	await _check_stop_at_target(game)
	await _check_stage_cleared(game)
	await _check_death_returns_to_map(game)
	await _check_resume(game)

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame
	GameSave.clear()
	GameSave.save_path = original_path
	print("Stage run flow: 进关起手、到点叫停、通关记账、死亡回地图、续局与 v1 迁移全部通过")
	quit()


## v1 老档：没有关卡概念，但半局进度要归给第一关，且已通关集合从空开始。
func _check_v1_migration() -> void:
	var file := FileAccess.open(GameSave.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 1,
		"data": {
			"current_level": 6,
			"tutorial_completed": true,
			"gold": 17,
			"lantern_bonus": 2,
			"achievements": [],
		},
	}))
	file.close()

	var data := GameSave.load_data()
	assert(not data.is_empty(), "v1 存档没能加载")
	assert((data["cleared_stages"] as Array).is_empty(), "v1 迁移后已通关集合不是空的")
	assert(
		String(data["resume_stage_id"]) == String(StageTable.STAGES[0]["id"]),
		"v1 的半局进度没归给第一关，而是 %s" % String(data["resume_stage_id"])
	)
	assert(int(data["stage_round"]) == 6, "v1 迁移后的本关盘数不对: %d" % int(data["stage_round"]))
	assert(int(data["gold"]) == 17, "v1 迁移弄丢了金币")
	assert(int(data["lantern_bonus"]) == 2, "v1 迁移弄丢了道具强化")
	assert(not bool(data["music_break_played"]), "v1 迁移后换歌插播被当成已放过")

	# 没有半局进度的 v1 档不该凭空长出一个续局槽。
	file = FileAccess.open(GameSave.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 1, "data": {"current_level": 1, "achievements": []},
	}))
	file.close()
	var fresh := GameSave.load_data()
	assert(String(fresh["resume_stage_id"]) == "", "干净的 v1 档被塞进了续局槽")

	# 比本版新的档一律拒绝，而不是猜字段。
	file = FileAccess.open(GameSave.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": GameSave.VERSION + 1, "data": {"gold": 3}}))
	file.close()
	assert(GameSave.load_data().is_empty(), "比本版新的存档没有被拒绝")
	GameSave.clear()


## `GameSave.write()` 总会盖上当前版本号，所以"版本是 2 但字段不全"的档确实存在（测试
## 夹具、旧代码写的档）。那时迁移分支不跑，得靠读取侧兜底。
func _check_partial_save_fallback() -> void:
	GameSave.write({"current_level": 4, "tutorial_completed": true, "achievements": []})
	var data := GameSave.load_data()
	assert(int(data.get("version", 0)) == 0, "load_data 不该把版本号透给调用方")
	assert(not data.has("resume_stage_id"), "字段不全的同版本档不该被迁移函数改写")
	GameSave.clear()


## 标题页点「开始」进的是世界地图，不是棋盘。
func _check_start_goes_to_map(game: Node) -> void:
	# 有推图战绩 → 跳过开场演出，直奔地图。
	game.set("_cleared_stages", [String(StageTable.STAGES[0]["id"])])
	game.call("_on_start_game_requested")
	await process_frame
	await process_frame
	var map := game.get("_world_map") as WorldMap
	assert(map != null, "点开始之后世界地图没有建起来")
	assert(map.visible, "点开始之后世界地图没有显示")
	assert(not bool(game.get("_started")), "点开始之后直接开了棋盘")
	assert(String(game.get("_stage_id")) == "", "还没选关就已经在关卡里了")


## 教学关：保留 4 盘教程，起手只有蓝鸟、强化全 0。
func _check_teaching_stage(game: Node) -> void:
	var teaching := ""
	for stage in StageTable.STAGES:
		if bool(stage.get("teaches", false)):
			teaching = String(stage["id"])
			break
	assert(teaching != "", "关卡表里没有教学关")

	game.set("_cleared_stages", [])
	game.call("_enter_stage", teaching, false)
	await process_frame

	assert(String(game.get("_stage_id")) == teaching, "没进到教学关")
	assert(int(game.get("_run_number")) == 1, "教学关的第一盘不是全局第 1 盘")
	assert(int(game.get("_stage_round")) == 1, "教学关的本关盘数不是 1")
	assert(
		int(game.get("_stage_target_round")) == int(StageTable.stage(teaching)["target_round"]),
		"目标盘数没从关卡表取"
	)
	var board = game.get("_board")
	assert(board.width == 2 and board.height == 1, "教学关的第一盘不是 2×1 的教程盘")
	assert(bool(game.get("_blue_bird_unlocked")), "蓝鸟没解锁")
	assert(not bool(game.get("_red_bird_unlocked")), "教学关起手就送了红尾水鸲")
	assert(not bool(game.get("_night_heron_unlocked")), "教学关起手就送了夜鹭")
	assert(int(game.get("_lantern_bonus")) == 0, "教学关起手就送了夜鹭强化")
	assert(int(game.get("_super_luck_bonus")) == 0, "教学关起手就送了红隼强化")
	assert(String(game.get("_resume_stage_id")) == teaching, "进关后续局槽没指向这一关")


## 非教学关：跳过教程盘，但必须补发教程本该给的 4 只鸟 + 4 点强化，否则整关只有蓝鸟。
func _check_normal_stage(game: Node) -> void:
	var normal := ""
	for stage in StageTable.STAGES:
		if not bool(stage.get("teaches", false)):
			normal = String(stage["id"])
			break
	game.set("_cleared_stages", [])
	game.call("_enter_stage", normal, false)
	await process_frame

	var tutorial_count := int(game.get("TUTORIAL_LEVEL_COUNT")) if false else 4
	assert(
		int(game.get("_run_number")) == tutorial_count + 1,
		"非教学关没有跳过教程段，全局盘序是 %d" % int(game.get("_run_number"))
	)
	assert(int(game.get("_stage_round")) == 1, "非教学关的本关盘数不是 1")
	var board = game.get("_board")
	assert(board.width > 5, "非教学关的第一盘还是教程尺寸 %d×%d" % [board.width, board.height])
	for flag in [
		"_blue_bird_unlocked", "_red_bird_unlocked", "_night_heron_unlocked",
		"_attacker_bird_unlocked", "_lucky_bird_unlocked",
	]:
		assert(bool(game.get(flag)), "非教学关起手缺了 %s" % flag)
	for bonus in ["_lantern_bonus", "_compass_bonus", "_orbital_strike_bonus", "_super_luck_bonus"]:
		assert(int(game.get(bonus)) == 1, "非教学关起手的 %s 不是 1" % bonus)
	# 起始血金不做关卡差异化（共识 1）。
	assert(int(game.get("_player_max_hp")) == 3, "非教学关改了生命上限")
	assert(int(game.get("_gold")) == 0, "非教学关起手就有金币")


## 未解锁的关卡进不去。
func _check_locked_stage_refused(game: Node) -> void:
	var locked := String(StageTable.stages_in_region(String(StageTable.REGIONS[1]["id"]))[0]["id"])
	game.set("_cleared_stages", [])
	game.call("_enter_stage", locked, false)
	await process_frame
	assert(String(game.get("_stage_id")) != locked, "未解锁的关卡被进去了")


## 到点叫停的边界：差一盘不算通关，打满才算；不在关卡里则永远不算。
func _check_stop_at_target(game: Node) -> void:
	game.set("_stage_id", "grass_2")
	game.set("_stage_target_round", 6)
	game.set("_stage_round", 5)
	assert(not bool(game.call("_stage_complete")), "差一盘就被判成通关了")
	game.set("_stage_round", 6)
	assert(bool(game.call("_stage_complete")), "打满目标盘数没被判成通关")
	game.set("_stage_round", 7)
	assert(bool(game.call("_stage_complete")), "超过目标盘数反而不算通关")
	game.set("_stage_id", "")
	assert(not bool(game.call("_stage_complete")), "不在关卡里也被判成通关")


func _check_stage_cleared(game: Node) -> void:
	game.set("_cleared_stages", [])
	game.set("_stage_id", "grass_2")
	game.set("_stage_target_round", 6)
	game.set("_stage_round", 6)
	game.set("_resume_stage_id", "grass_2")
	game.set("_run_number", 10)
	game.set("_resume_level", 10)
	game.call("_on_stage_cleared")
	await process_frame

	assert((game.get("_cleared_stages") as Array).has("grass_2"), "通关后没记进已通关集合")
	assert(String(game.get("_resume_stage_id")) == "", "通关后续局槽没清掉")
	assert(String(game.get("_stage_id")) == "", "通关后还留在关卡里")
	# 盘序必须回 1，否则读取侧的兜底规则会据此又推出一个续局槽，刚通关的关变回「进行中」。
	assert(int(game.get("_resume_level")) == 1, "通关后盘序没有归位")
	var map := game.get("_world_map") as WorldMap
	assert(map != null and map.visible, "通关后没有回到世界地图")

	# 落盘的内容要能被重新读回来。
	var saved := GameSave.load_data()
	assert(
		(saved["cleared_stages"] as Array).has("grass_2"),
		"通关记录没落盘"
	)
	assert(String(saved["resume_stage_id"]) == "", "落盘的续局槽没清掉")

	# 再通一关不该产生重复条目。
	game.set("_stage_id", "grass_2")
	game.set("_stage_target_round", 6)
	game.set("_stage_round", 6)
	game.call("_on_stage_cleared")
	await process_frame
	var cleared := game.get("_cleared_stages") as Array
	assert(cleared.count("grass_2") == 1, "同一关被记了两次")


## 死亡：回地图，而不是回标题页；那一关仍然算进行中，可以再续。
func _check_death_returns_to_map(game: Node) -> void:
	game.set("_cleared_stages", [])
	game.call("_enter_stage", "grass_2", false)
	await process_frame
	assert(String(game.get("_stage_id")) == "grass_2", "没进到关卡里")

	game.call("_on_game_over_return")
	await process_frame
	var map := game.get("_world_map") as WorldMap
	assert(map.visible, "死亡返回后没有回到世界地图")
	assert(game.get("_start_screen") == null, "死亡返回跑回了标题页")
	assert(String(game.get("_resume_stage_id")) == "grass_2", "死亡后那一关不再算进行中")
	assert(not bool(game.get("_started")), "回地图后棋盘还是活的")
	assert((game.get("_cells") as Array).is_empty(), "回地图后棋盘格子没收干净")

	# 不在关卡里时（对战/异常），「返回」仍然回标题页。
	game.set("_stage_id", "")
	game.call("_on_game_over_return")
	await process_frame
	assert(game.get("_start_screen") != null, "不在关卡里时返回没有回到标题页")


## 续局：沿用内存里的血量/金币/强化，并从离开时那一盘的开头重建——盘面尺寸要一致。
func _check_resume(game: Node) -> void:
	game.set("_cleared_stages", [])
	game.call("_enter_stage", "grass_3", false)
	await process_frame
	# 真的往下发两盘，模拟打了两盘之后离开——手动改 `_run_number` 会漏掉
	# `_start_game` 对 `_resume_level` 的同步，存出来的档就和真实存档不是一回事。
	game.call("_start_game")
	await process_frame
	game.call("_start_game")
	await process_frame
	assert(int(game.get("_stage_round")) == 3, "推了两盘之后本关盘数不是 3")
	var run_number_before := int(game.get("_run_number"))
	var width_before: int = game.get("_board").width
	game.set("_gold", 14)
	game.set("_lantern_bonus", 4)
	game.set("_player_hp", 2)
	game.call("_save_progress")

	game.call("_return_to_world_map")
	await process_frame
	assert((game.get("_world_map") as WorldMap).visible, "离开关卡后没回到地图")

	# 走一遍真实的"重开游戏读档"路径。
	game.call("_return_to_main_menu")
	await process_frame
	assert(String(game.get("_resume_stage_id")) == "grass_3", "读档后续局槽指错了关卡")
	assert(int(game.get("_gold")) == 14, "读档丢了金币")
	assert(int(game.get("_lantern_bonus")) == 4, "读档丢了道具强化")
	# 读取侧会把两个计数器各退一格，等 `_start_game` 加回来。
	assert(int(game.get("_stage_round")) == 2, "读档后的本关盘数没退格: %d" % int(game.get("_stage_round")))

	game.call("_enter_stage", "grass_3", true)
	await process_frame
	assert(int(game.get("_stage_round")) == 3, "续局后没回到第 3 盘")
	assert(
		int(game.get("_run_number")) == run_number_before,
		"续局后全局盘序不对: %d，应为 %d" % [int(game.get("_run_number")), run_number_before]
	)
	assert(
		game.get("_board").width == width_before,
		"续局后的盘面尺寸变了: %d → %d" % [width_before, game.get("_board").width]
	)
	assert(int(game.get("_gold")) == 14, "续局把金币清了")
	assert(int(game.get("_lantern_bonus")) == 4, "续局把强化清了")
