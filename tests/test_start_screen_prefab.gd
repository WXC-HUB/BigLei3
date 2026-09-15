extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(50.0).timeout.connect(func() -> void:
		push_error("Start screen prefab test timed out")
		quit(2)
	)
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	var start_screen := game.get("_start_screen") as StartScreen
	assert(start_screen != null, "Main did not instantiate the StartScreen prefab")
	assert(start_screen.scene_file_path == "res://scenes/ui/start_screen.tscn", "Start screen is still built inline")
	await create_timer(0.4).timeout
	var start_button := start_screen.get_node("%StartButton") as Button
	start_button.pressed.emit()
	await create_timer(0.35).timeout
	assert(game.get("_start_screen") == null, "Start screen did not dismiss itself through its signal")
	# The headphone card now sits between the title and the world map, so nothing
	# else may take over until that card has played out.
	var notice := game.get("_headphone_notice") as HeadphoneNotice
	assert(notice != null and notice.visible, "Headphone notice did not take over after the title")
	assert(int(game.get("_run_number")) == 0, "The board started before the notice finished")
	# FEAT-002：两段开场演出之后交棒的是**世界地图**，不再是棋盘（共识 1）。
	# 棋盘要等玩家在地图上点掉一个关卡才出现，所以这里分两步验。
	var story: Control = game.get("_opening_story")
	var story_seen := false
	var deadline := Time.get_ticks_msec() + 45000
	while game.get("_world_map") == null or not (game.get("_world_map") as StageCabinet).visible:
		story_seen = story_seen or bool(story.visible)
		assert(Time.get_ticks_msec() < deadline, "Opening presentation never handed off to the world map")
		await create_timer(0.1).timeout
	var map := game.get("_world_map") as StageCabinet
	assert(int(game.get("_run_number")) == 0, "The board started before a stage was picked")
	assert(not notice.visible, "Headphone notice stayed up after the world map opened")
	assert(story_seen and not story.visible, "Opening story did not play between the headphone notice and the world map")

	# 在地图上点第一关，这才该开棋盘。
	var first_stage := String(StageTable.STAGES[0]["id"])
	var badge := map.badge_for(first_stage)
	assert(badge != null and not badge.disabled, "First stage is not selectable on a fresh save")
	badge.pressed.emit()
	await create_timer(0.2).timeout
	assert(int(game.get("_run_number")) == 1, "Picking the first stage did not begin the game")
	assert(String(game.get("_stage_id")) == first_stage, "Picking a stage did not enter that stage")
	assert(not map.visible, "World map stayed up after entering a stage")
	print("Start screen prefab: headphone notice, opening story, world map handoff and stage entry passed")
	quit()
