extends SceneTree
## 抓插播环节的两张图：四行提示语落定的一刻，和名单加【继续玩】。

const NOTICE_PATH := "res://artifacts/music_break_notice.png"
const CREDITS_PATH := "res://artifacts/music_break_credits.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var notice := (load("res://scenes/ui/music_break_notice.tscn") as PackedScene).instantiate()
	root.add_child(notice)
	await process_frame
	notice.call("present")
	await create_timer(2.4).timeout
	root.get_texture().get_image().save_png(NOTICE_PATH)
	print(ProjectSettings.globalize_path(NOTICE_PATH))
	notice.queue_free()

	var credits := (load("res://scenes/ui/credits_screen.tscn") as PackedScene).instantiate()
	root.add_child(credits)
	await process_frame
	credits.call("present", true)
	# 停在发光呼吸的最亮处，截图才看得出来强度。
	await create_timer(2.55).timeout
	root.get_texture().get_image().save_png(CREDITS_PATH)
	print(ProjectSettings.globalize_path(CREDITS_PATH))
	quit()
