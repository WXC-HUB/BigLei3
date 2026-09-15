extends SceneTree
## 逐步截图新手第 1 盘强引导：每一步各存一张到 artifacts/guided_tutorial_step_N.png。
## 用法：godot --fixed-fps 60 --script tools/capture_guided_tutorial.gd

const OUTPUT_DIR := "res://artifacts"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	GameSave.save_path = "user://capture_guided_tutorial_save.json"
	GameSave.clear()
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var screen := game.get("_start_screen") as Control
	if screen != null:
		game.set("_start_screen", null)
		screen.get_parent().queue_free()
	game.call("_start_game")
	var overlay := game.get("_guided_overlay") as GuidedTutorialOverlay
	await _wait_step(game, 0)
	await create_timer(0.7).timeout
	await _shot(1)

	game.call("_on_cell_mouse_button_changed", 6, MOUSE_BUTTON_LEFT, true)
	await _wait_step(game, 1)
	await create_timer(0.9).timeout
	await _shot(2)

	overlay.next_button().pressed.emit()
	await _wait_step(game, 2)
	await create_timer(0.6).timeout
	await _shot(3)

	game.call("_on_cell_mouse_button_changed", 9, MOUSE_BUTTON_LEFT, true)
	await _wait_step(game, 3)
	await create_timer(0.9).timeout
	await _shot(4)

	overlay.next_button().pressed.emit()
	await _wait_step(game, 4)
	await create_timer(0.6).timeout
	await _shot(5)

	game.call("_on_cell_mouse_button_changed", 18, MOUSE_BUTTON_RIGHT, true)
	await _wait_step(game, 5)
	await create_timer(0.8).timeout
	await _shot(6)

	game.call("_on_cell_mouse_button_changed", 3, MOUSE_BUTTON_LEFT, true)
	await create_timer(1.2).timeout
	await _shot(7)
	GameSave.clear()
	quit()


func _wait_step(game: Node, step: int) -> void:
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline and int(game.get("_guided_step")) != step:
		await process_frame
	if int(game.get("_guided_step")) != step:
		push_error("Guided tutorial never reached step %d" % step)
		quit(1)


func _shot(number: int) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/guided_tutorial_step_%d.png" % [OUTPUT_DIR, number]
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		quit(1)
		return
	print("Saved ", ProjectSettings.globalize_path(path))
