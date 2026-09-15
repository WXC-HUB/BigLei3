extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(10.0).timeout.connect(func() -> void:
		push_error("Save progress and clear UI test timed out")
		quit(2)
	)
	var original_path := GameSave.save_path
	GameSave.save_path = "user://test_main_progress_save.json"
	GameSave.clear()
	GameSave.write({
		"current_level": 6,
		"tutorial_completed": true,
		"gold": 17,
		"player_hp": 2,
		"player_max_hp": 4,
		"blue_bird_unlocked": true,
		"red_bird_unlocked": true,
		"night_heron_unlocked": true,
		"attacker_bird_unlocked": true,
		"lucky_bird_unlocked": true,
		"lantern_bonus": 2,
		"xray_bonus": 3,
		"achievements": [AchievementCatalog.START_GAME],
		"cleared_stages": [String(StageTable.STAGES[0]["id"])],
		"stage_high_scores": {String(StageTable.STAGES[0]["id"]): 4242},
		"endless_best_round": 13,
		"leaderboard_name": "PROBE",
	})

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	# 存档标了 tutorial_completed，读盘会把进度顶到教学段之后，所以这里跟着常量走。
	var tutorial_levels := int(game.get("TUTORIAL_LEVEL_COUNT"))
	assert(int(game.get("_run_number")) == tutorial_levels, "Saved level was not prepared for resume: %d" % int(game.get("_run_number")))
	assert(int(game.get("_gold")) == 17, "Saved gold was not loaded")
	assert(int(game.get("_player_hp")) == 2 and int(game.get("_player_max_hp")) == 4, "Saved health was not loaded")
	assert(int(game.get("_lantern_bonus")) == 2 and int(game.get("_xray_bonus")) == 3, "Saved items were not loaded")
	assert((game.get("_unlocked_achievements") as Dictionary).has(AchievementCatalog.START_GAME), "Saved achievement was not loaded")

	var start_screen := game.get("_start_screen") as StartScreen
	var clear_button := start_screen.get_node("%ClearSaveButton") as Button
	var confirmation := start_screen.get_node("%ClearConfirmation") as Control
	var confirm := start_screen.get_node("%ClearConfirmButton") as Button
	assert(clear_button.visible and not clear_button.disabled, "Clear-save button is unavailable when a save exists")
	clear_button.pressed.emit()
	await process_frame
	assert(confirmation.visible, "Clear-save confirmation did not open")
	confirm.pressed.emit()
	await create_timer(0.22).timeout
	assert(not GameSave.exists(), "Confirming clear did not delete the save")
	assert(int(game.get("_run_number")) == 0 and int(game.get("_gold")) == 0, "Clearing did not reset in-memory progress")
	assert((game.get("_unlocked_achievements") as Dictionary).is_empty(), "Clearing did not reset achievements")
	assert(not clear_button.visible, "Clear-save button remained visible without a save")
	# 盘外的几笔账（推图战绩、最高分、无尽记录、昵称）活得比一轮长，所以 run 级重置
	# 故意不碰它们——清档必须另外把它们抹掉，否则文件删了，内存里的战绩还在，下一次
	# 落盘原样写回来，等于没清。
	assert((game.get("_cleared_stages") as Array).is_empty(), "Clearing kept the cleared-stage roster")
	assert((game.get("_stage_high_scores") as Dictionary).is_empty(), "Clearing kept the per-stage high scores")
	assert(int(game.get("_endless_best_round")) == 0, "Clearing kept the endless best round")
	assert(String(game.get("_leaderboard_name")) == "", "Clearing kept the leaderboard name")
	assert(String(game.get("_resume_stage_id")) == "", "Clearing kept the resume slot")
	# 玩家看得见的那一半：续局槽没清干净，开始按钮就一直写着「继续游戏」。
	var start_button := start_screen.get_node("%StartButton") as Button
	assert(start_button.text == "开始游戏", "Start button still offers to continue after clearing: %s" % start_button.text)
	assert(not start_screen.abandon_run_button.visible, "Abandon-run button survived clearing the save")
	game.call("_save_progress")
	var rewritten := GameSave.load_data()
	assert((rewritten.get("cleared_stages", []) as Array).is_empty(), "A save after clearing resurrected the cleared stages")
	assert(int(rewritten.get("endless_best_round", -1)) == 0, "A save after clearing resurrected the endless record")
	GameSave.clear()

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame
	GameSave.save_path = original_path
	print("Saved progression load and clear confirmation passed")
	quit()
