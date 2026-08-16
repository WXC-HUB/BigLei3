extends SceneTree
## 夜鹭解锁页：被摸太多次后跳到右下角出画、顶着怒气符号，主文案砸成倾斜的红字，
## 并且这套状态在页面重开时能全部还原。

const HERON := preload("res://scripts/ui/night_heron_unlock.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(await _test_rage())
	print("Heron rage: hover buildup, corner leap, anger mark and reset passed")
	await process_frame
	quit()


func _test_rage() -> bool:
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	# 跳过标题之后的耳机提示与序章：它们和这段演出无关，只会拖长等待。
	var title := game.get("_start_screen") as Control
	if title != null:
		game.set("_start_screen", null)
		title.get_parent().queue_free()
	game.call("_start_game")
	await create_timer(0.4).timeout
	var unlock := game.get("_night_heron_unlock") as NightHeronUnlock
	assert(unlock != null)
	unlock.present()
	await create_timer(3.0).timeout
	assert(unlock.visible, "Unlock page never appeared")

	var home_text: String = unlock.name_label.text
	var home_position: Vector2 = unlock.final_bird.position
	for hover in range(HERON.RAGE_HOVERS - 1):
		unlock.final_bird.mouse_entered.emit()
		await create_timer(0.03).timeout
	assert(not bool(unlock.get("_raging")), "The heron snapped too early")
	assert(unlock.name_label.text == home_text, "The name changed before the rage")

	unlock.final_bird.mouse_entered.emit()
	assert(bool(unlock.get("_raging")), "The last hover did not trigger the rage")

	var deadline := Time.get_ticks_msec() + 8000
	while unlock.name_label.text == home_text:
		assert(Time.get_ticks_msec() < deadline, "The name never turned")
		await create_timer(0.05).timeout
	await create_timer(0.6).timeout

	assert(unlock.name_label.text == HERON.RAGE_NAME_TEXT, "Wrong rage text")
	assert(
		unlock.name_label.get_theme_color("font_color").is_equal_approx(HERON.RAGE_NAME_COLOR),
		"The rage text is not red"
	)
	assert(not is_zero_approx(unlock.name_label.rotation), "The rage text is not tilted")

	# 跳到右下角，并且确实出了画：右边和下边都要越过页面边界。
	var bird := unlock.final_bird
	assert(bird.position.x > home_position.x, "The heron did not move right")
	assert(bird.position.x + bird.size.x > unlock.size.x, "The heron stayed inside the right edge")
	assert(bird.position.y + bird.size.y > unlock.size.y, "The heron stayed inside the bottom edge")

	var anger := unlock.get("_anger_mark") as Node2D
	assert(anger != null and is_instance_valid(anger), "No anger mark appeared")
	assert(anger.position.y < bird.position.y + bird.size.y, "The anger mark is not over the bird")
	assert(is_equal_approx(Engine.time_scale, 1.0), "Hitstop left the clock scaled")

	# 重开这一页：翻脸留下的东西必须全部清干净。
	unlock.present()
	await create_timer(0.2).timeout
	assert(unlock.name_label.text == home_text, "The name was not restored")
	assert(is_zero_approx(unlock.name_label.rotation), "The tilt was not restored")
	assert(unlock.get("_anger_mark") == null, "The anger mark survived a re-present")
	assert(int(unlock.get("_hover_count")) == 0, "Hover counter was not reset")
	assert(not bool(unlock.get("_raging")), "Rage state stuck on")
	game.queue_free()
	await process_frame
	return true
