extends SceneTree
## 单关展品过目截图：实例化 scenes/dioramas/<id>.tscn，用它自带的展柜相机拍 1920×1080。
## 跑法（**不能加 --headless**）：
##   godot --fixed-fps 60 --script tools/capture_diorama.gd
## 环境变量：
##   DIORAMA        选展品（默认 grass_1）
##   DIORAMA_SHOT   输出路径（默认 artifacts/diorama_<id>.png）
##   DIORAMA_LIVE=1 直接读 .glb 不走导入缓存，调模型时用
##   DIORAMA_ENTRANCE=1 播入场动画，并按 DIORAMA_FRAMES（默认 0.25,0.55,0.9,1.3 秒）
##                  另存几张过程帧到 artifacts/diorama_<id>_entrance_<n>.png

func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var id := OS.get_environment("DIORAMA")
	if id == "":
		id = "grass_1"
	var packed := load("res://scenes/dioramas/%s.tscn" % id) as PackedScene
	if packed == null:
		push_error("没有这件展品：%s" % id)
		quit(2)
		return
	var diorama := packed.instantiate() as StageDiorama
	# 场景文件默认一进来就播入场（给 F6 预览用）；截图要的是完全体或自己控制的过程帧。
	diorama.entrance_on_ready = false
	root.add_child(diorama)
	await process_frame
	await process_frame
	diorama.showcase_camera().make_current()
	for _i in 12:
		await process_frame
	if OS.get_environment("DIORAMA_ENTRANCE") == "1":
		await _capture_entrance(diorama, id)
	else:
		for _i in 28:
			await process_frame
	var out := OS.get_environment("DIORAMA_SHOT")
	if out == "":
		out = "res://artifacts/diorama_%s.png" % id
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(out))
	print("已保存 ", out)
	quit()


## 用 --fixed-fps 60 的固定步长数帧：每帧 1/60 秒，按时刻表在中途截几张。
func _capture_entrance(diorama: StageDiorama, id: String) -> void:
	var spec := OS.get_environment("DIORAMA_FRAMES")
	if spec == "":
		spec = "0.25,0.55,0.9,1.3"
	var times: Array[float] = []
	for piece in spec.split(","):
		times.append(float(piece.strip_edges()))
	diorama.play_entrance()
	var elapsed := 0.0
	var shot := 0
	var total := diorama.entrance_duration() + 0.3
	while elapsed < total:
		await process_frame
		elapsed += 1.0 / 60.0
		if shot < times.size() and elapsed >= times[shot]:
			var path := "res://artifacts/diorama_%s_entrance_%d.png" % [id, shot]
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			print("入场帧 %.2fs → %s" % [elapsed, path])
			shot += 1
