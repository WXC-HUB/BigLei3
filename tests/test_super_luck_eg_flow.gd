extends SceneTree

const EG_FLY := preload("res://my_asset/birds/eg_fly_big.png")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	var eg_bird := game.get_node("EgBirdPerch") as BirdPerch
	var perch_sprite := eg_bird.get_node("Sprite") as TextureRect
	var home := perch_sprite.position
	game.call("_resolve_super_luck", center)
	await create_timer(0.2).timeout
	var flyer := _find_eg_flyer(game)
	assert(flyer != null, "Giant EG flyover did not appear")
	assert((eg_bird.get_node("TriggerSFX") as AudioStreamPlayer).playing, "EG trigger audio did not play")
	assert(flyer.size.x >= 700.0, "EG flyover is not giant")
	assert(not bool(game.get("_super_luck_mode_active")), "Mode activated before the giant flyover finished")
	assert(perch_sprite.position.is_equal_approx(home), "Bottom EG bird moved with the giant flyover")
	await create_timer(1.22).timeout
	assert(bool(game.get("_super_luck_mode_active")), "Super luck mode did not activate after the flyover")
	assert(int(game.get("_super_luck_clicks_remaining")) == 1, "Super luck did not grant one click")
	assert(bool(game.call("_is_invincible")), "Super luck mode did not protect the player")
	for bird_name in ["BlueBirdPerch", "RedBirdPerch", "BlackBirdPerch", "AttackerBirdPerch"]:
		var bird_sprite := game.get_node(NodePath(bird_name + "/Sprite")) as TextureRect
		var branch := game.get_node(NodePath(bird_name + "/Tree")) as TextureRect
		assert(not bird_sprite.is_visible_in_tree(), "%s did not slide offscreen" % bird_name)
		assert(not branch.is_visible_in_tree(), "%s branch did not slide offscreen" % bird_name)
	assert(_find_eg_flyer(game) == null, "Giant EG flyer did not leave the screen")
	assert(perch_sprite.visible, "Bottom EG bird should stay onscreen during its mode")
	print("Super luck EG flow: giant flyover, protected mode, and bird exits passed")
	quit()


func _find_eg_flyer(game: Node) -> TextureRect:
	var effects_layer := game.get("_effects_layer") as Control
	for child in effects_layer.get_children():
		if child is TextureRect and (child as TextureRect).texture == EG_FLY:
			return child as TextureRect
	return null
