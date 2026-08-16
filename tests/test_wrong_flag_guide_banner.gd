extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(8.0).timeout.connect(func() -> void:
		push_error("Wrong-flag guide banner test timed out")
		quit(2)
	)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.call("_start_game")
	await process_frame
	var banner := game.get("_wrong_flag_guide_banner") as WrongFlagGuideBanner
	assert(banner != null and not banner.banner.visible, "Wrong-flag guide flashed before damage")

	game.set("_player_hp", 3)
	game.call("_play_wrong_flag_player_hit", 0)
	await create_timer(0.5).timeout
	assert(int(game.get("_player_hp")) == 2, "Wrong flag did not deal damage")
	assert(bool(game.get("_wrong_flag_damage_guide_shown")), "Wrong-flag guide was not recorded")
	assert(banner.banner.visible, "Wrong-flag guide banner did not appear")
	assert(banner.presentation_count == 1, "Wrong-flag guide did not present exactly once")

	game.call("_play_wrong_flag_player_hit", 0)
	await create_timer(0.5).timeout
	assert(banner.presentation_count == 1, "Wrong-flag guide repeated after the first damage")

	print("Wrong-flag guide: first real damage presents one non-blocking banner")
	quit()
