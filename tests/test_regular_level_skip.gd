extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(8.0).timeout.connect(func() -> void:
		push_error("Regular level skip test timed out")
		quit(2)
	)
	# 用自己的存档槽：借真实存档的话，上一局/上一条测试留下的进度会把盘序顶到教学段之后。
	GameSave.save_path = "user://test_regular_level_skip_save.json"
	GameSave.clear()
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	# 写死盘号会随教学关变长而失效：从常量推出「第一盘正式关」。
	var first_regular := int(game.get("TUTORIAL_LEVEL_COUNT")) + 1
	game.set("_run_number", first_regular - 1)
	game.call("_start_game")
	await process_frame
	game.set("_gold", 7)
	game.call("_refresh_gold_display")

	var skip_ui: Control = game.get("_regular_skip_control")
	var skip_button := skip_ui.get_node("SkipButton") as Button
	var modal := skip_ui.get_node("Confirmation") as Control
	var message := skip_ui.get_node("Confirmation/Center/Card/Margin/Stack/Message") as Label
	var cancel := skip_ui.get_node("Confirmation/Center/Card/Margin/Stack/Actions/Cancel") as Button
	var confirm := skip_ui.get_node("Confirmation/Center/Card/Margin/Stack/Actions/Confirm") as Button
	assert(skip_button.visible and not skip_button.disabled, "Normal-level skip button is not available")
	assert(skip_button.text == "蒜鸟，下一关  ›", "Normal-level skip button copy is incorrect")
	assert(skip_button.anchor_left == 1.0 and skip_button.offset_right < 0.0, "Normal-level skip button is not top-right anchored")
	assert(skip_button.get_theme_stylebox("normal") is StyleBoxFlat, "Normal-level skip button has no production styling")

	skip_button.pressed.emit()
	await process_frame
	assert(modal.visible, "Skip confirmation did not open")
	assert(message.text == "这样做不会获得金钱哦，确认要跳过这一关么？", "Skip warning copy is incorrect")
	assert((skip_ui.get_node("Confirmation/Center/Card") as PanelContainer).get_theme_stylebox("panel") is StyleBoxFlat, "Skip confirmation has no production card styling")
	cancel.pressed.emit()
	await create_timer(0.2).timeout
	assert(not modal.visible and int(game.get("_run_number")) == first_regular, "Cancelling skip changed the current level")

	skip_button.pressed.emit()
	await process_frame
	confirm.pressed.emit()
	await create_timer(0.22).timeout
	assert(int(game.get("_run_number")) == first_regular + 1, "Confirming skip did not enter the next level")
	assert(int(game.get("_gold")) == 7, "Skipping a level incorrectly awarded or spent gold")
	assert(not (game.get("_shop_layer") as ShopOverlay).visible, "Skipping a level opened the shop")
	assert(not (game.get("_level_bill") as LevelBill).visible, "Skipping a level opened the level bill")
	assert(skip_button.visible and not skip_button.disabled, "Skip button did not return on the next normal level")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame
	print("Regular-level skip confirmation and no-gold transition passed")
	GameSave.clear()
	quit()
