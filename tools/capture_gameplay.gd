extends SceneTree

const OUTPUT_PATH := "res://artifacts/gameplay_review.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame

	game.call("_on_cell_revealed", 44)
	await create_timer(0.13).timeout
	var effect_image := root.get_texture().get_image()
	effect_image.save_png("res://artifacts/gameplay_effect.png")
	await create_timer(1.2).timeout

	var board = game.get("_board")
	for index in range(board.width * board.height):
		if (
			board.item_at(index) != board.ItemType.NONE
			and board.state_at(index) == board.CellState.COVERED
		):
			game.call("_on_cell_revealed", index)
			break
	await create_timer(2.4).timeout
	await process_frame

	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Could not save gameplay screenshot: %s" % error_string(error))
		quit(1)
		return
	print("Saved gameplay screenshot to ", ProjectSettings.globalize_path(OUTPUT_PATH))
	quit()
