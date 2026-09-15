extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(8.0).timeout.connect(func() -> void:
		push_error("Regular level return-to-menu test timed out")
		quit(2)
	)
	# 用自己的存档槽：借真实存档的话，上一局/上一条测试留下的进度会把盘序顶到教学段之后。
	GameSave.save_path = "user://test_regular_level_return_save.json"
	GameSave.clear()
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var controls: RegularSkipControl = game.get("_regular_skip_control")
	var return_button := controls.get_node("ReturnButton") as Button
	assert(not return_button.visible, "Return button leaked onto the main menu or tutorial entry state")
	# 写死盘号会随教学关变长而失效：从常量推出「第一盘正式关」。
	var first_regular := int(game.get("TUTORIAL_LEVEL_COUNT")) + 1
	game.set("_run_number", first_regular - 1)
	game.call("_start_game")
	await process_frame
	game.set("_gold", 9)
	game.call("_refresh_gold_display")

	var modal := controls.get_node("Confirmation") as Control
	var title := controls.get_node("Confirmation/Center/Card/Margin/Stack/Title") as Label
	var message := controls.get_node("Confirmation/Center/Card/Margin/Stack/Message") as Label
	var cancel := controls.get_node("Confirmation/Center/Card/Margin/Stack/Actions/Cancel") as Button
	var confirm := controls.get_node("Confirmation/Center/Card/Margin/Stack/Actions/Confirm") as Button
	assert(return_button.visible and not return_button.disabled, "Return button is unavailable in a normal level")
	assert(return_button.text == "返回主界面", "Return button copy is incorrect")
	assert(return_button.anchor_left == 1.0 and return_button.offset_right < 0.0, "Return button is not top-right anchored")
	assert(return_button.get_theme_stylebox("normal") is StyleBoxFlat, "Return button has no production styling")

	return_button.pressed.emit()
	await process_frame
	assert(modal.visible, "Return confirmation did not open")
	assert(title.text == "返回主界面", "Return confirmation title is incorrect")
	assert(message.text == "返回主界面，您的进度将会丢失，要返回么？", "Return warning copy is incorrect")
	cancel.pressed.emit()
	await create_timer(0.2).timeout
	assert(not modal.visible and int(game.get("_run_number")) == first_regular, "Cancelling return changed the current run")
	assert(return_button.visible and not return_button.disabled, "Return button did not recover after cancellation")

	return_button.pressed.emit()
	await process_frame
	confirm.pressed.emit()
	await create_timer(0.22).timeout
	assert(int(game.get("_run_number")) == 0, "Confirming return did not reset the run: %d" % int(game.get("_run_number")))
	assert(int(game.get("_gold")) == 0, "Returning to the title kept run progress")
	assert(game.get("_start_screen") != null, "Confirming return did not rebuild the main menu")
	assert(not return_button.visible, "Return button remained visible on the main menu")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame
	print("Regular-level return-to-menu confirmation passed")
	GameSave.clear()
	quit()
