extends SceneTree
## 长尾山雀解锁页验收截图：页面成型、鸟群蹦了一半、融成一碗汤圆。
## 跑法（**不能加 --headless**，否则渲不出东西）：
##   godot --resolution 1920x1080 --fixed-fps 60 --script tools/capture_tit_unlock.gd

const OUTPUT_DIR := "res://artifacts/tit_bird"
const CAPTURE_SIZE := Vector2i(1920, 1080)
const TIT := preload("res://scripts/ui/tit_unlock.gd")


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var original_save := GameSave.save_path
	GameSave.save_path = "user://tit_capture_save.json"
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

	var unlock := game.get("_tit_unlock") as TitUnlock
	unlock.present()
	await create_timer(3.2).timeout
	_save("10_unlock_page")
	for _hover in range(TIT.TANGYUAN_FLOCK / 2):
		unlock.bird.mouse_entered.emit()
		await create_timer(0.12).timeout
	await create_timer(0.4).timeout
	_save("11_unlock_flock")
	while unlock.flock_count() < TIT.TANGYUAN_FLOCK and not unlock.is_merged():
		unlock.bird.mouse_entered.emit()
		await create_timer(0.08).timeout
	await create_timer(TIT.MERGE_BRACE_TIME + TIT.MERGE_STAGGER * 6 + TIT.MERGE_FLIGHT_TIME * 0.55).timeout
	_save("12_unlock_gathering")
	await create_timer(TIT.MERGE_STAGGER * 6 + TIT.MERGE_FLIGHT_TIME * 0.45 + 0.1).timeout
	_save("13_unlock_impact")
	await create_timer(TIT.MERGE_SERVE_TIME + 1.0).timeout
	_save("14_unlock_tangyuan")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	GameSave.clear()
	GameSave.save_path = original_save
	print("Saved tit unlock screenshots to ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, name]
	var error := image.save_png(path)
	if error != OK:
		push_error("保存失败 %s: %s" % [path, error_string(error)])
	else:
		print("已保存 ", path, " ", image.get_size())
