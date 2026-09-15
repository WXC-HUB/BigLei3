extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(8.0).timeout.connect(func() -> void:
		push_error("First normal-level heal test timed out")
		quit(2)
	)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame

	# 教学段长度以 main.gd 的常量为准：最后一盘教学打完，下一盘才是第一盘正式关。
	var tutorial_count := int(game.get("TUTORIAL_LEVEL_COUNT"))
	game.set("_run_number", tutorial_count)
	game.set("_player_hp", 1)
	game.call("_start_game")
	await process_frame
	assert(int(game.get("_run_number")) == tutorial_count + 1, "Test did not enter the first normal level")
	assert(
		int(game.get("_player_hp")) == int(game.get("_player_max_hp")),
		"Finishing the tutorial did not restore full health"
	)

	game.set("_player_hp", 1)
	game.call("_start_game")
	await process_frame
	assert(int(game.get("_run_number")) == tutorial_count + 2, "Test did not enter the second normal level")
	assert(int(game.get("_player_hp")) == 1, "Later normal levels incorrectly restored health")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame
	print("First normal level restores health exactly once")
	quit()
