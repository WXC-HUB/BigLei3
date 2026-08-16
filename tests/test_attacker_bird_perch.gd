extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/birds/attacker_bird_perch.tscn") as PackedScene
	var bird := packed.instantiate() as BirdPerch
	root.add_child(bird)
	await process_frame
	assert(bird.idle_frames.size() == 4)
	assert(bird.action_frames.size() == 2)
	var sprite := bird.get_node("Sprite") as TextureRect
	var action_sfx := bird.get_node("ActionSFX") as AudioStreamPlayer
	var trigger_sfx := bird.get_node("TriggerSFX") as AudioStreamPlayer
	assert(action_sfx.stream != null)
	assert(trigger_sfx.stream != null)
	var home := sprite.position
	bird.play_trigger_sfx()
	assert(trigger_sfx.playing)
	await bird.begin_travel_action(0, false)
	assert(not action_sfx.playing)
	assert(sprite.texture == bird.action_frames[0])
	await bird.move_travel_sprite_to_global_center(Vector2(620, 410), 0.06)
	bird.set_travel_frame(1)
	bird.play_action_sfx()
	assert(sprite.texture == bird.action_frames[1])
	assert(action_sfx.playing)
	await bird.finish_travel_action(0.06)
	assert(sprite.position.is_equal_approx(home))
	assert(sprite.texture == bird.idle_frames[0])
	print("AttackerBirdPerch: travel, peck, and return passed")
	quit()
