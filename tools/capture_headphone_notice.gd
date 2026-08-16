extends SceneTree
## 截黑屏耳机提示的逐行打击。
##   godot --fixed-fps 60 --script tools/capture_headphone_notice.gd

const OUTPUT_DIR := "res://artifacts/headphone_notice"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var screen := game.get("_start_screen") as StartScreen
	(screen.get_node("%StartButton") as Button).pressed.emit()
	for shot in range(14):
		await create_timer(0.15).timeout
		await process_frame
		var image := root.get_texture().get_image()
		image.save_png("%s/notice_%02d.png" % [OUTPUT_DIR, shot])
	print("Saved headphone notice frames; run=", game.get("_run_number"))
	quit()
