extends SceneTree
## 开场演出（耳机提示 + 开场剧情）每份存档放一次，判据是落盘的 `intro_played`。
##
## 这条测试盯的是一次真实回归：FEAT-002 把判据改成「地图上一片空白」之后，只要通关过
## 任何一关，耳机提示与开场剧情就再也不出现了。所以这里**专门用一份有进度的存档**：
## 没有 `intro_played` 键 → 补放一次 → 记账落盘 → 回标题再开始不再重放。
##
## 用独立存档路径，不碰玩家的真存档。

const SAVE_PATH := "user://test_opening_intro_gate_save.json"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("Opening intro gate test timed out")
		quit(2)
	)
	var original_path := GameSave.save_path
	GameSave.save_path = SAVE_PATH
	_write_progress_save()

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.4).timeout
	assert(not (game.get("_cleared_stages") as Array).is_empty(), "这份存档本该带着推图进度")
	assert(not bool(game.get("_intro_played")), "老档没有 intro_played，应当按没放过读")

	# 第一次「开始游戏」：有进度也要补放开场。
	_press_start(game)
	var notice := game.get("_headphone_notice") as HeadphoneNotice
	var story: Control = game.get("_opening_story")
	var notice_seen: bool = await _wait_visible(notice)
	assert(notice_seen, "有进度的存档没有补放耳机提示——正是 FEAT-002 带来的那个回归")
	var story_seen: bool = await _wait_visible(story)
	assert(story_seen, "耳机提示之后没有接上开场剧情")
	await _wait_cabinet(game)
	assert(bool(game.get("_intro_played")), "开场放完没有记账")
	var saved := GameSave.load_data()
	assert(bool(saved.get("intro_played", false)), "intro_played 没有落盘，重开游戏还会再放一次")

	# 回标题再开始：这一次不该再放。
	game.call("_return_to_main_menu")
	await create_timer(0.4).timeout
	assert(bool(game.get("_intro_played")), "回标题重读存档后 intro_played 丢了")
	_press_start(game)
	await create_timer(0.6).timeout
	assert(not notice.visible and not story.visible, "同一份存档第二次开始不该重放开场")
	await _wait_cabinet(game)

	game.queue_free()
	await process_frame
	GameSave.save_path = original_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("Opening intro gate: 有进度的存档补放开场、放完记账落盘、第二次不再重放")
	quit()


## 一份「打通了第一关」的存档，且没有 intro_played 键——正是玩家手上那种档。
func _write_progress_save() -> void:
	GameSave.write({
		"current_level": 1,
		"tutorial_completed": true,
		"achievements": ["start_game"],
		"cleared_stages": ["grass_1"],
		"resume_stage_id": "",
		"stage_round": 0,
		"music_break_played": true,
		"stage_high_scores": {},
		"endless_best_round": 0,
		"leaderboard_name": "",
	})


func _press_start(game: Node) -> void:
	var screen := game.get("_start_screen") as StartScreen
	assert(screen != null, "标题页没起来")
	(screen.get_node("%StartButton") as Button).pressed.emit()


## 演出是一段 await 链，可见窗口有限；盯着它出现过就算数。
func _wait_visible(node: Control, cap_seconds := 30.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(cap_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if node != null and node.visible:
			return true
		await create_timer(0.05).timeout
	return false


func _wait_cabinet(game: Node) -> void:
	var deadline := Time.get_ticks_msec() + 45000
	while game.get("_world_map") == null or not (game.get("_world_map") as StageCabinet).visible:
		assert(Time.get_ticks_msec() < deadline, "开场之后没有交棒给陈列柜")
		await create_timer(0.1).timeout
