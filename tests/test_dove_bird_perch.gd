extends SceneTree
## 斑鸠栖位预制体：3 帧待机（第 4 帧不用）+ 4 帧动作（叼枝站、叼枝走、飞两帧）；
## 素材朝左，转身按 art_faces_right 走；下棋盘要缩小；扇翅膀的帧率按真实时间走。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/birds/dove_bird_perch.tscn") as PackedScene
	var bird := packed.instantiate() as BirdPerch
	root.add_child(bird)
	await process_frame
	assert(bird.idle_frames.size() == 3, "The dove idles on frames 1-3 only; frame 4 is not used")
	assert(bird.action_frames.size() == 4, "Dove needs four action frames")
	for frame in bird.idle_frames + bird.action_frames:
		assert(frame != null and frame.get_size() == Vector2(220, 220), "Bird frame is not on the 220×220 standard canvas")
	assert(bird.get_node_or_null("Tree") != null, "Every bird stands on a branch; the dove has none")
	assert(not bird.art_faces_right, "The dove sheet is drawn facing left")
	var sprite := bird.get_node("Sprite") as TextureRect
	var home := sprite.position
	var first_texture := sprite.texture
	await create_timer(0.7).timeout
	assert(sprite.texture != first_texture, "Idle loop did not advance")

	await bird.begin_travel_action(2, false)
	assert(sprite.texture == bird.action_frames[2], "Travel did not start on the flying frame")
	# 下棋盘就得缩小：栖位上这只鸟有好几格宽，原样飞上去会盖住它要作用的格子。
	assert(bird.board_travel_scale < 0.7, "Dove does not shrink for board work")
	assert(sprite.scale.is_equal_approx(Vector2.ONE * bird.board_travel_scale), "Travel did not shrink the sprite")
	bird.set_travel_facing_right(true)
	assert(sprite.flip_h, "Facing right did not flip the left-facing art")
	bird.set_travel_facing_right(false)
	assert(not sprite.flip_h, "Facing left should leave the art alone")

	# 扇着翅膀飞过去：落点要准，中途帧号要换过。
	bird.set_travel_sprite_global_center(Vector2(400, 300))
	var seen: Array[Texture2D] = []
	var watch := bird.get_tree().create_timer(0.12)
	watch.timeout.connect(func() -> void: seen.append(sprite.texture))
	await bird.flap_travel_sprite_to_global_center(Vector2(760, 420), 0.3, [2, 3], 0.08, 20.0)
	var centre := bird.get_launch_global_position()
	assert(centre.is_equal_approx(Vector2(760, 420)), "Flapping flight did not land on the target centre: %s" % centre)
	assert(seen.size() == 1 and bird.action_frames.has(seen[0]), "The wings were not cycling mid-flight")

	await bird.fade_out_travel_sprite(0.1)
	assert(not sprite.visible, "Dove is still visible after fading out")
	await bird.reappear_on_perch(0.1)
	assert(sprite.visible and sprite.position.is_equal_approx(home), "Dove did not reappear on its perch")
	assert(sprite.scale.is_equal_approx(Vector2.ONE), "Dove stayed shrunk after coming home")
	assert(sprite.texture == bird.idle_frames[0], "Dove did not resume idle after reappearing")
	print("DoveBirdPerch: idle, facing, shrink, flapping flight and reappear passed")
	quit()
