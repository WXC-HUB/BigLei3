extends SceneTree
## 长尾山雀栖枝预制体：4 帧待机 + 4 帧摔落，树枝不动，摔落走 travel 接口后能回到原位。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/birds/tit_bird_perch.tscn") as PackedScene
	var bird := packed.instantiate() as BirdPerch
	root.add_child(bird)
	await process_frame
	assert(bird.idle_frames.size() == 4, "Long-tailed tit needs four idle frames")
	assert(bird.action_frames.size() == 4, "Long-tailed tit needs four fall frames (slip, flap, dive, crash)")
	for frame in bird.idle_frames + bird.action_frames:
		assert(frame != null and frame.get_size() == Vector2(220, 220), "Bird frame is not on the 220×220 standard canvas")
	assert(bird.get_node("Tree") != null, "Perch scene has no branch layer")
	var sprite := bird.get_node("Sprite") as TextureRect
	var tree := bird.get_node("Tree") as TextureRect
	var home := sprite.position
	var tree_home := tree.position
	var first_texture := sprite.texture
	await create_timer(0.6).timeout
	assert(sprite.texture != first_texture, "Idle loop did not advance")
	assert(tree.position == tree_home, "Branch moved with the idle rhythm")

	await bird.begin_travel_action(0, false)
	assert(sprite.texture == bird.action_frames[0], "Travel did not start on the slip frame")
	bird.set_travel_sprite_global_center(Vector2(900, 500))
	var draw_scale := sprite.get_global_transform().get_scale()
	var centre := sprite.global_position + sprite.size * draw_scale * 0.5
	assert(centre.is_equal_approx(Vector2(900, 500)), "set_travel_sprite_global_center missed: %s" % centre)
	bird.set_travel_frame(3)
	assert(sprite.texture == bird.action_frames[3], "Crash frame did not show")
	var action_sfx := bird.get_node("ActionSFX") as AudioStreamPlayer
	assert(action_sfx.stream != null, "Crash SFX is not assigned")
	bird.play_action_sfx()
	assert(action_sfx.playing, "Crash SFX did not play")
	assert(tree.position == tree_home, "Branch moved during the fall")

	await bird.tumble_sprite_offscreen_bottom(0.2, 1, 0)
	assert(not sprite.visible, "Bird is still visible after tumbling off the screen")
	assert(sprite.texture == bird.action_frames[0], "Tumble did not switch to the slip frame")
	assert(sprite.position.is_equal_approx(home), "Sprite was not parked at home after tumbling")
	await bird.reappear_on_perch(0.1)
	assert(sprite.visible and sprite.position.is_equal_approx(home), "Bird did not reappear on its perch")
	assert(sprite.texture == bird.idle_frames[0], "Bird did not resume idle after reappearing")
	assert(is_equal_approx(sprite.rotation, 0.0) and is_equal_approx(sprite.modulate.a, 1.0), "Reappear left rotation or fade behind")
	assert(tree.position == tree_home, "Branch moved during the exit")
	print("TitBirdPerch: idle, fall travel, crash frame, tumble-off and reappear passed")
	quit()
