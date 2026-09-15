extends SceneTree
## 小嘴乌鸦解锁页：文案齐全；每撩一次薅一只、换下一只、副标题跟着改口，
## 薅到熊猫就被追着满屏幕跑、报成就、副标题改成「薅错了」；重开页面全部还原。

const CROW := preload("res://scripts/ui/crow_unlock.gd")
const Catalog := preload("res://scripts/game/achievement_catalog.gd")
## 一次「薅一只 + 换下一只」全程。
const SWAP_CYCLE := CROW.PLUCK_LEAN_TIME + CROW.PLUCK_YANK_TIME + CROW.SWAP_OUT_TIME + CROW.SWAP_IN_TIME + 0.1


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("Crow unlock test timed out")
		quit(2)
	)
	# 成就写在存档里：换到临时存档位，否则本机存档里已点亮的成就会让「太早」断言误报。
	GameSave.save_path = "user://test_crow_unlock_save.json"
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

	var unlock := game.get("_crow_unlock") as CrowUnlock
	assert(unlock != null, "Main did not build the crow unlock page")
	var name_label := unlock.get_node("Finale/Name") as Label
	var tagline := unlock.get_node("Finale/Tagline") as Label
	var effect := unlock.get_node("Finale/Effect") as Label
	var continue_button := unlock.get_node("Finale/Continue") as Button
	var stand := unlock.get_node("AnimalStand") as TextureRect
	var fur_layer := unlock.get_node("FurLayer") as Control
	assert(name_label.text.replace(" ", "") == "小嘴乌鸦", "Crow name line is incorrect")
	assert(effect.text.contains("3 秒"), "Crow effect line does not describe the three-second peek")
	assert((unlock.get_node("BirdCall") as AudioStreamPlayer).stream != null, "Crow hover call is missing")
	assert((unlock.get_node("AnimalYelp") as AudioStreamPlayer).stream != null, "The victim's yelp is missing")
	assert(CROW.VICTIMS.size() == 7, "The victim line-up should run cat → dog → sheep → horse → deer → fox → panda")

	unlock.present()
	await create_timer(3.0).timeout
	assert(unlock.visible and not continue_button.disabled, "Unlock page reveal never finished")
	assert(unlock.plucked_count() == 0 and not unlock.is_chased(), "The page opened with the egg already spent")
	assert(tagline.text.replace(" ", "") == "薅小猫毛", "The page did not open on the cat")
	assert(stand.texture == CROW.VICTIMS[0]["texture"], "The cat is not the one lying there at the start")
	var unlocked: Dictionary = game.get("_unlocked_achievements")
	var bird_home: Vector2 = unlock.get("_bird_home")
	var stand_home: Vector2 = unlock.get("_stand_home")

	# 撩一次薅一只：飞出一撮毛，换下一只躺过来，副标题改口。
	unlock.bird.mouse_entered.emit()
	await create_timer(CROW.PLUCK_LEAN_TIME + CROW.PLUCK_YANK_TIME * 0.5).timeout
	assert(unlock.plucked_count() == 1, "First hover did not pluck")
	assert(fur_layer.get_child_count() >= 1, "No tuft of fur came loose")
	await create_timer(SWAP_CYCLE).timeout
	assert(stand.texture == CROW.VICTIMS[1]["texture"], "The dog did not take the cat's place")
	assert(tagline.text.replace(" ", "") == "薅小狗毛", "The tagline did not follow the line-up")

	# 一路薅到熊猫躺上来为止：还没被追，也还没报成就。
	for _pluck in range(CROW.VICTIMS.size() - 2):
		unlock.bird.mouse_entered.emit()
		await create_timer(SWAP_CYCLE).timeout
	assert(unlock.plucked_count() == CROW.VICTIMS.size() - 1, "Plucks were dropped along the way")
	assert(tagline.text.replace(" ", "") == "薅熊猫毛", "The line-up did not end on the panda")
	assert(stand.texture == CROW.VICTIMS[6]["texture"], "The panda is not the one lying there last")
	assert(not unlock.is_chased() and not unlocked.has(Catalog.CROW_CHASED_BY_PANDA), "The chase started one victim too early")

	# 薅熊猫：报成就，熊猫翻脸，两边绕着屏幕跑起来。
	unlock.bird.mouse_entered.emit()
	await create_timer(CROW.PLUCK_LEAN_TIME + CROW.PLUCK_YANK_TIME + 0.08).timeout
	assert(unlocked.has(Catalog.CROW_CHASED_BY_PANDA), "Plucking the panda did not award its achievement")
	assert(stand.texture != CROW.VICTIMS[6]["texture"], "The panda did not switch to its angry face")
	await create_timer(CROW.CHASE_FREEZE_TIME + CROW.CHASE_LAP_TIME * 0.6).timeout
	assert(unlock.bird.position.distance_to(bird_home) > 200.0, "The crow is not running for it")
	assert(stand.position.distance_to(stand_home) > 200.0, "The panda is not giving chase")

	# 跑完：乌鸦回原位，熊猫在旁边坐下，副标题认栽。
	await create_timer(CROW.chase_duration()).timeout
	assert(unlock.is_chased(), "The chase never finished")
	assert(unlock.bird.position.is_equal_approx(bird_home), "The crow did not slink back to its spot")
	assert(stand.position.is_equal_approx(stand_home), "The panda did not settle back down")
	assert(is_equal_approx(unlock.bird.rotation, 0.0) and not unlock.bird.flip_h, "The crow kept its running pose")
	assert(tagline.text.replace(" ", "") == CROW.CHASED_TAGLINE_TEXT.replace(" ", ""), "The tagline did not own up at the end")

	# 收场之后再撩：不再薅了，只是熊猫扑一下。
	var count_before := unlock.plucked_count()
	unlock.bird.mouse_entered.emit()
	await create_timer(0.06).timeout
	assert(unlock.plucked_count() == count_before, "Hovering after the chase kept plucking")
	await create_timer(0.5).timeout

	# 重开页面：一切还原。
	continue_button.pressed.emit()
	await create_timer(0.4).timeout
	unlock.present()
	await create_timer(0.2).timeout
	assert(unlock.plucked_count() == 0 and not unlock.is_chased(), "Reopening the page kept the egg state")
	assert(stand.texture == CROW.VICTIMS[0]["texture"], "Reopening the page did not put the cat back")
	assert(stand.position.is_equal_approx(stand_home), "Reopening the page left the victim off its mark")
	assert(tagline.text.replace(" ", "") == "薅小猫毛", "Reopening the page kept the last tagline")
	assert(fur_layer.get_child_count() == 0, "Reopening the page kept loose fur lying around")
	GameSave.clear()
	print("Crow unlock: texts, the whole line-up, the panda chase, achievement and reset passed")
	quit()
