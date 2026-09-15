extends SceneTree
## 宣传截图之世界地图（1920×1080）。配合 tools/capture_promo.gd 使用：
##   godot --resolution 1920x1080 --fixed-fps 60 --script tools/capture_promo_map.gd
## 视口尺寸在脚本里强制写死，避免被任务栏压成 1920×1055。

const OUTPUT_PATH := "res://artifacts/promo/03_world_map.png"
const CAPTURE_SIZE := Vector2i(1920, 1080)


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/promo"))
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
	# 前三关通了、第 4 关打到第 2 盘：四种悬浮牌状态与续局条同屏。
	game.set("_cleared_stages", ["grass_1", "grass_2", "grass_3"])
	game.set("_resume_stage_id", "river_1")
	game.set("_stage_round", 1)
	game.call("_show_world_map")
	for _i in 60:
		await process_frame

	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("已保存 ", OUTPUT_PATH, " ", image.get_size())

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	GameSave.clear()
	GameSave.save_path = original_save
	quit()
