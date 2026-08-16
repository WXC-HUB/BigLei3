extends SceneTree
## 抓长按跳过的几个进度节点：刚按下、按到一半、快按满。

const OUTPUT_DIR := "res://artifacts/story_frames"
const SHOT_AT := [0.25, 0.55, 0.95]


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var story := (load("res://scenes/ui/opening_story.tscn") as PackedScene).instantiate()
	root.add_child(story)
	await process_frame
	story.call("present")
	await create_timer(2.2).timeout
	var skip := story.get_node("LongPressSkip") as LongPressSkip
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press)
	var taken := 0
	while taken < SHOT_AT.size():
		await process_frame
		if skip.hold_progress() >= float(SHOT_AT[taken]):
			var path := "%s/hold_%d.png" % [OUTPUT_DIR, taken]
			root.get_texture().get_image().save_png(path)
			print(ProjectSettings.globalize_path(path))
			taken += 1
	quit()
