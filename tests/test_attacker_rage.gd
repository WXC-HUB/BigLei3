extends SceneTree
## 啄木鸟解锁页：拟声词堆到上限后，鸟放大啄碎屏幕飞走，并且把页面状态收干净。

const RAGE := preload("res://scripts/ui/attacker_unlock.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(await _test_rage_breaks_the_screen())
	print("Attacker rage: peck buildup, screen break and cleanup passed")
	await process_frame
	quit()


func _test_rage_breaks_the_screen() -> bool:
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	# 跳过标题之后的耳机提示与序章：它们和这段演出无关，只会拖长等待。
	var title := game.get("_start_screen") as Control
	if title != null:
		game.set("_start_screen", null)
		title.get_parent().queue_free()
	game.call("_start_game")
	await create_timer(0.5).timeout
	var unlock := game.get("_attacker_unlock") as AttackerUnlock
	assert(unlock != null)
	unlock.present()
	await create_timer(3.0).timeout
	assert(unlock.visible, "Unlock page never appeared")

	var base_text: String = unlock.tagline_label.text
	# 前几下只是堆拟声词，页面不能提前进入暴走。
	for peck in range(RAGE.RAGE_PECKS - 1):
		unlock.bird.mouse_entered.emit()
		await create_timer(0.06).timeout
	assert(unlock.tagline_label.text.length() > base_text.length(), "Pecks did not stack up")
	assert(not bool(unlock.get("_raging")), "The bird raged too early")
	assert(unlock.visible, "The page closed before the last peck")

	unlock.bird.mouse_entered.emit()
	assert(bool(unlock.get("_raging")), "The last peck did not trigger the break")
	# 破屏那一拍：画面被换成碎片，本体的底板和文字同时熄掉。
	var deadline := Time.get_ticks_msec() + 6000
	var shard_layer: Node = null
	while shard_layer == null:
		assert(Time.get_ticks_msec() < deadline, "The screen never shattered")
		await create_timer(0.05).timeout
		shard_layer = unlock.get("_shard_layer")
	var shards := 0
	for child in shard_layer.get_children():
		if child is Polygon2D:
			shards += 1
	assert(shards >= 8, "Expected the screen to break into pieces, got %d" % shards)
	assert(not unlock.dimmer.visible, "The intact page is still showing behind the shards")

	# 演出跑完：页面自己收尾，时间缩放、碎片和计数都得还原。
	deadline = Time.get_ticks_msec() + 8000
	while unlock.visible:
		assert(Time.get_ticks_msec() < deadline, "The break never finished the page")
		await create_timer(0.05).timeout
	assert(is_equal_approx(Engine.time_scale, 1.0), "Hitstop left the clock scaled")
	assert(unlock.get("_shard_layer") == null, "Shards were not cleaned up")
	assert(int(unlock.get("_peck_count")) == 0, "Peck counter was not reset")
	assert(not bool(unlock.get("_raging")), "Rage state stuck on")
	assert(unlock.dimmer.visible, "The page was not restored for its next use")
	assert(is_equal_approx(unlock.bird.modulate.a, 1.0), "The bird did not come back")
	game.queue_free()
	await process_frame
	return true
