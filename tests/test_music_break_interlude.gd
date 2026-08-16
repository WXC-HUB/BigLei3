extends SceneTree
## 非教程第五关开场前插播的「换首音乐」环节：先弹和耳机提示同款的四行字，再把制
## 作人名单拉起来放歌，右边挂一个【继续玩】，按了才回到棋盘。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("Music break interlude test timed out")
		quit(2)
	)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame

	var notice := game.get("_music_break_notice") as HeadphoneNotice
	var credits := game.get("_credits_screen") as CreditsScreen
	assert(notice != null, "Main did not build the music break notice")
	assert(notice.scene_file_path == "res://scenes/ui/music_break_notice.tscn", "The music break notice is not its own prefab")
	assert(notice.get_script() == load("res://scripts/ui/headphone_notice.gd"), "The music break notice is not the headphone notice prefab reskinned")
	var lines: Array[String] = []
	for child in notice.get_node("Lines").get_children():
		lines.append((child as Label).text)
	assert(lines == ["我们注意到", "玩到这里", "应该换首音乐", "请 您 欣 赏"], "The music break notice says the wrong thing: %s" % [lines])

	var continue_root := credits.get_node("Continue") as Control
	var continue_button := credits.get_node("Continue/ContinueButton") as Button
	assert(not continue_root.visible, "The continue button showed up outside the music break")

	# 第四关（最后一关教程）之后开第五关：这一关的编号是 TUTORIAL_LEVEL_COUNT + 5。
	var break_level: int = game.get("MUSIC_BREAK_LEVEL")
	game.set("_run_number", break_level - 1)
	game.call("_start_game")
	await create_timer(0.2).timeout
	assert(notice.visible, "Reaching the fifth regular level did not raise the music break notice")
	assert(int(game.get("_run_number")) == break_level - 1, "The board started before the interlude finished")

	var deadline := Time.get_ticks_msec() + 30000
	while not credits.visible:
		assert(Time.get_ticks_msec() < deadline, "The music break never handed off to the credits")
		await create_timer(0.1).timeout
	await create_timer(0.4).timeout
	assert(not notice.visible, "The notice stayed up over the credits")
	assert(continue_root.visible, "The credits came up without the continue button")
	assert(not (credits.get_node("BackButton") as Button).visible, "The credits kept their back button during the music break")
	assert(int(game.get("_run_number")) == break_level - 1, "The board started while the credits were playing")

	# 按【继续玩】：名单收掉，这一关照常开起来。
	continue_button.pressed.emit()
	deadline = Time.get_ticks_msec() + 10000
	while int(game.get("_run_number")) != break_level:
		assert(Time.get_ticks_msec() < deadline, "Pressing 继续玩 never started the level")
		await create_timer(0.1).timeout
	assert(not credits.visible, "The credits stayed up after 继续玩")

	# 同一局里只演一次。
	game.call("_start_game")
	await create_timer(0.3).timeout
	assert(not notice.visible, "The music break played twice in one run")
	assert(int(game.get("_run_number")) == break_level + 1, "The level after the break did not start normally")
	print("Music break interlude: notice, credits jukebox and 继续玩 handoff passed")
	quit()
