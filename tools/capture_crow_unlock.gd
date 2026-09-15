extends SceneTree
## 小嘴乌鸦解锁页验收截图：初始页、薅到一半（换到哪只了）、熊猫翻脸、满屏幕追、收场。
## 跑法（**不能加 --headless**）：
##   godot --resolution 1920x1080 --fixed-fps 60 --path . --script tools/capture_crow_unlock.gd

const OUTPUT_DIR := "res://artifacts/crow"
const CAPTURE_SIZE := Vector2i(1920, 1080)
const CROW := preload("res://scripts/ui/crow_unlock.gd")
const SWAP_CYCLE := CROW.PLUCK_LEAN_TIME + CROW.PLUCK_YANK_TIME + CROW.SWAP_OUT_TIME + CROW.SWAP_IN_TIME + 0.1


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var original_save := GameSave.save_path
	GameSave.save_path = "user://crow_capture_save.json"
	GameSave.clear()
	DisplayServer.window_set_size(CAPTURE_SIZE)
	root.size = CAPTURE_SIZE
	for _i in 5:
		await process_frame

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var screen := game.get("_start_screen") as Control
	if screen != null:
		game.set("_start_screen", null)
		screen.get_parent().queue_free()
	game.call("_start_game")
	await create_timer(0.4).timeout

	var unlock := game.get("_crow_unlock") as CrowUnlock
	unlock.present()
	await create_timer(3.0).timeout
	_save("10_unlock_page")

	# 薅到一半：毛飞在半空，已经换到名单中段那只了。
	for _pluck in range(3):
		unlock.bird.mouse_entered.emit()
		await create_timer(SWAP_CYCLE).timeout
	unlock.bird.mouse_entered.emit()
	await create_timer(CROW.PLUCK_LEAN_TIME + CROW.PLUCK_YANK_TIME * 0.6).timeout
	_save("11_plucking")
	await create_timer(SWAP_CYCLE).timeout

	# 一路薅到熊猫躺上来。
	while unlock.plucked_count() < CROW.VICTIMS.size() - 1:
		unlock.bird.mouse_entered.emit()
		await create_timer(SWAP_CYCLE).timeout
	unlock.bird.mouse_entered.emit()
	await create_timer(CROW.PLUCK_LEAN_TIME + CROW.PLUCK_YANK_TIME + CROW.CHASE_FREEZE_TIME * 0.8).timeout
	_save("12_panda_turns")
	await create_timer(CROW.CHASE_LAP_TIME * 0.55).timeout
	_save("13_chase")
	await create_timer(CROW.chase_duration()).timeout
	_save("14_gave_up")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	GameSave.clear()
	GameSave.save_path = original_save
	print("Saved crow unlock screenshots to ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, name]
	var error := image.save_png(path)
	if error != OK:
		push_error("保存失败 %s: %s" % [path, error_string(error)])
	else:
		print("已保存 ", path, " ", image.get_size())
