extends SceneTree

const OUTPUT_PATH := "res://artifacts/item_counter_review.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	# The title page lives on its own CanvasLayer above everything. Drop it so the
	# board and its counter row are what the screenshot shows.
	var screen := game.get("_start_screen") as Control
	if screen != null:
		game.set("_start_screen", null)
		screen.get_parent().queue_free()
	game.set("_run_number", 6)
	game.call("_start_game")
	await process_frame

	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	game.call("_on_cell_revealed", center)
	await create_timer(1.6).timeout

	# Dig up one item card so the counter shows a partially collected level.
	for index in range(board.width * board.height):
		if (
			board.item_at(index) != board.ItemType.NONE
			and board.state_at(index) == board.CellState.COVERED
		):
			game.call("_on_cell_revealed", index)
			break
	await create_timer(2.6).timeout
	await process_frame

	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Could not save item counter screenshot: %s" % error_string(error))
		quit(1)
		return
	print("Saved item counter screenshot to ", ProjectSettings.globalize_path(OUTPUT_PATH))
	quit()
