extends SceneTree
## 小嘴乌鸦栖位预制体：4 帧待机 + 4 帧动作（探身 / 掀开 / 僵住 / 逃走），站在地上没有树枝；
## 素材本身朝左，所以 art_faces_right 必须是 false，转身才不会反。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/birds/crow_bird_perch.tscn") as PackedScene
	var bird := packed.instantiate() as BirdPerch
	root.add_child(bird)
	await process_frame
	assert(bird.idle_frames.size() == 4, "Crow needs four idle frames")
	assert(bird.action_frames.size() == 4, "Crow needs four action frames")
	for frame in bird.idle_frames + bird.action_frames:
		assert(frame != null and frame.get_size() == Vector2(220, 220), "Bird frame is not on the 220×220 standard canvas")
	assert(bird.get_node_or_null("Tree") != null, "Every bird stands on a branch; the crow has none")
	assert(not bird.art_faces_right, "The crow sheet is drawn facing left")
	var sprite := bird.get_node("Sprite") as TextureRect
	var home := sprite.position
	var first_texture := sprite.texture
	await create_timer(0.66).timeout
	assert(sprite.texture != first_texture, "Idle loop did not advance")

	await bird.begin_travel_action(0, false)
	assert(sprite.texture == bird.action_frames[0], "Travel did not start on the lean-in frame")
	# 下棋盘就得缩小：栖位上这只鸟有三格宽，原样飞上去会盖住它要作用的格子。
	assert(bird.board_travel_scale < 0.6, "Crow does not shrink for board work")
	assert(sprite.scale.is_equal_approx(Vector2.ONE * bird.board_travel_scale), "Travel did not shrink the sprite")
	# 素材朝左：朝右走要翻面，朝左走保持原样。
	bird.set_travel_facing_right(true)
	assert(sprite.flip_h, "Facing right did not flip the left-facing art")
	bird.set_travel_facing_right(false)
	assert(not sprite.flip_h, "Facing left should leave the art alone")

	bird.set_travel_sprite_global_center(Vector2(500, 400))
	var centre := bird.get_launch_global_position()
	assert(centre.is_equal_approx(Vector2(500, 400)), "set_travel_sprite_global_center missed: %s" % centre)
	await bird.move_travel_sprite_to_global_center(Vector2(620, 360), 0.12)
	centre = bird.get_launch_global_position()
	assert(centre.is_equal_approx(Vector2(620, 360)), "Travel did not land on the target centre: %s" % centre)
	bird.set_travel_frame(2)
	assert(sprite.texture == bird.action_frames[2], "Startle frame did not show")
	var action_sfx := bird.get_node("ActionSFX") as AudioStreamPlayer
	assert(action_sfx.stream != null, "Crow call is not assigned")
	bird.play_action_sfx()
	assert(action_sfx.playing, "Crow call did not play")

	bird.set_travel_frame(3)
	await bird.fly_sprite_offscreen_right(0.12)
	assert(not sprite.visible, "Crow is still visible after fleeing offscreen")
	assert(sprite.position.is_equal_approx(home), "Sprite was not parked at home after fleeing")
	await bird.reappear_on_perch(0.1)
	assert(sprite.visible and sprite.position.is_equal_approx(home), "Crow did not reappear on its perch")
	assert(not sprite.flip_h, "Reappearing did not restore the home facing")
	assert(sprite.texture == bird.idle_frames[0], "Crow did not resume idle after reappearing")
	print("CrowBirdPerch: idle, facing, travel, startle, flee and reappear passed")
	quit()
