extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(3.0).timeout.connect(func() -> void:
		push_error("Mine card prefab test timed out after an assertion")
		quit(2)
	)
	var prefab := load("res://scenes/ui/mine_card.tscn") as PackedScene
	assert(prefab != null, "Mine card prefab is missing")
	var card := prefab.instantiate() as MineCell
	card.configure(0, 88.0)
	root.add_child(card)
	await process_frame

	var visual := card.get("_visual_root") as Control
	card.mouse_entered.emit()
	await create_timer(0.18).timeout
	assert(visual.scale.x > 1.1, "Covered mine card hover is not strong enough")
	assert(absf(visual.rotation) > deg_to_rad(2.0), "Covered mine card rotation is not strong enough")
	card.mouse_exited.emit()
	await create_timer(0.18).timeout
	assert(visual.scale.is_equal_approx(Vector2.ONE), "Mine card hover did not reset")

	var covered: Texture2D = load("res://outlined_tiles/ground_tiles/revealed_plain.png")
	var revealed: Texture2D = load("res://outlined_tiles/ground_tiles/fogged_plain.png")
	card.set_ground_texture(covered)
	card.display_covered()
	card.prepare_reveal_face(revealed)
	card.display_revealed(null, MineCell.ContentKind.NUMBER, true, 1, 2)
	card.play_reveal()
	await create_timer(0.08).timeout
	assert(visual.scale.x < 0.8, "Mine card did not begin closing during flip")
	assert(absf(visual.rotation) > deg_to_rad(3.0) and visual.scale.y < 0.9, "Mine card flip is not diagonal")
	await create_timer(0.1).timeout
	var face := card.get("_base") as TextureRect
	var number := card.get("_number_label") as Label
	assert(face.texture == revealed, "Mine card face did not swap at flip midpoint")
	assert(number.modulate.a < 0.01, "Card number appeared before the face finished opening")
	await create_timer(0.27).timeout
	assert(number.modulate.a > 0.5 and number.scale.x > 0.5, "Card number did not pop after the face opened")
	await create_timer(0.24).timeout
	assert(not bool(card.get("_flipping")), "Mine card flip did not finish")
	assert(visual.scale.is_equal_approx(Vector2.ONE), "Mine card did not settle after flip")
	card.mouse_entered.emit()
	await create_timer(0.18).timeout
	assert(visual.scale.is_equal_approx(Vector2.ONE), "Revealed mine card still enlarges on hover")
	assert(is_zero_approx(visual.rotation), "Revealed mine card still rotates on hover")

	print("Mine card prefab: test passed")
	quit()
