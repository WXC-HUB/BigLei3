extends SceneTree
## 逐步截图新手第 2 盘伙伴牌课：三步各一张 + 伙伴图鉴一张，存到 artifacts/item_lesson_step_N.png。
## 用法：godot --fixed-fps 60 --script tools/capture_item_lesson.gd

const OUTPUT_DIR := "res://artifacts"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	GameSave.save_path = "user://capture_item_lesson_save.json"
	GameSave.clear()
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var screen := game.get("_start_screen") as Control
	if screen != null:
		game.set("_start_screen", null)
		screen.get_parent().queue_free()
	game.set("_run_number", 1)
	game.set("_night_heron_unlocked", true)
	game.set("_lantern_bonus", 1)
	game.call("_start_game")
	var overlay := game.get("_guided_overlay") as GuidedTutorialOverlay
	await _wait_step(game, 0)
	await create_timer(0.7).timeout
	await _shot(1)

	game.call("_on_cell_mouse_button_changed", 10, MOUSE_BUTTON_LEFT, true)
	await _wait_step(game, 1)
	await create_timer(1.0).timeout
	await _shot(2)

	overlay.next_button().pressed.emit()
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline and not (int(game.get("_guided_step")) == 2 and overlay.is_presenting()):
		await process_frame
	await create_timer(0.8).timeout
	await _shot(3)

	overlay.next_button().pressed.emit()
	await create_timer(0.7).timeout
	await _shot(4)
	GameSave.clear()
	quit()


func _wait_step(game: Node, step: int) -> void:
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline and int(game.get("_guided_step")) != step:
		await process_frame
	if int(game.get("_guided_step")) != step:
		push_error("Item lesson never reached step %d" % step)
		quit(1)


func _shot(number: int) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/item_lesson_step_%d.png" % [OUTPUT_DIR, number]
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		quit(1)
		return
	print("Saved ", ProjectSettings.globalize_path(path))
