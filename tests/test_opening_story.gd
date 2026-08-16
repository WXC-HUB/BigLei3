extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("Opening story test timed out")
		quit(2)
	)
	var story := (load("res://scenes/ui/opening_story.tscn") as PackedScene).instantiate()
	root.add_child(story)
	await process_frame
	story.set("playback_speed", 6.0)

	var main_text := story.get_node("Stage/Composition/TextColumn/MainText") as Label
	var sub_text := story.get_node("Stage/Composition/TextColumn/SubText") as Label
	var composition := story.get_node("Stage/Composition") as HBoxContainer
	var coaster := story.get_node("MainTextCoaster") as TextCoaster
	assert(coaster != null, "Opening story did not build the shared title coaster")
	assert(coaster.digits_enabled, "Opening story main text is not spouting the title digits")
	var bird_call := story.get_node("BirdCall") as AudioStreamPlayer
	assert(bird_call.stream != null, "Opening story has no blue bird call wired up")

	# Sample the run while it plays: the line has to type out one glyph at a time
	# rather than appearing whole, and the bird has to call once per beat. Each
	# call retunes the pitch first, so one distinct pitch means one call.
	var partial_reveal_seen := false
	var coaster_motion_seen := false
	var partial_sub_reveal_seen := false
	var call_pitches: Array[float] = []
	var image_sides: Array[int] = []

	story.call("present")
	while story.get("_presenting"):
		var shown := 0
		for glyph in coaster.get_node("Glyphs").get_children():
			var label := glyph as Label
			if not label.visible:
				continue
			shown += 1
			if absf(label.rotation) > 0.001:
				coaster_motion_seen = true
		var total := coaster.glyph_count()
		if total > 0 and shown > 0 and shown < total:
			partial_reveal_seen = true
		if sub_text.visible_ratio > 0.0 and sub_text.visible_ratio < 1.0:
			partial_sub_reveal_seen = true
		if not call_pitches.has(bird_call.pitch_scale):
			call_pitches.append(bird_call.pitch_scale)
		var beat: int = (story.get("_segment_history") as Array).size()
		while image_sides.size() < beat:
			image_sides.append(composition.get_children().find(story.get_node("Stage/Composition/Illustration")))
		await process_frame
	await process_frame

	assert(not story.visible, "Opening story remained visible after playback")
	assert(int(story.get("_presentation_count")) == 1, "Opening story did not play exactly once")
	assert(story.get("_segment_history") == [0, 1, 2, 3], "Opening story did not play all four story images in order")
	assert(partial_reveal_seen, "Opening story main text appeared all at once instead of typing out")
	assert(partial_sub_reveal_seen, "Opening story sub text appeared all at once instead of typing out")
	assert(image_sides == [0, 1, 0, 1], "The illustration did not alternate left-right across the four beats (got %s)" % [image_sides])
	assert(coaster_motion_seen, "Opening story main text never rode the title coaster")
	assert(call_pitches.size() == 4, "The blue bird did not call once per story beat (got %d calls)" % call_pitches.size())

	var illustration := story.get_node("Stage/Composition/Illustration") as TextureRect
	assert(illustration.texture.resource_path.ends_with("st_4.png"), "The last story beat did not reach the fourth image")
	assert(main_text.text == "揪揪揪揪揪揪揪揪揪揪揪揪揪揪", "The last story beat did not reach its main text")
	assert(sub_text.text == "叫声大意：我们上吧！", "The last story beat did not reach its sub text")
	assert(is_equal_approx(sub_text.visible_ratio, 1.0), "The sub text never finished typing")

	# The whole point of the coaster is that the line is drawn as one Label per
	# character; a single Label would mean the shared title motion is bypassed.
	assert(coaster.glyph_count() == main_text.text.length(), "Main text was not split into per-character glyphs")

	# The call is a wall of one repeated character, so it is the widest thing on
	# the page: if the column ever gets narrower than the line, the coaster
	# centres the overflow straight onto the illustration.
	var text_column := story.get_node("Stage/Composition/TextColumn") as Control
	var line_width := main_text.get_theme_font("font").get_string_size(
		main_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, main_text.get_theme_font_size("font_size")
	).x
	assert(
		line_width <= text_column.size.x,
		"The main text (%.0fpx) is wider than its column (%.0fpx)" % [line_width, text_column.size.x]
	)

	# No dialogue cards left anywhere: a beat is one image plus one line, nothing else.
	assert(not story.has_node("Stage/SegmentImageLeft"), "The retired dialogue segments are still in the scene")
	for child in composition.get_children():
		assert(
			child.name in ["Illustration", "TextColumn"],
			"Unexpected node %s left on the story stage" % child.name
		)
	await _run_long_press_skip()
	print("Opening story: typed coaster main text, bird calls, four beats and long-press skip passed")
	quit()


## 第二遍只验长按跳过：按住一会儿看水印和小鸟有没有跟着长出来，松手看它们退回
## 去，再按满一次看整段有没有真的提前收场。
func _run_long_press_skip() -> void:
	var story := (load("res://scenes/ui/opening_story.tscn") as PackedScene).instantiate()
	root.add_child(story)
	await process_frame
	var skip := story.get_node("LongPressSkip") as LongPressSkip
	assert(skip != null, "Opening story has no long-press skip layer")
	var hint := skip.get_node("Hint") as Control
	var wipe := skip.get_node("Hint/Wipe") as Control
	var black := skip.get_node("Birds/Black") as Control
	var hidden_x := black.position.x

	story.call("present")
	await create_timer(0.6).timeout
	assert(story.get("_presenting"), "Opening story ended before the skip test could hold")
	assert(is_zero_approx(hint.modulate.a), "The skip watermark showed up without a hold")

	_press(true)
	await create_timer(0.45).timeout
	assert(skip.hold_progress() > 0.1, "Holding did not advance the long-press")
	assert(hint.modulate.a > 0.5, "The skip watermark did not fade in while holding")
	assert(wipe.size.x > 0.0 and wipe.size.x < hint.size.x, "The watermark wipe did not track the hold")
	assert(black.position.x > hidden_x, "The other birds did not peek out while holding")
	assert(story.get("_presenting"), "The story skipped before the hold was complete")

	# 松手：一切退回原位，剧情继续。
	_press(false)
	await create_timer(0.6).timeout
	assert(is_zero_approx(skip.hold_progress()), "Releasing did not rewind the long-press")
	assert(is_equal_approx(black.position.x, hidden_x), "The birds did not duck back after releasing")
	assert(story.get("_presenting"), "Releasing the hold ended the story anyway")

	# 按满：剧情提前收场，且没有播完四幕。
	_press(true)
	var deadline := Time.get_ticks_msec() + 5000
	while story.get("_presenting"):
		assert(Time.get_ticks_msec() < deadline, "Holding never skipped the opening story")
		await process_frame
	_press(false)
	assert(not story.visible, "The skipped story stayed on screen")
	assert(
		(story.get("_segment_history") as Array).size() < 4,
		"The long press did not cut the story short"
	)
	story.queue_free()


func _press(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event)
