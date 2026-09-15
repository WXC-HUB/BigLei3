extends SceneTree
## 灰喜鹊解锁页验收截图：初始页、撩几下变虚焦、眼镜滑进来、镜片里的学姐。
## 跑法（**不能加 --headless**）：
##   godot --resolution 1920x1080 --fixed-fps 60 --script tools/capture_magpie_unlock.gd

const OUTPUT_DIR := "res://artifacts/magpie"
const CAPTURE_SIZE := Vector2i(1920, 1080)
const MAGPIE := preload("res://scripts/ui/magpie_unlock.gd")


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var original_save := GameSave.save_path
	GameSave.save_path = "user://magpie_capture_save.json"
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

	var unlock := game.get("_magpie_unlock") as MagpieUnlock
	unlock.present()
	await create_timer(3.0).timeout
	_save("10_unlock_page")
	for _hover in range(3):
		unlock.bird.mouse_entered.emit()
		await create_timer(0.1).timeout
	await create_timer(0.3).timeout
	_save("11_unlock_defocus")
	while not unlock.glasses_on():
		unlock.bird.mouse_entered.emit()
		await create_timer(0.08).timeout
		if unlock.hover_count() >= MAGPIE.HOVERS_TO_GLASSES:
			break
	await create_timer(MAGPIE.GLASSES_SLIDE_TIME * 0.55).timeout
	_save("12_unlock_glasses_sliding")
	await create_timer(MAGPIE.glasses_duration()).timeout
	_save("13_unlock_senpai")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	GameSave.clear()
	GameSave.save_path = original_save
	print("Saved magpie unlock screenshots to ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, name]
	var error := image.save_png(path)
	if error != OK:
		push_error("保存失败 %s: %s" % [path, error_string(error)])
	else:
		print("已保存 ", path, " ", image.get_size())
