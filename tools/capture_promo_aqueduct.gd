extends SceneTree
## 宣传截图之「宏伟水渠」彩蛋（1920×1080）：红尾水鸲解锁页撩鸟 21 下，水渠轰然立起。
##   godot --resolution 1920x1080 --fixed-fps 60 --script tools/capture_promo_aqueduct.gd
## 拍两张：立起途中（震动）与落定后。

const OUTPUT_DIR := "res://artifacts/promo"
const CAPTURE_SIZE := Vector2i(1920, 1080)


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var original_save := GameSave.save_path
	GameSave.save_path = "user://promo_capture_save.json"
	GameSave.clear()
	DisplayServer.window_set_size(CAPTURE_SIZE)
	root.size = CAPTURE_SIZE
	for _i in 5:
		await process_frame

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var screen := game.get("_start_screen") as Control
	if screen != null:
		game.set("_start_screen", null)
		screen.get_parent().queue_free()
	await process_frame

	var page: RedstartUnlock = game.get("_redstart_unlock")
	page.present()
	# 相册蒙太奇 + 揭幕动画走完再撩。
	await create_timer(7.0).timeout
	_save("06_redstart_unlock")
	page.set("_hover_count", RedstartUnlock.RAGE_HOVERS - 1)
	page.call("_on_bird_hovered")
	await create_timer(1.5).timeout
	_save("07_aqueduct_rising")
	await create_timer(2.6).timeout
	await process_frame
	_save("08_aqueduct")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	GameSave.clear()
	GameSave.save_path = original_save
	print("Saved aqueduct frames")
	quit()


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, name]
	image.save_png(path)
	print("已保存 ", path, " ", image.get_size())
