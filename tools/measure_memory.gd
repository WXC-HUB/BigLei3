extends SceneTree
## 量一遍运行时的内存与显存占用：排查玩家报的「卡住然后闪退」时，先确认显存/内存
## 有没有逼近机器上限（项目里 122 张贴图全是无损导入，展开成 RGBA8 之后总量很可观）。
## 跑法（**不能加 --headless**，显存读数需要真渲染器）：
##   godot --fixed-fps 60 --script tools/measure_memory.gd

const STAGE_IDS := ["grass_1", "grass_2", "grass_3", "river_1", "river_2", "coast_1"]


func _init() -> void:
	_measure.call_deferred()


func _measure() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	_report("空场景")

	var cabinet := (load("res://scenes/stage_cabinet.tscn") as PackedScene).instantiate() as StageCabinet
	cabinet.mosquito_events = false
	cabinet.entrance_events = false
	root.add_child(cabinet)
	await process_frame
	cabinet.present(STAGE_IDS.duplicate(), "grass_1", 1, {})
	for _i in 90:
		await process_frame
	_report("陈列柜 · 第 1 关展品")

	# 一路切过去：每件展品都被加载过一次，看内存是切一件涨一截还是切完就放。
	for index in range(1, STAGE_IDS.size()):
		cabinet.press_next()
		for _i in 90:
			await process_frame
		_report("陈列柜 · 切到第 %d 关" % (index + 1))

	cabinet.queue_free()
	await process_frame
	for _i in 30:
		await process_frame
	_report("柜子拆掉之后")
	quit()


func _report(label: String) -> void:
	var mb := 1024.0 * 1024.0
	print("%-26s 静态内存 %7.1f MB ｜ 显存 %7.1f MB ｜ 贴图显存 %7.1f MB ｜ 对象 %d" % [
		label,
		Performance.get_monitor(Performance.MEMORY_STATIC) / mb,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / mb,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / mb,
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
	])
