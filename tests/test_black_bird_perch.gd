extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/birds/black_bird_perch.tscn") as PackedScene
	var bird := packed.instantiate() as BirdPerch
	root.add_child(bird)
	await process_frame
	assert(bird.idle_frames.size() == 4)
	assert(bird.action_frames.size() == 2)
	assert(int(bird.launch_frame_index) == 1)
	var action_sfx := bird.get_node("ActionSFX") as AudioStreamPlayer
	assert(action_sfx.stream != null)
	bird.play_action()
	assert(action_sfx.playing)
	await create_timer(0.26).timeout
	assert((bird.get_node("Sprite") as TextureRect).texture == bird.action_frames[1])
	var sprite := bird.get_node("Sprite") as TextureRect
	var start_x := sprite.global_position.x
	await bird.fly_sprite_offscreen_bottom(0.1)
	assert(not (bird.get_node("Sprite") as TextureRect).visible)
	assert(is_equal_approx(sprite.global_position.x, start_x), "Black bird drifted sideways while leaving downward")
	bird.reset_to_idle()
	assert((bird.get_node("Sprite") as TextureRect).visible)
	print("BlackBirdPerch: idle, launch, audio, and reset passed")
	quit()
