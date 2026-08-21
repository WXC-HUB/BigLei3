extends SceneTree
## 标题页的「继续游戏 / 放弃本轮」这一组：有本轮进度时开始按钮换文案换颜色，放弃
## 之后只剩成就，存档文件本身还在（「清除存档」才是删文件的那个）。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("Abandon-run UI test timed out")
		quit(2)
	)
	var original_path := GameSave.save_path
	GameSave.save_path = "user://test_abandon_run_save.json"
	GameSave.clear()
	GameSave.write({
		"current_level": 7,
		"tutorial_completed": true,
		"gold": 23,
		"player_hp": 2,
		"player_max_hp": 5,
		"red_bird_unlocked": true,
		"lantern_bonus": 3,
		"achievements": [AchievementCatalog.START_GAME],
	})

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var start_screen := game.get("_start_screen") as StartScreen
	var start_button := start_screen.get_node("%StartButton") as Button
	var clear_button := start_screen.get_node("%ClearSaveButton") as Button
	var abandon_button: Button = start_screen.abandon_run_button
	var fresh_bg := (start_button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color

	assert(start_button.text == "继续游戏", "Start button did not become the continue button")
	assert(fresh_bg == StartScreen.CONTINUE_BG, "Continue button kept the new-game colour")
	assert(abandon_button.visible and not abandon_button.disabled, "Abandon button is missing with a run in progress")
	assert(clear_button.visible, "Clear-save button disappeared when the abandon button appeared")
	assert(
		abandon_button.global_position.x > start_button.global_position.x + start_button.size.x,
		"Abandon button is not to the right of the start button"
	)

	abandon_button.pressed.emit()
	await process_frame
	var confirmation := start_screen.get_node("%ClearConfirmation") as Control
	var card_title := start_screen.confirm_title
	assert(confirmation.visible, "Abandon confirmation did not open")
	assert(card_title.text == "放弃本轮？", "Confirmation card kept the clear-save copy")
	(start_screen.get_node("%ClearConfirmButton") as Button).pressed.emit()
	await create_timer(0.3).timeout

	assert(GameSave.exists(), "Abandoning the run deleted the whole save file")
	assert(int(game.get("_run_number")) == 0, "Abandoning did not reset the run")
	assert(int(game.get("_resume_level")) == 1, "Abandoning did not send the run back to level 1")
	assert(int(game.get("_gold")) == 0, "Abandoning kept the run's gold")
	assert(int(game.get("_lantern_bonus")) == 0, "Abandoning kept the run's items")
	assert(not bool(game.get("_red_bird_unlocked")), "Abandoning kept the run's bird unlocks")
	assert(
		(game.get("_unlocked_achievements") as Dictionary).has(AchievementCatalog.START_GAME),
		"Abandoning the run wiped the achievements"
	)

	var menu := game.get("_start_screen") as StartScreen
	var menu_start := menu.get_node("%StartButton") as Button
	assert(menu_start.text == "开始游戏", "Start button stayed on continue after abandoning")
	assert(
		(menu_start.get_theme_stylebox("normal") as StyleBoxFlat).bg_color != StartScreen.CONTINUE_BG,
		"Start button kept the continue colour after abandoning"
	)
	assert(not menu.abandon_run_button.visible, "Abandon button stayed up with no run to abandon")
	assert((menu.get_node("%ClearSaveButton") as Button).visible, "Clear-save button vanished with a save on disk")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame
	GameSave.clear()
	GameSave.save_path = original_path
	print("Abandon run: continue button, placement, copy and achievement retention passed")
	quit()
