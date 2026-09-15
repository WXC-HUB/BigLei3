extends SceneTree

const StageProgressBannerView := preload("res://scenes/ui/stage_progress_banner.tscn")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var banner = StageProgressBannerView.instantiate()
	root.add_child(banner)
	await process_frame
	assert(banner.visible == false)
	banner.present("测试关", 2, 5)
	await process_frame
	assert(banner.title.text == "测试关")
	assert(banner.subtitle.text == "第 2 / 5 盘")
	banner.hide_immediately()
	assert(banner.visible == false)
	print("Stage progress banner: present/hide smoke passed")

	# 回归：低帧率下横幅必须能自己收掉。50 fps 时 11 盘关卡（老井村）的分段点动画
	# 会拖过进度条 tween 的 0.4 秒，旧代码随后 await 一个已结束的 tween 就永远挂起，
	# 横幅盖着棋盘不走——玩家反馈的"卡在开始界面"。无头模式 max_fps 能真实限帧。
	Engine.max_fps = 50
	var done := [false]
	_present_to_end(banner, done)
	var frames := 0
	while not done[0] and frames < 600:
		await process_frame
		frames += 1
	Engine.max_fps = 0
	assert(done[0], "banner.present() never returned at 50 fps (11 rounds)")
	assert(banner.visible == false)
	assert(banner.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	print("Stage progress banner: low-fps present completes passed")
	quit()


func _present_to_end(banner, done: Array) -> void:
	await banner.present("老井村", 7, 11)
	done[0] = true
