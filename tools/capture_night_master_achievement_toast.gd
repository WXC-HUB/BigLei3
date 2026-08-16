extends SceneTree
## 截取“夜师傅吃鱼”成就提示的停留阶段。

const OUTPUT_PATH := "res://artifacts/achievements/night_master_fish_toast.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_unlock_achievement", "night_master_fish")
	await create_timer(0.65).timeout
	await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("Saved night-master achievement toast capture")
	quit()
