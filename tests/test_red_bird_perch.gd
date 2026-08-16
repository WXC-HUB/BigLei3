extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/birds/red_bird_perch.tscn") as PackedScene
	var bird := packed.instantiate() as BirdPerch
	root.add_child(bird)
	await process_frame
	var action_sfx := bird.get_node("ActionSFX") as AudioStreamPlayer
	assert(not action_sfx.playing)
	bird.play_action()
	assert(bool(bird.get("_acting")))
	assert(action_sfx.playing)
	assert(int(bird.launch_frame_index) == 1)
	assert(bird.action_frames.size() == 2)
	await create_timer(0.26).timeout
	assert((bird.get_node("Sprite") as TextureRect).texture == bird.action_frames[1], "Perched bird must depart in frame 2")
	assert((bird.get_node("Sprite") as TextureRect).visible, "Perched bird must remain distinct before departing")
	assert(not bool(bird.get("_acting")))
	assert(int(bird.get("_action_play_count")) == 1)
	await bird.fly_sprite_offscreen_right(0.12)
	assert(not (bird.get_node("Sprite") as TextureRect).visible, "Perched bird did not leave to the right")
	bird.reset_to_idle()
	assert((bird.get_node("Sprite") as TextureRect).visible)
	print("RedBirdPerch: compass action and SFX passed")
	quit()
