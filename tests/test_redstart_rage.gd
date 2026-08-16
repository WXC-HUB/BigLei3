extends SceneTree
## 红尾水鸲解锁页：撩太多次后小鸟消失、水渠从下方立起、全程震屏，
## 并且这套状态在页面重开时能全部还原。

const REDSTART := preload("res://scripts/ui/redstart_unlock.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(await _test_rage())
	print("Redstart rage: hover buildup, bird vanish, aqueduct rise and reset passed")
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
	var unlock := game.get("_redstart_unlock") as RedstartUnlock
	assert(unlock != null)
	unlock.present()
	await create_timer(3.0).timeout
	assert(unlock.visible, "Unlock page never appeared")

	var home_title: String = unlock.name_label.text
	var aqueduct_title: String = unlock.tagline_label.text
	for hover in range(REDSTART.RAGE_HOVERS - 1):
		unlock.final_bird.mouse_entered.emit()
		await create_timer(0.03).timeout
	assert(not bool(unlock.get("_raging")), "The aqueduct came up too early")
	assert(unlock.final_bird.visible, "The bird vanished before the rage")

	unlock.final_bird.mouse_entered.emit()
	assert(bool(unlock.get("_raging")), "The last hover did not trigger the rage")

	var deadline := Time.get_ticks_msec() + 8000
	var aqueduct: TextureRect = null
	while aqueduct == null:
		assert(Time.get_ticks_msec() < deadline, "The aqueduct never appeared")
		await create_timer(0.05).timeout
		aqueduct = unlock.get("_aqueduct") as TextureRect
	assert(not unlock.final_bird.visible, "The bird should be gone once the aqueduct shows")
	assert(aqueduct.position.y > unlock.size.y * 0.4, "The aqueduct did not start below the screen")
	# 图片要沉在所有文字下面。
	for sibling in unlock.finale.get_children():
		if sibling is Label or sibling is Button:
			assert(
				aqueduct.get_index() < sibling.get_index(),
				"The aqueduct is drawing over %s" % sibling.name
			)
	# 主标题锁死成「宏伟水渠」，副标题收起。
	assert(unlock.name_label.text == aqueduct_title, "The title did not lock to the aqueduct")
	assert(not unlock.tagline_label.visible, "The subtitle should be hidden once the title locks")

	# 立起过程中：一路往上走，同时整页在抖。
	var shaken := false
	var highest := aqueduct.position.y
	for sample in range(24):
		await create_timer(0.09).timeout
		if not is_instance_valid(aqueduct):
			break
		assert(aqueduct.position.y <= highest + 30.0, "The aqueduct went back down")
		highest = minf(highest, aqueduct.position.y)
		if unlock.position != Vector2.ZERO:
			shaken = true
	assert(shaken, "The page never shook while the aqueduct rose")

	# 之后再怎么撩，标题都不再互换。
	unlock.final_bird.mouse_entered.emit()
	unlock.final_bird.mouse_entered.emit()
	assert(unlock.name_label.text == aqueduct_title, "The locked title changed again")

	deadline = Time.get_ticks_msec() + 8000
	while absf(aqueduct.position.y) > 1.0:
		assert(Time.get_ticks_msec() < deadline, "The aqueduct never locked into place")
		await create_timer(0.05).timeout
	await create_timer(0.4).timeout
	assert(unlock.position == Vector2.ZERO, "The page did not settle back after the shake")
	assert(is_equal_approx(Engine.time_scale, 1.0), "Hitstop left the clock scaled")
	assert(is_zero_approx(unlock.dimmer.offset_left), "The backdrop overscan was not undone")

	# 重开这一页：水渠留下的东西必须全部清干净。
	unlock.present()
	await create_timer(0.3).timeout
	assert(unlock.get("_aqueduct") == null, "The aqueduct survived a re-present")
	assert(unlock.final_bird.visible, "The bird did not come back")
	assert(unlock.name_label.text == home_title, "The title was not restored")
	assert(unlock.tagline_label.visible, "The subtitle did not come back")
	assert(int(unlock.get("_hover_count")) == 0, "Hover counter was not reset")
	assert(not bool(unlock.get("_raging")), "Rage state stuck on")
	game.queue_free()
	await process_frame
	return true
