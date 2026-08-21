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
	})

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	assert(int(game.get("_run_number")) == 5, "Saved level was not prepared for resume")
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

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame
	GameSave.save_path = original_path
	print("Saved progression load and clear confirmation passed")
	quit()
