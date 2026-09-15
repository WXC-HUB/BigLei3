extends SceneTree
## 陈列柜选关的过目截图：停在第一关的画面一张、按 › 切到第二关途中一张、到位后一张。
## 跑法（**不能加 --headless**）：
##   godot --fixed-fps 60 --script tools/capture_cabinet.gd
## 环境变量 DIORAMA_LIVE=1 让展品直读 .glb（调模型时用）。
## 输出 artifacts/cabinet_stage1.png、artifacts/cabinet_switching.png、artifacts/cabinet_stage2.png。

func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var cabinet := (load("res://scenes/stage_cabinet.tscn") as PackedScene).instantiate() as StageCabinet
	cabinet.mosquito_events = false
	cabinet.entrance_events = false
	root.add_child(cabinet)
	await process_frame
	# 第一关通了、第 2 关打到一半：停在进行中的第 2 关；先往回切一格看第一关的完全体。
	cabinet.present(["grass_1"], "grass_2", 2, {"grass_1": 2556, "grass_2": 1764})
	cabinet.press_prev()
	for _i in 70:
		await process_frame
	_shot("res://artifacts/cabinet_stage1.png")
	cabinet.entrance_events = true
	cabinet.press_next()
	for _i in 24:
		await process_frame
	_shot("res://artifacts/cabinet_switching.png")
	for _i in int(60 * 2.6):
		await process_frame
	_shot("res://artifacts/cabinet_stage2.png")
	quit()


func _shot(path: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("已保存 ", path)
