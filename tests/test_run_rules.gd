extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(5.0).timeout.connect(func() -> void:
		push_error("Run rules test did not reach quit")
		quit(2)
	)
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_start_game")

	game.set("_player_hp", 6)
	game.call("_start_game")
	await process_frame
	assert(game.get("_player_hp") == 3)
	var player_status := game.get("_player_status") as PlayerStatus
	assert(player_status.heart_count() == 3)
	assert(player_status.maximum_heart_count() == 3)

	var run_before_death: int = game.get("_run_number")
	game.set("_player_hp", 0)
	game.call("_choose_shop_offer", 0)
	assert(game.get("_run_number") == run_before_death)
	var shop := game.get("_shop_layer") as ShopOverlay
	shop.present_game_over()
	assert(shop.visible)
	var shop_items: Array = shop.get("_item_nodes")
	for item in shop_items:
		assert(not (item as CanvasItem).visible)

	print("Run rules: all tests passed")
	quit()
