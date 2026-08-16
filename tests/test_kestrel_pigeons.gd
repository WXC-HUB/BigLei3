extends SceneTree
## 红隼解锁页：撩过头之后掠过效果下线，改成天上随机掉鸽子；重开页面回到掠过模式。

const KESTREL := preload("res://scripts/ui/kestrel_unlock.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(await _test_pigeon_mode())
	print("Kestrel pigeons: flyover buildup, pigeon rain swap and reset passed")
	await process_frame
	quit()


func _test_pigeon_mode() -> bool:
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
	var unlock := game.get("_kestrel_unlock") as KestrelUnlock
	assert(unlock != null)
	unlock.present()
	await create_timer(3.0).timeout
	assert(unlock.visible, "Unlock page never appeared")

	# 阈值之前：掠过照旧，天上不掉东西。
	unlock.bird.mouse_entered.emit()
	await create_timer(0.1).timeout
	assert(_count_flyers(unlock) > 0, "The flyover stopped working before the threshold")
	assert(_count_pigeons(unlock) == 0, "Pigeons dropped before the threshold")

	for hover in range(KESTREL.RAGE_HOVERS - 2):
		unlock.bird.mouse_entered.emit()
		await create_timer(0.03).timeout
	# 等在飞的掠过全部落幕，后面才能干净地判断"不再掠过"。
	await create_timer(1.4).timeout
	assert(_count_flyers(unlock) == 0, "Old flyovers never cleaned up")

	unlock.bird.mouse_entered.emit()
	await create_timer(0.1).timeout
	assert(_count_flyers(unlock) == 0, "The flyover still fired past the threshold")
	assert(_count_pigeons(unlock) == 1, "The threshold hover did not drop a pigeon")

	# 继续撩就继续掉，而且是真的在往下落。
	var pigeon := _first_pigeon(unlock)
	var start_y := pigeon.position.y
	unlock.bird.mouse_entered.emit()
	await create_timer(0.3).timeout
	assert(_count_pigeons(unlock) >= 2, "Later hovers stopped dropping pigeons")
	assert(pigeon.position.y > start_y, "The pigeon is not falling")
	assert(
		KESTREL.PIGEON_TEXTURES.has(pigeon.texture),
		"The falling object is not one of the pigeon assets"
	)

	# 吃撑：掉够 30 只之后主文案变打嗝、立绘横着撑开。
	var home_title: String = unlock.name_label.text
	assert(home_title != KESTREL.GLUTTON_NAME_TEXT, "Already full before eating")
	while int(unlock.get("_pigeon_count")) <= KESTREL.GLUTTON_PIGEONS:
		unlock.bird.mouse_entered.emit()
		await create_timer(0.02).timeout
	await create_timer(0.5).timeout
	assert(unlock.name_label.text == KESTREL.GLUTTON_NAME_TEXT, "The title did not turn into a burp")
	assert(unlock.bird.scale.x > 1.3, "The portrait did not get fat")
	# 悬停动效是按基准缩放算的，进出一次不能把肚子收回去。
	unlock.bird.mouse_exited.emit()
	await create_timer(0.3).timeout
	assert(unlock.bird.scale.x > 1.3, "Un-hovering deflated the fat portrait")

	# 吃撑之后滑过只冒一次气泡：不再掉鸽子，气泡也不会重播或消失。
	var fed_tally: int = unlock.get("_pigeon_count")
	unlock.bird.mouse_entered.emit()
	await create_timer(0.4).timeout
	var bubble := unlock.get("_full_bubble") as Control
	assert(bubble != null and is_instance_valid(bubble), "No 饱了 bubble appeared")
	assert(int(unlock.get("_pigeon_count")) == fed_tally, "A full kestrel still dropped pigeons")
	unlock.bird.mouse_entered.emit()
	unlock.bird.mouse_entered.emit()
	await create_timer(0.5).timeout
	assert(unlock.get("_full_bubble") == bubble, "The bubble was rebuilt on a later hover")
	assert(int(unlock.get("_pigeon_count")) == fed_tally, "Later hovers still dropped pigeons")
	await create_timer(1.0).timeout
	assert(is_instance_valid(bubble) and bubble.visible, "The bubble should stay put for good")

	# 掉完自己消失。
	var deadline := Time.get_ticks_msec() + 6000
	while _count_pigeons(unlock) > 0:
		assert(Time.get_ticks_msec() < deadline, "Pigeons never cleaned themselves up")
		await create_timer(0.1).timeout

	# 重开这一页：回到掠过模式。
	unlock.bird.mouse_entered.emit()
	unlock.present()
	await create_timer(0.2).timeout
	assert(int(unlock.get("_flyover_count")) == 0, "The hover counter was not reset")
	assert(int(unlock.get("_pigeon_count")) == 0, "The pigeon tally was not reset")
	assert(unlock.name_label.text == home_title, "The burp title survived a re-present")
	# 重开时揭示动画本来就在缩放这只鸟，所以只判"不再是胖的"。
	assert(unlock.bird.scale.x < 1.2, "The fat portrait survived a re-present")
	assert(_count_pigeons(unlock) == 0, "Leftover pigeons survived a re-present")
	assert(unlock.get("_full_bubble") == null, "The bubble survived a re-present")
	unlock.bird.mouse_entered.emit()
	await create_timer(0.1).timeout
	assert(_count_flyers(unlock) > 0, "The flyover did not come back after a re-present")
	game.queue_free()
	await process_frame
	return true


func _count_pigeons(unlock: KestrelUnlock) -> int:
	var total := 0
	for child in unlock.flight_layer.get_children():
		if child is TextureRect and KESTREL.PIGEON_TEXTURES.has(child.texture):
			total += 1
	return total


func _first_pigeon(unlock: KestrelUnlock) -> TextureRect:
	for child in unlock.flight_layer.get_children():
		if child is TextureRect and KESTREL.PIGEON_TEXTURES.has(child.texture):
			return child
	return null


func _count_flyers(unlock: KestrelUnlock) -> int:
	var total := 0
	for child in unlock.flight_layer.get_children():
		if child is TextureRect and child.texture == KESTREL.FLY_TEXTURE:
			total += 1
	return total
