extends SceneTree
## 第 2 关（麦垄）的游荡动物彩蛋过目图：把柜子停在麦垄，四只挨个放出来各拍一张站位，
## 再对最后一只薅一下，连拍薅毛那几拍。跑法（**不能加 --headless**）：
##   godot --fixed-fps 60 --script tools/capture_wander_animal.gd
## 输出 artifacts/wander_<key>.png 与 artifacts/wander_pluck_<n>.png。

const KEYS := ["bear", "monkey", "penguin", "fox"]


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var cabinet := (load("res://scenes/stage_cabinet.tscn") as PackedScene).instantiate() as StageCabinet
	root.add_child(cabinet)
	await process_frame
	var all_ids: Array = []
	for stage in StageTable.all_stages():
		all_ids.append(String(stage["id"]))
	cabinet.present(all_ids, "", 0, {})
	# 停到麦垄：全部通关时柜子停在最后一关，所以要往回按，而且要认准方向别空转。
	var guard := 0
	while cabinet.current_stage() != StageCabinet.WANDER_STAGE:
		var here := cabinet.current_index()
		var want := 0
		for i in cabinet.slot_count():
			if cabinet.slots()[i].stage_id == StageCabinet.WANDER_STAGE:
				want = i
		if here < want:
			cabinet.press_next()
		else:
			cabinet.press_prev()
		while cabinet.is_transitioning():
			await process_frame
		guard += 1
		if guard > 20:
			push_error("切不到麦垄")
			quit(2)
			return
	for _i in 40:
		await process_frame

	var bug := cabinet.wander_animal()
	for key in KEYS:
		bug.stop()
		bug.start()
		bug.spawn_key(key)
		# 让它从画外走进地面带中间，站定再拍。
		for _i in 150:
			await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/wander_%s.png" % key))
		print("已保存 res://artifacts/wander_%s.png（走位）" % key)

	# 最后一只留在场上，薅它。
	bug.stop()
	bug.start()
	bug.spawn_key("bear")
	for _i in 150:
		await process_frame
	bug.pluck_now()
	var shots := [12, 30, 46, 74]
	var frame := 0
	for index in shots.size():
		while frame < int(shots[index]):
			await process_frame
			frame += 1
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/wander_pluck_%d.png" % index))
		print("已保存 res://artifacts/wander_pluck_%d.png" % index)
	quit()
