extends SceneTree
## 本地存档是否真的记住了自己的每关最高分：
##   - 打完一盘（走 `_award_time_bonus`）后写进 `_stage_high_scores` 并落盘
##   - 分数更低的一次不会把记录改小
##   - 存档往返读得回来
##   - 放弃本轮 / 重置跑合成态不会把它清掉（它是跨 run 的记录）
##   - 上榜昵称同样记在本地，下次预填
##
## 顺带把「哪些路径会更新最高分」这件事钉死：只有盘结算那条路会更新，途中连击不会。

const STAGE := "grass_1"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("Stage high score test timed out")
		quit(2)
	)
	var original_path := GameSave.save_path
	GameSave.save_path = "user://test_stage_high_score.json"
	GameSave.clear()

	await _check_records_and_persists()
	await _check_survives_run_reset()

	GameSave.clear()
	GameSave.save_path = original_path
	print("Stage high score: 记录、择大、落盘、往返、跨 run 保留、昵称记忆全部通过")
	quit()


func _check_records_and_persists() -> void:
	var game := _boot()
	await process_frame
	await create_timer(0.4).timeout

	_enter(game)
	await create_timer(0.5).timeout

	assert(bool(game.call("_is_stage_run")), "没有进到关卡局里")
	assert(String(game.get("_stage_id")) == STAGE, "进错关了：%s" % String(game.get("_stage_id")))
	var combo = game.get("_score_combo")
	assert(combo != null, "关卡局里没有计分器")

	# 开局应当还没有记录。
	var scores: Dictionary = game.get("_stage_high_scores")
	assert(int(scores.get(STAGE, 0)) == 0, "还没打就有最高分了")

	# 途中拿分不落记录：刷新点在盘结算，不在每次连击。
	combo.score = 4200
	assert(
		int((game.get("_stage_high_scores") as Dictionary).get(STAGE, 0)) == 0,
		"分数刚进账就被当成最高分了，刷新点应该在盘结算"
	)

	# 走真实的盘结算路径。
	game.call("_award_time_bonus")
	var recorded := int((game.get("_stage_high_scores") as Dictionary).get(STAGE, 0))
	assert(recorded >= 4200, "盘结算后没记最高分：%d" % recorded)
	print("  盘结算后记录 = %d" % recorded)

	# 落盘了没有：直接读存档文件核对。
	assert(GameSave.exists(), "最高分没有落盘")
	var saved: Dictionary = GameSave.load_data()
	var saved_scores: Dictionary = saved.get("stage_high_scores", {})
	assert(
		int(saved_scores.get(STAGE, 0)) == recorded,
		"存档里的最高分和内存对不上：存档 %d，内存 %d" % [int(saved_scores.get(STAGE, 0)), recorded]
	)

	# 更低的一次不该把记录改小。`_award_time_bonus` 有一次性闸，要先放开才能再走一遍。
	combo.score = 1000
	game.set("_time_bonus_awarded_this_run", false)
	game.call("_award_time_bonus")
	assert(
		int((game.get("_stage_high_scores") as Dictionary).get(STAGE, 0)) == recorded,
		"更低的分把最高分改小了"
	)

	# 更高的一次要刷新。
	combo.score = 9000
	game.set("_time_bonus_awarded_this_run", false)
	game.call("_award_time_bonus")
	var higher := int((game.get("_stage_high_scores") as Dictionary).get(STAGE, 0))
	assert(higher >= 9000, "更高的分没有刷新记录：%d" % higher)
	print("  刷新后记录 = %d" % higher)

	# 昵称：写进去要落盘，读回来要在。
	game.set("_leaderboard_name", "阿吴")
	game.call("_save_progress")
	assert(
		String(GameSave.load_data().get("leaderboard_name", "")) == "阿吴",
		"上榜昵称没落盘"
	)

	_shutdown(game)
	await process_frame


## 换一局游戏重新读档：记录要还在，并且放弃本轮也不会清掉。
func _check_survives_run_reset() -> void:
	var game := _boot()
	await process_frame
	await create_timer(0.5).timeout

	var loaded := int((game.get("_stage_high_scores") as Dictionary).get(STAGE, 0))
	assert(loaded >= 9000, "重开游戏后最高分没读回来：%d" % loaded)
	assert(String(game.get("_leaderboard_name")) == "阿吴", "重开游戏后昵称没读回来")
	print("  重开后读回记录 = %d，昵称 = %s" % [loaded, String(game.get("_leaderboard_name"))])

	# 放弃本轮走的是 `_reset_run_state`，它只清这一轮的东西，不该动跨 run 的记录。
	game.call("_reset_run_state")
	assert(
		int((game.get("_stage_high_scores") as Dictionary).get(STAGE, 0)) == loaded,
		"重置跑合成态把最高分清掉了"
	)
	assert(String(game.get("_leaderboard_name")) == "阿吴", "重置跑合成态把昵称清掉了")

	_shutdown(game)
	await process_frame


func _boot() -> Node:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	return game


## 拆掉标题页直接进关，省掉开场演出那一长串 await。
func _enter(game: Node) -> void:
	var screen := game.get("_start_screen") as Control
	if screen != null:
		game.set("_start_screen", null)
		var parent := screen.get_parent()
		if is_instance_valid(parent):
			parent.queue_free()
	game.call("_enter_stage", STAGE, false)


func _shutdown(game: Node) -> void:
	var bgm := game.get_node_or_null("BGM") as AudioStreamPlayer
	if bgm != null:
		bgm.stop()
	game.queue_free()
