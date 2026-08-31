extends SceneTree
## 世界地图选关屏的过目截图。
## 跑法（**不能加 --headless**，否则渲不出东西）：
##   godot --fixed-fps 60 --script tools/capture_world_map.gd

const OUTPUT_PATH := "res://artifacts/world_map_review.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	# 收掉标题页，直接摆出地图。造一份"前两关通了、第 3 关打到一半"的进度，
	# 这样四种悬浮牌状态和续局提示条能同时出现在一张图里。
	var screen := game.get("_start_screen") as Control
	if screen != null:
		game.set("_start_screen", null)
		screen.get_parent().queue_free()
	game.set("_cleared_stages", ["grass_1", "grass_2"])
	game.set("_resume_stage_id", "grass_3")
	game.set("_stage_round", 1)
	game.call("_show_world_map")

	# 3D 内容第一帧还在上传网格，多等几帧再拍（也让云雾动画走几步）。
	for _i in 45:
		await process_frame

	_save(OUTPUT_PATH)

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	quit()


func _save(path: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))
	print("已保存 ", path)
