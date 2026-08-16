extends SceneTree

const OUTPUT_PATH := "res://artifacts/background_composite_review.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_start_game")
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Could not save background review: %s" % error_string(error))
		quit(1)
		return
	print("Saved background review to ", ProjectSettings.globalize_path(OUTPUT_PATH))
	quit()
