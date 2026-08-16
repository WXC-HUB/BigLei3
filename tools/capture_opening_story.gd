extends SceneTree

const OUTPUT_DIR := "res://artifacts/story_frames"
## 四幕各抓一张：入场、主文本打完、小字打完，以及左右换边之后的下一幕。
const SHOT_TIMES := [1.15, 1.55, 2.3, 4.6, 8.0, 11.4]


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var story := (load("res://scenes/ui/opening_story.tscn") as PackedScene).instantiate()
	root.add_child(story)
	await process_frame
	story.set("playback_speed", 1.0)
	story.call("present")
	var elapsed := 0.0
	for index in SHOT_TIMES.size():
		var target: float = SHOT_TIMES[index]
		await create_timer(target - elapsed).timeout
		elapsed = target
		await process_frame
		var path := "%s/frame_%d.png" % [OUTPUT_DIR, index]
		root.get_texture().get_image().save_png(path)
		print(ProjectSettings.globalize_path(path))
	quit()
