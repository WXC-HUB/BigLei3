extends SceneTree
## 六关展品逐张过目截图：在陈列柜里从第一关一路按 › 到最后一关，每到一关等入场播完拍一张，
## 台面配色也跟着切。跑法（**不能加 --headless**）：
##   godot --fixed-fps 60 --script tools/capture_stages.gd
## 环境变量 DIORAMA_LIVE=1 让展品直读 .glb；DIORAMA_WITHERED=1 拍每关的荒废版（全部按未通关摆、
## 不叠泥胚抽色）。输出 artifacts/stage_<id>.png 或 stage_<id>_withered.png。

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
	var all_ids: Array = []
	for stage in StageTable.all_stages():
		all_ids.append(String(stage["id"]))
	var withered := OS.get_environment("DIORAMA_WITHERED") == "1"
	var suffix := "_withered" if withered else ""
	# 生机版：全部通关；荒废版：一关都没通关，但把泥胚抽色关掉，看荒废版本身的颜色。
	cabinet.present([] if withered else all_ids, "", 0, {})
	if withered:
		for slot in cabinet.slots():
			slot.set_locked_look(false)
	while cabinet.current_index() > 0:
		cabinet.press_prev()
		while cabinet.is_transitioning():
			await process_frame
	for _i in 30:
		await process_frame
	while true:
		for _i in 40:
			await process_frame
		var id := cabinet.current_stage()
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/stage_%s%s.png" % [id, suffix]))
		print("已保存 res://artifacts/stage_%s%s.png" % [id, suffix])
		if cabinet.next_button().disabled:
			break
		cabinet.press_next()
		while cabinet.is_transitioning():
			await process_frame
	quit()
