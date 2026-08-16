extends SceneTree
## 截取右下角全局成就提示的停留阶段。

const OUTPUT_PATH := "res://artifacts/achievements/start_game_toast.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_unlock_achievement", "start_game")
	await create_timer(0.65).timeout
	await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("Saved achievement toast capture")
	quit()
