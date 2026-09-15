extends SceneTree
## 复原仪式过目截图：先以「青草坡已通关」present 柜子，再以「麦垄刚通关」present，按时间点
## 连拍几张（荒废版收回 → 一圈光与粒子 → 生机版重搭 → 短句 → 自动滑走）。
## 跑法（**不能加 --headless**）：
##   godot --fixed-fps 60 --script tools/capture_restore.gd
## 输出 artifacts/restore_<n>.png。

const SHOT_TIMES := [0.2, 0.95, 1.6, 2.3, 3.1, 4.4]


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var cabinet := (load("res://scenes/stage_cabinet.tscn") as PackedScene).instantiate() as StageCabinet
	cabinet.mosquito_events = false
	root.add_child(cabinet)
	await process_frame
	cabinet.present(["grass_1"], "", 0, {})
	while cabinet.is_transitioning() or cabinet.slot_for("grass_2").is_entrance_playing():
		await process_frame
	for _i in 20:
		await process_frame
	cabinet.present(["grass_1", "grass_2"], "", 0, {})
	var elapsed := 0.0
	var shot := 0
	while shot < SHOT_TIMES.size():
		await process_frame
		elapsed += 1.0 / 60.0
		if elapsed >= float(SHOT_TIMES[shot]):
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/restore_%d.png" % shot))
			print("已保存 res://artifacts/restore_%d.png（t=%.2f）" % [shot, elapsed])
			shot += 1
	quit()
