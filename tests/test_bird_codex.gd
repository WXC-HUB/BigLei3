extends SceneTree
## 鸟类图鉴：标题页的入口开得了、关得上，卡片按总表铺齐，解锁位从 Main 推过来，
## 没解锁的那几只只露剪影。
##
## 跑的是主场景，所以先把存档指到自己那一槽——否则会把玩家的真存档覆盖掉
## （`test_achievements_screen` 的注释里记着这件事真的发生过）。

const Catalog := preload("res://scripts/game/bird_catalog.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("Bird codex test timed out")
		quit(2)
	)
	GameSave.save_path = "user://test_bird_codex_save.json"
	GameSave.clear()
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var start_screen := game.get("_start_screen") as StartScreen
	var codex := game.get("_bird_codex_screen") as BirdCodexScreen
	assert(start_screen != null, "Main menu is missing")
	assert(codex != null, "Bird codex was not instantiated")
	assert(not codex.visible, "Bird codex flashed on the first frame")

	# 每只鸟一张卡，一张不多一张不少。
	var grid := codex.get_node("Card/Layout/ContentPanel/BirdGrid") as GridContainer
	assert(
		grid.get_child_count() == Catalog.ENTRIES.size(),
		"Expected %d bird cards, got %d" % [Catalog.ENTRIES.size(), grid.get_child_count()]
	)
	for data in Catalog.ENTRIES:
		assert(not codex.entry_parts(String(data["id"])).is_empty(), "No card for %s" % data["id"])

	# 新档只有小蓝鸟在枝头，其余七只是剪影。
	assert(codex.is_unlocked(Catalog.BLUE), "The blue bird should start unlocked")
	assert(codex.unlocked_count() == 1, "A fresh save unlocked more than the blue bird")
	var blue: Dictionary = codex.entry_parts(Catalog.BLUE)
	assert((blue["name"] as Label).text == "点点小蓝鸟", "The unlocked bird is still masked")
	assert(
		(blue["portrait"] as TextureRect).self_modulate == Color.WHITE,
		"The unlocked bird is still a silhouette"
	)
	var crow: Dictionary = codex.entry_parts(Catalog.CROW)
	assert((crow["name"] as Label).text == BirdCodexScreen.LOCKED_NAME, "A locked bird leaked its name")
	assert(
		(crow["portrait"] as TextureRect).self_modulate == BirdCodexScreen.SILHOUETTE_TINT,
		"A locked bird is not a silhouette"
	)
	# 锁着的卡把能力换成解锁条件，卡片高度不跳。
	assert(
		(crow["ability"] as Label).text == String(Catalog.entry(Catalog.CROW)["unlock"]),
		"A locked bird did not show how to earn it"
	)
	# 乌鸦那套图朝左画，图鉴里要翻回来和其他鸟一个朝向。
	assert((crow["portrait"] as TextureRect).flip_h, "The crow was not flipped to face the others")

	# 标题页入口。
	start_screen.bird_codex_button.pressed.emit()
	await create_timer(0.35).timeout
	assert(codex.visible, "The title entry did not open the codex")
	assert(game.get("_start_screen") == start_screen, "Opening the codex destroyed the main menu")

	# 待机帧真的在走：红隼只有两帧，所以拿四帧的乌鸦来验。
	var portrait := crow["portrait"] as TextureRect
	var first := portrait.texture
	var deadline := Time.get_ticks_msec() + 4000
	while portrait.texture == first:
		assert(Time.get_ticks_msec() < deadline, "The portraits never cycled their idle frames")
		await create_timer(0.1).timeout

	codex.back_button.pressed.emit()
	await create_timer(0.35).timeout
	assert(not codex.visible, "Back did not close the codex")
	assert(game.get("_start_screen") != null, "Back did not return to the main menu")

	# 解锁位归 Main：送鸟的每条路最后都会调 _apply_bird_unlock_visibility()，
	# 图鉴挂在它上面，所以这一步就是所有解锁路径的公共出口。
	for flag in [
		"_night_heron_unlocked", "_red_bird_unlocked", "_attacker_bird_unlocked",
		"_lucky_bird_unlocked", "_tit_bird_unlocked", "_magpie_bird_unlocked",
		"_crow_bird_unlocked", "_dove_bird_unlocked",
	]:
		game.set(flag, true)
	game.call("_apply_bird_unlock_visibility")
	await process_frame
	assert(
		codex.unlocked_count() == Catalog.ENTRIES.size(),
		"Finishing the tutorial did not fill the codex: %d/%d" % [
			codex.unlocked_count(), Catalog.ENTRIES.size()
		]
	)
	assert((crow["name"] as Label).text == "小嘴乌鸦", "An unlocked bird kept its mask")

	print("Bird codex: title entry, per-bird cards, silhouettes and unlock hand-off passed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSave.save_path))
	quit()
