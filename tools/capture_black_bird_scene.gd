extends SceneTree


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
	var board: MinesweeperBoard = game.get("_board")
	var target := 44
	board.ensure_mines_placed(target)
	var empty_queue: Array[int] = []
	game.call("_resolve_lantern", target, empty_queue, {})
	await create_timer(0.85).timeout
	root.get_texture().get_image().save_png("res://artifacts/black_bird_cruise_review.png")
	await create_timer(0.58).timeout
	root.get_texture().get_image().save_png("res://artifacts/black_bird_dive_review.png")
	await create_timer(0.27).timeout
	root.get_texture().get_image().save_png("res://artifacts/black_bird_fish_drop_review.png")
	await create_timer(0.38).timeout
	root.get_texture().get_image().save_png("res://artifacts/black_bird_fish_blast_review.png")
	print("Saved black bird cruise, dive, fish-drop, and blast screenshots")
	quit()
