extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(10.0).timeout.connect(func() -> void:
		push_error("Tutorial skip test timed out")
		quit(2)
	)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_start_game")
	await process_frame

	var skip_ui: Control = game.get("_tutorial_skip_button")
	var guide := game.get("_tutorial_guide") as TextureRect
	var skip_button := skip_ui.get_node("SkipButton") as Button
	assert(skip_ui.visible and not skip_button.disabled, "Tutorial skip button was not available in tutorial state")
	assert(skip_button.text == "跳过新手教学  »", "Tutorial skip button does not use its final UI copy")
	assert(skip_button.get_theme_stylebox("normal") is StyleBoxFlat, "Tutorial skip button has no production styling")
	assert(skip_button.anchor_left == 1.0 and skip_button.offset_right < 0.0, "Tutorial skip button is not anchored at the top right")
	assert(guide != null and guide.visible, "Tutorial guide is not visible in a tutorial level")
	assert(guide.texture == load("res://my_asset/guide.png"), "Tutorial guide uses the wrong image")
	assert(guide.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Tutorial guide blocks board input")
	var board_panel := game.get("_board_panel") as PanelContainer
	assert(guide.global_position.y > board_panel.global_position.y, "Tutorial guide is not below the board")
	game.call("_start_game")
	game.call("_start_game")
	await process_frame
	assert(int(game.get("_run_number")) == 3, "Test did not reach tutorial level three")
	assert(guide.visible, "Tutorial guide disappeared in level three")
	assert(guide.texture == load("res://my_asset/guide_2.png"), "Tutorial levels three and four do not use guide_2.png")

	skip_button.pressed.emit()
	await process_frame
	var board: MinesweeperBoard = game.get("_board")
	assert(int(game.get("_run_number")) == 5, "Skipping tutorials did not enter the first normal level")
	assert(board.width == 6 and board.height == 6, "Skipped tutorial did not start the 6x6 normal board")
	assert(not skip_ui.visible, "Tutorial skip button remained visible in a normal level")
	assert(not guide.visible, "Tutorial guide remained visible in a normal level")
	assert(bool(game.get("_night_heron_unlocked")) and bool(game.get("_red_bird_unlocked")), "Skipping did not unlock the first two birds")
	assert(bool(game.get("_attacker_bird_unlocked")) and bool(game.get("_lucky_bird_unlocked")), "Skipping did not unlock the final two birds")
	assert(int(game.get("_lantern_bonus")) == 1 and int(game.get("_compass_bonus")) == 1, "Skipping did not grant the first two bird items")
	assert(int(game.get("_orbital_strike_bonus")) == 1 and int(game.get("_super_luck_bonus")) == 1, "Skipping did not grant the final two bird items")
	assert(not _tree_contains_debug_button(game), "A debug button remains in the game UI")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame
	print("Tutorial skip UI and debug-button removal passed")
	quit()


func _tree_contains_debug_button(node: Node) -> bool:
	if node is Button and (node as Button).text.to_lower().contains("debug"):
		return true
	for child in node.get_children():
		if _tree_contains_debug_button(child):
			return true
	return false
