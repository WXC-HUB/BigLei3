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
	game.call("_resolve_orbital_strike", target, empty_queue, {})
	await create_timer(0.47).timeout
	root.get_texture().get_image().save_png("res://artifacts/attacker_first_peck_review.png")
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png("res://artifacts/attacker_row_sweep_review.png")
	print("Saved attacker first-peck and row-sweep screenshots")
	quit()
