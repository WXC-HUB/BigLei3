extends SceneTree
## 无尽关在陈列柜里的过目截图：六关全通、无尽关有记录时，柜子停在第 7 关「无尽远海」。
## 跑法（**不能加 --headless**）：
##   godot --fixed-fps 60 --script tools/capture_cabinet_endless.gd
## 输出 artifacts/cabinet_endless.png。

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
	var six: Array = []
	for stage in StageTable.STAGES:
		if not bool(stage.get("endless", false)):
			six.append(String(stage["id"]))
	# 六关全通、没有续局：present 停在第一个还能打的关，也就是无尽关；给它一份最高分与最远盘数。
	cabinet.present(six, "", 0,
		{"grass_1": 2556, StageTable.ENDLESS_STAGE_ID: 18420},
		{StageTable.ENDLESS_STAGE_ID: 12})
	for _i in 70:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/cabinet_endless.png"))
	print("已保存 res://artifacts/cabinet_endless.png")
	quit()
