extends SceneTree
## 截取第一新手关棋盘下方的 guide.png。

const OUTPUT_PATH := "res://artifacts/tutorial/guide_below_board.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var start_screen := game.get("_start_screen") as Control
	if start_screen != null:
		start_screen.get_parent().queue_free()
		game.set("_start_screen", null)
	game.call("_start_game")
	await create_timer(0.4).timeout
	await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("Saved tutorial guide capture")
	quit()
