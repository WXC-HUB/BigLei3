extends SceneTree

const OUTPUT_PATH := "res://artifacts/bird_scene_review.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	var start_screen: Control = game.get("_start_screen")
	if start_screen != null:
		start_screen.queue_free()
		game.set("_start_screen", null)
	game.call("_start_game")
	await process_frame
	await create_timer(0.5).timeout
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Could not save bird scene screenshot: %s" % error_string(error))
		quit(1)
		return
	var blue_bird := game.get_node("BlueBirdPerch")
	blue_bird.call("play_find", true)
	await create_timer(0.55).timeout
	var action_image := root.get_texture().get_image()
	action_image.save_png("res://artifacts/blue_bird_action_review.png")
	var board: MinesweeperBoard = game.get("_board")
	board.reveal(44)
	var empty_item_queue: Array[int] = []
	game.call("_resolve_compass", 44, empty_item_queue, {})
	await create_timer(1.12).timeout
	var red_action_image := root.get_texture().get_image()
	red_action_image.save_png("res://artifacts/red_bird_action_review.png")
	print("Saved bird scene screenshot to ", ProjectSettings.globalize_path(OUTPUT_PATH))
	quit()
