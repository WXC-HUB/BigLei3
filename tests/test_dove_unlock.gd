extends SceneTree
## 斑鸠解锁页：文案齐全；每撩一次叼来一根枝丢到窝位上，堆够了红隼俯冲进来把它叼走、
## 报成就、副标题改成「好吃」；重开页面枝和鸟全部还原。

const DOVE := preload("res://scripts/ui/dove_unlock.gd")
const Catalog := preload("res://scripts/game/achievement_catalog.gd")
## 一次「叼过去—丢下—回原位」全程，留一点余量。
const TWIG_CYCLE := DOVE.TWIG_LEAN_TIME + DOVE.TWIG_DROP_TIME + DOVE.TWIG_RETURN_TIME + 0.14


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("Dove unlock test timed out")
		quit(2)
	)
	# 成就写在存档里：换到临时存档位，否则本机存档里已点亮的成就会让「太早」断言误报。
	GameSave.save_path = "user://test_dove_unlock_save.json"
	GameSave.clear()
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var title := game.get("_start_screen") as Control
	if title != null:
		game.set("_start_screen", null)
		title.get_parent().queue_free()
	game.call("_start_game")
	await create_timer(0.4).timeout

	var unlock := game.get("_dove_unlock") as DoveUnlock
	assert(unlock != null, "Main did not build the dove unlock page")
	var name_label := unlock.get_node("Finale/Name") as Label
	var tagline := unlock.get_node("Finale/Tagline") as Label
	var effect := unlock.get_node("Finale/Effect") as Label
	var continue_button := unlock.get_node("Finale/Continue") as Button
	var nest_layer := unlock.get_node("NestLayer") as Control
	assert(name_label.text.replace(" ", "") == "斑鸠", "Dove name line is incorrect")
	assert(effect.text.contains("爱心"), "Dove effect line does not describe the heal")
	assert((unlock.get_node("BirdCall") as AudioStreamPlayer).stream != null, "Dove hover coo is missing")
	assert((unlock.get_node("KestrelCry") as AudioStreamPlayer).stream != null, "The kestrel's cry is missing")

	unlock.present()
	await create_timer(3.0).timeout
	assert(unlock.visible and not continue_button.disabled, "Unlock page reveal never finished")
	assert(unlock.twig_count() == 0 and not unlock.is_snatched(), "The page opened with the egg already spent")
	assert(nest_layer.get_child_count() == 0, "The page opened with twigs already lying around")
	var unlocked: Dictionary = game.get("_unlocked_achievements")
	var bird_home: Vector2 = unlock.get("_bird_home")
	var home_tagline := tagline.text

	# 撩一次叼一根：鸟凑向窝位，一根枝落在上面。
	unlock.bird.mouse_entered.emit()
	await create_timer(DOVE.TWIG_LEAN_TIME + DOVE.TWIG_DROP_TIME * 0.5).timeout
	assert(unlock.twig_count() == 1, "First hover did not fetch a twig")
	assert(nest_layer.get_child_count() == 1, "No twig landed on the nest spot")
	assert(not unlock.bird.position.is_equal_approx(bird_home), "The dove did not lean over to drop it")
	await create_timer(TWIG_CYCLE).timeout
	assert(unlock.bird.position.is_equal_approx(bird_home), "The dove did not saunter back")

	# 撩到差最后一根：枝越堆越多，红隼还没来，成就也还没报。
	for _twig in range(DOVE.TWIGS_TO_NEST - 2):
		unlock.bird.mouse_entered.emit()
		await create_timer(TWIG_CYCLE).timeout
	assert(unlock.twig_count() == DOVE.TWIGS_TO_NEST - 1, "Twigs were dropped along the way")
	assert(nest_layer.get_child_count() == DOVE.TWIGS_TO_NEST - 1, "The nest is missing twigs")
	assert(not unlock.is_snatched() and not unlocked.has(Catalog.DOVE_SNATCHED), "The kestrel came one twig too early")
	assert(tagline.text == home_tagline, "The tagline changed before the snatch")

	# 最后一根：红隼俯冲进来，报成就，副标题当场改成「好吃」。
	unlock.bird.mouse_entered.emit()
	await create_timer(DOVE.TWIG_LEAN_TIME + DOVE.TWIG_DROP_TIME + DOVE.SNATCH_DIVE_TIME + 0.08).timeout
	assert(unlocked.has(Catalog.DOVE_SNATCHED), "The snatch did not award its achievement")
	assert(nest_layer.get_node_or_null("Kestrel") != null, "The kestrel never showed up")
	assert(tagline.text.replace(" ", "") == DOVE.SNATCHED_TAGLINE_TEXT.replace(" ", ""), "The tagline did not turn into 好吃")

	# 带出画面：鸟跟着走，最后收起来。
	await create_timer(DOVE.SNATCH_HOLD + DOVE.SNATCH_EXIT_TIME + 0.1).timeout
	assert(unlock.is_snatched(), "The snatch never finished")
	assert(unlock.bird.position.distance_to(bird_home) > 400.0, "The dove was not carried off")
	assert(not unlock.bird.visible, "The dove is still on screen after being carried off")

	# 收场之后再撩：没鸟了，也不再叼枝。
	var count_before := unlock.twig_count()
	unlock.bird.mouse_entered.emit()
	await create_timer(TWIG_CYCLE).timeout
	assert(unlock.twig_count() == count_before, "Hovering after the snatch kept fetching twigs")

	# 重开页面：一切还原。
	continue_button.pressed.emit()
	await create_timer(0.4).timeout
	unlock.present()
	# 入场动画会把立绘先推开再送回来，所以要等它播完才好比位置。
	await create_timer(3.0).timeout
	assert(unlock.twig_count() == 0 and not unlock.is_snatched(), "Reopening the page kept the egg state")
	assert(nest_layer.get_child_count() == 0, "Reopening the page kept the pile of twigs")
	assert(unlock.bird.visible and unlock.bird.position.is_equal_approx(bird_home), "Reopening the page left the dove off its mark")
	assert(is_equal_approx(unlock.bird.rotation, 0.0), "Reopening the page kept the carried-off pose")
	assert(tagline.text == home_tagline, "Reopening the page kept the 好吃 tagline")
	GameSave.clear()
	print("Dove unlock: texts, the twig pile, the kestrel snatch, achievement and reset passed")
	quit()
