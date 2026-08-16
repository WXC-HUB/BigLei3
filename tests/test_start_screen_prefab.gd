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
	# The headphone card now sits between the title and the first board, so the
	# run only begins once that card has played out.
	var notice := game.get("_headphone_notice") as HeadphoneNotice
	assert(notice != null and notice.visible, "Headphone notice did not take over after the title")
	assert(int(game.get("_run_number")) == 0, "The board started before the notice finished")
	var story: Control = game.get("_opening_story")
	var story_seen := false
	var deadline := Time.get_ticks_msec() + 45000
	while int(game.get("_run_number")) == 0:
		story_seen = story_seen or bool(story.visible)
		assert(Time.get_ticks_msec() < deadline, "Opening presentation never handed off to the board")
		await create_timer(0.1).timeout
	assert(int(game.get("_run_number")) == 1, "Start screen signal did not begin the game")
	assert(not notice.visible, "Headphone notice stayed up after the board started")
	assert(story_seen and not story.visible, "Opening story did not play between the headphone notice and first board")
	print("Start screen prefab: headphone notice, opening story and start signal passed")
	quit()
