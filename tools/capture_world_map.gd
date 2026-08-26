extends SceneTree
## 世界地图选关屏的过目截图。
## 跑法（**不能加 --headless**，否则渲不出东西）：
##   godot --fixed-fps 60 --script tools/capture_world_map.gd

const OUTPUT_PATH := "res://artifacts/world_map_review.png"
const ZOOMED_PATH := "res://artifacts/world_map_zoomed.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	# 收掉标题页，直接摆出地图。造一份"青草区通了 4 关、第 5 关打到一半"的进度，
	# 这样四种悬浮牌状态和续局提示条能同时出现在一张图里。
	var screen := game.get("_start_screen") as Control
	if screen != null:
		game.set("_start_screen", null)
		screen.get_parent().queue_free()
	game.set("_cleared_stages", ["grass_1", "grass_2", "grass_3", "grass_4"])
	game.set("_resume_stage_id", "grass_5")
	game.set("_stage_round", 2)
	game.call("_show_world_map")

	# 3D 内容第一帧还在上传网格，多等几帧再拍。
	for _i in 30:
		await process_frame

	var map: WorldMap = game.get("_world_map")
	_save(OUTPUT_PATH)

	# 再来一张拉近的，看清悬浮牌与地标建筑的细节。
	for _i in 6:
		map._zoom_by(-WorldMap.ZOOM_STEP)
	for _i in 20:
		await process_frame
	_save(ZOOMED_PATH)

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	quit()


func _save(path: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))
	print("已保存 ", path)
