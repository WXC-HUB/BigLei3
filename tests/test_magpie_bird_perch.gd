extends SceneTree
## 灰喜鹊栖枝预制体：4 帧待机 + 4 帧走路，没有树枝（站在屏幕底边的地上），
## 走路接口能一格一格跳、能转身，走完淡出再回原位。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/birds/magpie_bird_perch.tscn") as PackedScene
	var bird := packed.instantiate() as BirdPerch
	root.add_child(bird)
	await process_frame
	assert(bird.idle_frames.size() == 4, "Magpie needs four idle frames")
	assert(bird.action_frames.size() == 4, "Magpie needs four walking frames")
	for frame in bird.idle_frames + bird.action_frames:
		assert(frame != null and frame.get_size() == Vector2(220, 220), "Bird frame is not on the 220×220 standard canvas")
	assert(bird.get_node_or_null("Tree") != null, "Every bird stands on a branch; the magpie has none")
	var sprite := bird.get_node("Sprite") as TextureRect
	var home := sprite.position
	var first_texture := sprite.texture
	await create_timer(0.62).timeout
	assert(sprite.texture != first_texture, "Idle loop did not advance")

	await bird.begin_travel_action(0, false)
	assert(sprite.texture == bird.action_frames[0], "Travel did not start on the stride frame")
	# 下棋盘就得缩小：栖位上这只鸟有三格宽，原样飞上去会盖住它要作用的格子。
	assert(bird.board_travel_scale < 0.6, "Magpie does not shrink for board work")
	assert(sprite.scale.is_equal_approx(Vector2.ONE * bird.board_travel_scale), "Travel did not shrink the sprite")
	bird.set_travel_sprite_global_center(Vector2(600, 400))
	bird.set_travel_facing_right(false)
	assert(sprite.flip_h, "Facing left did not flip the sprite")
	bird.set_travel_facing_right(true)
	assert(not sprite.flip_h, "Facing right did not restore the sprite")
	await bird.hop_travel_sprite_to_global_center(Vector2(700, 400), 0.12, 16.0)
	var centre := bird.get_launch_global_position()
	assert(centre.is_equal_approx(Vector2(700, 400)), "Hop did not land on the target centre: %s" % centre)
	var action_sfx := bird.get_node("ActionSFX") as AudioStreamPlayer
	assert(action_sfx.stream != null, "Magpie call is not assigned")
	bird.play_action_sfx()
	assert(action_sfx.playing, "Magpie call did not play")

	bird.set_travel_facing_right(false)
	await bird.fade_out_travel_sprite(0.1)
	assert(not sprite.visible, "Sprite is still visible after fading out")
	assert(sprite.position.is_equal_approx(home), "Sprite was not parked at home after fading")
	await bird.reappear_on_perch(0.1)
	assert(sprite.visible and sprite.position.is_equal_approx(home), "Bird did not reappear at home")
	# 栖位上的灰喜鹊是左右颠倒摆的，归位要回到那个朝向，而不是素材本来的朝向。
	assert(sprite.flip_h, "Reappearing did not restore the home facing")
	assert(sprite.texture == bird.idle_frames[0] and is_equal_approx(sprite.modulate.a, 1.0), "Bird did not resume idle after reappearing")
	print("MagpieBirdPerch: idle, hop travel, facing, fade-out and reappear passed")
	quit()
