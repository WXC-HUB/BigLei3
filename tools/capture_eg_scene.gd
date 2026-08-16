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
	root.get_texture().get_image().save_png("res://artifacts/eg_bottom_perch_review.png")
	game.call("_resolve_super_luck", 44)
	await create_timer(0.45).timeout
	root.get_texture().get_image().save_png("res://artifacts/eg_giant_flyover_review.png")
	print("Saved EG bottom-perch and giant-flyover screenshots")
	quit()
