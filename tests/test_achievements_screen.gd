extends SceneTree

const Catalog := preload("res://scripts/game/achievement_catalog.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# 这条测试跑的是主场景，还会调两次 _start_game()：不隔离存档路径就会把玩家的真存档
	# 覆盖成一局新的（2026-09-12 真的发生过）。自带超时，免得卡住整个 runner。
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("Achievements screen test timed out")
		quit(2)
	)
	GameSave.save_path = "user://test_achievements_screen_save.json"
	GameSave.clear()
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var start_screen := game.get("_start_screen") as StartScreen
	var achievements := game.get("_achievements_screen") as AchievementsScreen
	assert(start_screen != null, "Main menu is missing")
	assert(achievements != null, "Achievements prefab was not instantiated")
	assert(achievements.scene_file_path == "res://scenes/ui/achievements_screen.tscn")
	assert(not achievements.visible, "Achievements flashed on the first frame")
	# 列表按总表铺开：模板本身也在列表里，所以是总表条数 + 1。
	assert(
		achievements.achievement_list.get_child_count() == Catalog.ENTRIES.size() + 1,
		"Achievement entries are missing"
	)
	assert(not achievements.entry_template.visible, "The row template leaked into the list")
	for data in Catalog.ENTRIES:
		var status := achievements.status_label(data["id"])
		assert(status != null, "No row for %s" % data["id"])
		assert(status.text == "未获得", "%s started unlocked" % data["id"])

	# 标题页的横幅只是个显示器，账记在 main 里；开局是零解锁。
	var banner_count := start_screen.get_node("%Count") as Label
	assert(
		banner_count.text == "成就解锁 0/%d" % Catalog.ENTRIES.size(),
		"Achievement banner did not start empty: %s" % banner_count.text
	)

	(start_screen.get_node("%AchievementsButton") as Button).pressed.emit()
	await create_timer(0.35).timeout
	assert(achievements.visible, "Achievements entry did not open the page")
	assert(game.get("_start_screen") == start_screen, "Opening achievements destroyed the main menu")

	achievements.back_button.pressed.emit()
	await create_timer(0.3).timeout
	assert(not achievements.visible, "Back did not close achievements")
	assert(game.get("_start_screen") != null, "Back did not return to the main menu")
	# 翻开成就页本身就是一个成就，横幅要当场跟上。
	assert(
		banner_count.text == "成就解锁 1/%d" % Catalog.ENTRIES.size(),
		"Achievement banner did not follow the unlock: %s" % banner_count.text
	)

	game.call("_start_game")
	await create_timer(0.5).timeout
	var toast := game.get("_achievement_toast") as AchievementToast
	assert(bool(game.get("_unlocked_achievements").has("start_game")), "Starting did not unlock the achievement")
	assert(
		achievements.status_label(Catalog.START_GAME).text == "已获得",
		"Achievement page did not refresh"
	)
	assert(toast.toast_card.visible, "Achievement toast did not appear")
	# 提示条是排队播的：翻开成就页那条还在台上，等轮到开局这条。
	var deadline := Time.get_ticks_msec() + 8000
	while toast.achievement_name.text != "开始一局游戏":
		assert(Time.get_ticks_msec() < deadline, "The start-game toast never got its turn")
		await create_timer(0.1).timeout

	game.call("_start_game")
	await process_frame
	assert(toast._queue.is_empty(), "The same achievement was queued twice")

	print("Achievements: page entry, first unlock and global toast passed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSave.save_path))
	quit()
