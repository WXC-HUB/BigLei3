extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	game.set("_player_hp", 6)
	game.call("_start_game")
	await process_frame
	assert(game.get("_player_hp") == 6)
	var health_bar := game.get("_health_bar") as ProgressBar
	assert(health_bar.value == 6.0)

	var run_before_death: int = game.get("_run_number")
	game.set("_player_hp", 0)
	game.call("_choose_shop_offer", 0)
	assert(game.get("_run_number") == run_before_death)
	var shop := game.get("_shop_layer") as ShopOverlay
	shop.present_game_over()
	assert(shop.visible)
	assert(not shop.offers.visible)

	print("Run rules: all tests passed")
	quit()
