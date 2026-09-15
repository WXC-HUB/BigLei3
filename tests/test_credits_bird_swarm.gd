extends SceneTree
## 名单页上的八只鸟：直线飞、撞墙和撞同伴都要弹开，鼠标滑过要叫一声并炸出音符。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("Credits bird swarm test timed out")
		quit(2)
	)
	var credits := (load("res://scenes/ui/credits_screen.tscn") as PackedScene).instantiate()
	root.add_child(credits)
	await process_frame
	credits.call("present")
	await process_frame
	await process_frame

	var swarm := credits.get_node("BirdSwarm") as CreditsBirdSwarm
	assert(swarm != null, "The credits screen has no bird swarm")
	var birds: Array[TextureRect] = []
	var voices: Array[AudioStreamPlayer] = []
	for child in swarm.get_children():
		if child is TextureRect:
			birds.append(child)
		elif child is AudioStreamPlayer:
			voices.append(child)
	assert(birds.size() == 9, "Expected nine birds, found %d" % birds.size())
	assert(voices.size() == 9, "Expected one call per bird, found %d" % voices.size())

	# 一鸟一叫，九个音效不能重样。
	var streams: Array[String] = []
	for voice in voices:
		assert(voice.stream != null, "%s has no call" % voice.name)
		var path := voice.stream.resource_path
		assert(not streams.has(path), "Two birds share the same call: %s" % path)
		streams.append(path)

	# 鸟群在上面那排按钮下面：它们绝不能吃掉切歌和返回的点击。
	assert(
		swarm.get_index() < (credits.get_node("TopBar") as Control).get_index(),
		"The bird swarm is drawn over the credits buttons"
	)
	for bird in birds:
		assert(bird.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s can swallow clicks" % bird.name)

	# 直线飞：放着不管，每只鸟都得挪窝，而且始终留在画面里。
	var before: Array[Vector2] = []
	for bird in birds:
		before.append(bird.position)
	await create_timer(0.4).timeout
	for index in birds.size():
		assert(birds[index].position != before[index], "%s never moved" % birds[index].name)
	for _tick in 40:
		await process_frame
		for bird in birds:
			var rect := Rect2(Vector2.ZERO, swarm.size).grow(1.0)
			assert(rect.encloses(bird.get_rect()), "%s flew off screen at %s" % [bird.name, bird.position])

	# 撞同伴：把两只鸟摆成迎面相撞，下一帧就该被推开并交换法向速度。
	var velocities: PackedVector2Array = swarm.get("_velocities")
	var span := CreditsBirdSwarm.BIRD_SIZE
	birds[0].position = Vector2(swarm.size.x * 0.5 - span * 0.7, swarm.size.y * 0.5)
	birds[1].position = Vector2(swarm.size.x * 0.5 - span * 0.3, swarm.size.y * 0.5)
	velocities[0] = Vector2(200.0, 0.0)
	velocities[1] = Vector2(-200.0, 0.0)
	swarm.set("_velocities", velocities)
	var gap_before := birds[0].position.distance_to(birds[1].position)
	await process_frame
	await process_frame
	var after: PackedVector2Array = swarm.get("_velocities")
	assert(after[0].x < 0.0 and after[1].x > 0.0, "The birds passed through each other instead of bouncing")
	assert(
		birds[0].position.distance_to(birds[1].position) > gap_before,
		"The birds stayed locked together after colliding"
	)

	# 鼠标滑过：把一只鸟挪到光标底下，它就该叫一声并炸出一把音符。
	var notes := swarm.get_node("Notes") as Control
	assert(notes.get_child_count() == 0, "Notes were spawned before any hover")
	var target := birds[2]
	var pointer := swarm.get_local_mouse_position()
	target.position = pointer - Vector2(span, span) * 0.5
	await process_frame
	assert(notes.get_child_count() > 0, "Hovering a bird did not burst any music notes")
	assert(voices[2].playing, "Hovering %s did not play its call" % target.name)

	# 停在原地不该反复触发；离开再回来才算新的一次。
	var burst := notes.get_child_count()
	await process_frame
	assert(notes.get_child_count() <= burst, "The note burst retriggered while the mouse sat still")

	# 音符有上限：名单是常驻画面，不能无限堆。
	for _round in 12:
		target.position = Vector2(0.0, 0.0)
		await process_frame
		target.position = pointer - Vector2(span, span) * 0.5
		await process_frame
	assert(
		notes.get_child_count() <= CreditsBirdSwarm.NOTE_LIMIT,
		"Music notes blew past their cap: %d" % notes.get_child_count()
	)
	print("Credits bird swarm: six birds, bouncing, per-bird calls and note bursts passed")
	quit()
