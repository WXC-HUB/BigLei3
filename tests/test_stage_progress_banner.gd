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
	quit()
