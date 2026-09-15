extends SceneTree
## 长尾山雀解锁页：文案齐全；每撩一次多一只小鸟，凑够一群融成一碗汤圆并报成就；
## 融合后再撩只晃碗、不再加鸟；重开页面全部还原。

const TIT := preload("res://scripts/ui/tit_unlock.gd")
const Catalog := preload("res://scripts/game/achievement_catalog.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("Tit unlock test timed out")
		quit(2)
	)
	GameSave.save_path = "user://test_tit_unlock_save.json"
	GameSave.clear()
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var title := game.get("_start_screen") as Control
	if title != null:
		game.set("_start_screen", null)
		title.get_parent().queue_free()
	game.call("_start_game")
	await create_timer(0.4).timeout

	var unlock := game.get("_tit_unlock") as TitUnlock
	assert(unlock != null, "Main did not build the tit unlock page")
	var name_label := unlock.get_node("Finale/Name") as Label
	var tagline := unlock.get_node("Finale/Tagline") as Label
	var effect := unlock.get_node("Finale/Effect") as Label
	var continue_button := unlock.get_node("Finale/Continue") as Button
	assert(name_label.text.replace(" ", "") == "长尾山雀", "Tit name line is incorrect")
	assert(not tagline.text.is_empty(), "Tit tagline is missing")
	assert(effect.text.contains("3×3"), "Tit effect line does not describe the 3×3 crash")
	assert((unlock.get_node("BirdCall") as AudioStreamPlayer).stream != null, "Tit hover chirp is missing")
	var pattern := (unlock.get_node("IconPattern") as ColorRect).material as ShaderMaterial
	assert(pattern != null and pattern.get_shader_parameter("icon_texture") != null, "Tit unlock has no moving icon pattern")

	unlock.present()
	await create_timer(3.0).timeout
	assert(unlock.visible and not continue_button.disabled, "Unlock page reveal never finished")
	var flight_layer := unlock.get_node("FlightLayer") as Control
	var home_name := name_label.text

	# 每撩一次多一只小鸟。
	unlock.bird.mouse_entered.emit()
	await process_frame
	assert(unlock.flock_count() == 1, "First hover did not add a flock bird")
	assert(flight_layer.get_child_count() == 1, "Flock bird was not placed on the flight layer")
	var chick := flight_layer.get_child(0) as TextureRect
	assert(TIT.FLOCK_TEXTURES.has(chick.texture), "Flock bird is not a long-tailed tit frame")
	var unlocked: Dictionary = game.get("_unlocked_achievements")
	for hover in range(TIT.TANGYUAN_FLOCK - 2):
		unlock.bird.mouse_entered.emit()
	assert(unlock.flock_count() == TIT.TANGYUAN_FLOCK - 1, "Flock count did not follow the hovers")
	assert(not unlock.is_merged() and not unlocked.has(Catalog.TIT_TANGYUAN), "Tangyuan came out before the flock was complete")
	assert(name_label.text == home_name, "Name changed before the merge")

	# 凑够一群：报成就、鸟群收拢、端出汤圆、文案换成汤圆。
	unlock.bird.mouse_entered.emit()
	assert(unlocked.has(Catalog.TIT_TANGYUAN), "Merging did not award the tangyuan achievement")
	# 预备阶段：鸟还都在，只是蹲下去了。
	await create_timer(TIT.MERGE_BRACE_TIME * 0.5).timeout
	assert(unlock.flock_count() == TIT.TANGYUAN_FLOCK, "Flock vanished before the gather started")
	assert(not unlock.is_merged(), "Merge finished before the birds even flew")
	await create_timer(TIT.merge_duration() + 0.6).timeout
	assert(unlock.is_merged(), "Flock never finished merging")
	assert((unlock.get_node("ServeThud") as AudioStreamPlayer).stream != null, "Serve thud SFX is not assigned")
	assert(unlock.flock_count() == 0, "Flock birds remained after merging")
	var bowl := flight_layer.get_node_or_null("TangyuanBowl") as TextureRect
	assert(bowl != null and bowl.texture == TIT.BOWL_TEXTURE, "Tangyuan bowl did not appear")
	assert(bowl.scale.is_equal_approx(Vector2.ONE), "Bowl did not finish popping in")
	assert(name_label.text == TIT.TANGYUAN_NAME_TEXT, "Name line did not change to tangyuan")
	assert(unlock.bird.modulate.a < 0.05, "Main bird is still visible after merging into the bowl")

	# 融合后再撩：不再加鸟，碗晃一下。
	unlock.bird.mouse_entered.emit()
	bowl.mouse_entered.emit()
	await create_timer(0.1).timeout
	assert(unlock.flock_count() == 0, "Hovering after the merge spawned birds again")
	assert(not bowl.scale.is_equal_approx(Vector2.ONE), "Bowl did not wobble on hover")
	await create_timer(0.5).timeout

	# 重开页面：一切还原。
	continue_button.pressed.emit()
	await create_timer(0.4).timeout
	unlock.present()
	await create_timer(0.2).timeout
	assert(not unlock.is_merged() and unlock.flock_count() == 0, "Reopening the page kept the merged state")
	assert(flight_layer.get_node_or_null("TangyuanBowl") == null, "Reopening the page kept the bowl")
	assert(name_label.text == home_name, "Reopening the page kept the tangyuan name")
	assert(unlock.bird.scale.is_equal_approx(Vector2.ONE) or unlock.bird.scale.x > 0.5, "Main bird scale was not restored")
	GameSave.clear()
	print("Tit unlock: texts, flock growth, tangyuan merge, achievement, wobble and reset passed")
	quit()
