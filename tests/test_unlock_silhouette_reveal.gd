extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(14.0).timeout.connect(func() -> void:
		push_error("Unlock silhouette reveal test timed out")
		quit(2)
	)
	for scene_path in [
		"res://scenes/ui/night_heron_unlock.tscn",
		"res://scenes/ui/redstart_unlock.tscn",
		"res://scenes/ui/attacker_unlock.tscn",
		"res://scenes/ui/kestrel_unlock.tscn",
	]:
		await _verify_unlock(scene_path)
	print("All bird unlocks use centered silhouette shake and color flip passed")
	quit()


func _verify_unlock(scene_path: String) -> void:
	var unlock := (load(scene_path) as PackedScene).instantiate() as Control
	root.add_child(unlock)
	await process_frame
	unlock.call("present")
	var initial_bird := unlock.get_node("Finale/Bird") as TextureRect
	var initial_continue := unlock.get_node("Finale/Continue") as Button
	assert(initial_bird.modulate.a < 0.01, "%s displayed its bird before the reveal started" % scene_path)
	assert(not initial_continue.visible, "%s displayed its continue button on the first frame" % scene_path)
	for label_name in ["Name", "Tagline", "Effect"]:
		assert((unlock.get_node("Finale/" + label_name) as Label).modulate.a < 0.01, "%s displayed %s on the first frame" % [scene_path, label_name])
	var silhouette_deadline := Time.get_ticks_msec() + 500
	while str(unlock.get_meta(&"unlock_reveal_phase", "")) == "" and Time.get_ticks_msec() < silhouette_deadline:
		await process_frame
	var finale := unlock.get_node("Finale") as Control
	var bird := unlock.get_node("Finale/Bird") as TextureRect
	assert(str(unlock.get_meta(&"unlock_reveal_phase", "")) == "silhouette", "%s skipped its silhouette phase" % scene_path)
	assert(bird.material is ShaderMaterial, "%s silhouette was not desaturated" % scene_path)
	assert(bird.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s minigame accepted input during its silhouette phase" % scene_path)
	var expected_center := (finale.size - bird.size) * 0.5 + Vector2(0.0, -34.0)
	assert(bird.position.distance_to(expected_center) < 32.0, "%s silhouette was not centered" % scene_path)
	if unlock.has_node("PhotoStage"):
		assert(not (unlock.get_node("PhotoStage") as Control).visible, "%s still displayed its photo montage" % scene_path)
	var continue_button := unlock.get_node("Finale/Continue") as Button
	var deadline := Time.get_ticks_msec() + 3000
	while continue_button.disabled and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not continue_button.disabled, "%s color reveal did not finish" % scene_path)
	assert(str(unlock.get_meta(&"unlock_reveal_phase", "")) == "color", "%s did not finish on its color phase" % scene_path)
	assert(bird.material == null, "%s bird stayed desaturated after flipping" % scene_path)
	assert(bird.mouse_filter != Control.MOUSE_FILTER_IGNORE, "%s minigame stayed disabled after the color flip" % scene_path)
	for label_name in ["Name", "Tagline", "Effect"]:
		assert((unlock.get_node("Finale/" + label_name) as Label).modulate.a > 0.98, "%s text did not appear with the color reveal" % scene_path)
	continue_button.pressed.emit()
	await create_timer(0.28).timeout
	unlock.queue_free()
	await process_frame
